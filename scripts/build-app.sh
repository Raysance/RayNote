#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"

# Some Command Line Tools beta releases expose a newer SDK without shipping its
# matching SwiftUI macro host. Prefer the newest installed pre-macro SDK there.
if [[ ! -e /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/libSwiftUIMacros.dylib ]] && \
   [[ -d /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk ]]; then
  SDK_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk"
fi

cd "$ROOT_DIR"
swift build -c release --sdk "$SDK_PATH"

APP_DIR="$ROOT_DIR/dist/RayNote.app"
CONTENTS_DIR="$APP_DIR/Contents"
mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"
cp "$ROOT_DIR/.build/release/RayNote" "$CONTENTS_DIR/MacOS/RayNote"
cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
codesign --force --deep --sign - "$APP_DIR"

echo "Built $APP_DIR"
