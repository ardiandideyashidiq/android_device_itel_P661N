#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME=$(basename "$0")
DEFAULT_MONKEY_DURATION_SEC=150
DEFAULT_MONKEY_THROTTLE_MS=200
DEFAULT_MONKEY_SEED=424242
DEFAULT_OUT_ROOT="./bringup_reports"
ADB_BIN="${ADB_BIN:-adb}"
SERIAL=""
OUT_ROOT="$DEFAULT_OUT_ROOT"
MONKEY_DURATION_SEC="$DEFAULT_MONKEY_DURATION_SEC"
MONKEY_THROTTLE_MS="$DEFAULT_MONKEY_THROTTLE_MS"
MONKEY_SEED="$DEFAULT_MONKEY_SEED"
RUN_BUGREPORT=1
CLEAR_LOGCAT=1
TOGGLE_RADIOS=0
TARGET_PACKAGES="${TARGET_PACKAGES:-}"

usage() {
  cat <<USAGE
Usage: $SCRIPT_NAME [options]

Options:
  -s, --serial SERIAL          adb device serial to use
  -o, --out-root DIR           output root directory (default: $DEFAULT_OUT_ROOT)
  -d, --monkey-duration SEC    monkey duration in seconds (default: $DEFAULT_MONKEY_DURATION_SEC)
  -t, --monkey-throttle MS     monkey throttle in ms (default: $DEFAULT_MONKEY_THROTTLE_MS)
  --seed N                     monkey random seed (default: $DEFAULT_MONKEY_SEED)
  --packages CSV               comma-separated package filters for monkey (default: unrestricted)
  --no-bugreport               skip adb bugreport capture
  --no-clear-logcat            do not clear logcat buffers before running
  --toggle-radios              try optional Wi-Fi/Bluetooth smoke toggles (may be disruptive)
  -h, --help                   show this help

Environment:
  ADB_BIN                      path to adb binary
  TARGET_PACKAGES              same as --packages

Examples:
  $SCRIPT_NAME
  $SCRIPT_NAME -s ABC123 -o ./reports --packages com.android.settings,com.android.launcher3
  TARGET_PACKAGES=com.android.settings,com.android.launcher3 $SCRIPT_NAME --toggle-radios
USAGE
}

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

fail() {
  printf '[%s] ERROR: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2
  exit 1
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

run_timeout_cmd() {
  local timeout_bin=""
  if have_cmd timeout; then
    timeout_bin="timeout"
  elif have_cmd gtimeout; then
    timeout_bin="gtimeout"
  fi

  if [[ -n "$timeout_bin" ]]; then
    "$timeout_bin" "$@"
  else
    shift
    "$@"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--serial)
      SERIAL="$2"
      shift 2
      ;;
    -o|--out-root)
      OUT_ROOT="$2"
      shift 2
      ;;
    -d|--monkey-duration)
      MONKEY_DURATION_SEC="$2"
      shift 2
      ;;
    -t|--monkey-throttle)
      MONKEY_THROTTLE_MS="$2"
      shift 2
      ;;
    --seed)
      MONKEY_SEED="$2"
      shift 2
      ;;
    --packages)
      TARGET_PACKAGES="$2"
      shift 2
      ;;
    --no-bugreport)
      RUN_BUGREPORT=0
      shift
      ;;
    --no-clear-logcat)
      CLEAR_LOGCAT=0
      shift
      ;;
    --toggle-radios)
      TOGGLE_RADIOS=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown option: $1"
      ;;
  esac
done

[[ "$MONKEY_DURATION_SEC" =~ ^[0-9]+$ ]] || fail "--monkey-duration must be an integer"
[[ "$MONKEY_THROTTLE_MS" =~ ^[0-9]+$ ]] || fail "--monkey-throttle must be an integer"
[[ "$MONKEY_SEED" =~ ^[0-9]+$ ]] || fail "--seed must be an integer"
(( MONKEY_DURATION_SEC >= 120 )) || fail "Monkey duration must be at least 120 seconds"
(( MONKEY_THROTTLE_MS > 0 )) || fail "Monkey throttle must be > 0"

ADB_ARGS=()
if [[ -n "$SERIAL" ]]; then
  ADB_ARGS+=( -s "$SERIAL" )
fi

adb_cmd() {
  "$ADB_BIN" "${ADB_ARGS[@]}" "$@"
}

adb_shell() {
  adb_cmd shell "$@"
}

timestamp=$(date '+%Y%m%d_%H%M%S')
mkdir -p "$OUT_ROOT"
OUT_DIR="$OUT_ROOT/bringup_${timestamp}"
mkdir -p "$OUT_DIR"

# Add output dir to .gitignore if not already present
if [[ -d ".git" ]]; then
  if [[ -f ".gitignore" ]]; then
    if ! grep -q "^${OUT_ROOT##./}/" .gitignore 2>/dev/null; then
      echo "${OUT_ROOT##./}/" >> .gitignore
      echo "Added $OUT_DIR to .gitignore"
    fi
  else
    echo "${OUT_ROOT##./}/" > .gitignore
    echo "Created .gitignore with $OUT_DIR"
  fi
fi

text_sanitize() {
  tr -d '\r' < "$1"
}

capture_shell() {
  local label="$1"
  shift
  log "Collecting $label"
  if ! adb_shell "$@" > "$OUT_DIR/${label}.txt" 2>&1; then
    log "WARN: $label failed"
    return 1
  fi
}

capture_cmd() {
  local label="$1"
  shift
  log "Collecting $label"
  if ! "$@" > "$OUT_DIR/${label}.txt" 2>&1; then
    log "WARN: $label failed"
    return 1
  fi
}

capture_shell_allow_fail() {
  local label="$1"
  shift
  adb_shell "$@" > "$OUT_DIR/${label}.txt" 2>&1 || true
}

service_dump_try() {
  local label="$1"
  shift
  local ok=1
  : > "$OUT_DIR/${label}.txt"
  for svc in "$@"; do
    if adb_shell dumpsys "$svc" > "$OUT_DIR/${label}.txt" 2>&1; then
      ok=0
      break
    fi
  done
  return $ok
}

prop_get() {
  adb_shell getprop "$1" 2>/dev/null | tr -d '\r'
}

contains_feature() {
  local feature="$1"
  grep -Fq "$feature" "$OUT_DIR/pm_list_features.txt"
}

bool_str() {
  if [[ "$1" -eq 0 ]]; then
    printf 'yes'
  else
    printf 'no'
  fi
}

check_su() {
  if ! adb_shell 'command -v su >/dev/null 2>&1' >/dev/null 2>&1; then
    return 1
  fi
  if run_timeout_cmd 8s "$ADB_BIN" "${ADB_ARGS[@]}" shell 'su -c id >/dev/null 2>&1'; then
    return 0
  fi
  return 1
}

wait_for_device() {
  adb_cmd start-server >/dev/null
  adb_cmd wait-for-device
  local state
  state=$(adb_cmd get-state 2>/dev/null || true)
  [[ "$state" == "device" ]] || fail "adb device state is '$state', expected 'device'"
}

collect_baseline() {
  capture_cmd adb_version "$ADB_BIN" version
  capture_cmd adb_devices "$ADB_BIN" devices -l
  capture_shell getprop getprop
  capture_shell pm_list_features pm list features
  capture_shell pm_list_packages pm list packages -U
  capture_shell service_list service list
  capture_shell dumpsys_services dumpsys -l
  capture_shell uname uname -a
  capture_shell getenforce getenforce
  capture_shell df_h df -h
  capture_shell mount mount
  capture_shell ip_addr ip addr
  capture_shell ip_rule ip rule
  capture_shell ip_route ip route
  capture_shell settings_global settings list global
  capture_shell settings_secure settings list secure
  capture_shell settings_system settings list system
  capture_shell sm_list_volumes sm list-volumes all
  capture_shell cmd_overlay cmd overlay list
  capture_shell cmd_thermalservice cmd thermalservice dump

  capture_shell_allow_fail top_snapshot top -b -n 1
  capture_shell_allow_fail logcat_buffers logcat -g
  capture_shell_allow_fail logcat_crash_buffer logcat -b crash -d
  capture_shell_allow_fail logcat_events_buffer logcat -b events -d

  service_dump_try dumpsys_activity activity activity_task_manager activity_manager || true
  service_dump_try dumpsys_window window window_manager || true
  service_dump_try dumpsys_power power || true
  service_dump_try dumpsys_battery battery || true
  service_dump_try dumpsys_display display || true
  service_dump_try dumpsys_input input input_method || true
  service_dump_try dumpsys_surfaceflinger SurfaceFlinger || true
  service_dump_try dumpsys_wifi wifi || true
  service_dump_try dumpsys_connectivity connectivity || true
  service_dump_try dumpsys_bluetooth bluetooth_manager bluetooth_adapter bluetooth || true
  service_dump_try dumpsys_nfc nfc || true
  service_dump_try dumpsys_location location || true
  service_dump_try dumpsys_sensorservice sensorservice sensors || true
  service_dump_try dumpsys_audio audio || true
  service_dump_try dumpsys_media_camera media.camera camera || true
  service_dump_try dumpsys_media_session media_session || true
  service_dump_try dumpsys_usb usb || true
  service_dump_try dumpsys_telephony telephony.registry telecom phone subscription || true
  service_dump_try dumpsys_biometrics biometric biometric_service fingerprint face iris || true
  service_dump_try dumpsys_keystore android.security.keystore keystore || true
  service_dump_try dumpsys_notification notification || true
  service_dump_try dumpsys_alarm alarm || true
  service_dump_try dumpsys_jobscheduler jobscheduler || true
  service_dump_try dumpsys_meminfo meminfo || true
  service_dump_try dumpsys_procstats procstats || true
  service_dump_try dumpsys_dropbox dropbox || true
}

wake_and_smoke_ui() {
  log "Running basic UI smoke actions"
  adb_shell input keyevent KEYCODE_WAKEUP >/dev/null 2>&1 || true
  sleep 1
  adb_shell wm dismiss-keyguard >/dev/null 2>&1 || true
  sleep 1
  adb_shell input keyevent KEYCODE_HOME >/dev/null 2>&1 || true
  sleep 2
  adb_shell screencap -p /sdcard/bringup_home.png >/dev/null 2>&1 || true
  adb_cmd pull /sdcard/bringup_home.png "$OUT_DIR/home.png" >/dev/null 2>&1 || true
  adb_shell rm -f /sdcard/bringup_home.png >/dev/null 2>&1 || true

  adb_shell am start -a android.settings.SETTINGS >/dev/null 2>&1 || true
  sleep 3
  adb_shell input keyevent KEYCODE_HOME >/dev/null 2>&1 || true

  if contains_feature 'android.hardware.camera'; then
    adb_shell am start -a android.media.action.STILL_IMAGE_CAMERA >/dev/null 2>&1 || true
    sleep 4
    adb_shell input keyevent KEYCODE_HOME >/dev/null 2>&1 || true
  fi

  if contains_feature 'android.hardware.telephony'; then
    adb_shell am start -a android.intent.action.DIAL >/dev/null 2>&1 || true
    sleep 3
    adb_shell input keyevent KEYCODE_HOME >/dev/null 2>&1 || true
  fi
}

optional_radio_toggles() {
  if [[ "$TOGGLE_RADIOS" -ne 1 ]]; then
    return 0
  fi

  log "Running optional radio toggles"
  if contains_feature 'android.hardware.wifi'; then
    adb_shell svc wifi disable >/dev/null 2>&1 || true
    sleep 3
    adb_shell svc wifi enable >/dev/null 2>&1 || true
    sleep 5
  fi

  if contains_feature 'android.hardware.bluetooth'; then
    adb_shell cmd bluetooth_manager disable >/dev/null 2>&1 || true
    sleep 3
    adb_shell cmd bluetooth_manager enable >/dev/null 2>&1 || true
    sleep 5
  fi
}

start_logcat_capture() {
  if [[ "$CLEAR_LOGCAT" -eq 1 ]]; then
    adb_shell logcat -b all -c >/dev/null 2>&1 || true
  fi
  log "Starting background logcat capture"
  adb_cmd logcat -b all -v threadtime > "$OUT_DIR/logcat_all.txt" 2>&1 &
  LOGCAT_PID=$!
}

stop_logcat_capture() {
  if [[ -n "${LOGCAT_PID:-}" ]]; then
    kill "$LOGCAT_PID" >/dev/null 2>&1 || true
    wait "$LOGCAT_PID" >/dev/null 2>&1 || true
  fi
}

run_monkey() {
  local events
  local monkey_cmd
  events=$(( (MONKEY_DURATION_SEC * 1000 + MONKEY_THROTTLE_MS - 1) / MONKEY_THROTTLE_MS ))

  monkey_cmd=(monkey --throttle "$MONKEY_THROTTLE_MS" -s "$MONKEY_SEED" --ignore-crashes --ignore-timeouts --ignore-security-exceptions --monitor-native-crashes -v -v)

  if [[ -n "$TARGET_PACKAGES" ]]; then
    IFS=',' read -r -a pkg_array <<< "$TARGET_PACKAGES"
    for pkg in "${pkg_array[@]}"; do
      pkg=$(printf '%s' "$pkg" | xargs)
      [[ -n "$pkg" ]] && monkey_cmd+=( -p "$pkg" )
    done
  fi

  monkey_cmd+=( "$events" )

  printf '%s\n' "${monkey_cmd[@]}" > "$OUT_DIR/monkey_command.txt"
  log "Running monkey for ${MONKEY_DURATION_SEC}s (~${events} events @ ${MONKEY_THROTTLE_MS}ms)"
  set +e
  adb_shell "${monkey_cmd[@]}" > "$OUT_DIR/monkey_output.txt" 2>&1
  MONKEY_EXIT=$?
  set -e
  printf '%s\n' "$MONKEY_EXIT" > "$OUT_DIR/monkey_exit_code.txt"
}

collect_bugreport() {
  if [[ "$RUN_BUGREPORT" -ne 1 ]]; then
    return 0
  fi

  log "Collecting bugreport"
  mkdir -p "$OUT_DIR/bugreport"
  if ! adb_cmd bugreport "$OUT_DIR/bugreport" > "$OUT_DIR/bugreport_capture.txt" 2>&1; then
    log "WARN: adb bugreport path capture failed; trying shell fallback"
    adb_shell bugreport > "$OUT_DIR/bugreport/bugreport.txt" 2> "$OUT_DIR/bugreport_capture.txt" || true
  fi
}

collect_privileged_artifacts() {
  HAS_SU=1
  if check_su; then
    log "su is available; collecting privileged artifacts"
    printf 'yes\n' > "$OUT_DIR/has_su.txt"
    adb_cmd exec-out su -c 'dmesg -T 2>/dev/null || dmesg' > "$OUT_DIR/dmesg.txt" 2> "$OUT_DIR/dmesg.stderr" || true
    adb_cmd exec-out su -c 'tar -C /data -czf - tombstones 2>/dev/null' > "$OUT_DIR/tombstones.tar.gz" 2> "$OUT_DIR/tombstones.stderr" || true
    adb_cmd exec-out su -c 'for f in /sys/fs/pstore/* /proc/last_kmsg; do [ -e "$f" ] && { echo "===== $f ====="; cat "$f"; echo; }; done' > "$OUT_DIR/pstore_and_last_kmsg.txt" 2> "$OUT_DIR/pstore_and_last_kmsg.stderr" || true
  else
    HAS_SU=0
    printf 'no\n' > "$OUT_DIR/has_su.txt"
    log "su unavailable or not granted; skipping privileged artifacts"
  fi
}

report_line() {
  printf '%s\n' "$1" >> "$OUT_DIR/report.md"
}

service_state() {
  local file="$1"
  if [[ ! -s "$file" ]]; then
    printf 'missing'
  elif grep -Eqi 'Can.t find service|Unknown service|not found|No service published|Permission denial' "$file"; then
    printf 'error/denied'
  else
    printf 'present'
  fi
}

feature_state() {
  local feat="$1"
  if contains_feature "$feat"; then
    printf 'yes'
  else
    printf 'no'
  fi
}

count_grep() {
  local pattern="$1"
  local file="$2"
  grep -Eic "$pattern" "$file" 2>/dev/null || printf '0'
}

first_line() {
  local file="$1"
  head -n 1 "$file" 2>/dev/null | tr -d '\r'
}

generate_report() {
  local serial model device product build_fp build_id release sdk security_patch vbstate flash_locked crypto_state crypto_type selinux monkey_events anr_count fatal_count tombstone_count native_crash_count watchdog_count monkey_status bugreport_paths
  serial=$(adb_cmd get-serialno 2>/dev/null | tr -d '\r')
  model=$(prop_get ro.product.model)
  device=$(prop_get ro.product.device)
  product=$(prop_get ro.build.product)
  build_fp=$(prop_get ro.build.fingerprint)
  build_id=$(prop_get ro.build.id)
  release=$(prop_get ro.build.version.release)
  sdk=$(prop_get ro.build.version.sdk)
  security_patch=$(prop_get ro.build.version.security_patch)
  vbstate=$(prop_get ro.boot.verifiedbootstate)
  flash_locked=$(prop_get ro.boot.flash.locked)
  crypto_state=$(prop_get ro.crypto.state)
  crypto_type=$(prop_get ro.crypto.type)
  selinux=$(first_line "$OUT_DIR/getenforce.txt")
  monkey_events=$(( (MONKEY_DURATION_SEC * 1000 + MONKEY_THROTTLE_MS - 1) / MONKEY_THROTTLE_MS ))
  anr_count=$(count_grep 'ANR in|Application Not Responding' "$OUT_DIR/logcat_all.txt")
  fatal_count=$(count_grep 'FATAL EXCEPTION' "$OUT_DIR/logcat_all.txt")
  tombstone_count=$(count_grep 'tombstone|Tombstone written|DEBUG   : .*backtrace' "$OUT_DIR/logcat_all.txt")
  native_crash_count=$(count_grep 'Fatal signal|SIGSEGV|SIGABRT|crash_dump' "$OUT_DIR/logcat_all.txt")
  watchdog_count=$(count_grep 'Watchdog' "$OUT_DIR/logcat_all.txt")
  monkey_status="pass"
  if [[ -f "$OUT_DIR/monkey_exit_code.txt" ]]; then
    if [[ "$(tr -d '\r' < "$OUT_DIR/monkey_exit_code.txt")" != "0" ]]; then
      monkey_status="non-zero exit"
    fi
  fi

  : > "$OUT_DIR/report.md"
  report_line "# Android Bring-up Smoke Report"
  report_line ""
  report_line "Generated: $(date '+%Y-%m-%d %H:%M:%S %Z')"
  report_line "Output directory: $OUT_DIR"
  report_line ""
  report_line "## Device"
  report_line "- Serial: \`$serial\`"
  report_line "- Model: \`$model\`"
  report_line "- Device: \`$device\`"
  report_line "- Product: \`$product\`"
  report_line "- Android: \`$release\` (SDK $sdk)"
  report_line "- Build ID: \`$build_id\`"
  report_line "- Security patch: \`$security_patch\`"
  report_line "- Fingerprint: \`$build_fp\`"
  report_line ""
  report_line "## Security / boot state"
  report_line "- SELinux: **$selinux**"
  report_line "- Verified Boot state: \`$vbstate\`"
  report_line "- Flash locked: \`$flash_locked\`"
  report_line "- Crypto state: \`$crypto_state\`"
  report_line "- Crypto type: \`$crypto_type\`"
  report_line "- su available: **$(cat "$OUT_DIR/has_su.txt" 2>/dev/null || printf 'no')**"
  report_line ""
  report_line "## Feature flags"
  report_line "| Area | Feature flag present |"
  report_line "|---|---|"
  report_line "| Fingerprint | $(feature_state 'android.hardware.fingerprint') |"
  report_line "| Face | $(feature_state 'android.hardware.biometrics.face') |"
  report_line "| Camera | $(feature_state 'android.hardware.camera') |"
  report_line "| Camera front | $(feature_state 'android.hardware.camera.front') |"
  report_line "| Bluetooth | $(feature_state 'android.hardware.bluetooth') |"
  report_line "| Bluetooth LE | $(feature_state 'android.hardware.bluetooth_le') |"
  report_line "| Wi-Fi | $(feature_state 'android.hardware.wifi') |"
  report_line "| Wi-Fi Aware | $(feature_state 'android.hardware.wifi.aware') |"
  report_line "| Wi-Fi Direct | $(feature_state 'android.hardware.wifi.direct') |"
  report_line "| NFC | $(feature_state 'android.hardware.nfc') |"
  report_line "| Telephony | $(feature_state 'android.hardware.telephony') |"
  report_line "| GPS | $(feature_state 'android.hardware.location.gps') |"
  report_line "| Accelerometer | $(feature_state 'android.hardware.sensor.accelerometer') |"
  report_line "| Gyroscope | $(feature_state 'android.hardware.sensor.gyroscope') |"
  report_line "| Proximity | $(feature_state 'android.hardware.sensor.proximity') |"
  report_line "| Light sensor | $(feature_state 'android.hardware.sensor.light') |"
  report_line "| Barometer | $(feature_state 'android.hardware.sensor.barometer') |"
  report_line "| USB host | $(feature_state 'android.hardware.usb.host') |"
  report_line "| Vulkan | $(feature_state 'android.hardware.vulkan.level') |"
  report_line ""
  report_line "## Dumpsys / service smoke status"
  report_line "| Check | Status | File |"
  report_line "|---|---|---|"
  report_line "| Activity | $(service_state "$OUT_DIR/dumpsys_activity.txt") | \`dumpsys_activity.txt\` |"
  report_line "| Window | $(service_state "$OUT_DIR/dumpsys_window.txt") | \`dumpsys_window.txt\` |"
  report_line "| Power | $(service_state "$OUT_DIR/dumpsys_power.txt") | \`dumpsys_power.txt\` |"
  report_line "| Battery | $(service_state "$OUT_DIR/dumpsys_battery.txt") | \`dumpsys_battery.txt\` |"
  report_line "| Display | $(service_state "$OUT_DIR/dumpsys_display.txt") | \`dumpsys_display.txt\` |"
  report_line "| Input | $(service_state "$OUT_DIR/dumpsys_input.txt") | \`dumpsys_input.txt\` |"
  report_line "| SurfaceFlinger | $(service_state "$OUT_DIR/dumpsys_surfaceflinger.txt") | \`dumpsys_surfaceflinger.txt\` |"
  report_line "| Wi-Fi | $(service_state "$OUT_DIR/dumpsys_wifi.txt") | \`dumpsys_wifi.txt\` |"
  report_line "| Connectivity | $(service_state "$OUT_DIR/dumpsys_connectivity.txt") | \`dumpsys_connectivity.txt\` |"
  report_line "| Bluetooth | $(service_state "$OUT_DIR/dumpsys_bluetooth.txt") | \`dumpsys_bluetooth.txt\` |"
  report_line "| NFC | $(service_state "$OUT_DIR/dumpsys_nfc.txt") | \`dumpsys_nfc.txt\` |"
  report_line "| Location | $(service_state "$OUT_DIR/dumpsys_location.txt") | \`dumpsys_location.txt\` |"
  report_line "| Sensors | $(service_state "$OUT_DIR/dumpsys_sensorservice.txt") | \`dumpsys_sensorservice.txt\` |"
  report_line "| Audio | $(service_state "$OUT_DIR/dumpsys_audio.txt") | \`dumpsys_audio.txt\` |"
  report_line "| Camera | $(service_state "$OUT_DIR/dumpsys_media_camera.txt") | \`dumpsys_media_camera.txt\` |"
  report_line "| USB | $(service_state "$OUT_DIR/dumpsys_usb.txt") | \`dumpsys_usb.txt\` |"
  report_line "| Telephony | $(service_state "$OUT_DIR/dumpsys_telephony.txt") | \`dumpsys_telephony.txt\` |"
  report_line "| Biometrics | $(service_state "$OUT_DIR/dumpsys_biometrics.txt") | \`dumpsys_biometrics.txt\` |"
  report_line "| Keystore | $(service_state "$OUT_DIR/dumpsys_keystore.txt") | \`dumpsys_keystore.txt\` |"
  report_line "| Notification | $(service_state "$OUT_DIR/dumpsys_notification.txt") | \`dumpsys_notification.txt\` |"
  report_line "| Alarm | $(service_state "$OUT_DIR/dumpsys_alarm.txt") | \`dumpsys_alarm.txt\` |"
  report_line "| JobScheduler | $(service_state "$OUT_DIR/dumpsys_jobscheduler.txt") | \`dumpsys_jobscheduler.txt\` |"
  report_line "| Meminfo | $(service_state "$OUT_DIR/dumpsys_meminfo.txt") | \`dumpsys_meminfo.txt\` |"
  report_line "| Procstats | $(service_state "$OUT_DIR/dumpsys_procstats.txt") | \`dumpsys_procstats.txt\` |"
  report_line "| Dropbox | $(service_state "$OUT_DIR/dumpsys_dropbox.txt") | \`dumpsys_dropbox.txt\` |"
  report_line ""
  report_line "## Monkey"
  report_line "- Requested duration: **${MONKEY_DURATION_SEC}s**"
  report_line "- Throttle: **${MONKEY_THROTTLE_MS}ms**"
  report_line "- Approx events: **${monkey_events}**"
  report_line "- Seed: **${MONKEY_SEED}**"
  report_line "- Package filter: \`${TARGET_PACKAGES:-<none>}\`"
  report_line "- Exit status: **$monkey_status**"
  report_line "- Output file: \`monkey_output.txt\`"
  report_line ""
  report_line "## Log summary"
  report_line "- ANR lines in logcat: **$anr_count**"
  report_line "- FATAL EXCEPTION lines in logcat: **$fatal_count**"
  report_line "- Native crash signals in logcat: **$native_crash_count**"
  report_line "- Tombstone/backtrace lines in logcat: **$tombstone_count**"
  report_line "- Watchdog mentions in logcat: **$watchdog_count**"
  report_line ""
  report_line "## Artifacts"
  report_line "- ADB / device metadata: \`adb_version.txt\`, \`adb_devices.txt\`, \`getprop.txt\`, \`service_list.txt\`"
  report_line "- Dumpsys snapshots: \`dumpsys_*.txt\`"
  report_line "- Runtime logs: \`logcat_all.txt\`, \`logcat_crash_buffer.txt\`, \`logcat_events_buffer.txt\`"
  report_line "- Monkey: \`monkey_command.txt\`, \`monkey_output.txt\`, \`monkey_exit_code.txt\`"
  if [[ "$RUN_BUGREPORT" -eq 1 ]]; then
    bugreport_paths=$(find "$OUT_DIR/bugreport" -maxdepth 2 -type f | sed "s|$OUT_DIR/||" | sort || true)
    if [[ -n "$bugreport_paths" ]]; then
      report_line "- Bugreport:"
      while IFS= read -r path; do
        report_line "  - \`$path\`"
      done <<< "$bugreport_paths"
    fi
  fi
  if [[ -f "$OUT_DIR/dmesg.txt" ]]; then
    report_line "- Privileged logs: \`dmesg.txt\`, \`tombstones.tar.gz\`, \`pstore_and_last_kmsg.txt\`"
  fi
  report_line ""
  report_line "## Notes"
  report_line "- This script is a **host-side smoke test**. It can confirm feature flags, service availability, basic app launches, logs, and crash evidence, but it cannot fully prove end-to-end hardware behavior for items that need user interaction or external fixtures, such as camera image quality, fingerprint enrollment/unlock UX, audio quality, GPS accuracy, or sensor calibration."
  report_line "- Review \`monkey_output.txt\`, \`logcat_all.txt\`, bugreport output, and any tombstones/native crashes before calling the build stable."
}

main() {
  wait_for_device
  log "Connected to $(adb_cmd get-serialno | tr -d '\r')"
  collect_baseline
  wake_and_smoke_ui
  optional_radio_toggles
  start_logcat_capture
  run_monkey
  stop_logcat_capture
  collect_bugreport
  collect_privileged_artifacts
  generate_report
  log "Done. Report: $OUT_DIR/report.md"
}

trap stop_logcat_capture EXIT
main "$@"
