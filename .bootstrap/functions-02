    printf '%s\n' "$value" > "$(boot_failure_file)"
    chmod 0600 "$(boot_failure_file)" 2>/dev/null
}
boot_guard_reset() {
    rm -f "$(boot_failure_file)" "$(boot_recovery_file)" "$STATE_SUBDIR/boot-warning.txt"
}
profile_quarantine_file() { printf '%s\n' "$STATE_SUBDIR/profile-quarantine.txt"; }
profile_reboot_file() { printf '%s\n' "$STATE_SUBDIR/reboot-stock-required"; }
profile_quarantine_active() { [ -f "$(profile_quarantine_file)" ]; }
clear_profile_quarantine() {
    rm -f "$(profile_quarantine_file)" "$(profile_reboot_file)" "$STATE_SUBDIR/safe-mode.txt"
}
quarantine_profile() {
    reason="${1:-unspecified}"
    configured="$(normalize_profile "$(config_get PROFILE stock)")"
    [ "$configured" != invalid ] || configured=stock
    renderer="$(profile_renderer "$configured")"
    ensure_state_dirs
    {
        printf 'time=%s\n' "$(now_stamp)"
        printf 'reason=%s\n' "$reason"
        printf 'profile=%s\n' "$configured"
        printf 'renderer=%s\n' "$renderer"
        printf 'fingerprint=%s\n' "$(current_fingerprint)"
        printf 'boot_id=%s\n' "$(current_boot_id)"
    } > "$(profile_quarantine_file)"
    chmod 0600 "$(profile_quarantine_file)" 2>/dev/null
    config_set PROFILE stock >/dev/null 2>&1 || true
    restore_baseline >/dev/null 2>&1 || true
    printf '%s\n' "$(now_stamp)" > "$(profile_reboot_file)"
    chmod 0600 "$(profile_reboot_file)" 2>/dev/null
    boot_failure_set 0
    rm -f "$(boot_recovery_file)" "$STATE_SUBDIR/boot-warning.txt"
    boot_history_add quarantine "reason=$reason,previous-profile=$configured"
    log_msg "Renderer profile quarantined: reason=$reason previous-profile=$configured; PROFILE=stock; reboot required."
}
systemui_pid() {
    command -v pidof >/dev/null 2>&1 && { pidof com.android.systemui 2>/dev/null | awk '{print $1}'; return; }
    ps -A 2>/dev/null | awk '$NF == "com.android.systemui" {print $2; exit}'
}
top_package() {
    pkg="$(dumpsys activity activities 2>/dev/null | sed -n 's/.*mResumedActivity:.* \([^/ ]*\)\/.*/\1/p' | head -n 1)"
    [ -n "$pkg" ] || pkg="$(dumpsys window windows 2>/dev/null | sed -n 's/.*mCurrentFocus=.* \([^/ ]*\)\/.*/\1/p' | head -n 1)"
    printf '%s\n' "$pkg"
}
pipeline_for_package() { dumpsys gfxinfo "$1" 2>/dev/null | grep -m 1 -E 'Pipeline|Rendering pipeline' | sed 's/^[[:space:]]*//'; }

app_profile_get() { pkg="$1"; [ -f "$APP_PROFILE_FILE" ] || return 1; awk -F= -v p="$pkg" '$1==p {print $2; exit}' "$APP_PROFILE_FILE" 2>/dev/null; }
app_profile_set() {
    pkg="$1"; renderer="$2"; valid_package_name "$pkg" || return 1; renderer="$(normalize_renderer "$renderer")"; [ "$renderer" != invalid ] || return 1
    ensure_state_dirs; tmp="${APP_PROFILE_FILE}.tmp.$$"
    awk -F= -v p="$pkg" -v r="$renderer" 'BEGIN{done=0} $1==p {if(!done){print p "=" r; done=1}; next} {print} END{if(!done) print p "=" r}' "$APP_PROFILE_FILE" > "$tmp" || return 1
    mv -f "$tmp" "$APP_PROFILE_FILE"; chmod 0600 "$APP_PROFILE_FILE" 2>/dev/null
}
app_profile_remove() { pkg="$1"; [ -f "$APP_PROFILE_FILE" ] || return 0; tmp="${APP_PROFILE_FILE}.tmp.$$"; awk -F= -v p="$pkg" '$1!=p {print}' "$APP_PROFILE_FILE" > "$tmp" || return 1; mv -f "$tmp" "$APP_PROFILE_FILE"; chmod 0600 "$APP_PROFILE_FILE" 2>/dev/null; }

recommendation_get_line() { pkg="$1"; [ -f "$RECOMMEND_FILE" ] || return 1; awk -F '\t' -v p="$pkg" '$1==p {print; exit}' "$RECOMMEND_FILE"; }
recommendation_set() {
    pkg="$1"; renderer="$2"; confidence="$3"; reason="$4"; report="$5"; fp="$(current_fingerprint)"; stamp="$(now_stamp)"
    tmp="${RECOMMEND_FILE}.tmp.$$"
    awk -F '\t' -v p="$pkg" '$1!=p {print}' "$RECOMMEND_FILE" 2>/dev/null > "$tmp" || : > "$tmp"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$pkg" "$renderer" "$confidence" "$stamp" "$fp" "$reason" "$report" >> "$tmp"
    mv -f "$tmp" "$RECOMMEND_FILE"; chmod 0600 "$RECOMMEND_FILE" 2>/dev/null
}

launch_package_with_renderer() {
    pkg="$1"; renderer="$(normalize_renderer "$2")"
    valid_package_name "$pkg" || return 2; [ "$renderer" != invalid ] || return 2; package_exists "$pkg" || return 3; validate_environment "$renderer" || return 4
    if protected_package_reason "$pkg" >/dev/null 2>&1 && [ "$(config_get ALLOW_PROTECTED_PACKAGES 0)" != 1 ]; then return 8; fi
    ensure_state_dirs; recover_stale_transaction >/dev/null 2>&1 || return 9
    transaction_begin "$pkg" "$renderer" || return 9
    restored=0
    _restore_temp() { [ "$restored" -eq 0 ] && { transaction_restore; restored=1; }; }
    trap '_restore_temp; exit 130' 1 2 15
    apply_renderer "$renderer" || { _restore_temp; trap - 1 2 15; return 5; }
    am force-stop "$pkg" >/dev/null 2>&1
    activity="$(cmd package resolve-activity --brief "$pkg" 2>/dev/null | tail -n 1)"; started=0
    case "$activity" in */*) am start -n "$activity" >/dev/null 2>&1 && started=1 ;; esac
    [ "$started" -eq 1 ] || { monkey -p "$pkg" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 && started=1; }
    [ "$started" -eq 1 ] || { _restore_temp; trap - 1 2 15; return 6; }
    wait_seconds="$(numeric_config APP_LAUNCH_WAIT_SECONDS 20 60)"; elapsed=0; app_pid=""
    while [ "$elapsed" -lt "$wait_seconds" ]; do app_pid="$(pidof "$pkg" 2>/dev/null | awk '{print $1}')"; [ -n "$app_pid" ] && break; sleep 1; elapsed=$((elapsed + 1)); done
    [ -n "$app_pid" ] || { _restore_temp; trap - 1 2 15; return 7; }
    pipeline_wait="$(numeric_config APP_PIPELINE_WAIT_SECONDS 15 60)"; elapsed=0; app_pipeline=""
    while [ "$elapsed" -lt "$pipeline_wait" ]; do app_pipeline="$(pipeline_for_package "$pkg")"; [ -n "$app_pipeline" ] && break; sleep 1; elapsed=$((elapsed + 1)); done
    _restore_temp; trap - 1 2 15
    LAUNCHED_PID="$app_pid"; LAUNCHED_PIPELINE="$app_pipeline"; return 0
}

battery_field() { dumpsys battery 2>/dev/null | awk -F: -v k="$1" '$1 ~ "^[[:space:]]*" k "$" {gsub(/^[[:space:]]+/,"",$2); print $2; exit}'; }
thermal_summary() { dumpsys thermalservice 2>/dev/null | grep -E 'Temperature\{|mStatus|Current temperatures|value=' | head -n 80; }
root_manager() {
    if command -v magisk >/dev/null 2>&1; then printf 'Magisk %s\n' "$(magisk -v 2>/dev/null)"; return; fi
    [ -d /data/adb/ksu ] && { echo KernelSU; return; }
    if [ -d /data/adb/ap ] || [ -d /data/adb/apatch ]; then echo APatch; return; fi
    echo unknown
}
module_version() { awk -F= '$1=="version" {print $2; exit}' "$MODULE_DIR/module.prop" 2>/dev/null; }
rotate_pattern() {
    pattern="$1"; retention="$(numeric_config REPORT_RETENTION 30 100)"
    # Intentional word splitting: pattern is an internal trusted glob.
    ls -1t $pattern 2>/dev/null | awk -v keep="$retention" 'NR>keep {print}' | while IFS= read -r old; do rm -f "$old"; done
}

scan_conflicts() {
    found=0
    for dir in /data/adb/modules/*; do
        [ -d "$dir" ] || continue; [ "$dir" = "$MODULE_DIR" ] && continue; [ -f "$dir/disable" ] && continue; [ -f "$dir/remove" ] && continue
        matches="$(find "$dir" -maxdepth 3 -type f \( -name '*.sh' -o -name '*.prop' -o -name '*.conf' -o -name '*.txt' \) -exec grep -IlE 'debug\.hwui\.renderer|debug\.renderengine\.backend|ro\.hwui\.use_vulkan|skiavk|skiagl' {} \; 2>/dev/null | head -n 10)"
        [ -n "$matches" ] || continue; found=1; printf '%s\n' "MODULE: $(basename "$dir")"; printf '%s\n' "$matches" | sed 's/^/  /'
    done
    [ "$found" -eq 1 ] || echo none
}

config_validate() {
    errors=0; profile="$(normalize_profile "$(config_get PROFILE stock)")"
    [ "$profile" != invalid ] || { echo 'PROFILE: invalid'; errors=$((errors + 1)); }
    [ "$(config_get CONFIG_SCHEMA 0)" = 4 ] || { echo 'CONFIG_SCHEMA: expected 4'; errors=$((errors + 1)); }
    for key in BOOT_GUARD REAPPLY_ON_OVERRIDE PROFILE_QUARANTINE REQUIRE_REALME REQUIRE_QUALCOMM REQUIRE_HARDWARE_VULKAN STRICT_TARGET_MODEL ALLOW_PROTECTED_PACKAGES; do
        value="$(config_get "$key" x)"; case "$value" in 0|1) : ;; *) echo "$key: expected 0 or 1"; errors=$((errors + 1)) ;; esac
    done
    for key in BOOT_COMPLETED_TIMEOUT_SECONDS STABILITY_DELAY_SECONDS WATCHDOG_SECONDS STOCK_WATCHDOG_SECONDS SYSTEMUI_RESTART_LIMIT PROPERTY_OVERRIDE_LIMIT BOOT_FAILURE_LIMIT BOOT_PENDING_MAX_AGE_SECONDS APP_LAUNCH_WAIT_SECONDS APP_PIPELINE_WAIT_SECONDS TRANSACTION_STALE_SECONDS BENCH_MIN_FRAMES BENCH_MIN_DURATION_SECONDS BENCH_MAX_DURATION_DRIFT_PERCENT BENCH_IMPROVEMENT_PERCENT BENCH_MAX_REGRESSION_PERCENT BENCH_THERMAL_PENALTY_TENTHS_C REPORT_RETENTION LOG_MAX_KIB; do
        value="$(config_get "$key" x)"; case "$value" in ''|*[!0-9]*) echo "$key: expected integer"; errors=$((errors + 1)) ;; esac
    done
    renderer="$(normalize_renderer "$(config_get DEFAULT_APP_RENDERER skiavk)")"; [ "$renderer" != invalid ] || { echo 'DEFAULT_APP_RENDERER: invalid'; errors=$((errors + 1)); }
    [ "$errors" -eq 0 ]
}

sha256_tool() {
    command -v sha256sum >/dev/null 2>&1 && { echo sha256sum; return; }
    command -v toybox >/dev/null 2>&1 && toybox sha256sum /dev/null >/dev/null 2>&1 && { echo 'toybox sha256sum'; return; }
    return 1
}
self_check() {
    sums="$MODULE_DIR/RUNTIME_SHA256SUMS"; [ -f "$sums" ] || { echo 'RUNTIME_SHA256SUMS missing'; return 1; }
    tool="$(sha256_tool)" || { echo 'sha256sum unavailable'; return 2; }
    failed=0
    while IFS= read -r line; do
        expected="${line%%  *}"; rel="${line#*  }"; [ -n "$expected" ] && [ -n "$rel" ] || continue
        file="$MODULE_DIR/$rel"; [ -f "$file" ] || { echo "MISSING  $rel"; failed=1; continue; }
        actual="$($tool "$file" 2>/dev/null | awk '{print $1}')"
        if [ "$actual" = "$expected" ]; then echo "OK       $rel"; else echo "FAILED   $rel"; failed=1; fi
    done < "$sums"
    [ "$failed" -eq 0 ]
}

boot_history_add() { ensure_state_dirs; printf '%s\t%s\t%s\t%s\n' "$(now_stamp)" "$1" "$(config_get PROFILE stock)" "$2" >> "$BOOT_HISTORY"; chmod 0600 "$BOOT_HISTORY" 2>/dev/null; }

write_report() {
    ensure_state_dirs; output="$REPORT_DIR/system-$(file_stamp).txt"; foreground="$(top_package)"; pipeline=""; [ -n "$foreground" ] && pipeline="$(pipeline_for_package "$foreground")"
    {
        echo 'NeoRender Engine v1 system report'; echo "Version: $(module_version)"; echo "Generated: $(now_stamp)"; echo
        echo '[Configuration]'; echo "Schema: $(config_get CONFIG_SCHEMA 0)"; echo "Profile: $(config_get PROFILE stock)"; echo "Active ${RENDERER_PROP}: $(read_prop "$RENDERER_PROP")"
        baseline='<not captured>'; [ -f "$STATE_SUBDIR/baseline.renderer" ] && baseline="$(cat "$STATE_SUBDIR/baseline.renderer")"; [ "$baseline" = "$EMPTY_MARKER" ] && baseline='<empty>'
        echo "OEM baseline: $baseline"; echo "Boot guard marker: $([ -f "$(boot_pending_file)" ] && echo active || echo clear)"; echo "Incomplete boot count: $(boot_failure_count)"; echo "Recovery stock boot: $([ -f "$(boot_recovery_file)" ] && echo active || echo clear)"; echo "Safe mode: $([ -f "$STATE_SUBDIR/safe-mode.txt" ] && echo active || echo clear)"; echo "Profile quarantine: $(profile_quarantine_active && echo active || echo clear)"; echo "Stock reboot required: $([ -f "$(profile_reboot_file)" ] && echo yes || echo no)"; echo "Transaction: $([ -d "$(transaction_active_dir)" ] && echo active || echo clear)"; echo
        echo '[Device]'; echo "Identity: $(device_identity)"; echo "Target model match: $(is_target_model && echo yes || echo no)"; echo "Android: $(read_prop ro.build.version.release) / API $(read_prop ro.build.version.sdk)"; echo "Fingerprint: $(current_fingerprint)"; echo "SoC: $(read_prop ro.soc.manufacturer) $(read_prop ro.soc.model)"; echo "Board: $(read_prop ro.board.platform)"; echo "Root manager: $(root_manager)"; echo "SELinux: $(getenforce 2>/dev/null || echo unknown)"; echo
        echo '[Graphics]'; echo "ro.hwui.use_vulkan: $(read_prop ro.hwui.use_vulkan)"; echo "ro.hardware.egl: $(read_prop ro.hardware.egl)"; echo "ro.hardware.vulkan: $(read_prop ro.hardware.vulkan)"; echo "Hardware Vulkan: $(has_hardware_vulkan && echo yes || echo no)"; echo "Foreground package: ${foreground:-unknown}"; echo "Foreground HWUI pipeline: ${pipeline:-not reported}"; echo
        echo '[Battery]'; echo "Level: $(battery_field level)"; echo "Temperature (0.1 C): $(battery_field temperature)"; echo "Voltage (mV): $(battery_field voltage)"; echo
        echo '[Potential conflicts]'; scan_conflicts
    } > "$output"
    chmod 0644 "$output" 2>/dev/null; rotate_pattern "$REPORT_DIR/system-*.txt"; printf '%s\n' "$output"
}
