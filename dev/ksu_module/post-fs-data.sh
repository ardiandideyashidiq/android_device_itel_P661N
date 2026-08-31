#!/system/bin/sh
# Performance Boost - post-fs-data.sh
# Runs as root in the KSU context before HAL services start.
# Overrides the read-only /vendor/etc/powerhint.json via bind mount
# (erofs /vendor cannot be written directly) and applies boot-time tweaks.

MODDIR=${0%/*}

log() {
    echo "[performance_boost] $*" >> /data/adb/performance_boost.log
}

log "post-fs-data: starting"

# 1. Override powerhint.json for the lineage-libperfmgr power HAL.
#    The power HAL (hal_power_default) reads /vendor/etc/powerhint.json once at
#    init. erofs /vendor is read-only, so a bind mount is required. The bind
#    source must carry a context readable by hal_power_default
#    (vendor_configs_file), otherwise SELinux denies the read.
SRC=$MODDIR/vendor/etc/powerhint.json
DST=/vendor/etc/powerhint.json
if [ -f "$SRC" ] && [ -f "$DST" ]; then
    chcon u:object_r:vendor_configs_file:s0 "$SRC" 2>/dev/null
    mount --bind "$SRC" "$DST" 2>/dev/null && log "bind-mounted powerhint.json" || log "bind mount FAILED"
else
    log "skip bind mount (src or dst missing)"
fi

# 2. Boot-time tweaks (early, before heavy services).
apply_gpu() {
    # Force GPU to highest OPP and enable block boost.
    echo 0 > /proc/gpufreqv2/fix_target_opp_index 2>/dev/null
    echo 150 > /sys/kernel/ged/hal/dvfs_margin_value 2>/dev/null
}

apply_fpsgo() {
    echo 1 > /sys/kernel/fpsgo/fbt/enable_ceiling 2>/dev/null
    echo 1 > /sys/kernel/fpsgo/fbt/blc_boost 2>/dev/null
    echo 1 > /sys/kernel/fpsgo/fbt/boost_ta 2>/dev/null
    echo 1 > /sys/kernel/fpsgo/fbt/ultra_rescue 2>/dev/null
    echo 1 > /sys/kernel/fpsgo/fbt/switch_idleprefer 2>/dev/null
    echo 1 > /sys/kernel/fpsgo/fbt/llf_task_policy 2>/dev/null
}

apply_sched() {
    echo 2000000 > /proc/sys/kernel/sched_latency_ns 2>/dev/null
    echo 1000000 > /proc/sys/kernel/sched_min_granularity_ns 2>/dev/null
    echo 1000000 > /proc/sys/kernel/sched_wakeup_granularity_ns 2>/dev/null
    echo 100000 > /proc/sys/kernel/sched_migration_cost_ns 2>/dev/null
    echo 4 > /proc/sys/kernel/sched_pelt_multiplier 2>/dev/null
    echo 16 > /proc/sys/kernel/sched_nr_migrate 2>/dev/null
}

apply_mem() {
    echo 50 > /proc/sys/vm/vfs_cache_pressure 2>/dev/null
    echo 40 > /proc/sys/vm/dirty_ratio 2>/dev/null
    echo 5 > /proc/sys/vm/dirty_background_ratio 2>/dev/null
    echo 32768 > /proc/sys/vm/min_free_kbytes 2>/dev/null
    echo 15000 > /proc/sys/vm/watermark_boost_factor 2>/dev/null
}

apply_io() {
    echo 2048 > /sys/block/sda/queue/read_ahead_kb 2>/dev/null
    echo 128 > /sys/block/sda/queue/nr_requests 2>/dev/null
    echo 0 > /sys/block/sda/queue/iostats 2>/dev/null
}

apply_gpu
apply_fpsgo
apply_sched
apply_mem
apply_io

log "post-fs-data: done"
