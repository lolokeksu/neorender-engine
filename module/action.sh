#!/system/bin/sh
MODDIR=${0%/*}
NEORENDER_MODULE_DIR="$MODDIR"
. "$MODDIR/common/functions.sh"

ensure_state_dirs
[ -f "$CONFIG_FILE" ] || cp -f "$MODDIR/config.conf.default" "$CONFIG_FILE"
merge_config_defaults "$MODDIR/config.conf.default"
recover_stale_transaction >/dev/null 2>&1 || true
acquire_lock action 10 || { echo 'NeoRender Engine: другая операция уже выполняется.'; exit 1; }
trap 'release_lock' 0 1 2 15

current="$(normalize_profile "$(config_get PROFILE stock)")"
case "$current" in
    stock) next=compatibility ;;
    *) next=stock ;;
esac

if config_set PROFILE "$next" && apply_profile "$next"; then
    clear_profile_quarantine
    echo 'NeoRender Engine v1.0.0'
    echo "Profile: $current -> $next"
    echo "Active $RENDERER_PROP: $(read_prop "$RENDERER_PROP")"
    echo 'Кнопка Action безопасно переключает только Stock ↔ SkiaGL.'
    echo 'Глобальный SkiaVK включается через меню Termux после подтверждения.'
    echo 'Полное применение ко всей системе — после перезагрузки.'
else
    restore_baseline
    echo 'ERROR: профиль не применён; OEM baseline восстановлен.'
    exit 1
fi
