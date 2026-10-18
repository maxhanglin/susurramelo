#!/usr/bin/env bash
# Builds Susurramelo.app and packages it as dist/Susurramelo-<version>-arm64.zip (+ .sha256)
# for a GitHub Release.
set -euo pipefail

cd "$(dirname "$0")/.."
scripts/build-app.sh

VERSION="$(plutil -extract CFBundleShortVersionString raw dist/Susurramelo.app/Contents/Info.plist)"
ZIP="dist/Susurramelo-${VERSION}-arm64.zip"

# Refuse to ship a binary that embeds local paths (e.g. /Users/<name>/...).
# `grep -c` reads all input: with `grep -q`, an early match makes `strings` die of SIGPIPE and,
# under pipefail, the whole check reads as "no match".
local_paths="$(strings -a dist/Susurramelo.app/Contents/MacOS/Susurramelo | grep -c '/Users/' || true)"
if [[ "$local_paths" -gt 0 ]]; then
    echo "error: the binary contains $local_paths local path(s); not packaging" >&2
    exit 1
fi

rm -f "$ZIP" "$ZIP.sha256"
# ditto keeps the bundle's code signature and extended attributes intact.
ditto -c -k --keepParent dist/Susurramelo.app "$ZIP"
(cd dist && shasum -a 256 "$(basename "$ZIP")" > "$(basename "$ZIP").sha256")
echo "Packaged $ZIP"
cat "$ZIP.sha256"
