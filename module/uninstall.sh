#!/system/bin/sh
MODDIR=${0%/*}
NEORENDER_MODULE_DIR="$MODDIR"
. "$MODDIR/common/functions.sh"
ensure_state_dirs
recover_stale_transaction >/dev/null 2>&1 || transaction_restore >/dev/null 2>&1
capture_baseline_if_needed
restore_baseline
log_msg 'Uninstall requested; OEM renderer baseline restored.'
rm -rf "$STATE_DIR"
