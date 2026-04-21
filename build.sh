#!/bin/bash
set -euo pipefail

PROJECT="ClickNFix.xcodeproj"
SCHEME="ClickNFix"
CONFIGURATION="Release"
BUILD_PATH="build"
APP_PATH="$BUILD_PATH/Build/Products/$CONFIGURATION/ClickNFix.app"

mkdir -p "$BUILD_PATH"

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$BUILD_PATH" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="-" \
  build

codesign --force --sign - --deep --timestamp=none "$APP_PATH"

echo "Ad-hoc signed app built at $APP_PATH"
