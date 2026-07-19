#!/system/bin/sh
MODDIR=${0%/*}
NEORENDER_MODULE_DIR="$MODDIR"
. "$MODDIR/common/functions.sh"

ensure_state_dirs
recover_stale_transaction >/dev/null 2>&1 || true
if ! wait_for_boot_completed; then
    boot_history_add pending boot-completed-timeout
    log_msg 'sys.boot_completed timeout; boot guard marker remains active for the next stock recovery boot.'
    exit 1
fi

sleep "$(numeric_config STABILITY_DELAY_SECONDS 60 300)"
recovery_stock=0
if [ -f "$(boot_recovery_file)" ] || [ -f "$(profile_reboot_file)" ]; then
    recovery_stock=1
    profile=stock
else
    profile="$(normalize_profile "$(config_get PROFILE stock)")"
    [ "$profile" != invalid ] || profile=stock
fi
renderer="$(profile_renderer "$profile")"

if [ "$profile" = stock ]; then
    watchdog="$(numeric_config STOCK_WATCHDOG_SECONDS 30 120)"
else
    watchdog="$(numeric_config WATCHDOG_SECONDS 120 600)"
fi
restart_limit="$(numeric_config SYSTEMUI_RESTART_LIMIT 4 20)"
override_limit="$(numeric_config PROPERTY_OVERRIDE_LIMIT 3 20)"
reapply="$(config_get REAPPLY_ON_OVERRIDE 1)"
elapsed=0
last_pid=""
restarts=0
overrides=0
failed=0
failure_reason=""
missing_samples=0

while [ "$elapsed" -le "$watchdog" ]; do
    pid="$(systemui_pid)"
    if [ -n "$pid" ]; then
        missing_samples=0
        if [ -n "$last_pid" ] && [ "$pid" != "$last_pid" ]; then
            restarts=$((restarts + 1))
            log_msg "SystemUI PID changed after stability delay: $last_pid -> $pid ($restarts/$restart_limit)"
        fi
        last_pid="$pid"
    else
        missing_samples=$((missing_samples + 1))
        log_msg "SystemUI PID not reported after boot_completed (sample $missing_samples); treated as diagnostic warning."
    fi

    if [ "$profile" != stock ] && [ "$restarts" -ge "$restart_limit" ]; then
        failed=1
        failure_reason=systemui-restart-limit
        break
    fi

    if [ "$renderer" != stock ]; then
        actual="$(read_prop "$RENDERER_PROP")"
        if [ "$actual" != "$renderer" ]; then
            overrides=$((overrides + 1))
            log_msg "Renderer override detected: expected=$renderer actual=${actual:-<empty>} ($overrides/$override_limit)"
            if [ "$overrides" -ge "$override_limit" ]; then
                failed=1
                failure_reason=property-conflict
                break
            fi
            if [ "$reapply" = 1 ] && ! apply_renderer "$renderer"; then
                failed=1
                failure_reason=renderer-reapply-failed
                break
            fi
        fi
    fi

    [ "$elapsed" -eq "$watchdog" ] && break
    sleep 10
    elapsed=$((elapsed + 10))
done

if [ "$failed" -eq 1 ]; then
    quarantine_profile "$failure_reason"
    boot_history_add rollback-profile "$failure_reason"
    log_msg "Renderer stability failure: $failure_reason. PROFILE changed to stock; module remains enabled; reboot required."
else
    rm -f "$STATE_SUBDIR/safe-mode.txt"
    if [ "$recovery_stock" -eq 1 ]; then
        boot_history_add success "recovery-stock,restarts=$restarts,missing=$missing_samples"
        log_msg 'OEM/stock recovery boot validated. Module remains active; renderer profile is stock.'
    else
        boot_history_add success "profile=$profile,restarts=$restarts,overrides=$overrides,missing=$missing_samples"
        log_msg "Boot validated: profile=$profile restarts=$restarts overrides=$overrides missing=$missing_samples."
    fi
    boot_guard_reset
    rm -f "$(profile_reboot_file)"
    if [ "$profile" = stock ] && [ -f "$(profile_quarantine_file)" ] && \
       grep -Eq '^reason=(rc(2|3)|v1)-safe-first-upgrade$' "$(profile_quarantine_file)" 2>/dev/null; then
        clear_profile_quarantine
        boot_history_add info upgrade-quarantine-cleared-after-stock-success
        log_msg 'Safe-first upgrade quarantine cleared after a verified stock boot.'
    fi
fi

write_report >/dev/null 2>&1
rm -f "$(boot_pending_file)"
