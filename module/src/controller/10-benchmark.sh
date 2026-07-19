    [ "$requested" != invalid ] || { echo 'ERROR: renderer должен быть skiagl или skiavk.'; return 2; }
    acquire_lock launch 10 || { echo 'ERROR: другой запуск или benchmark уже выполняется.'; return 1; }
    launch_package_with_renderer "$pkg" "$requested"; rc=$?; release_lock
    case "$rc" in
        0) echo "Запущено: $pkg"; echo "Renderer при создании процесса: $requested"; echo "PID: $LAUNCHED_PID"; echo "HWUI pipeline: ${LAUNCHED_PIPELINE:-not reported}"; echo 'Глобальное property восстановлено после запуска.' ;;
        2) echo 'ERROR: некорректный пакет или renderer.' ;;
        3) echo "ERROR: пакет не установлен: $pkg" ;;
        4) echo 'ERROR: устройство не прошло проверку среды.' ;;
        5) echo 'ERROR: временный renderer не применён.' ;;
        6) echo 'ERROR: launchable activity не найдена.' ;;
        7) echo 'ERROR: процесс приложения не появился в заданный срок.' ;;
        8) echo 'ERROR: системный критический пакет защищён от force-stop.' ;;
        9) echo 'ERROR: активна другая renderer-транзакция.' ;;
        *) echo "ERROR: запуск завершился с кодом $rc." ;;
    esac
    return "$rc"
}

metric_extract() {
    raw="$1"; key="$2"
    case "$key" in
        pipeline) grep -m 1 -E 'Pipeline|Rendering pipeline' "$raw" 2>/dev/null | sed 's/^[[:space:]]*//' ;;
        frames) grep -m 1 -E 'Total frames rendered:' "$raw" 2>/dev/null | sed -E 's/.*:[[:space:]]*([0-9]+).*/\1/' ;;
        janky_count) grep -m 1 -E 'Janky frames:' "$raw" 2>/dev/null | sed -E 's/.*:[[:space:]]*([0-9]+).*/\1/' ;;
        janky_percent) grep -m 1 -E 'Janky frames:' "$raw" 2>/dev/null | sed -nE 's/.*\(([0-9.]+)%\).*/\1/p' ;;
        p50) grep -m 1 -E '50th percentile:' "$raw" 2>/dev/null | sed -nE 's/.*:[[:space:]]*([0-9.]+)ms.*/\1/p' ;;
        p90) grep -m 1 -E '90th percentile:' "$raw" 2>/dev/null | sed -nE 's/.*:[[:space:]]*([0-9.]+)ms.*/\1/p' ;;
        p95) grep -m 1 -E '95th percentile:' "$raw" 2>/dev/null | sed -nE 's/.*:[[:space:]]*([0-9.]+)ms.*/\1/p' ;;
        p99) grep -m 1 -E '99th percentile:' "$raw" 2>/dev/null | sed -nE 's/.*:[[:space:]]*([0-9.]+)ms.*/\1/p' ;;
    esac
}
metric_get() { awk -F= -v k="$2" '$1==k {sub(/^[^=]*=/, "", $0); print; exit}' "$1" 2>/dev/null; }
number_or_zero() { case "$1" in ''|*[!0-9.-]*) echo 0 ;; *) echo "$1" ;; esac; }
float_calc() { awk "BEGIN {printf \"%.3f\\n\", $*}" 2>/dev/null; }
float_ge() { awk -v a="$1" -v b="$2" 'BEGIN{exit !(a+0>=b+0)}'; }
float_le() { awk -v a="$1" -v b="$2" 'BEGIN{exit !(a+0<=b+0)}'; }
percent_improvement() { awk -v old="$1" -v new="$2" 'BEGIN{if(old+0<=0){print 0}else{printf "%.3f", ((old-new)/old)*100}}'; }
absolute_percent_drift() { awk -v a="$1" -v b="$2" 'BEGIN{m=(a>b?a:b); if(m<=0){print 0}else{d=a-b;if(d<0)d=-d;printf "%.3f",(d/m)*100}}'; }

create_benchmark_report() {
    pkg="$1"; renderer="$2"; session="$3"; output="$4"
    start_epoch="$(cat "$session/start.epoch" 2>/dev/null)"; end_epoch="$(epoch_now)"
    start_epoch="$(number_or_zero "$start_epoch")"; end_epoch="$(number_or_zero "$end_epoch")"
    elapsed=$((end_epoch - start_epoch)); [ "$elapsed" -ge 0 ] 2>/dev/null || elapsed=0
    raw="$output.raw.tmp"
    dumpsys gfxinfo "$pkg" framestats > "$raw" 2>&1
    start_temp="$(number_or_zero "$(cat "$session/battery_temp.start" 2>/dev/null)")"; end_temp="$(number_or_zero "$(battery_field temperature)")"; temp_delta=$((end_temp - start_temp))
    {
        echo 'NeoRender Engine v1 benchmark report'
        echo "Package: $pkg"; echo "Renderer at process creation: $renderer"
        echo "Started: $(cat "$session/start.time" 2>/dev/null)"; echo "Finished: $(now_stamp)"; echo "Elapsed seconds: $elapsed"
        echo "PID at start: $(cat "$session/pid" 2>/dev/null)"; echo "HWUI pipeline at start: $(cat "$session/pipeline" 2>/dev/null)"
        echo "Battery temperature start (0.1 C): $start_temp"; echo "Battery temperature finish (0.1 C): $end_temp"; echo "Battery temperature delta (0.1 C): $temp_delta"
        echo "Global $RENDERER_PROP at finish: $(read_prop "$RENDERER_PROP")"; echo
        echo '[Battery before]'; cat "$session/battery.start.txt" 2>/dev/null; echo
        echo '[Battery after]'; dumpsys battery 2>/dev/null; echo
        echo '[Thermal before]'; cat "$session/thermal.start.txt" 2>/dev/null; echo
        echo '[Thermal after]'; thermal_summary; echo
        echo '[gfxinfo framestats]'; cat "$raw"
    } > "$output"
    summary="$output.summary"
    {
        echo "package=$pkg"; echo "renderer=$renderer"; echo "duration_seconds=$elapsed"; echo "temperature_start=$start_temp"; echo "temperature_finish=$end_temp"; echo "temperature_delta=$temp_delta"
        echo "pipeline=$(metric_extract "$raw" pipeline)"; echo "frames=$(metric_extract "$raw" frames)"; echo "janky_count=$(metric_extract "$raw" janky_count)"; echo "janky_percent=$(metric_extract "$raw" janky_percent)"
        echo "p50_ms=$(metric_extract "$raw" p50)"; echo "p90_ms=$(metric_extract "$raw" p90)"; echo "p95_ms=$(metric_extract "$raw" p95)"; echo "p99_ms=$(metric_extract "$raw" p99)"
        echo "report=$output"
    } > "$summary"
    rm -f "$raw"; chmod 0644 "$output" "$summary" 2>/dev/null
    BENCH_OUTPUT="$output"; BENCH_SUMMARY="$summary"
}

benchmark_begin_session() {
    pkg="$1"; renderer="$2"; session="$3"
    mkdir -p "$session" || return 1
    printf '%s\n' "$pkg" > "$session/package"; printf '%s\n' "$renderer" > "$session/renderer"; printf '%s\n' "$(epoch_now)" > "$session/start.epoch"; printf '%s\n' "$(now_stamp)" > "$session/start.time"
    dumpsys battery > "$session/battery.start.txt" 2>&1; battery_field temperature > "$session/battery_temp.start"; thermal_summary > "$session/thermal.start.txt" 2>&1
    dumpsys gfxinfo "$pkg" reset >/dev/null 2>&1
    launch_package_with_renderer "$pkg" "$renderer"; rc=$?
    if [ "$rc" -ne 0 ]; then rm -rf "$session"; return "$rc"; fi
    printf '%s\n' "$LAUNCHED_PID" > "$session/pid"; printf '%s\n' "$LAUNCHED_PIPELINE" > "$session/pipeline"
}

bench_start() {
    pkg="$1"; requested="$2"; valid_package_name "$pkg" || { echo 'ERROR: некорректный package name.'; return 2; }; package_exists "$pkg" || { echo 'ERROR: пакет не установлен.'; return 1; }
    [ -n "$requested" ] || requested="$(app_profile_get "$pkg")"; [ -n "$requested" ] || requested="$(config_get DEFAULT_APP_RENDERER skiavk)"
    requested="$(normalize_renderer "$requested")"; [ "$requested" != invalid ] || { echo 'ERROR: renderer должен быть skiagl или skiavk.'; return 2; }
    session="$BENCH_DIR/active"; [ ! -d "$session" ] || { echo 'ERROR: уже существует активный benchmark.'; return 1; }; [ ! -d "$PAIR_DIR/active" ] || { echo 'ERROR: активен парный benchmark.'; return 1; }
    acquire_lock launch 10 || { echo 'ERROR: другой запуск уже выполняется.'; return 1; }
    benchmark_begin_session "$pkg" "$requested" "$session"; rc=$?; release_lock
    [ "$rc" -eq 0 ] || { echo "ERROR: приложение не запущено, код $rc."; return "$rc"; }
    echo "Benchmark запущен: $pkg"; echo "Renderer: $requested"; echo 'Выполните одинаковый сценарий, затем:'; echo "su -c neorenderctl bench stop $pkg"
}
bench_stop() {
    pkg="$1"; session="$BENCH_DIR/active"; [ -d "$session" ] || { echo 'ERROR: активного benchmark нет.'; return 1; }
    saved_pkg="$(cat "$session/package" 2>/dev/null)"; [ "$pkg" = "$saved_pkg" ] || { echo "ERROR: активный пакет — $saved_pkg"; return 2; }
    renderer="$(cat "$session/renderer" 2>/dev/null)"; output="$REPORT_DIR/benchmark-${pkg}-${renderer}-$(file_stamp).txt"
    create_benchmark_report "$pkg" "$renderer" "$session" "$output"; rm -rf "$session"; rotate_pattern "$REPORT_DIR/benchmark-*.txt"
    echo "Benchmark saved: $BENCH_OUTPUT"; cat "$BENCH_SUMMARY"
}
bench_status() {
    session="$BENCH_DIR/active"; [ -d "$session" ] || { echo 'Активного benchmark нет.'; return; }
    echo "Package: $(cat "$session/package" 2>/dev/null)"; echo "Renderer: $(cat "$session/renderer" 2>/dev/null)"; echo "Started: $(cat "$session/start.time" 2>/dev/null)"; echo "PID: $(cat "$session/pid" 2>/dev/null)"
}

pair_start() {
    pkg="$1"; valid_package_name "$pkg" || { echo 'ERROR: некорректный package name.'; return 2; }; package_exists "$pkg" || { echo 'ERROR: пакет не установлен.'; return 1; }
    [ ! -d "$BENCH_DIR/active" ] || { echo 'ERROR: активен обычный benchmark.'; return 1; }; pair_active="$PAIR_DIR/active"; [ ! -d "$pair_active" ] || { echo 'ERROR: парный benchmark уже активен.'; return 1; }
    acquire_lock launch 10 || { echo 'ERROR: другой запуск уже выполняется.'; return 1; }
    mkdir -p "$pair_active"; printf '%s\n' "$pkg" > "$pair_active/package"; printf '%s\n' skiagl > "$pair_active/phase"
    benchmark_begin_session "$pkg" skiagl "$pair_active/current"; rc=$?; release_lock
    [ "$rc" -eq 0 ] || { rm -rf "$pair_active"; echo "ERROR: SkiaGL-фаза не запущена, код $rc."; return "$rc"; }
    echo 'A/B benchmark: фаза 1/2 — SkiaGL.'; echo 'Выполните тестовый сценарий, затем:'; echo "su -c neorenderctl bench pair next $pkg"
}
pair_next() {
    pkg="$1"; pair_active="$PAIR_DIR/active"; [ -d "$pair_active" ] || { echo 'ERROR: парный benchmark не активен.'; return 1; }
    saved_pkg="$(cat "$pair_active/package" 2>/dev/null)"; phase="$(cat "$pair_active/phase" 2>/dev/null)"; [ "$pkg" = "$saved_pkg" ] || { echo "ERROR: активный пакет — $saved_pkg"; return 2; }
    case "$phase" in
        skiagl)
            output="$REPORT_DIR/pair-${pkg}-skiagl-$(file_stamp).txt"
            create_benchmark_report "$pkg" skiagl "$pair_active/current" "$output"
            mv -f "$BENCH_SUMMARY" "$pair_active/skiagl.summary"
            printf '%s\n' "$BENCH_OUTPUT" > "$pair_active/skiagl.report"
            rm -rf "$pair_active/current"
            printf '%s\n' gl-captured > "$pair_active/phase"
            ;;
        gl-captured) : ;;
        *) echo 'ERROR: ожидается завершение SkiaVK-фазы.'; return 2 ;;
    esac
    acquire_lock launch 10 || { echo 'ERROR: другой запуск уже выполняется.'; return 1; }
    benchmark_begin_session "$pkg" skiavk "$pair_active/current"; rc=$?; release_lock
    if [ "$rc" -ne 0 ]; then
        printf '%s\n' gl-captured > "$pair_active/phase"
        echo "ERROR: SkiaVK-фаза не запущена, код $rc. Повторите pair next; SkiaGL-отчёт сохранён."
        return "$rc"
    fi
    printf '%s\n' skiavk > "$pair_active/phase"
    echo 'A/B benchmark: фаза 2/2 — SkiaVK.'; echo 'Повторите тот же сценарий, затем:'; echo "su -c neorenderctl bench pair finish $pkg"
}

compare_pair_summaries() {
    gl="$1"; vk="$2"; result="$3"
    min_frames="$(numeric_config BENCH_MIN_FRAMES 120 10000)"; min_duration="$(numeric_config BENCH_MIN_DURATION_SECONDS 20 600)"; max_drift="$(numeric_config BENCH_MAX_DURATION_DRIFT_PERCENT 30 100)"; min_gain="$(numeric_config BENCH_IMPROVEMENT_PERCENT 5 50)"; max_regress="$(numeric_config BENCH_MAX_REGRESSION_PERCENT 3 25)"; thermal_penalty="$(numeric_config BENCH_THERMAL_PENALTY_TENTHS_C 20 100)"
    gl_frames="$(number_or_zero "$(metric_get "$gl" frames)")"; vk_frames="$(number_or_zero "$(metric_get "$vk" frames)")"; gl_duration="$(number_or_zero "$(metric_get "$gl" duration_seconds)")"; vk_duration="$(number_or_zero "$(metric_get "$vk" duration_seconds)")"
    gl_jank="$(number_or_zero "$(metric_get "$gl" janky_percent)")"; vk_jank="$(number_or_zero "$(metric_get "$vk" janky_percent)")"; gl_p95="$(number_or_zero "$(metric_get "$gl" p95_ms)")"; vk_p95="$(number_or_zero "$(metric_get "$vk" p95_ms)")"
    gl_temp="$(number_or_zero "$(metric_get "$gl" temperature_delta)")"; vk_temp="$(number_or_zero "$(metric_get "$vk" temperature_delta)")"
    duration_drift="$(absolute_percent_drift "$gl_duration" "$vk_duration")"
    vk_p95_gain="$(percent_improvement "$gl_p95" "$vk_p95")"; vk_jank_gain="$(percent_improvement "$gl_jank" "$vk_jank")"; gl_p95_gain="$(percent_improvement "$vk_p95" "$gl_p95")"; gl_jank_gain="$(percent_improvement "$vk_jank" "$gl_jank")"
    recommendation=inconclusive; confidence=none; reason='insufficient-or-inconsistent-data'; gl_wins=0; vk_wins=0

    valid=1
    [ "$gl_frames" -ge "$min_frames" ] 2>/dev/null || valid=0; [ "$vk_frames" -ge "$min_frames" ] 2>/dev/null || valid=0
    [ "$gl_duration" -ge "$min_duration" ] 2>/dev/null || valid=0; [ "$vk_duration" -ge "$min_duration" ] 2>/dev/null || valid=0
    float_le "$duration_drift" "$max_drift" || valid=0
    float_ge "$gl_p95" 0.001 || valid=0; float_ge "$vk_p95" 0.001 || valid=0

    if [ "$valid" -eq 1 ]; then
        vk_p95_regress="$(percent_improvement "$vk_p95" "$gl_p95")"; vk_jank_regress="$(percent_improvement "$vk_jank" "$gl_jank")"
        gl_p95_regress="$(percent_improvement "$gl_p95" "$vk_p95")"; gl_jank_regress="$(percent_improvement "$gl_jank" "$vk_jank")"
        if float_ge "$vk_p95_gain" "$min_gain" && float_le "$vk_jank_regress" "$max_regress"; then vk_wins=$((vk_wins + 1)); fi
        if float_ge "$vk_jank_gain" "$min_gain" && float_le "$vk_p95_regress" "$max_regress"; then vk_wins=$((vk_wins + 1)); fi