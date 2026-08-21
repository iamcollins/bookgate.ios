#!/bin/sh
#
# Xcode Cloud runs this automatically after cloning the repo.
#
# Give every Cloud build a unique, increasing CFBundleVersion. Without it the build number
# stays at whatever is committed (1), and App Store Connect rejects the second and every
# later upload of a version as a duplicate — the first build works, so this is a trap that
# only springs once you are relying on TestFlight.
#
# BookGate builds its Info.plist with GENERATE_INFOPLIST_FILE, so CFBundleVersion comes from
# the CURRENT_PROJECT_VERSION build setting rather than a plist key. That means patching the
# project file, not the plist (Thrise and PillSeal patch a plist because they carry a full
# one). Both the app and the test target are stamped; only the app's is used.
set -e

PROJECT="$CI_PRIMARY_REPOSITORY_PATH/BookGate.xcodeproj/project.pbxproj"

if [ -z "$CI_BUILD_NUMBER" ]; then
    echo "CI_BUILD_NUMBER unset — leaving CURRENT_PROJECT_VERSION unchanged."
    exit 0
fi
if [ ! -f "$PROJECT" ]; then
    echo "warning: $PROJECT not found — leaving CURRENT_PROJECT_VERSION unchanged."
    exit 0
fi

sed -i '' -E "s/CURRENT_PROJECT_VERSION = [0-9]+;/CURRENT_PROJECT_VERSION = $CI_BUILD_NUMBER;/g" "$PROJECT"
echo "Set CURRENT_PROJECT_VERSION to $CI_BUILD_NUMBER"
grep -c "CURRENT_PROJECT_VERSION = $CI_BUILD_NUMBER;" "$PROJECT" | sed 's/^/  targets stamped: /'
