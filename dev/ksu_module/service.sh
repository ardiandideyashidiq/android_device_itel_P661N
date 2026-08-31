#!/system/bin/sh
# Performance Boost - service.sh
# Runs after boot completes to apply / re-assert persistent tweaks.

MODDIR=${0%/*}

log() {
    echo "[performance_boost] $*" >> /data/adb/performance_boost.log
}

log "service: starting"

# Wait for boot
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 1
done

# Re-assert GPU tuning (fix_target_opp_index 0 = highest OPP).
echo 0 > /proc/gpufreqv2/fix_target_opp_index 2>/dev/null
echo 150 > /sys/kernel/ged/hal/dvfs_margin_value 2>/dev/null

# FPSGO persistent boost.
echo 1 > /sys/kernel/fpsgo/fbt/enable_ceiling 2>/dev/null
echo 1 > /sys/kernel/fpsgo/fbt/blc_boost 2>/dev/null
echo 1 > /sys/kernel/fpsgo/fbt/boost_ta 2>/dev/null
echo 1 > /sys/kernel/fpsgo/fbt/switch_idleprefer 2>/dev/null
echo 1 > /sys/kernel/fpsgo/fbt/llf_task_policy 2>/dev/null
echo 1 > /sys/kernel/fpsgo/fbt/ultra_rescue 2>/dev/null

# Scheduler persistent tuning (matches init.mt6833.power.rc).
# MTK exposes the schedutil rate limit as one global node here.
echo 200 > /sys/devices/system/cpu/cpufreq/schedutil/rate_limit_us 2>/dev/null
echo 4 > /proc/sys/kernel/sched_pelt_multiplier 2>/dev/null
echo 2000000 > /proc/sys/kernel/sched_latency_ns 2>/dev/null
echo 1000000 > /proc/sys/kernel/sched_min_granularity_ns 2>/dev/null
echo 1000000 > /proc/sys/kernel/sched_wakeup_granularity_ns 2>/dev/null
echo 100000 > /proc/sys/kernel/sched_migration_cost_ns 2>/dev/null
echo 16 > /proc/sys/kernel/sched_nr_migrate 2>/dev/null

# Memory persistent tuning.
echo 50 > /proc/sys/vm/vfs_cache_pressure 2>/dev/null
echo 40 > /proc/sys/vm/dirty_ratio 2>/dev/null
echo 5 > /proc/sys/vm/dirty_background_ratio 2>/dev/null
echo 32768 > /proc/sys/vm/min_free_kbytes 2>/dev/null
echo 15000 > /proc/sys/vm/watermark_boost_factor 2>/dev/null

# IO tuning.
echo 2048 > /sys/block/sda/queue/read_ahead_kb 2>/dev/null
echo 128 > /sys/block/sda/queue/nr_requests 2>/dev/null
echo 0 > /sys/block/sda/queue/iostats 2>/dev/null

log "service: done"
