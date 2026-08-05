#!/bin/bash
#
# Rebuild the installable Spoon zips in Spoons/ from the sources in Source/.
#
# SpoonInstall fetches docs/docs.json for the repo index, then downloads
# Spoons/<Name>.spoon.zip for whatever it's asked to install — so the zips are
# committed artifacts, not build output, and must be regenerated whenever a
# Source/ tree changes.
#
# Each zip contains the .spoon directory itself at its root, which is what
# Hammerspoon expects when it unpacks into ~/.hammerspoon/Spoons/.

set -euo pipefail

cd "$(dirname "$0")"

mkdir -p Spoons

for src in Source/*.spoon; do
    name=$(basename "$src")
    zip_path="Spoons/${name}.zip"
    rm -f "$zip_path"
    # -x excludes macOS cruft that would otherwise ride along.
    (cd Source && zip -qr "../$zip_path" "$name" -x '*.DS_Store' -x '__MACOSX/*')
    echo "built $zip_path"
done

echo
echo "Reminder: if you added or renamed a Spoon, update docs/docs.json too —"
echo "SpoonInstall resolves downloads by the 'name' field in that index."
