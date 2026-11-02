#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

echo "=== Building Tanks of Freedom for Android ==="

# 1. Ensure Godot 2.1.6 headless and templates are available
GODOT_BIN=""
if command -v godot_headless >/dev/null 2>&1; then
    GODOT_BIN="godot_headless"
elif command -v linux_server.64 >/dev/null 2>&1; then
    GODOT_BIN="linux_server.64"
elif [ -x "/home/fervi/godot-2.1.6/Godot_v2.1.6-stable_linux_server.64" ]; then
    GODOT_BIN="/home/fervi/godot-2.1.6/Godot_v2.1.6-stable_linux_server.64"
else
    echo "Downloading Godot 2.1.6 headless..."
    mkdir -p "$HOME/.cache/godot2"
    curl -sL "https://github.com/godotengine/godot/releases/download/2.1.6-stable/Godot_v2.1.6-stable_linux_server.64.zip" -o "$HOME/.cache/godot2/godot.zip"
    unzip -q -o "$HOME/.cache/godot2/godot.zip" -d "$HOME/.cache/godot2/"
    chmod +x "$HOME/.cache/godot2/Godot_v2.1.6-stable_linux_server.64"
    GODOT_BIN="$HOME/.cache/godot2/Godot_v2.1.6-stable_linux_server.64"
fi

if [ ! -f "$HOME/.godot/templates/android_release.apk" ]; then
    echo "Downloading Godot 2.1.6 export templates..."
    mkdir -p "$HOME/.godot/templates" "$HOME/.local/share/godot/templates"
    TMP_TPL=$(mktemp -d)
    curl -sL "https://github.com/godotengine/godot/releases/download/2.1.6-stable/Godot_v2.1.6-stable_export_templates.tpz" -o "$TMP_TPL/templates.zip"
    unzip -q "$TMP_TPL/templates.zip" -d "$TMP_TPL"
    cp -r "$TMP_TPL/templates/"* "$HOME/.godot/templates/"
    cp -r "$TMP_TPL/templates/"* "$HOME/.local/share/godot/templates/"
    rm -rf "$TMP_TPL"
fi

# 2. Setup configs
cp buildConfig/engine_android.cfg engine.cfg
cp buildConfig/export_android.cfg export.cfg

trap 'git checkout engine.cfg 2>/dev/null || true; rm -f export.cfg' EXIT

OUTPUT_DIR="$ROOT_DIR/build"
mkdir -p "$OUTPUT_DIR"
UNSIGNED_APK="$OUTPUT_DIR/tof-unsigned.apk"
ALIGNED_APK="$OUTPUT_DIR/TanksOfFreedom-0.7.1-beta.apk"

echo "Exporting Android APK with $GODOT_BIN..."
"$GODOT_BIN" -export "Android" "$UNSIGNED_APK"

# 3. Find Android build-tools (zipalign, apksigner)
ZIPALIGN_BIN="zipalign"
APKSIGNER_BIN="apksigner"
if ! command -v zipalign >/dev/null 2>&1; then
    for bt in "${ANDROID_HOME:-/home/fervi/android-sdk}"/build-tools/*; do
        if [ -x "$bt/zipalign" ]; then
            ZIPALIGN_BIN="$bt/zipalign"
            APKSIGNER_BIN="$bt/apksigner"
            break
        fi
    done
fi

echo "Aligning APK..."
rm -f "$ALIGNED_APK"
"$ZIPALIGN_BIN" -v 4 "$UNSIGNED_APK" "$ALIGNED_APK" >/dev/null
rm -f "$UNSIGNED_APK"

# 4. Sign APK
KEYSTORE="${KEYSTORE_PATH:-$HOME/.android/debug.keystore}"
KEYSTORE_PASS="${KEYSTORE_PASS:-android}"
KEY_ALIAS="${KEY_ALIAS:-androiddebugkey}"
KEY_PASS="${KEY_PASS:-android}"

if [ -f "$KEYSTORE" ]; then
    echo "Signing APK with $KEYSTORE..."
    "$APKSIGNER_BIN" sign --ks "$KEYSTORE" --ks-pass "pass:$KEYSTORE_PASS" --ks-key-alias "$KEY_ALIAS" --key-pass "pass:$KEY_PASS" "$ALIGNED_APK"
    "$APKSIGNER_BIN" verify "$ALIGNED_APK"
    echo "Signing successful!"
else
    echo "Keystore not found at $KEYSTORE, leaving unsigned."
fi

echo "=== Build complete: $ALIGNED_APK ==="
