#!/usr/bin/env sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
MODULE="$ROOT/module"

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

[ -f "$MODULE/module.prop" ] || fail 'module/module.prop is missing'

prop() {
    sed -n "s/^$1=//p" "$MODULE/module.prop" | head -n 1
}

[ "$(prop id)" = 'neorender-engine' ] || fail 'unexpected module id'
[ "$(prop version)" = 'v1.0.0' ] || fail 'unexpected version'
[ "$(prop versionCode)" = '10000' ] || fail 'unexpected versionCode'
[ "$(prop author)" = 'Lolokeksu' ] || fail 'unexpected author'
[ "$(prop updateJson)" = 'https://raw.githubusercontent.com/lolokeksu/neorender-engine/main/update.json' ] || fail 'unexpected updateJson'

required='module.prop action.sh common/functions.sh config.conf.default customize.sh neorender neorenderctl post-fs-data.sh service.sh uninstall.sh'
for rel in $required; do
    [ -f "$MODULE/$rel" ] || fail "missing module file: $rel"
done

for rel in README.md README_RU.md CHANGELOG.md RELEASE_NOTES.md SECURITY.md LICENSE update.json; do
    [ -f "$ROOT/$rel" ] || fail "missing repository file: $rel"
done

grep -q '"version": "v1.0.0"' "$ROOT/update.json" || fail 'update.json version mismatch'
grep -q '"versionCode": 10000' "$ROOT/update.json" || fail 'update.json versionCode mismatch'
grep -q '/releases/download/v1.0.0/NeoRender_Engine_v1.0.0_RMX3700_RMX3701_Android13.zip' "$ROOT/update.json" || fail 'update.json zipUrl mismatch'

syntax_files=$(find "$MODULE" "$ROOT/scripts" -type f \( -name '*.sh' -o -name neorender -o -name neorenderctl \) | LC_ALL=C sort)
for file in $syntax_files; do
    sh -n "$file" || fail "POSIX syntax failed: $file"
    if command -v busybox >/dev/null 2>&1; then
        busybox ash -n "$file" || fail "BusyBox ash syntax failed: $file"
    fi
    if grep -q "$(printf '\r')" "$file"; then
        fail "CRLF detected: $file"
    fi
done

runtime_shell_files=$(find "$MODULE" -type f \( -name '*.sh' -o -name neorender -o -name neorenderctl \) | LC_ALL=C sort)
if grep -En '(^|[;&|[:space:]])(curl|wget)([[:space:]]|$)|(^|[;&|[:space:]])eval([[:space:]]|$)|setenforce[[:space:]]+0|chmod[[:space:]]+(-R[[:space:]]+)?0?777|/dev/block/' $runtime_shell_files; then
    fail 'forbidden high-risk shell construct detected'
fi

if grep -En 'pm[[:space:]]+uninstall|touch[^#\n]*\/remove([[:space:]]|$)' $runtime_shell_files; then
    fail 'silent application or module removal detected'
fi

if find "$MODULE" -type f \( -name '*.apk' -o -name '*.so' -o -name '*.elf' -o -name '*.bin' \) | grep -q .; then
    fail 'native binary or APK found in module tree'
fi

printf 'All source checks passed.\n'
