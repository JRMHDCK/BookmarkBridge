#!/bin/sh
set -eu

SCRIPT_DIRECTORY=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DMG_DIRECTORY=$(CDPATH= cd -- "$SCRIPT_DIRECTORY/.." && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$DMG_DIRECTORY/../.." && pwd)

PROJECT="$REPOSITORY_ROOT/BookmarkBridge.xcodeproj"
SCHEME="BookmarkBridge"
VOLUME_NAME="BookmarkBridge"
BACKGROUND_SOURCE="$REPOSITORY_ROOT/BookmarkBridge/Assets.xcassets/AppIcon.appiconset/AppIcon-512@2x.png"
BACKGROUND_IMAGE="$DMG_DIRECTORY/Background/BookmarkBridge-DMG-Background.png"
LAYOUT_SCRIPT="$DMG_DIRECTORY/Templates/DMGLayout.applescript"
OUTPUT_DIRECTORY=${DMG_OUTPUT_DIRECTORY:-"$DMG_DIRECTORY/Output"}

require_tool() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Missing required macOS tool: $1" >&2
        exit 1
    fi
}

for tool in xcodebuild hdiutil osascript SetFile swift ditto; do
    require_tool "$tool"
done

if [ ! -f "$BACKGROUND_SOURCE" ]; then
    echo "Official BookmarkBridge icon not found: $BACKGROUND_SOURCE" >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIRECTORY" "$DMG_DIRECTORY/Background"

WORK_DIRECTORY=$(mktemp -d "${TMPDIR:-/tmp}/bookmarkbridge-dmg.XXXXXX")
ARCHIVE_PATH="$WORK_DIRECTORY/BookmarkBridge.xcarchive"
STAGING_DIRECTORY="$WORK_DIRECTORY/staging"
MOUNT_DIRECTORY="/Volumes/$VOLUME_NAME"
READ_WRITE_DMG="$WORK_DIRECTORY/BookmarkBridge-rw.dmg"
FINAL_TEMP_DMG="$WORK_DIRECTORY/BookmarkBridge-final.dmg"
MOUNTED=0

cleanup() {
    if [ "$MOUNTED" -eq 1 ]; then
        hdiutil detach "$MOUNT_DIRECTORY" -quiet -force >/dev/null 2>&1 || true
    fi
    rm -rf "$WORK_DIRECTORY"
}
trap cleanup EXIT INT TERM

echo "Generating DMG background…"
CLANG_MODULE_CACHE_PATH="$WORK_DIRECTORY/ModuleCache" \
SWIFT_MODULECACHE_PATH="$WORK_DIRECTORY/ModuleCache" \
swift "$SCRIPT_DIRECTORY/generate-background.swift" \
    "$BACKGROUND_SOURCE" \
    "$BACKGROUND_IMAGE"

echo "Building unsigned Release archive…"
xcodebuild archive \
    -quiet \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -archivePath "$ARCHIVE_PATH" \
    -derivedDataPath "$WORK_DIRECTORY/DerivedData" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO

APPLICATION="$ARCHIVE_PATH/Products/Applications/BookmarkBridge.app"
if [ ! -d "$APPLICATION" ]; then
    echo "Release application was not produced: $APPLICATION" >&2
    exit 1
fi

VERSION=$(
    /usr/libexec/PlistBuddy \
        -c "Print :CFBundleShortVersionString" \
        "$APPLICATION/Contents/Info.plist"
)
BUILD=$(
    /usr/libexec/PlistBuddy \
        -c "Print :CFBundleVersion" \
        "$APPLICATION/Contents/Info.plist"
)
FINAL_DMG="$OUTPUT_DIRECTORY/BookmarkBridge-${VERSION}-build-${BUILD}.dmg"

if [ -e "$MOUNT_DIRECTORY" ]; then
    echo "A volume is already mounted at $MOUNT_DIRECTORY" >&2
    exit 1
fi

mkdir -p "$STAGING_DIRECTORY/.background"
ditto "$APPLICATION" "$STAGING_DIRECTORY/BookmarkBridge.app"
cp "$BACKGROUND_IMAGE" "$STAGING_DIRECTORY/.background/BookmarkBridge-DMG-Background.png"
ln -s /Applications "$STAGING_DIRECTORY/Applications"

echo "Creating writable disk image…"
hdiutil create \
    -quiet \
    -srcfolder "$STAGING_DIRECTORY" \
    -volname "$VOLUME_NAME" \
    -fs HFS+ \
    -format UDRW \
    "$READ_WRITE_DMG"

hdiutil attach \
    -quiet \
    -readwrite \
    -noverify \
    "$READ_WRITE_DMG"
MOUNTED=1

if [ ! -d "$MOUNT_DIRECTORY" ]; then
    echo "Disk image did not mount at $MOUNT_DIRECTORY" >&2
    exit 1
fi

SetFile -a V "$MOUNT_DIRECTORY/.background"

echo "Applying Finder presentation…"
sleep 2
osascript "$LAYOUT_SCRIPT" \
    "$VOLUME_NAME" \
    "BookmarkBridge-DMG-Background.png"

if [ ! -d "$MOUNT_DIRECTORY/BookmarkBridge.app" ]; then
    echo "Mounted DMG does not contain BookmarkBridge.app" >&2
    exit 1
fi
if [ ! -L "$MOUNT_DIRECTORY/Applications" ] \
    || [ "$(readlink "$MOUNT_DIRECTORY/Applications")" != "/Applications" ]; then
    echo "Mounted DMG has an invalid Applications link" >&2
    exit 1
fi
if [ ! -f "$MOUNT_DIRECTORY/.background/BookmarkBridge-DMG-Background.png" ]; then
    echo "Mounted DMG background is missing" >&2
    exit 1
fi
if [ ! -f "$MOUNT_DIRECTORY/.DS_Store" ]; then
    echo "Finder presentation was not saved in the DMG" >&2
    exit 1
fi

sync
sleep 2
hdiutil detach "$MOUNT_DIRECTORY" -quiet
MOUNTED=0

echo "Compressing final disk image…"
hdiutil convert \
    -quiet \
    "$READ_WRITE_DMG" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$FINAL_TEMP_DMG"

rm -f "$FINAL_DMG"
mv "$FINAL_TEMP_DMG" "$FINAL_DMG"
hdiutil verify "$FINAL_DMG" >/dev/null

DMG_SIZE=$(stat -f "%z" "$FINAL_DMG")
DMG_SHA256=$(shasum -a 256 "$FINAL_DMG" | awk '{print $1}')

echo "DMG created successfully:"
echo "$FINAL_DMG"
echo "Size: $DMG_SIZE bytes"
echo "SHA-256: $DMG_SHA256"
