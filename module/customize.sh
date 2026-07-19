#!/system/bin/sh

ui_print '=========================================='
ui_print ' NeoRender Engine v1.0.0'
ui_print ' Public release / RMX3700-RMX3701'
ui_print ' RMX3700-RMX3701 / Android 13'
ui_print '=========================================='

API_NOW="$(getprop ro.build.version.sdk)"
IDENTITY="$(getprop ro.product.model) $(getprop ro.product.name) $(getprop ro.product.device) $(getprop ro.product.marketname) $(getprop ro.build.product)"
REALME_ID="$(getprop ro.product.manufacturer) $(getprop ro.product.brand)"
QCOM_ID="$(getprop ro.soc.manufacturer) $(getprop ro.hardware) $(getprop ro.board.platform)"

ui_print "- Device: $(getprop ro.product.model)"
ui_print "- Identity: $IDENTITY"
ui_print "- Android: $(getprop ro.build.version.release) (API $API_NOW)"
ui_print "- SoC: $(getprop ro.soc.manufacturer) $(getprop ro.soc.model)"
[ "$API_NOW" = 33 ] || abort '! NeoRender Engine v1.0.0 предназначен только для Android 13 (API 33).'
printf '%s' "$REALME_ID" | grep -qi realme || abort '! Устройство Realme не обнаружено.'
if ! printf '%s' "$QCOM_ID" | grep -Eqi 'qualcomm|qcom' && [ ! -e /vendor/lib64/hw/vulkan.adreno.so ] && [ ! -e /vendor/lib/hw/vulkan.adreno.so ]; then
    abort '! Платформа Qualcomm/Adreno не обнаружена.'
fi
[ "$(getprop ro.boot.qemu)" != 1 ] || abort '! Эмулятор не поддерживается.'
printf '%s' "$IDENTITY" | grep -Eqi 'RMX3700|RMX3701|GT[[:space:]_-]*Neo[[:space:]_-]*5[[:space:]_-]*SE|GT[[:space:]_-]*Neo5[[:space:]_-]*SE' \
    || abort '! Целевая модель RMX3700/RMX3701 (Realme GT Neo 5 SE) не подтверждена.'
ui_print '- Целевая модель подтверждена.'

STATE_DIR=/data/adb/neorender-engine
STATE_SUBDIR="$STATE_DIR/state"
CONFIG="$STATE_DIR/config.conf"
OLD_MODULE_DIR=/data/adb/modules/neorender-engine
mkdir -p "$STATE_SUBDIR" "$STATE_DIR/logs" "$STATE_DIR/reports" "$STATE_DIR/backups" "$STATE_DIR/bench" "$STATE_DIR/history"
chmod 0700 "$STATE_DIR" "$STATE_SUBDIR" "$STATE_DIR/backups" "$STATE_DIR/bench" "$STATE_DIR/history" 2>/dev/null
chmod 0755 "$STATE_DIR/logs" "$STATE_DIR/reports" 2>/dev/null

stamp="$(date '+%Y%m%d-%H%M%S' 2>/dev/null || echo update)"
previous_profile=""
previous_disabled=0
[ -f "$OLD_MODULE_DIR/disable" ] && previous_disabled=1
if [ -f "$CONFIG" ]; then
    previous_profile="$(awk -F= '$1 ~ /^[[:space:]]*PROFILE[[:space:]]*$/ {gsub(/[[:space:]]/,"",$2); print $2; exit}' "$CONFIG" 2>/dev/null)"
    backup="$STATE_DIR/backups/pre-v1.0.0-$stamp"
    mkdir -p "$backup"
    cp -f "$CONFIG" "$backup/config.conf" 2>/dev/null
    [ -f "$STATE_DIR/app-profiles.conf" ] && cp -f "$STATE_DIR/app-profiles.conf" "$backup/app-profiles.conf" 2>/dev/null
    [ -f "$STATE_DIR/recommendations.tsv" ] && cp -f "$STATE_DIR/recommendations.tsv" "$backup/recommendations.tsv" 2>/dev/null
    [ -f "$STATE_SUBDIR/safe-mode.txt" ] && cp -f "$STATE_SUBDIR/safe-mode.txt" "$backup/safe-mode.txt" 2>/dev/null
    [ -f "$STATE_SUBDIR/profile-quarantine.txt" ] && cp -f "$STATE_SUBDIR/profile-quarantine.txt" "$backup/profile-quarantine.txt" 2>/dev/null
    ui_print "- Резервная копия предыдущей версии: $backup"
else
    cp -f "$MODPATH/config.conf.default" "$CONFIG"
    ui_print '- Создана безопасная конфигурация схемы 4.'
fi
chmod 0600 "$CONFIG" 2>/dev/null
[ -f "$STATE_DIR/app-profiles.conf" ] || : > "$STATE_DIR/app-profiles.conf"
[ -f "$STATE_DIR/recommendations.tsv" ] || : > "$STATE_DIR/recommendations.tsv"
chmod 0600 "$STATE_DIR/app-profiles.conf" "$STATE_DIR/recommendations.tsv"

set_config_key() {
    wanted="$1"; replacement="$2"; tmp="$CONFIG.tmp.$$"
    awk -v wanted="$wanted" -v replacement="$replacement" '
        BEGIN { changed=0 }
        {
            line=$0
            if (line !~ /^[[:space:]]*#/ && line ~ /^[[:space:]]*[A-Za-z0-9_]+[[:space:]]*=/) {
                split(line, p, "="); key=p[1]
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
                if (key == wanted) { print wanted "=" replacement; changed=1; next }
            }
            print line
        }
        END { if (!changed) print wanted "=" replacement }
    ' "$CONFIG" > "$tmp" && mv -f "$tmp" "$CONFIG"
}

while IFS='=' read -r key value; do
    case "$key" in ''|'#'*) continue ;; esac
    clean="$(printf '%s' "$key" | tr -d '[:space:]')"
    printf '%s' "$clean" | grep -Eq '^[A-Z0-9_]+$' || continue
    grep -Eq "^[[:space:]]*${clean}[[:space:]]*=" "$CONFIG" 2>/dev/null || printf '%s=%s\n' "$clean" "$value" >> "$CONFIG"
done < "$MODPATH/config.conf.default"
set_config_key CONFIG_SCHEMA 4
set_config_key STRICT_TARGET_MODEL 1
set_config_key PROFILE_QUARANTINE 1
set_config_key STABILITY_DELAY_SECONDS 60
set_config_key WATCHDOG_SECONDS 120
set_config_key STOCK_WATCHDOG_SECONDS 30
set_config_key SYSTEMUI_RESTART_LIMIT 4
set_config_key PROPERTY_OVERRIDE_LIMIT 3

case "$previous_profile" in stock|compatibility|vulkan) : ;; *) previous_profile=stock ;; esac
if [ "$previous_profile" = vulkan ] || [ "$previous_disabled" -eq 1 ]; then
    set_config_key PROFILE stock
else
    set_config_key PROFILE "$previous_profile"
fi
chmod 0600 "$CONFIG"

if [ -f "$STATE_SUBDIR/baseline.renderer" ]; then
    value="$(cat "$STATE_SUBDIR/baseline.renderer" 2>/dev/null)"
    if [ "$value" = '__NEORENDER_EMPTY_PROPERTY__' ] || [ -z "$value" ]; then
        resetprop --delete debug.hwui.renderer >/dev/null 2>&1 || resetprop -n debug.hwui.renderer '' >/dev/null 2>&1
    else
        resetprop -n debug.hwui.renderer "$value" >/dev/null 2>&1
    fi
    ui_print '- OEM renderer восстановлен перед первой загрузкой v1.0.0.'
fi

if [ "$previous_profile" = vulkan ] || [ "$previous_disabled" -eq 1 ] || [ -f "$STATE_SUBDIR/safe-mode.txt" ]; then
    {
        printf 'time=%s\n' "$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null)"
        printf 'reason=v1-safe-first-upgrade\n'
        printf 'profile=%s\n' "$previous_profile"
        printf 'renderer=%s\n' "$([ "$previous_profile" = vulkan ] && echo skiavk || { [ "$previous_profile" = compatibility ] && echo skiagl || echo stock; })"
        printf 'fingerprint=%s\n' "$(getprop ro.build.fingerprint)"
    } > "$STATE_SUBDIR/profile-quarantine.txt"
    chmod 0600 "$STATE_SUBDIR/profile-quarantine.txt" 2>/dev/null
    ui_print "! Предыдущий профиль '$previous_profile' помещён в карантин."
    ui_print '! Следующая загрузка будет выполнена в Stock для проверки стабильности.'
fi

rm -f "$OLD_MODULE_DIR/disable" "$MODPATH/disable" "$STATE_SUBDIR/reboot-stock-required" 2>/dev/null

LEGACY_DIR=/data/adb/modules/core-render
LEGACY_STATE=/data/adb/core-render
if [ -d "$LEGACY_DIR" ] || [ -d "$LEGACY_STATE" ]; then
    legacy_backup="$STATE_DIR/backups/legacy-core-render-$stamp"
    mkdir -p "$legacy_backup"
    [ -f "$LEGACY_DIR/module.prop" ] && cp -f "$LEGACY_DIR/module.prop" "$legacy_backup/module.prop" 2>/dev/null
    [ -f "$LEGACY_STATE/config.conf" ] && cp -f "$LEGACY_STATE/config.conf" "$legacy_backup/config.conf" 2>/dev/null
    if [ -d "$LEGACY_DIR" ]; then
        touch "$LEGACY_DIR/disable"
        rm -f "$LEGACY_DIR/remove"
    fi
    printf '%s\n' "$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null)" > "$STATE_SUBDIR/legacy-core-render.detected"
    ui_print '! Старый core-render обнаружен и только отключён.'
fi

if pm list packages 2>/dev/null | grep -q '^package:bellavita.toast$'; then
    printf '%s\n' "$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null)" > "$STATE_SUBDIR/legacy-bellavita-toast.detected"
    ui_print '! Обнаружен bellavita.toast. NeoRender не удаляет приложения.'
else
    rm -f "$STATE_SUBDIR/legacy-bellavita-toast.detected"
fi

if [ -d "$STATE_SUBDIR/transaction/active" ]; then
    saved="$STATE_SUBDIR/transaction/active/saved.renderer"
    if [ -f "$saved" ]; then
        value="$(cat "$saved" 2>/dev/null)"
        if [ "$value" = '__NEORENDER_EMPTY_PROPERTY__' ] || [ -z "$value" ]; then
            resetprop --delete debug.hwui.renderer >/dev/null 2>&1 || resetprop -n debug.hwui.renderer '' >/dev/null 2>&1
        else
            resetprop -n debug.hwui.renderer "$value" >/dev/null 2>&1
        fi
    fi
    rm -rf "$STATE_SUBDIR/transaction/active"
    ui_print '- Незавершённая renderer-транзакция восстановлена.'
fi
rm -rf "$STATE_DIR/bench/active" "$STATE_DIR/bench/pair/active" 2>/dev/null

rm -f "$STATE_SUBDIR/boot.pending" "$STATE_SUBDIR/boot.recovery-stock" \
      "$STATE_SUBDIR/boot-failure.count" "$STATE_SUBDIR/boot-warning.txt" \
      "$STATE_SUBDIR/safe-mode.txt" 2>/dev/null

set_perm_recursive "$MODPATH" 0 0 0755 0644
for f in customize.sh post-fs-data.sh service.sh action.sh uninstall.sh neorender neorenderctl system/bin/neorender system/bin/neorenderctl; do
    set_perm "$MODPATH/$f" 0 0 0755
done
set_perm "$MODPATH/common/functions.sh" 0 0 0644

ui_print '- NeoRender не отключает весь модуль при renderer-сбое.'
ui_print '- Нестабильный профиль переводится в карантин, PROFILE становится Stock.'
ui_print '- Stock/SkiaGL сохраняются; активный Vulkan после обновления проходит Stock-проверку.'
ui_print '- Главное меню после reboot: neorender'
ui_print '- После успешной Stock-загрузки тестируйте SkiaVK сначала на приложениях.'
