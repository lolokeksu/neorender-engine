        if float_ge "$gl_p95_gain" "$min_gain" && float_le "$gl_jank_regress" "$max_regress"; then gl_wins=$((gl_wins + 1)); fi
        if float_ge "$gl_jank_gain" "$min_gain" && float_le "$gl_p95_regress" "$max_regress"; then gl_wins=$((gl_wins + 1)); fi
        if [ "$vk_wins" -gt "$gl_wins" ]; then recommendation=skiavk; [ "$vk_wins" -ge 2 ] && confidence=high || confidence=medium; reason="vk-wins-$vk_wins-metrics"; fi
        if [ "$gl_wins" -gt "$vk_wins" ]; then recommendation=skiagl; [ "$gl_wins" -ge 2 ] && confidence=high || confidence=medium; reason="gl-wins-$gl_wins-metrics"; fi
        temp_diff=$((vk_temp - gl_temp))
        if [ "$recommendation" = skiavk ] && [ "$temp_diff" -ge "$thermal_penalty" ] 2>/dev/null && [ "$vk_wins" -lt 2 ]; then recommendation=inconclusive; confidence=none; reason=vk-thermal-penalty; fi
        temp_diff=$((gl_temp - vk_temp))
        if [ "$recommendation" = skiagl ] && [ "$temp_diff" -ge "$thermal_penalty" ] 2>/dev/null && [ "$gl_wins" -lt 2 ]; then recommendation=inconclusive; confidence=none; reason=gl-thermal-penalty; fi
    fi

    {
        echo 'NeoRender Engine v1 paired benchmark comparison'; echo "Generated: $(now_stamp)"; echo "Package: $(metric_get "$gl" package)"; echo
        echo '[SkiaGL]'; cat "$gl"; echo; echo '[SkiaVK]'; cat "$vk"; echo
        echo '[Comparison]'; echo "Duration drift percent: $duration_drift"; echo "SkiaVK p95 improvement percent: $vk_p95_gain"; echo "SkiaVK jank improvement percent: $vk_jank_gain"; echo "SkiaGL p95 improvement percent: $gl_p95_gain"; echo "SkiaGL jank improvement percent: $gl_jank_gain"; echo "SkiaVK metric wins: $vk_wins"; echo "SkiaGL metric wins: $gl_wins"; echo "Recommendation: $recommendation"; echo "Confidence: $confidence"; echo "Reason: $reason"
        echo; echo '[Decision constraints]'; echo "Minimum frames per phase: $min_frames"; echo "Minimum duration seconds: $min_duration"; echo "Maximum duration drift percent: $max_drift"; echo "Minimum improvement percent: $min_gain"; echo "Maximum opposite-metric regression percent: $max_regress"; echo "Thermal penalty threshold (0.1 C): $thermal_penalty"
    } > "$result"
    PAIR_RECOMMENDATION="$recommendation"; PAIR_CONFIDENCE="$confidence"; PAIR_REASON="$reason"
}

pair_finish() {
    pkg="$1"; pair_active="$PAIR_DIR/active"; [ -d "$pair_active" ] || { echo 'ERROR: парный benchmark не активен.'; return 1; }
    saved_pkg="$(cat "$pair_active/package" 2>/dev/null)"; phase="$(cat "$pair_active/phase" 2>/dev/null)"; [ "$pkg" = "$saved_pkg" ] || { echo "ERROR: активный пакет — $saved_pkg"; return 2; }; [ "$phase" = skiavk ] || { echo 'ERROR: сначала завершите SkiaGL-фазу командой pair next.'; return 2; }
    output="$REPORT_DIR/pair-${pkg}-skiavk-$(file_stamp).txt"; create_benchmark_report "$pkg" skiavk "$pair_active/current" "$output"; mv -f "$BENCH_SUMMARY" "$pair_active/skiavk.summary"; printf '%s\n' "$BENCH_OUTPUT" > "$pair_active/skiavk.report"
    comparison="$REPORT_DIR/comparison-${pkg}-$(file_stamp).txt"; compare_pair_summaries "$pair_active/skiagl.summary" "$pair_active/skiavk.summary" "$comparison"
    if [ "$PAIR_RECOMMENDATION" = skiagl ] || [ "$PAIR_RECOMMENDATION" = skiavk ]; then recommendation_set "$pkg" "$PAIR_RECOMMENDATION" "$PAIR_CONFIDENCE" "$PAIR_REASON" "$comparison"; fi
    rm -rf "$pair_active"; rotate_pattern "$REPORT_DIR/pair-*.txt"; rotate_pattern "$REPORT_DIR/comparison-*.txt"
    echo "Comparison saved: $comparison"; grep -E 'Recommendation:|Confidence:|Reason:|SkiaVK p95|SkiaVK jank|SkiaGL p95|SkiaGL jank' "$comparison"
    [ "$PAIR_RECOMMENDATION" = inconclusive ] && echo 'Персональный профиль не изменён: данных недостаточно или результат противоречив.' || echo "Рекомендация сохранена: $pkg -> $PAIR_RECOMMENDATION"
}
pair_status() {
    pair_active="$PAIR_DIR/active"; [ -d "$pair_active" ] || { echo 'Парный benchmark не активен.'; return; }
    echo "Package: $(cat "$pair_active/package" 2>/dev/null)"; echo "Phase: $(cat "$pair_active/phase" 2>/dev/null)"; [ -d "$pair_active/current" ] && { echo "Started: $(cat "$pair_active/current/start.time" 2>/dev/null)"; echo "PID: $(cat "$pair_active/current/pid" 2>/dev/null)"; }
    return 0
}
pair_abort() { rm -rf "$PAIR_DIR/active"; echo 'Парный benchmark сброшен. Глобальное property не изменено.'; }

recommend_list() {
    [ -s "$RECOMMEND_FILE" ] || { echo 'Сохранённых рекомендаций нет.'; return; }
    awk -F '\t' '{printf "%-45s %-8s confidence=%-6s %s\n",$1,$2,$3,$4}' "$RECOMMEND_FILE"
}
recommend_show() {
    pkg="$1"; valid_package_name "$pkg" || { echo 'ERROR: некорректный package name.'; return 2; }; line="$(recommendation_get_line "$pkg")"; [ -n "$line" ] || { echo 'Рекомендация отсутствует.'; return 1; }
    printf '%s\n' "$line" | awk -F '\t' '{print "Package: "$1"\nRenderer: "$2"\nConfidence: "$3"\nCreated: "$4"\nFingerprint: "$5"\nReason: "$6"\nReport: "$7}'
    current_fp="$(current_fingerprint)"; saved_fp="$(printf '%s\n' "$line" | awk -F '\t' '{print $5}')"; [ "$current_fp" = "$saved_fp" ] || echo 'WARNING: рекомендация создана на другой сборке прошивки.'
    return 0
}
recommend_apply() {
    pkg="$1"; line="$(recommendation_get_line "$pkg")"; [ -n "$line" ] || { echo 'ERROR: рекомендация отсутствует.'; return 1; }
    renderer="$(printf '%s\n' "$line" | awk -F '\t' '{print $2}')"; saved_fp="$(printf '%s\n' "$line" | awk -F '\t' '{print $5}')"
    [ "$saved_fp" = "$(current_fingerprint)" ] || { echo 'ERROR: рекомендация относится к другой сборке прошивки; повторите A/B benchmark.'; return 1; }
    app_profile_set "$pkg" "$renderer" || return 1; echo "Применён персональный профиль: $pkg -> $renderer"
}
recommend_remove() { pkg="$1"; tmp="${RECOMMEND_FILE}.tmp.$$"; awk -F '\t' -v p="$pkg" '$1!=p {print}' "$RECOMMEND_FILE" > "$tmp" && mv -f "$tmp" "$RECOMMEND_FILE"; chmod 0600 "$RECOMMEND_FILE"; echo "Рекомендация удалена: $pkg"; }

capture_gfx() {
    pkg="$1"; valid_package_name "$pkg" || { echo 'ERROR: некорректный package name.'; return 2; }; package_exists "$pkg" || { echo 'ERROR: пакет не установлен.'; return 1; }
    output="$REPORT_DIR/gfx-${pkg}-$(file_stamp).txt"; dumpsys gfxinfo "$pkg" framestats > "$output" 2>&1 || { rm -f "$output"; echo 'ERROR: gfxinfo capture failed.'; return 1; }
    chmod 0644 "$output"; rotate_pattern "$REPORT_DIR/gfx-*.txt"; echo "Saved: $output"; grep -E 'Pipeline|Total frames rendered|Janky frames|50th percentile|90th percentile|95th percentile|99th percentile' "$output" || true
}

doctor_cmd() {
    warnings=0; failures=0; echo 'NeoRender Engine doctor'; echo "Version: $(module_version)"; echo "Root manager: $(root_manager)"
    if [ "$(read_prop ro.build.version.sdk)" = 33 ]; then echo 'Android API 33: [OK]'; else echo "Android API $(read_prop ro.build.version.sdk): [FAIL]"; failures=$((failures + 1)); fi
    if is_realme_device; then echo 'Realme: [OK]'; else echo 'Realme: [FAIL]'; failures=$((failures + 1)); fi
    if is_target_model; then echo 'GT Neo 5 SE identifier: [OK]'; else echo 'GT Neo 5 SE identifier: [FAIL]'; failures=$((failures + 1)); fi
    if is_qualcomm_device; then echo 'Qualcomm/Adreno: [OK]'; else echo 'Qualcomm/Adreno: [FAIL]'; failures=$((failures + 1)); fi
    if has_hardware_vulkan; then echo 'Hardware Vulkan: [OK]'; else echo 'Hardware Vulkan: [FAIL]'; failures=$((failures + 1)); fi
    ensure_state_dirs; config_tmp="$TMP_DIR/config-check.$$"; if config_validate >"$config_tmp" 2>&1; then echo 'Configuration: [OK]'; else echo 'Configuration: [FAIL]'; sed 's/^/  /' "$config_tmp"; failures=$((failures + 1)); fi; rm -f "$config_tmp"
    echo "SELinux: $(getenforce 2>/dev/null || echo unknown)"; echo "Configured profile: $(config_get PROFILE stock)"; echo "Active $RENDERER_PROP: $(read_prop "$RENDERER_PROP")"; echo "SystemUI PID: $(systemui_pid)"
    echo "Incomplete boot count: $(boot_failure_count)/$(numeric_config BOOT_FAILURE_LIMIT 2 5)"; [ -f "$(boot_recovery_file)" ] && { echo 'Recovery stock boot: [WARN]'; warnings=$((warnings + 1)); } || echo 'Recovery stock boot: [OK]'; [ -f "$STATE_SUBDIR/boot-warning.txt" ] && { echo 'Boot warning:'; sed 's/^/  /' "$STATE_SUBDIR/boot-warning.txt"; warnings=$((warnings + 1)); }; [ -f "$STATE_SUBDIR/safe-mode.txt" ] && { echo 'Safe mode: [WARN]'; sed 's/^/  /' "$STATE_SUBDIR/safe-mode.txt"; warnings=$((warnings + 1)); } || echo 'Safe mode: [OK]'
    if profile_quarantine_active; then echo 'Profile quarantine: [WARN]'; sed 's/^/  /' "$(profile_quarantine_file)"; warnings=$((warnings + 1)); else echo 'Profile quarantine: [OK]'; fi
    [ -f "$(profile_reboot_file)" ] && { echo 'Stock reboot required: [WARN]'; warnings=$((warnings + 1)); } || echo 'Stock reboot required: [OK]'
    [ -d "$(transaction_active_dir)" ] && { echo 'Renderer transaction: [WARN]'; warnings=$((warnings + 1)); } || echo 'Renderer transaction: [OK]'
    echo 'Potential renderer conflicts:'; conflicts="$(scan_conflicts)"; printf '%s\n' "$conflicts" | sed 's/^/  /'; [ "$conflicts" = none ] || warnings=$((warnings + 1))
    echo "Warnings: $warnings"; echo "Failures: $failures"; [ "$failures" -eq 0 ]
}

backup_cmd() {
    ensure_state_dirs; output="$BACKUP_DIR/manual-$(file_stamp)"; mkdir -p "$output"
    for f in config.conf app-profiles.conf recommendations.tsv; do [ -f "$STATE_DIR/$f" ] && cp -f "$STATE_DIR/$f" "$output/$f"; done
    for f in baseline.renderer baseline.fingerprint safe-mode.txt profile-quarantine.txt reboot-stock-required boot-warning.txt boot-failure.count boot.recovery-stock; do [ -f "$STATE_SUBDIR/$f" ] && cp -f "$STATE_SUBDIR/$f" "$output/$f"; done
    [ -f "$MODDIR/module.prop" ] && cp -f "$MODDIR/module.prop" "$output/module.prop"; chmod -R go-rwx "$output" 2>/dev/null; echo "Backup created: $output"
}
support_cmd() {
    ensure_state_dirs; stamp="$(file_stamp)"; temp="$BACKUP_DIR/support-$stamp"; archive="$REPORT_DIR/neorender-support-$stamp.tar.gz"; mkdir -p "$temp"
    report="$(write_report)"; cp -f "$report" "$temp/system-report.txt"; for f in config.conf app-profiles.conf recommendations.tsv; do [ -f "$STATE_DIR/$f" ] && cp -f "$STATE_DIR/$f" "$temp/$f"; done
    [ -f "$LOG_FILE" ] && tail -n 500 "$LOG_FILE" > "$temp/neorender-last-500.log"; [ -f "$BOOT_HISTORY" ] && cp -f "$BOOT_HISTORY" "$temp/boot.tsv"; [ -f "$STATE_SUBDIR/safe-mode.txt" ] && cp -f "$STATE_SUBDIR/safe-mode.txt" "$temp/safe-mode.txt"; [ -f "$(profile_quarantine_file)" ] && cp -f "$(profile_quarantine_file)" "$temp/profile-quarantine.txt"; [ -f "$(profile_reboot_file)" ] && cp -f "$(profile_reboot_file)" "$temp/reboot-stock-required"; [ -f "$STATE_SUBDIR/boot-warning.txt" ] && cp -f "$STATE_SUBDIR/boot-warning.txt" "$temp/boot-warning.txt"; [ -f "$(boot_failure_file)" ] && cp -f "$(boot_failure_file)" "$temp/boot-failure.count"; cp -f "$MODDIR/module.prop" "$temp/module.prop"
    (cd "$temp" && tar -czf "$archive" .) || { rm -rf "$temp"; echo 'ERROR: support archive creation failed.'; return 1; }; rm -rf "$temp"; chmod 0644 "$archive"; echo "Support bundle: $archive"
}

config_cmd() {
    case "$1" in
        show) cat "$CONFIG_FILE" ;;
        validate) if config_validate; then echo 'Configuration valid.'; else echo 'Configuration invalid.'; return 1; fi ;;
        reset) backup_cmd >/dev/null; cp -f "$MODDIR/config.conf.default" "$CONFIG_FILE"; chmod 0600 "$CONFIG_FILE"; echo 'Configuration reset to v1.0.0 safe Stock defaults. Выполните reboot для полного применения.' ;;
        *) usage; return 2 ;;
    esac
}
safe_cmd() {
    case "$1" in
        disable) recover_stale_transaction >/dev/null 2>&1 || transaction_restore; restore_baseline; touch "$MODDIR/disable"; printf '%s\n%s\n' "$(now_stamp)" manual-safe-disable > "$STATE_SUBDIR/safe-mode.txt"; rm -f "$(boot_pending_file)" "$(boot_recovery_file)"; boot_failure_set 0; echo 'OEM baseline восстановлен; модуль отключён.' ;;
        clear) rm -f "$(boot_pending_file)" "$(boot_recovery_file)" "$(boot_failure_file)" "$STATE_SUBDIR/boot-warning.txt" "$STATE_SUBDIR/safe-mode.txt" "$(profile_quarantine_file)" "$(profile_reboot_file)" "$MODDIR/disable"; echo 'Safe-mode markers cleared. Перезагрузите устройство.' ;;
        *) usage; return 2 ;;
    esac
}

quarantine_cmd() {
    case "$1" in
        show)
            if profile_quarantine_active; then cat "$(profile_quarantine_file)"; else echo 'Карантин профиля отсутствует.'; fi
            ;;
        clear)
            clear_profile_quarantine
            echo 'Карантин профиля очищен. Текущий PROFILE не изменён.'
            ;;
        *) usage; return 2 ;;
    esac
}

command_name="${1:-status}"
case "$command_name" in
    status) show_status ;;
    profile) [ -n "${2:-}" ] || { usage; exit 2; }; set_profile "$2" ;;
    apply) set_profile "$(config_get PROFILE stock)" ;;
    restore) set_profile stock ;;
    verify) verify_package "${2:-}" ;;
    doctor) doctor_cmd ;;
    report) report="$(write_report)"; cat "$report"; echo; echo "Saved: $report" ;;
    conflicts) scan_conflicts ;;
    self-check) self_check ;;
    app)
        case "${2:-}" in list) app_list ;; set) [ -n "${3:-}" ] && [ -n "${4:-}" ] || { usage; exit 2; }; app_set_cmd "$3" "$4" ;; remove) [ -n "${3:-}" ] || { usage; exit 2; }; app_remove_cmd "$3" ;; launch) [ -n "${3:-}" ] || { usage; exit 2; }; app_launch_cmd "$3" "${4:-}" ;; *) usage; exit 2 ;; esac ;;
    bench)
        if [ "${2:-}" = pair ]; then case "${3:-}" in start) [ -n "${4:-}" ] || { usage; exit 2; }; pair_start "$4" ;; next) [ -n "${4:-}" ] || { usage; exit 2; }; pair_next "$4" ;; finish) [ -n "${4:-}" ] || { usage; exit 2; }; pair_finish "$4" ;; status) pair_status ;; abort) pair_abort ;; *) usage; exit 2 ;; esac
        else case "${2:-}" in start) [ -n "${3:-}" ] || { usage; exit 2; }; bench_start "$3" "${4:-}" ;; stop) [ -n "${3:-}" ] || { usage; exit 2; }; bench_stop "$3" ;; status) bench_status ;; *) usage; exit 2 ;; esac; fi ;;
    recommend)
        case "${2:-}" in list) recommend_list ;; show) [ -n "${3:-}" ] || { usage; exit 2; }; recommend_show "$3" ;; apply) [ -n "${3:-}" ] || { usage; exit 2; }; recommend_apply "$3" ;; remove) [ -n "${3:-}" ] || { usage; exit 2; }; recommend_remove "$3" ;; *) usage; exit 2 ;; esac ;;
    gfx)
        case "${2:-}" in reset) [ -n "${3:-}" ] || { usage; exit 2; }; valid_package_name "$3" || { echo 'ERROR: invalid package.'; exit 2; }; dumpsys gfxinfo "$3" reset >/dev/null 2>&1 && echo "gfxinfo reset: $3" || { echo 'ERROR: reset failed.'; exit 1; } ;; capture) [ -n "${3:-}" ] || { usage; exit 2; }; capture_gfx "$3" ;; *) usage; exit 2 ;; esac ;;
    config) config_cmd "${2:-}" ;;
    safe) safe_cmd "${2:-}" ;;
    quarantine) quarantine_cmd "${2:-show}" ;;
    backup) backup_cmd ;;
    support) support_cmd ;;
    logs) lines="$(numeric_value "${2:-80}" 80 1000)"; [ -f "$LOG_FILE" ] && tail -n "$lines" "$LOG_FILE" || echo 'Лог пока отсутствует.' ;;
    history) lines="$(numeric_value "${2:-20}" 20 200)"; [ -f "$BOOT_HISTORY" ] && tail -n "$lines" "$BOOT_HISTORY" | tr '\t' ' ' || echo 'История загрузок отсутствует.' ;;
    guard) [ "${2:-}" = reset ] || { usage; exit 2; }; safe_cmd clear ;;
    paths) echo "Module: $MODDIR"; echo "State: $STATE_DIR"; echo "Config: $CONFIG_FILE"; echo "App profiles: $APP_PROFILE_FILE"; echo "Recommendations: $RECOMMEND_FILE"; echo "Logs: $LOG_DIR"; echo "Reports: $REPORT_DIR"; echo "Backups: $BACKUP_DIR" ;;
    menu)
        menu_script="$MODDIR/neorender"
        [ -x "$menu_script" ] || menu_script="$MODDIR/system/bin/neorender"
        [ -x "$menu_script" ] || { echo 'ERROR: интерактивное меню не найдено.'; exit 1; }
        exec "$menu_script"
        ;;
    help|-h|--help) usage ;;
    *) usage; exit 2 ;;
esac
