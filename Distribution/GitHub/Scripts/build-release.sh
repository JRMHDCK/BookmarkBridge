#!/bin/sh
set -eu

SCRIPT_DIRECTORY=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
GITHUB_DIRECTORY=$(CDPATH= cd -- "$SCRIPT_DIRECTORY/.." && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$GITHUB_DIRECTORY/../.." && pwd)

PROJECT_FILE="$REPOSITORY_ROOT/BookmarkBridge.xcodeproj/project.pbxproj"
DMG_DIRECTORY="$REPOSITORY_ROOT/Distribution/DMG/Output"
DOCUMENTATION_DIRECTORY="$REPOSITORY_ROOT/Documentation"
USER_GUIDE="$REPOSITORY_ROOT/BookmarkBridge/Documentation/Resources/BookmarkBridge-User-Guide.pdf"
RELEASE_TEMPLATE="$GITHUB_DIRECTORY/Templates/RELEASE_NOTES.md.template"
CHANGELOG_TEMPLATE="$GITHUB_DIRECTORY/Templates/CHANGELOG.md.template"
RELEASE_ROOT=${GITHUB_RELEASE_DIRECTORY:-"$GITHUB_DIRECTORY/Release"}

require_tool() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Missing required tool: $1" >&2
        exit 1
    fi
}

for tool in awk date find git shasum stat; do
    require_tool "$tool"
done

read_build_setting() {
    awk -v key="$1" '
        $1 == key {
            value = $3
            sub(/;$/, "", value)
            print value
            exit
        }
    ' "$PROJECT_FILE"
}

VERSION=$(read_build_setting MARKETING_VERSION)
BUILD=$(read_build_setting CURRENT_PROJECT_VERSION)
MINIMUM_MACOS=$(read_build_setting MACOSX_DEPLOYMENT_TARGET)

if [ -z "$VERSION" ] || [ -z "$BUILD" ] || [ -z "$MINIMUM_MACOS" ]; then
    echo "Unable to read release metadata from the Xcode project" >&2
    exit 1
fi

DMG_NAME="BookmarkBridge-${VERSION}-build-${BUILD}.dmg"
DMG_SOURCE="$DMG_DIRECTORY/$DMG_NAME"

if [ ! -f "$DMG_SOURCE" ]; then
    echo "Expected DMG not found: $DMG_SOURCE" >&2
    echo "Run Distribution/DMG/Scripts/build-dmg.sh first." >&2
    exit 1
fi
if [ ! -f "$USER_GUIDE" ]; then
    echo "User guide not found: $USER_GUIDE" >&2
    exit 1
fi

RELEASE_NOTES_SOURCE=$(
    find "$DOCUMENTATION_DIRECTORY" \
        -maxdepth 1 \
        -type f \
        -name "RELEASE_NOTES_${VERSION}-*.md" \
        | sort \
        | head -n 1
)
if [ -n "$RELEASE_NOTES_SOURCE" ]; then
    RELEASE_LABEL=$(basename "$RELEASE_NOTES_SOURCE" .md)
    RELEASE_LABEL=${RELEASE_LABEL#RELEASE_NOTES_}
else
    RELEASE_LABEL="${VERSION}-build-${BUILD}"
fi

KNOWN_ISSUES_SOURCE="$DOCUMENTATION_DIRECTORY/KNOWN_ISSUES.md"
if [ ! -f "$KNOWN_ISSUES_SOURCE" ]; then
    echo "Known issues document not found: $KNOWN_ISSUES_SOURCE" >&2
    exit 1
fi

RELEASE_DATE=$(date "+%Y-%m-%d")
DMG_SHA256=$(shasum -a 256 "$DMG_SOURCE" | awk '{print $1}')
DMG_SIZE_BYTES=$(stat -f "%z" "$DMG_SOURCE")
DMG_SIZE_MIB=$(awk -v bytes="$DMG_SIZE_BYTES" 'BEGIN { printf "%.2f", bytes / 1048576 }')
DMG_SIZE="${DMG_SIZE_MIB} MiB (${DMG_SIZE_BYTES} octets)"
USER_GUIDE_NAME="BookmarkBridge-User-Guide.pdf"

OUTPUT_DIRECTORY="$RELEASE_ROOT/BookmarkBridge-${RELEASE_LABEL}"
case "$OUTPUT_DIRECTORY" in
    "$RELEASE_ROOT"/BookmarkBridge-*) ;;
    *)
        echo "Unsafe release output path: $OUTPUT_DIRECTORY" >&2
        exit 1
        ;;
esac

WORK_DIRECTORY=$(mktemp -d "${TMPDIR:-/tmp}/bookmarkbridge-github-release.XXXXXX")
cleanup() {
    rm -rf "$WORK_DIRECTORY"
}
trap cleanup EXIT INT TERM

KNOWN_ISSUES_BODY="$WORK_DIRECTORY/known-issues.md"
CHANGELOG_ENTRIES="$WORK_DIRECTORY/changelog-entries.md"

awk '
    NR == 1 && /^# / { next }
    /^## / { sub(/^## /, "### ") }
    { print }
' "$KNOWN_ISSUES_SOURCE" >"$KNOWN_ISSUES_BODY"

git -C "$REPOSITORY_ROOT" log \
    --reverse \
    --date=short \
    --pretty=format:'- `%h` — %ad — %s' \
    >"$CHANGELOG_ENTRIES"
printf '\n' >>"$CHANGELOG_ENTRIES"

render_template() {
    template=$1
    destination=$2

    awk \
        -v version="$VERSION" \
        -v build="$BUILD" \
        -v release_label="$RELEASE_LABEL" \
        -v release_date="$RELEASE_DATE" \
        -v minimum_macos="$MINIMUM_MACOS" \
        -v dmg_name="$DMG_NAME" \
        -v dmg_sha256="$DMG_SHA256" \
        -v dmg_size="$DMG_SIZE" \
        -v user_guide_name="$USER_GUIDE_NAME" \
        -v known_issues="$KNOWN_ISSUES_BODY" \
        -v changelog_entries="$CHANGELOG_ENTRIES" '
        function emit_file(path, line) {
            while ((getline line < path) > 0) {
                print line
            }
            close(path)
        }

        $0 == "{{KNOWN_ISSUES}}" {
            emit_file(known_issues)
            next
        }
        $0 == "{{CHANGELOG_ENTRIES}}" {
            emit_file(changelog_entries)
            next
        }

        {
            gsub(/\{\{VERSION\}\}/, version)
            gsub(/\{\{BUILD\}\}/, build)
            gsub(/\{\{RELEASE_LABEL\}\}/, release_label)
            gsub(/\{\{RELEASE_DATE\}\}/, release_date)
            gsub(/\{\{MINIMUM_MACOS\}\}/, minimum_macos)
            gsub(/\{\{DMG_NAME\}\}/, dmg_name)
            gsub(/\{\{DMG_SHA256\}\}/, dmg_sha256)
            gsub(/\{\{DMG_SIZE\}\}/, dmg_size)
            gsub(/\{\{USER_GUIDE_NAME\}\}/, user_guide_name)
            print
        }
    ' "$template" >"$destination"
}

rm -rf "$OUTPUT_DIRECTORY"
mkdir -p "$OUTPUT_DIRECTORY"

cp "$DMG_SOURCE" "$OUTPUT_DIRECTORY/$DMG_NAME"
cp "$USER_GUIDE" "$OUTPUT_DIRECTORY/$USER_GUIDE_NAME"
render_template \
    "$RELEASE_TEMPLATE" \
    "$OUTPUT_DIRECTORY/RELEASE_NOTES.md"
render_template \
    "$CHANGELOG_TEMPLATE" \
    "$OUTPUT_DIRECTORY/CHANGELOG.md"

cat >"$OUTPUT_DIRECTORY/SHA256.txt" <<EOF
$DMG_SHA256  $DMG_NAME
EOF

for expected in \
    "$DMG_NAME" \
    "SHA256.txt" \
    "RELEASE_NOTES.md" \
    "CHANGELOG.md" \
    "$USER_GUIDE_NAME"
do
    if [ ! -s "$OUTPUT_DIRECTORY/$expected" ]; then
        echo "Missing or empty release asset: $expected" >&2
        exit 1
    fi
done

GENERATED_SHA256=$(awk '{print $1}' "$OUTPUT_DIRECTORY/SHA256.txt")
COPIED_SHA256=$(shasum -a 256 "$OUTPUT_DIRECTORY/$DMG_NAME" | awk '{print $1}')
if [ "$GENERATED_SHA256" != "$COPIED_SHA256" ]; then
    echo "Copied DMG checksum does not match SHA256.txt" >&2
    exit 1
fi

echo "GitHub Release kit created successfully:"
echo "$OUTPUT_DIRECTORY"
echo "Release: $RELEASE_LABEL"
echo "DMG: $DMG_NAME"
echo "Size: $DMG_SIZE"
echo "SHA-256: $DMG_SHA256"
