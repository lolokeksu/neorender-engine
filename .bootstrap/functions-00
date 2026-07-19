#!/system/bin/sh
# NeoRender Engine v1 shared runtime. POSIX / Magisk BusyBox ash compatible.

MODID="neorender-engine"
MODULE_DIR="${NEORENDER_MODULE_DIR:-/data/adb/modules/${MODID}}"
STATE_DIR="${NEORENDER_STATE_DIR:-/data/adb/${MODID}}"
CONFIG_FILE="${STATE_DIR}/config.conf"
APP_PROFILE_FILE="${STATE_DIR}/app-profiles.conf"
RECOMMEND_FILE="${STATE_DIR}/recommendations.tsv"
STATE_SUBDIR="${STATE_DIR}/state"
LOG_DIR="${STATE_DIR}/logs"
REPORT_DIR="${STATE_DIR}/reports"
BACKUP_DIR="${STATE_DIR}/backups"
BENCH_DIR="${STATE_DIR}/bench"
PAIR_DIR="${BENCH_DIR}/pair"
TRANSACTION_DIR="${STATE_SUBDIR}/transaction"
LOCK_DIR="${STATE_SUBDIR}/locks"
HISTORY_DIR="${STATE_DIR}/history"
TMP_DIR="${STATE_SUBDIR}/tmp"
LOG_FILE="${LOG_DIR}/neorender.log"
BOOT_HISTORY="${HISTORY_DIR}/boot.tsv"
RENDERER_PROP="debug.hwui.renderer"
EMPTY_MARKER="__NEORENDER_EMPTY_PROPERTY__"

uptime_seconds() {
    value="$(awk '{print int($1)}' /proc/uptime 2>/dev/null)"
    case "$value" in ''|*[!0-9]*) value=0 ;; esac
    printf '%s\n' "$value"
}
clock_is_valid() {
    value="$(date '+%s' 2>/dev/null)"
    case "$value" in ''|*[!0-9]*) return 1 ;; esac
    [ "$value" -ge 1577836800 ] 2>/dev/null
}
now_stamp() {
    if clock_is_valid; then
        date '+%Y-%m-%d %H:%M:%S' 2>/dev/null
    else
        printf 'boot+%ss\n' "$(uptime_seconds)"
    fi
}
file_stamp() {
    if clock_is_valid; then
        date '+%Y%m%d-%H%M%S' 2>/dev/null
    else
        printf 'boot-%06us-%s\n' "$(uptime_seconds)" "$$"
    fi
}
epoch_now() { date '+%s' 2>/dev/null || echo 0; }

ensure_state_dirs() {
    mkdir -p "$STATE_SUBDIR" "$LOG_DIR" "$REPORT_DIR" "$BACKUP_DIR" "$BENCH_DIR" "$PAIR_DIR" "$TRANSACTION_DIR" "$LOCK_DIR" "$HISTORY_DIR" "$TMP_DIR"
    chmod 0700 "$STATE_DIR" "$STATE_SUBDIR" "$BACKUP_DIR" "$BENCH_DIR" "$PAIR_DIR" "$TRANSACTION_DIR" "$LOCK_DIR" "$HISTORY_DIR" "$TMP_DIR" 2>/dev/null
    chmod 0755 "$LOG_DIR" "$REPORT_DIR" 2>/dev/null
    [ -f "$APP_PROFILE_FILE" ] || : > "$APP_PROFILE_FILE"
    [ -f "$RECOMMEND_FILE" ] || : > "$RECOMMEND_FILE"
    chmod 0600 "$APP_PROFILE_FILE" "$RECOMMEND_FILE" 2>/dev/null
}

numeric_value() {
    value="$1"; fallback="$2"; maximum="$3"
    case "$value" in ''|*[!0-9]*) value="$fallback" ;; esac
    [ "$value" -le "$maximum" ] 2>/dev/null || value="$maximum"
    printf '%s\n' "$value"
}

log_rotate_if_needed() {
    [ -f "$LOG_FILE" ] || return 0
    max_kib="$(numeric_config LOG_MAX_KIB 512 4096)"
    size="$(wc -c < "$LOG_FILE" 2>/dev/null)"
    case "$size" in ''|*[!0-9]*) return 0 ;; esac
    [ "$size" -le $((max_kib * 1024)) ] && return 0
    mv -f "$LOG_FILE" "$LOG_FILE.1" 2>/dev/null || true
}

log_msg() {
    ensure_state_dirs
    log_rotate_if_needed
    printf '%s | %s\n' "$(now_stamp)" "$*" >> "$LOG_FILE"
    command -v log >/dev/null 2>&1 && log -t NeoRender "$*" >/dev/null 2>&1 || true
}

read_prop() { getprop "$1" 2>/dev/null; }
set_prop_value() {
    prop_name="$1"; prop_value="$2"
    if command -v resetprop >/dev/null 2>&1; then
        resetprop -n "$prop_name" "$prop_value" >/dev/null 2>&1
    else
        setprop "$prop_name" "$prop_value" >/dev/null 2>&1
    fi
}
delete_prop_value() {
    prop_name="$1"
    if command -v resetprop >/dev/null 2>&1; then
        resetprop --delete "$prop_name" >/dev/null 2>&1 || resetprop -n "$prop_name" "" >/dev/null 2>&1
    else
        setprop "$prop_name" "" >/dev/null 2>&1
    fi
}

config_get() {
    key="$1"; default_value="$2"
    [ -f "$CONFIG_FILE" ] || { printf '%s\n' "$default_value"; return 0; }
    value="$(awk -F= -v wanted="$key" '
        /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
        {
            k=$1; gsub(/^[[:space:]]+|[[:space:]]+$/, "", k)
            if (k == wanted) {
                sub(/^[^=]*=/, "", $0)
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
                print $0; exit
            }
        }
    ' "$CONFIG_FILE" 2>/dev/null)"
    [ -n "$value" ] && printf '%s\n' "$value" || printf '%s\n' "$default_value"
}

config_has() {
    key="$1"
    [ -f "$CONFIG_FILE" ] && awk -F= -v wanted="$key" '
        /^[[:space:]]*#/ {next}
        {k=$1; gsub(/^[[:space:]]+|[[:space:]]+$/, "", k); if(k==wanted){found=1; exit}}
        END{exit found?0:1}
    ' "$CONFIG_FILE"
}

config_set() {
    key="$1"; replacement="$2"
    ensure_state_dirs
    [ -f "$CONFIG_FILE" ] || return 1
    tmp="${CONFIG_FILE}.tmp.$$"
    awk -v wanted="$key" -v replacement="$replacement" '
        BEGIN { changed=0 }
        {
            line=$0
            if (line !~ /^[[:space:]]*#/ && line ~ /^[[:space:]]*[A-Za-z0-9_]+[[:space:]]*=/) {
                split(line, p, "="); k=p[1]
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", k)
                if (k == wanted) { print wanted "=" replacement; changed=1; next }
            }
            print line
        }
        END { if (!changed) print wanted "=" replacement }
    ' "$CONFIG_FILE" > "$tmp" || { rm -f "$tmp"; return 1; }
    mv -f "$tmp" "$CONFIG_FILE" || return 1
    chmod 0600 "$CONFIG_FILE" 2>/dev/null
}

merge_config_defaults() {
    default_file="$1"
    [ -f "$default_file" ] || return 1
    [ -f "$CONFIG_FILE" ] || cp -f "$default_file" "$CONFIG_FILE"
    while IFS='=' read -r key value; do
        case "$key" in ''|'#'*) continue ;; esac
        key="$(printf '%s' "$key" | tr -d '[:space:]')"
        printf '%s' "$key" | grep -Eq '^[A-Z0-9_]+$' || continue
        config_has "$key" || config_set "$key" "$value"
    done < "$default_file"
    config_set CONFIG_SCHEMA 4
    chmod 0600 "$CONFIG_FILE" 2>/dev/null
}

numeric_config() { numeric_value "$(config_get "$1" "$2")" "$2" "$3"; }

acquire_lock() {
    name="$1"; timeout="${2:-10}"; path="${LOCK_DIR}/${name}.lock"
    ensure_state_dirs; waited=0
    while ! mkdir "$path" 2>/dev/null; do
        if [ -f "$path/pid" ]; then
            holder="$(cat "$path/pid" 2>/dev/null)"