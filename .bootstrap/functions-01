            case "$holder" in ''|*[!0-9]*) holder=0 ;; esac
            if [ "$holder" -gt 1 ] 2>/dev/null && ! kill -0 "$holder" 2>/dev/null; then rm -rf "$path"; continue; fi
        fi
        [ "$waited" -lt "$timeout" ] || return 1
        sleep 1; waited=$((waited + 1))
    done
    printf '%s\n' "$$" > "$path/pid"
    CURRENT_LOCK="$path"
}
release_lock() { [ -n "${CURRENT_LOCK:-}" ] && rm -rf "$CURRENT_LOCK"; CURRENT_LOCK=""; }

normalize_profile() { case "$1" in stock|compatibility|vulkan) printf '%s\n' "$1" ;; *) printf '%s\n' invalid ;; esac; }
normalize_renderer() { case "$1" in skiagl|skiavk) printf '%s\n' "$1" ;; *) printf '%s\n' invalid ;; esac; }
profile_renderer() { case "$1" in stock) echo stock ;; compatibility) echo skiagl ;; vulkan) echo skiavk ;; *) echo invalid ;; esac; }
valid_package_name() { printf '%s' "$1" | grep -Eq '^[A-Za-z0-9_]+([.][A-Za-z0-9_]+)+$'; }
package_exists() { cmd package path "$1" >/dev/null 2>&1 || pm path "$1" >/dev/null 2>&1; }

current_fingerprint() {
    fp="$(read_prop ro.build.fingerprint)"; [ -n "$fp" ] || fp="$(read_prop ro.build.description)"
    [ -n "$fp" ] || fp=unknown-build; printf '%s\n' "$fp"
}
device_identity() {
    printf '%s %s %s %s %s\n' "$(read_prop ro.product.model)" "$(read_prop ro.product.name)" "$(read_prop ro.product.device)" "$(read_prop ro.product.marketname)" "$(read_prop ro.build.product)"
}
is_target_model() { device_identity | grep -Eqi 'RMX3700|RMX3701|GT[[:space:]_-]*Neo[[:space:]_-]*5[[:space:]_-]*SE|GT[[:space:]_-]*Neo5[[:space:]_-]*SE'; }
is_realme_device() { printf '%s %s' "$(read_prop ro.product.manufacturer)" "$(read_prop ro.product.brand)" | grep -qi realme; }
is_qualcomm_device() {
    combined="$(read_prop ro.soc.manufacturer) $(read_prop ro.hardware) $(read_prop ro.board.platform)"
    printf '%s' "$combined" | grep -Eqi 'qualcomm|qcom' && return 0
    [ -e /vendor/lib64/hw/vulkan.adreno.so ] || [ -e /vendor/lib/hw/vulkan.adreno.so ]
}
has_hardware_vulkan() {
    [ "$(read_prop ro.boot.qemu)" = 1 ] && return 1
    for candidate in /vendor/lib64/hw/vulkan.*.so /vendor/lib/hw/vulkan.*.so; do
        [ -e "$candidate" ] || continue
        case "$candidate" in *swiftshader*|*lavapipe*|*ranchu*|*goldfish*) continue ;; *) return 0 ;; esac
    done
    command -v pm >/dev/null 2>&1 && pm list features 2>/dev/null | grep -q 'android.hardware.vulkan' && return 0
    return 1
}

protected_package_reason() {
    pkg="$1"
    case "$pkg" in
        android|com.android.systemui|com.android.phone|com.android.permissioncontroller|com.google.android.permissioncontroller|com.android.packageinstaller|com.google.android.packageinstaller)
            echo core-system; return 0 ;;
    esac
    home="$(cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME 2>/dev/null | tail -n 1 | cut -d/ -f1)"
    [ -n "$home" ] && [ "$pkg" = "$home" ] && { echo home-launcher; return 0; }
    return 1
}

validate_environment() {
    renderer="$1"; required_api="$(config_get REQUIRED_ANDROID_API 33)"; actual_api="$(read_prop ro.build.version.sdk)"
    [ -z "$required_api" ] || [ "$actual_api" = "$required_api" ] || { log_msg "Rejected API $actual_api; required $required_api"; return 1; }
    [ "$(config_get REQUIRE_REALME 1)" != 1 ] || is_realme_device || { log_msg 'Realme device not detected'; return 1; }
    [ "$(config_get REQUIRE_QUALCOMM 1)" != 1 ] || is_qualcomm_device || { log_msg 'Qualcomm platform not detected'; return 1; }
    [ "$(config_get STRICT_TARGET_MODEL 1)" != 1 ] || is_target_model || { log_msg 'Target RMX3700/RMX3701 not detected'; return 1; }
    if [ "$renderer" = skiavk ] && [ "$(config_get REQUIRE_HARDWARE_VULKAN 1)" = 1 ]; then has_hardware_vulkan || { log_msg 'Hardware Vulkan not detected'; return 1; }; fi
    return 0
}

capture_baseline_if_needed() {
    ensure_state_dirs
    current_fp="$(current_fingerprint)"; saved_fp=""
    [ -f "$STATE_SUBDIR/baseline.fingerprint" ] && saved_fp="$(cat "$STATE_SUBDIR/baseline.fingerprint" 2>/dev/null)"
    if [ ! -f "$STATE_SUBDIR/baseline.renderer" ] || [ "$saved_fp" != "$current_fp" ]; then
        current="$(read_prop "$RENDERER_PROP")"
        [ -n "$current" ] && printf '%s\n' "$current" > "$STATE_SUBDIR/baseline.renderer" || printf '%s\n' "$EMPTY_MARKER" > "$STATE_SUBDIR/baseline.renderer"
        printf '%s\n' "$current_fp" > "$STATE_SUBDIR/baseline.fingerprint"
        chmod 0600 "$STATE_SUBDIR/baseline.renderer" "$STATE_SUBDIR/baseline.fingerprint" 2>/dev/null
        log_msg "Captured OEM baseline ${RENDERER_PROP}=${current:-<empty>}"
    fi
}
restore_baseline() {
    if [ ! -f "$STATE_SUBDIR/baseline.renderer" ]; then delete_prop_value "$RENDERER_PROP"; log_msg "Baseline absent; deleted ${RENDERER_PROP}"; return 0; fi
    value="$(cat "$STATE_SUBDIR/baseline.renderer" 2>/dev/null)"
    if [ "$value" = "$EMPTY_MARKER" ] || [ -z "$value" ]; then delete_prop_value "$RENDERER_PROP"; log_msg 'Restored empty OEM renderer baseline'; else set_prop_value "$RENDERER_PROP" "$value" || return 1; log_msg "Restored OEM renderer baseline: $value"; fi
}
save_renderer_to_file() { value="$(read_prop "$RENDERER_PROP")"; [ -n "$value" ] && printf '%s\n' "$value" > "$1" || printf '%s\n' "$EMPTY_MARKER" > "$1"; }
restore_renderer_from_file() {
    [ -f "$1" ] || return 1; value="$(cat "$1" 2>/dev/null)"
    if [ "$value" = "$EMPTY_MARKER" ] || [ -z "$value" ]; then delete_prop_value "$RENDERER_PROP"; else set_prop_value "$RENDERER_PROP" "$value"; fi
}
apply_renderer() {
    renderer="$(normalize_renderer "$1")"; [ "$renderer" != invalid ] || return 1
    validate_environment "$renderer" || return 1
    set_prop_value "$RENDERER_PROP" "$renderer" || return 1
    actual="$(read_prop "$RENDERER_PROP")"
    [ "$actual" = "$renderer" ] || { log_msg "Renderer verification failed: requested=$renderer actual=${actual:-<empty>}"; return 1; }
    log_msg "Applied ${RENDERER_PROP}=$renderer for newly created processes"
}
apply_profile() {
    profile="$(normalize_profile "$1")"; [ "$profile" != invalid ] || return 1
    capture_baseline_if_needed; renderer="$(profile_renderer "$profile")"
    if [ "$renderer" = stock ]; then restore_baseline; else apply_renderer "$renderer"; fi
}

transaction_active_dir() { printf '%s\n' "$TRANSACTION_DIR/active"; }
transaction_begin() {
    pkg="$1"; renderer="$2"; active="$(transaction_active_dir)"
    [ ! -d "$active" ] || return 1
    mkdir -p "$active" || return 1
    save_renderer_to_file "$active/saved.renderer" || { rm -rf "$active"; return 1; }
    printf '%s\n' "$$" > "$active/pid"
    printf '%s\n' "$pkg" > "$active/package"
    printf '%s\n' "$renderer" > "$active/renderer"
    printf '%s\n' "$(epoch_now)" > "$active/started.epoch"
    chmod -R 0700 "$active" 2>/dev/null
}
transaction_restore() {
    active="$(transaction_active_dir)"; [ -d "$active" ] || return 0
    restore_renderer_from_file "$active/saved.renderer" >/dev/null 2>&1 || restore_baseline >/dev/null 2>&1
    log_msg "Recovered renderer transaction for $(cat "$active/package" 2>/dev/null)"
    rm -rf "$active"
}
recover_stale_transaction() {
    active="$(transaction_active_dir)"; [ -d "$active" ] || return 0
    holder="$(cat "$active/pid" 2>/dev/null)"; started="$(cat "$active/started.epoch" 2>/dev/null)"; now="$(epoch_now)"
    case "$holder" in ''|*[!0-9]*) holder=0 ;; esac
    case "$started" in ''|*[!0-9]*) started=0 ;; esac
    case "$now" in ''|*[!0-9]*) now=0 ;; esac
    age=$((now - started)); [ "$age" -ge 0 ] 2>/dev/null || age=0
    stale_after="$(numeric_config TRANSACTION_STALE_SECONDS 180 1800)"
    if [ "$holder" -le 1 ] 2>/dev/null || ! kill -0 "$holder" 2>/dev/null || [ "$age" -ge "$stale_after" ]; then transaction_restore; return 0; fi
    return 1
}

wait_for_boot_completed() {
    timeout="$(numeric_config BOOT_COMPLETED_TIMEOUT_SECONDS 600 1200)"; elapsed=0
    while [ "$(read_prop sys.boot_completed)" != 1 ]; do sleep 2; elapsed=$((elapsed + 2)); [ "$elapsed" -lt "$timeout" ] || return 1; done
}


current_boot_id() {
    [ -r /proc/sys/kernel/random/boot_id ] && cat /proc/sys/kernel/random/boot_id 2>/dev/null || echo unknown-boot
}
boot_pending_file() { printf '%s\n' "$STATE_SUBDIR/boot.pending"; }
boot_recovery_file() { printf '%s\n' "$STATE_SUBDIR/boot.recovery-stock"; }
boot_failure_file() { printf '%s\n' "$STATE_SUBDIR/boot-failure.count"; }
boot_marker_get() {
    key="$1"; file="$(boot_pending_file)"
    [ -f "$file" ] || return 1
    awk -F= -v wanted="$key" '$1==wanted {sub(/^[^=]*=/, "", $0); print; exit}' "$file" 2>/dev/null
}
boot_marker_age() {
    started="$(boot_marker_get epoch)"; now="$(epoch_now)"
    case "$started" in ''|*[!0-9]*) started=0 ;; esac
    case "$now" in ''|*[!0-9]*) now=0 ;; esac
    age=$((now - started)); [ "$age" -ge 0 ] 2>/dev/null || age=0
    printf '%s\n' "$age"
}
boot_pending_write() {
    file="$(boot_pending_file)"; ensure_state_dirs
    {
        printf 'epoch=%s\n' "$(epoch_now)"
        printf 'fingerprint=%s\n' "$(current_fingerprint)"
        printf 'boot_id=%s\n' "$(current_boot_id)"
        printf 'profile=%s\n' "$(config_get PROFILE stock)"
    } > "$file"
    chmod 0600 "$file" 2>/dev/null
}
boot_failure_count() {
    file="$(boot_failure_file)"; value=0
    [ -f "$file" ] && value="$(cat "$file" 2>/dev/null)"
    case "$value" in ''|*[!0-9]*) value=0 ;; esac
    printf '%s\n' "$value"
}
boot_failure_set() {
    value="$1"; case "$value" in ''|*[!0-9]*) value=0 ;; esac