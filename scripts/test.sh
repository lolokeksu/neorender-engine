#!/usr/bin/env sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
MODULE="$ROOT/module"
TMP="${TMPDIR:-/tmp}/neorender-test.$$"
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
prop() { sed -n "s/^$1=//p" "$MODULE/module.prop" | head -n 1; }
[ "$(prop id)" = 'neorender-engine' ] || fail 'unexpected module id'
[ "$(prop version)" = 'v1.0.0' ] || fail 'unexpected version'
[ "$(prop versionCode)" = '10000' ] || fail 'unexpected versionCode'
[ "$(prop author)" = 'Lolokeksu' ] || fail 'unexpected author'
[ "$(prop updateJson)" = 'https://raw.githubusercontent.com/lolokeksu/neorender-engine/main/update.json' ] || fail 'unexpected updateJson'
for rel in module.prop action.sh config.conf.default customize.sh post-fs-data.sh service.sh uninstall.sh; do [ -f "$MODULE/$rel" ] || fail "missing module file: $rel"; done
for dir in functions menu controller; do find "$MODULE/src/$dir" -type f -name '*.sh' | grep -q . || fail "missing source fragments: $dir"; done
for rel in README.md README_RU.md CHANGELOG.md RELEASE_NOTES.md SECURITY.md LICENSE update.json; do [ -f "$ROOT/$rel" ] || fail "missing repository file: $rel"; done
grep -q '"version": "v1.0.0"' "$ROOT/update.json" || fail 'update.json version mismatch'
grep -q '"versionCode": 10000' "$ROOT/update.json" || fail 'update.json versionCode mismatch'
grep -q '/releases/download/v1.0.0/NeoRender_Engine_v1.0.0_RMX3700_RMX3701_Android13.zip' "$ROOT/update.json" || fail 'update.json zipUrl mismatch'
mkdir -p "$TMP/common"
assemble() { destination="$1"; shift; : > "$destination"; for part in "$@"; do cat "$part" >> "$destination"; printf '\n' >> "$destination"; done; }
assemble "$TMP/common/functions.sh" "$MODULE"/src/functions/*.sh
assemble "$TMP/neorender" "$MODULE"/src/menu/*.sh
assemble "$TMP/neorenderctl" "$MODULE"/src/controller/*.sh
syntax_files="$TMP/common/functions.sh $TMP/neorender $TMP/neorenderctl $(find "$MODULE" "$ROOT/scripts" -type f -name '*.sh' ! -path '*/src/*' | LC_ALL=C sort)"
for file in $syntax_files; do
    sh -n "$file" || fail "POSIX syntax failed: $file"
    if command -v busybox >/dev/null 2>&1; then busybox ash -n "$file" || fail "BusyBox ash syntax failed: $file"; fi
    if grep -q "$(printf '\r')" "$file"; then fail "CRLF detected: $file"; fi
done
scan_files="$TMP/common/functions.sh $TMP/neorender $TMP/neorenderctl $(find "$MODULE" -type f -name '*.sh' ! -path '*/src/*' | LC_ALL=C sort)"
if grep -En '(^|[;&|[:space:]])(curl|wget)([[:space:]]|$)|(^|[;&|[:space:]])eval([[:space:]]|$)|setenforce[[:space:]]+0|chmod[[:space:]]+(-R[[:space:]]+)?0?777|/dev/block/' $scan_files; then fail 'forbidden high-risk shell construct detected'; fi
if grep -En 'pm[[:space:]]+uninstall|touch[^#\n]*\/remove([[:space:]]|$)' $scan_files; then fail 'silent application or module removal detected'; fi
if find "$MODULE" -type f \( -name '*.apk' -o -name '*.so' -o -name '*.elf' -o -name '*.bin' \) | grep -q .; then fail 'native binary or APK found in module tree'; fi
printf 'All source checks passed.\n'
