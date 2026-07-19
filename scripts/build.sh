#!/usr/bin/env sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
MODULE="$ROOT/module"
BUILD="$ROOT/build/module"
DIST="$ROOT/dist"

"$ROOT/scripts/test.sh"

rm -rf "$ROOT/build" "$DIST"
mkdir -p "$BUILD" "$DIST"
cp -a "$MODULE/." "$BUILD/"

# Keep release documentation authoritative at repository root.
for file in README.md README_RU.md CHANGELOG.md RELEASE_NOTES.md SECURITY.md LICENSE; do
    cp "$ROOT/$file" "$BUILD/$file"
done

# system/bin copies are generated, not maintained independently.
mkdir -p "$BUILD/system/bin"
cp "$BUILD/neorender" "$BUILD/system/bin/neorender"
cp "$BUILD/neorenderctl" "$BUILD/system/bin/neorenderctl"
chmod 0755 "$BUILD/neorender" "$BUILD/neorenderctl" \
    "$BUILD/system/bin/neorender" "$BUILD/system/bin/neorenderctl"

rm -f "$BUILD/SHA256SUMS" "$BUILD/RUNTIME_SHA256SUMS"

runtime_files='module.prop action.sh common/functions.sh config.conf.default neorender neorenderctl post-fs-data.sh service.sh system/bin/neorender system/bin/neorenderctl uninstall.sh'
: > "$BUILD/RUNTIME_SHA256SUMS"
for rel in $runtime_files; do
    [ -f "$BUILD/$rel" ] || { printf 'Missing runtime file: %s\n' "$rel" >&2; exit 1; }
    (cd "$BUILD" && sha256sum "$rel") >> "$BUILD/RUNTIME_SHA256SUMS"
done

(
    cd "$BUILD"
    find . -type f ! -name SHA256SUMS -print | sed 's#^./##' | LC_ALL=C sort | while IFS= read -r rel; do
        sha256sum "$rel"
    done > SHA256SUMS
)

VERSION=$(sed -n 's/^version=//p' "$BUILD/module.prop" | head -n 1)
NAME="NeoRender_Engine_${VERSION}_RMX3700_RMX3701_Android13.zip"
ZIP="$DIST/$NAME"

(
    cd "$BUILD"
    zip -q -9 -r "$ZIP" .
)

unzip -t "$ZIP" >/dev/null
sha256sum "$ZIP" > "$ZIP.sha256"

printf 'Built: %s\n' "$ZIP"
printf 'SHA-256: %s\n' "$(awk '{print $1}' "$ZIP.sha256")"
