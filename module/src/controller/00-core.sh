#!/system/bin/sh

MODDIR=${0%/*}
[ -f "$MODDIR/common/functions.sh" ] || MODDIR=/data/adb/modules/neorender-engine
NEORENDER_MODULE_DIR="$MODDIR"
. "$MODDIR/common/functions.sh"

ensure_state_dirs
[ -f "$CONFIG_FILE" ] || cp -f "$MODDIR/config.conf.default" "$CONFIG_FILE"
merge_config_defaults "$MODDIR/config.conf.default"
recover_stale_transaction >/dev/null 2>&1 || true

usage() {
    cat <<'USAGE'
NeoRender Engine v1.0.0 control utility

Основные команды:
  neorenderctl status
  neorenderctl profile stock|compatibility|vulkan
  neorenderctl apply
  neorenderctl restore
  neorenderctl verify [package.name]
  neorenderctl doctor
  neorenderctl report
  neorenderctl conflicts
  neorenderctl self-check
  neorenderctl menu

Персональные профили:
  neorenderctl app list
  neorenderctl app set package.name skiagl|skiavk
  neorenderctl app remove package.name
  neorenderctl app launch package.name [skiagl|skiavk]

Обычный benchmark:
  neorenderctl bench start package.name [skiagl|skiavk]
  neorenderctl bench stop package.name
  neorenderctl bench status

Парный A/B benchmark:
  neorenderctl bench pair start package.name
  neorenderctl bench pair next package.name
  neorenderctl bench pair finish package.name
  neorenderctl bench pair status
  neorenderctl bench pair abort

Рекомендации:
  neorenderctl recommend list
  neorenderctl recommend show package.name
  neorenderctl recommend apply package.name
  neorenderctl recommend remove package.name

Диагностика и обслуживание:
  neorenderctl gfx reset package.name
  neorenderctl gfx capture package.name
  neorenderctl config show|validate|reset
  neorenderctl safe disable|clear
  neorenderctl quarantine show|clear
  neorenderctl backup
  neorenderctl support
  neorenderctl logs [число_строк]
  neorenderctl history [число_строк]
  neorenderctl paths

Важно: debug.hwui.renderer читается при инициализации процесса.
Модуль не переводит уже работающий процесс и игровой движок на другой API.
USAGE
}

show_status() {
    profile="$(config_get PROFILE stock)"; baseline='<not captured>'
    if [ -f "$STATE_SUBDIR/baseline.renderer" ]; then baseline="$(cat "$STATE_SUBDIR/baseline.renderer" 2>/dev/null)"; [ "$baseline" = "$EMPTY_MARKER" ] && baseline='<empty>'; fi
    foreground="$(top_package)"; pipeline=''; [ -n "$foreground" ] && pipeline="$(pipeline_for_package "$foreground")"
    echo "NeoRender Engine $(module_version)"
    echo "Config schema: $(config_get CONFIG_SCHEMA 0)"
    echo "Profile: $profile"
    echo "Active $RENDERER_PROP: $(read_prop "$RENDERER_PROP")"
    echo "OEM baseline: $baseline"
    echo "Target model: $(is_target_model && echo confirmed || echo unconfirmed)"
    echo "Hardware Vulkan: $(has_hardware_vulkan && echo available || echo unavailable)"
    echo "Boot guard: $([ -f "$(boot_pending_file)" ] && echo active || echo clear)"
    echo "Incomplete boot count: $(boot_failure_count)/$(numeric_config BOOT_FAILURE_LIMIT 2 5)"
    echo "Recovery stock boot: $([ -f "$(boot_recovery_file)" ] && echo active || echo clear)"
    [ -f "$STATE_SUBDIR/boot-warning.txt" ] && sed 's/^/  /' "$STATE_SUBDIR/boot-warning.txt"
    echo "Safe mode: $([ -f "$STATE_SUBDIR/safe-mode.txt" ] && echo active || echo clear)"
    [ -f "$STATE_SUBDIR/safe-mode.txt" ] && sed 's/^/  /' "$STATE_SUBDIR/safe-mode.txt"
    echo "Profile quarantine: $(profile_quarantine_active && echo active || echo clear)"
    [ -f "$(profile_quarantine_file)" ] && sed 's/^/  /' "$(profile_quarantine_file)"
    echo "Stock reboot required: $([ -f "$(profile_reboot_file)" ] && echo yes || echo no)"
    echo "Module marker: $([ -f "$MODDIR/disable" ] && echo disabled || echo enabled)"
    echo "Renderer transaction: $([ -d "$(transaction_active_dir)" ] && echo active || echo clear)"
    echo "Foreground: ${foreground:-unknown}"
    echo "Foreground pipeline: ${pipeline:-not reported}"
    profile_count="$(awk -F= 'NF==2 && $1 ~ /^[A-Za-z0-9_]+([.][A-Za-z0-9_]+)+$/ {n++} END{print n+0}' "$APP_PROFILE_FILE" 2>/dev/null)"
    recommendation_count="$(awk -F '\t' 'NF>=2 {n++} END{print n+0}' "$RECOMMEND_FILE" 2>/dev/null)"
    echo "Saved app profiles: ${profile_count:-0}"
    echo "Benchmark recommendations: ${recommendation_count:-0}"
    [ -f "$BOOT_HISTORY" ] && echo "Last boot result: $(tail -n 1 "$BOOT_HISTORY" | tr '\t' ' ')"
    return 0
}

set_profile() {
    requested="$(normalize_profile "$1")"
    [ "$requested" != invalid ] || { echo 'ERROR: допустимы stock, compatibility, vulkan.'; return 2; }
    acquire_lock control 10 || { echo 'ERROR: другая операция уже выполняется.'; return 1; }
    trap 'release_lock' 0 1 2 15
    if config_set PROFILE "$requested" && apply_profile "$requested"; then
        clear_profile_quarantine
        rm -f "$(boot_recovery_file)" "$(boot_failure_file)" "$STATE_SUBDIR/boot-warning.txt"
        echo "Профиль сохранён и применён для новых процессов: $requested"
        if [ "$requested" = vulkan ]; then
            echo 'ВНИМАНИЕ: глобальный SkiaVK экспериментален на Realme UI.'
            echo 'При нестабильности NeoRender переведёт профиль в Stock, сохранив меню и диагностику.'
        fi
        echo 'Для единого применения ко всей системе выполните перезагрузку.'
    else
        restore_baseline
        quarantine_profile "manual-profile-apply-failure:$requested"
        echo 'ERROR: профиль не применён; OEM baseline восстановлен, PROFILE переведён в stock.'
        return 1
    fi
}

verify_package() {
    pkg="$1"; [ -n "$pkg" ] || pkg="$(top_package)"
    [ -n "$pkg" ] || { echo 'ERROR: foreground package не определён.'; return 1; }
    valid_package_name "$pkg" || { echo "ERROR: некорректный package name: $pkg"; return 2; }
    echo "Package: $pkg"
    echo "Active $RENDERER_PROP: $(read_prop "$RENDERER_PROP")"
    pipeline="$(pipeline_for_package "$pkg")"
    echo "Reported HWUI pipeline: ${pipeline:-not reported by gfxinfo}"
    echo "PID: $(pidof "$pkg" 2>/dev/null || echo not-running)"
}

app_list() {
    if ! grep -q '^[A-Za-z0-9_].*=' "$APP_PROFILE_FILE" 2>/dev/null; then echo 'Сохранённых профилей нет.'; return; fi
    awk -F= '{printf "%-55s %s\n", $1, $2}' "$APP_PROFILE_FILE"
}
app_set_cmd() {
    pkg="$1"; renderer="$(normalize_renderer "$2")"
    valid_package_name "$pkg" || { echo 'ERROR: некорректный package name.'; return 2; }
    [ "$renderer" != invalid ] || { echo 'ERROR: renderer должен быть skiagl или skiavk.'; return 2; }
    package_exists "$pkg" || { echo "ERROR: пакет не установлен: $pkg"; return 1; }
    acquire_lock profiles 10 || { echo 'ERROR: файл профилей занят.'; return 1; }
    app_profile_set "$pkg" "$renderer"; rc=$?; release_lock
    [ "$rc" -eq 0 ] && echo "Сохранено: $pkg -> $renderer" || echo 'ERROR: профиль не сохранён.'
    return "$rc"
}
app_remove_cmd() {
    pkg="$1"; valid_package_name "$pkg" || { echo 'ERROR: некорректный package name.'; return 2; }
    acquire_lock profiles 10 || { echo 'ERROR: файл профилей занят.'; return 1; }
    app_profile_remove "$pkg"; rc=$?; release_lock
    [ "$rc" -eq 0 ] && echo "Удалён персональный профиль: $pkg" || echo 'ERROR: профиль не удалён.'
    return "$rc"
}
app_launch_cmd() {
    pkg="$1"; requested="$2"
    [ -n "$requested" ] || requested="$(app_profile_get "$pkg")"
    [ -n "$requested" ] || requested="$(config_get DEFAULT_APP_RENDERER skiavk)"
    requested="$(normalize_renderer "$requested")"