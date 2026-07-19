#!/system/bin/sh
MODDIR=${0%/*}
NEORENDER_MODULE_DIR="$MODDIR"
. "$MODDIR/common/functions.sh"

ensure_state_dirs
[ -f "$CONFIG_FILE" ] || cp -f "$MODDIR/config.conf.default" "$CONFIG_FILE"
merge_config_defaults "$MODDIR/config.conf.default"
chmod 0600 "$CONFIG_FILE" 2>/dev/null
recover_stale_transaction >/dev/null 2>&1 || true
capture_baseline_if_needed

recovery_stock=0
if [ "$(config_get BOOT_GUARD 1)" = 1 ] && [ -f "$(boot_pending_file)" ]; then
    previous_fp="$(boot_marker_get fingerprint)"
    current_fp="$(current_fingerprint)"
    age="$(boot_marker_age)"
    max_age="$(numeric_config BOOT_PENDING_MAX_AGE_SECONDS 172800 604800)"
    count="$(boot_failure_count)"

    if [ -z "$previous_fp" ] || [ "$previous_fp" != "$current_fp" ] || [ "$age" -gt "$max_age" ] 2>/dev/null; then
        count=0
        boot_history_add warning "stale-pending-reset,age=$age"
    fi

    count=$((count + 1))
    boot_failure_set "$count"
    restore_baseline
    pending_profile="$(normalize_profile "$(boot_marker_get profile)")"
    [ "$pending_profile" != invalid ] || pending_profile="$(normalize_profile "$(config_get PROFILE stock)")"
    rm -f "$(boot_pending_file)"
    limit="$(numeric_config BOOT_FAILURE_LIMIT 2 5)"

    if [ "$pending_profile" != stock ] && [ "$(config_get PROFILE_QUARANTINE 1)" = 1 ]; then
        quarantine_profile "incomplete-nonstock-boot:$pending_profile,count=$count"
        printf '%s\n%s\n' "$(now_stamp)" "nonstock-profile-quarantined,profile=$pending_profile,count=$count,age=$age" > "$STATE_SUBDIR/boot-warning.txt"
        printf '%s\n' 1 > "$(boot_recovery_file)"
        recovery_stock=1
    elif [ "$count" -ge "$limit" ]; then
        boot_history_add warning "stock-incomplete-limit,count=$count,age=$age"
        log_msg "Incomplete watchdog repeated while PROFILE=stock; keeping module active and validating another stock boot."
        boot_failure_set 0
        printf '%s\n%s\n' "$(now_stamp)" "stock-recovery,count=$count,age=$age" > "$STATE_SUBDIR/boot-warning.txt"
        printf '%s\n' 1 > "$(boot_recovery_file)"
        recovery_stock=1
    else
        printf '%s\n%s\n' "$(now_stamp)" "previous-stock-watchdog-incomplete,count=$count,age=$age" > "$STATE_SUBDIR/boot-warning.txt"
        printf '%s\n' "$count" > "$(boot_recovery_file)"
        recovery_stock=1
        boot_history_add warning "recovery-stock,count=$count,age=$age"
        log_msg "Previous stock watchdog was incomplete; validating another OEM/stock boot ($count/$limit)."
    fi
    chmod 0600 "$STATE_SUBDIR/boot-warning.txt" "$(boot_recovery_file)" 2>/dev/null
fi

boot_pending_write
if [ "$recovery_stock" -eq 1 ] || [ -f "$(boot_recovery_file)" ] || [ -f "$(profile_reboot_file)" ]; then
    restore_baseline
    boot_history_add pending recovery-stock-early-apply
    exit 0
fi

profile="$(normalize_profile "$(config_get PROFILE stock)")"
if [ "$profile" = invalid ] || ! apply_profile "$profile"; then
    restore_baseline
    quarantine_profile "early-profile-apply-failure"
    boot_history_add rollback early-profile-apply-failure
    log_msg 'Early profile apply failed; profile quarantined and module kept active in stock mode.'
    exit 0
fi
boot_history_add pending "early-apply-ok,profile=$profile"
