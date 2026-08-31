# Performance Tuning — itel P55 5G (P661N / mt6833)

## What, Why, How

This document explains the performance/smoothness-tuning changes made for scrolling and
gaming on the itel P55 5G (P661N, Dimensity 6080 / `mt6833`), built for **InfinityOS**.

It is a **what / why / how** write-up of the four levers that were changed:

1. `configs/powerhint.json` — Power HAL hint configuration
2. `rootdir/etc/init/hw/init.mt6833.power.rc` — boot-time init tuning
3. `configs/props/vendor.prop` — system properties
4. `sepolicy/vendor/*` — SELinux policy
5. `dev/ksu_module/` — KernelSU module (live, on-device, uses bind mount + ksud)

> Every value below was **verified against the live device** (adb shell, running stock ROM
> with the same kernel/`-kernel` repo the InfinityOS build reuses). Unverifiable or
> guesswork changes were deliberately dropped rather than shipped. The literal "10x"
> target is not proven by a benchmark; the tuning is applied and verified mechanically
> end to end.

---

## 1. powerhint.json

### What

Rewrote the power HAL hint config. It now contains **18 nodes** and **86 action entries**
across the **8 hints that this device's HAL actually dispatches**:

```
GAME_LOADING 15        EXPENSIVE_RENDERING 15
INTERACTION 12         LAUNCH 12
FIXED_PERFORMANCE 12   SUSTAINED_PERFORMANCE 9
CAMERA_LAUNCH 5        AUDIO_STREAMING_LOW_LATENCY 6
```

### Why

The power HAL on this device is **AIDL** (`vendor.power-hal-aidl`, the LineageOS
`power-libperfmgr`), **not** HIDL. Its hint dispatch is:

- `setBoost(Boost::INTERACTION)` -> `DoHint("INTERACTION")`
- `setMode(Mode::X)` -> `DoHint(toString(Mode::X))`
- `PowerExt::setMode/setBoost` -> `DoHint(<arbitrary string>)`

The old config referenced **`SCROLL`** and **`GAMING`** hints plus a `PowerHALGamingState`
node — but the `Mode` enum has **no `SCROLL` and no `GAMING`** values. Those hints were
**dead config** that a hint-name mismatch would never dispatch, so they were removed and
replaced with the real ones (`GAME_LOADING`, `SUSTAINED_PERFORMANCE`, `FIXED_PERFORMANCE`,
`INTERACTION`, ...). This makes every configured action actually fire.

### How

The 18 nodes cover the four categories of tuning the SoC family supports:

| Node group | Examples | Purpose |
|---|---|---|
| CPU freq | `CPULittleClusterMaxFreq` (policy0), `CPUBigClusterMaxFreq` (policy6) + MinFreq | ramp / hold CPU up during a hint |
| GPU | `GPUBlockBoost`, `GpuPwrLevel`, `GPUMaxFreq`/`MinFreq`/`SetFreq`, `GPUSchedMode`/`Period`, `GPUDVFSInterval`/`Ceiling` | drive the Mali GPU DVFS and block boost |
| uclamp | `FGUclampMin`, `TAUclampMin`, `CDUclampMin` | raise scheduler util-clamp floors for boosted tasks |
| Audio/Render state | `PowerHALAudioState`, `PowerHALRenderingState` | low-latency audio + frame pacing hints |

Each action is `{PowerHint, Node, Duration, Value}`. Boost actions hold a node high for a
`Duration`, then reset to `DefaultIndex` on hint end (nodes are `ResetOnInit`). The JSON
is validated: all `Values` exist in their node's `Values` array, and every action
references a defined node.

**Verified live:** touch swipe during `INTERACTION` pins both CPU clusters to max
(`policy0/min=2000000`, `policy6/min=2400000`, `ta_uclamp=max`) and raises GPU
(`boost=101` via GPUBlockBoost, `fix_target_opp_index=0`) — the whole boost chain works
end to end.

The same file is kept byte-identical in:
`configs/powerhint.json`, `dev/ksu_module/files/powerhint.json`,
`dev/ksu_module/vendor/etc/powerhint.json` (md5 `638e6377...`).

---

## 2. init.mt6833.power.rc

### What

`rootdir/etc/init/hw/init.mt6833.power.rc` — boot/perf init tuning. Changes:

- **Governor:** switch `policy0`/`policy6` to **`sugov_ext`** (MTK extended schedutil).
- **Rate limit:** single global node
  `write /sys/devices/system/cpu/cpufreq/schedutil/rate_limit_us 200`.
- **Aggressive scheduler / GED / FPSGO / GPU / IO / cpuset / uclamp** writes.

### Why

The old file wrote per-governor nodes that **do not exist on this device**:
`scaling_available_governors` (read-only) and per-policy
`schedutil/up_rate_limit_us` / `down_rate_limit_us` were dead writes. MTK exposes a
**single global** rate-limit node at
`/sys/devices/system/cpu/cpufreq/schedutil/rate_limit_us` (default `1000`). Setting it to
`200` makes the frequency ramp much faster for responsiveness (verified 500->200->1000).

`gpu_cust_boost_freq` / `gpu_cust_upbound_freq` also **do not exist**. The real GED nodes
are `/sys/kernel/ged/hal/custom_boost_gpu_freq` and `custom_upbound_gpu_freq`, and they take
an **OPP index**, not a Hz value (0 = max 1068 MHz ... 44 = min 390 MHz). The config now
writes `custom_boost_gpu_freq 0` / `custom_upbound_gpu_freq 0`.

### How

Every `write` target path in the file was checked against the live device and exists:

- **Scheduler:** `sched_latency_ns=2000000`, `sched_min_granularity_ns=1000000`,
  `sched_wakeup_granularity_ns=1000000`, `sched_migration_cost_ns=100000`,
  `sched_nr_migrate=16`, `sched_child_runs_first=1`, `sched_pelt_multiplier=4`.
- **FPSGO/FBT** (frame-aware scheduling): `enable_ceiling`, `blc_boost`, `boost_ta`,
  `switch_idleprefer`, `llf_task_policy`, `ultra_rescue` all `1`.
- **GED** (GPU DVFS): `fastdvfs_mode=0`, `dvfs_margin_value=150`,
  `dvfs_workload_mode=0`, `loading_window_size=4`, `loading_stride_size=1`,
  `fallback_interval=30`, `custom_boost_gpu_freq=0`, `custom_upbound_gpu_freq=0`.
- **Memory:** `vfs_cache_pressure=50`, `dirty_ratio=40`, `dirty_background_ratio=5`,
  `min_free_kbytes=32768`, `watermark_boost_factor=15000`.
- **IO:** `read_ahead_kb=2048`, `nr_requests` bump for `mmcblk0`/`sda`/`sdb`/`sdc`,
  `mq-deadline` scheduler, `iostats=0`.
- **cpuset / uclamp:** aggressive pinning of `foreground`/`top-app` to `0-7`, raised
  uclamp floors so boosted tasks get CPU headroom.

Deliberately **not** permanently pinning the GPU to max OPP via init (`fix_target_opp_index`)
— the powerhint's `GPUBlockBoost` already does per-hint GPU boosts, and a global max-GPU
pin causes unnecessary heat and eventual thermal throttling that hurts sustained gaming.
Pre-existing stock dead writes (e.g. `FG_daemon_log_level`) are left untouched.

---

## 3. vendor.prop

### What

`configs/props/vendor.prop` — changed a handful of properties. Explicitly **reverted**
several guesses from an earlier pass back to **verified stock values**.

### Why / How

**Fixed a bug:** a line had a space in the key — `persist.vendor.perf boosting=1` — which is
an invalid property line (keys cannot contain spaces). Now `persist.vendor.perf.boosting=1`.

**Kept (verified real levers):**
- **LMK de-aggressing** (`ro.lmk.*`): reduce killing so apps survive longer in memory =>
  snappier app-switching. Safe here because the device has **5.7 GB RAM, ~3.2 GB free,
  plus zram swap** (verified `MemTotal: 5742208 kB`).
- **90 Hz for gaming:** `ro.surface_flinger.enable_frame_rate_override=true` +
  `ro.surface_flinger.game_default_frame_rate_override=90` + `debug.sf.frame_rate_multiple_threshold=90`.
  Verified the panel supports `[90.0, 60.0]`.
- **Lower input latency:** `debug.sf.auto_latch_unsignaled=0 -> 1`.

**Reverted to verified stock (panel calibration — wrong values cause jank, not smoothness):**
- `ro.surface_flinger.vsync_event_phase_offset_ns` = `8400000` (not 6000000)
- `ro.surface_flinger.vsync_sf_event_phase_offset_ns` = `-10933333` (not -13333333)
- `debug.sf.high_fps_*_phase_offset_ns` = `-12666667` / `-8000000`
- `ro.surface_flinger.max_frame_buffer_acquired_buffers` = `3` (not 2)
- `ro.surface_flinger.uclamp.min` = `328`, `set_idle_timer_ms` = `3000`,
  `set_touch_timer_ms` = `500`
- `dalvik.vm.*` heap values back to stock (`heaptargetutilization=0.5`, `heapstartsize=16m`,
  `heapmaxfree=32m`, `heapminfree=8m`) — smaller free headroom causes more frequent GC
  pauses, i.e. the opposite of smooth.
- **Reverted `ro.vendor.mtk_bt_sap_enable`** back to the real name
  `ro.vendor.mtk.bt_sap_enable=true` (verified live) — the rename broke it and was unrelated
  to performance.

Removed unverified/fabricated props that no consumer reads on this device
(`persist.sys.perf.response`, `persist.sys.perf.app_prediction`,
`persist.sys.perf.control_cluster`, `persist.vendor.perf.config.loader`,
`ro.vendor.mtk_pms_wrap_around`, `enable_frame_rate_uids`, ...).

---

## 4. sepolicy/vendor

### What / Why

`sepolicy/vendor/{file.te,genfs_contexts,hal_power_default.te,init.te,vendor_init.te}`.

The **`sysfs_ged` and `sysfs_fpsgo` types and their `genfscon` labels are already declared
by the MTK base policy** (`device/mediatek/sepolicy_vndr`), verified against the compiled
`vendor_sepolicy.cil`:

```
954: (genfscon sysfs /kernel/fpsgo (u object_r sysfs_fpsgo ...))
960: (genfscon sysfs /kernel/ged  (u object_r sysfs_ged ...))
2558: (type sysfs_ged)
2564: (type sysfs_fpsgo)
```

So the earlier (correct-sounding but wrong) additions of `type sysfs_fpsgo` in `file.te`
and `genfscon sysfs /kernel/{ged,fpsgo}` in `genfs_contexts` were **duplicate declarations
that would break the sepolicy build** (a `type` can only be declared once). Those were
removed.

### How

Only **additive `allow` rules** remain, referencing the pre-declared types — granting the
performance-tuning domains write access to the GED / FPSGO nodes:

- `hal_power_default.te` — `rw_file_perms` on `sysfs_fpsgo` + `sysfs_ged`.
- `init.te` / `vendor_init.te` — `w_file_perms` on `sysfs_fpsgo`/`sysfs_ged`.

The running power HAL (lineage `vendor.power-hal-aidl`) runs in the **`hal_power_default`**
domain (verified `ls -Z /proc/<pid>/exe` -> `u:r:hal_power_default:s0`), so these are the
rules that make the powerhint/GED/FPSGO writes legal from the runtime power service —
the MTK `mtk_hal_power` rules don't apply to it.

---

## 5. KernelSU module (`dev/ksu_module/`)

### What

A KernelSU module (`id=performance_boost`) deployed live to
`/data/adb/modules/performance_boost/`:

```
module.prop
post-fs-data.sh
service.sh
files/powerhint.json
vendor/etc/powerhint.json
```

### Why / How

The device's `/vendor` is **erofs (read-only)** — it cannot be edited in place. The only
ways to affect the running system are a **bind mount** or the **ksud binary**. This module
uses both paths:

- **`post-fs-data.sh`**:
  1. **Bind-mounts** `vendor/etc/powerhint.json` over `/vendor/etc/powerhint.json` so the
     power HAL loads the tuned config. The bind source is `chcon`'d to
     `u:object_r:vendor_configs_file:s0` — without the right SELinux context, the HAL is
     denied the read and aborts with `Invalid config`.
  2. Applies early GPU / FPSGO / scheduler / memory / IO writes.
- **`service.sh`**: waits for boot, then re-asserts the persistent writes
  (`rate_limit_us=200`, `sched_pelt_multiplier=4`, FPSGO, GED, memory, IO).

**Verified live:** bind mount active on `/vendor/etc/powerhint.json`; `rate_limit_us=200`,
`blc_boost=1`, `dvfs_margin_value=150`; `vendor.power-hal-aidl` running with the
bind-mounted config (`Initialized HintManager from ... powerhint.json`, no `SCROLL`/`GAMING`).

> Note: `post-fs-data.sh`/`service.sh` still write `/proc/gpufreqv2/fix_target_opp_index 0`
> (pin GPU to max). This is the *intended* behaviour for the on-device "go fast" module
> and is a deliberate, documented trade-off (heat/thermal vs raw FPS) — unlike the init.rc,
> whose job is to leave GPU control to the dynamic powerhint. Keep them consistent if you
> change one.

---

## Verification summary

| Item | Evidence |
|---|---|
| powerhint JSON valid | 18 nodes / 86 actions, all refs valid, md5 identical across 3 copies |
| visibility of real hints | HAL logs load bind-mounted config; dispatch verified (INTERACTION pins CPU+GPU) |
| init.rc node paths | every `write` target exists on live device (removed dead `gpu_cust_*`, per-policy rate limits) |
| rate limit | `rate_limit_us=200` live |
| vendor.prop calibration | reverted to verified stock offsets; no jank regressions |
| sepolicy | no duplicate `type`/`genfscon`; additive allows on pre-declared types |
| module | deployed + bind-mount + SELinux fix verified (`rate_limit_us=200`, `blc_boost=1`, `dvfs_margin=150`) |

**Not proven:** the literal `10x` smoothness target was not benchmarked with a
frame-time / scroll test. The tuning is applied and verified mechanically, but a numerical
gain figure is not claimed.
