# Custom ROM Bring Up Checklist

> Mark anything as:
>   [ ] Not tested
>   [x] Working
>   [-] Not present on this device
>   [!} Bug / partial / broken

## 1) Boot / basic system
  [ ] Clean flash completes without errors
  [ ] First boot succeeds
  [ ] Boot time is reasonable
  [ ] No bootloop after first setup
  [ ] Reboot works
  [ ] Power off works
  [ ] Warm reboot works
  [ ] Recovery boots
  [ ] Fastboot / bootloader mode works
  [ ] ADB works in system
  [ ] ADB works in recovery
  [ ] Device can boot again after charging while powered off
  [ ] No random reboots / kernel panics
  [ ] No major spam in logcat / dmesg for core services

## 2) Setup wizard / provisioning
  [ ] Setup wizard completes
  [ ] Language selection works
  [ ] Wi Fi setup during first boot works
  [ ] Google account sign in works (if GApps included)
  [ ] Date / time auto sync works
  [ ] Restore flow works (if applicable)
  [ ] Device encryption state survives setup
  [ ] Lock screen can be configured during setup

## 3) UI / display / graphics
  [ ] Display turns on reliably
  [ ] Brightness slider works
  [ ] Auto brightness works
  [ ] Refresh rate switching works
  [ ] Color modes work
  [ ] Night Light / reading mode works
  [ ] Always on display works (if supported)
  [ ] Ambient display / tap to wake works
  [ ] Rotation works
  [ ] GPU acceleration feels normal
  [ ] No black screen / flicker / artifacting
  [ ] Screen recorder works
  [ ] Screenshot works
  [ ] E ternal display out works (USB C / HDMI / wireless), if supported
  [ ] DRM protected content behavior is as e pected

## 4) Touch / input / haptics / buttons
  [ ] Touchscreen works across whole panel
  [ ] Multi touch works
  [ ] Touch latency feels normal
  [ ] Edge touch rejection behaves correctly
  [ ] Gesture navigation works
  [ ] 3 button navigation works
  [ ] Back gesture works on both sides
  [ ] Hardware keys work (power / volume / others)
  [ ] Double tap to wake works
  [ ] Double tap to sleep works
  [ ] Glove / high sensitivity mode works, if supported
  [ ] Vibration works
  [ ] Haptic feedback strength is correct
  [ ] Fingerprint on display touch area wakes properly, if applicable

## 5) Lockscreen / biometrics / security
  [ ] PIN works
  [ ] Pattern works
  [ ] Password works
  [ ] Lock / unlock is stable
  [ ] Smart lock / e tend unlock works, if used
  [ ] Fingerprint enrollment works
  [ ] Fingerprint unlock works from screen off
  [ ] Fingerprint unlock works from AOD / lock screen
  [ ] Fingerprint app authentication works
  [ ] Multiple fingerprints can be added
  [ ] Failed attempt behavior is correct
  [ ] Face unlock works, if present
  [ ] BiometricPrompt works in apps
  [ ] Keystore backed auth works
  [ ] Lockout / fallback to credential works
  [ ] SELinu  is enforcing
  [ ] File based encryption is working
  [ ] Verified Boot / AVB state is understood and e pected
  [ ] Safety/security warnings shown to user are correct for bootloader state

## 6) Telephony / SIM / IMS
  [ ] Physical SIM detected
  [ ] Dual SIM works, if supported
  [ ] eSIM detected and can be provisioned, if supported
  [ ] Network registers on carrier
  [ ] Signal bars update correctly
  [ ] Outgoing calls work
  [ ] Incoming calls work
  [ ] Earpiece audio works during calls
  [ ] Mic works during calls
  [ ] Speakerphone works during calls
  [ ] Call waiting works
  [ ] Caller ID works
  [ ] DTMF tones work
  [ ] SMS send works
  [ ] SMS receive works
  [ ] MMS send works
  [ ] MMS receive works
  [ ] Mobile data works
  [ ] 2G/3G/4G/5G modes switch correctly as supported
  [ ] VoLTE works
  [ ] VoWiFi / Wi Fi Calling works
  [ ] IMS registers correctly
  [ ] Carrier video calling works, if e pected
  [ ] APNs are correct
  [ ] Airplane mode works
  [ ] Emergency dialing flow behaves correctly

## 7) Wi Fi / hotspot / network
  [ ] Wi Fi toggles on/off
  [ ] 2.4 GHz networks connect
  [ ] 5 GHz networks connect
  [ ] 6 GHz / Wi Fi 6E / Wi Fi 7 connect, if supported
  [ ] Hidden SSID connect works
  [ ] WPA2 works
  [ ] WPA3 works
  [ ] Captive portal detection works
  [ ] MAC randomization behaves correctly
  [ ] Wi Fi reconnect after reboot works
  [ ] Wi Fi reconnect after sleep works
  [ ] Throughput is normal
  [ ] Hotspot / tethering works
  [ ] USB tethering works
  [ ] Bluetooth tethering works
  [ ] Wi Fi Direct works, if supported
  [ ] Wi Fi Aware works, if supported
  [ ] Passpoint works, if supported
  [ ] Per app VPN works
  [ ] Private DNS works

## 8) Bluetooth / wearables / accessories
  [ ] Bluetooth toggles on/off
  [ ] Device scanning works
  [ ] Pairing works
  [ ] Unpairing works
  [ ] Reconnect works after reboot
  [ ] BLE scanning works
  [ ] BLE connection works
  [ ] File transfer works, if used
  [ ] Audio to TWS earbuds works
  [ ] Audio to speaker works
  [ ] Car Bluetooth works
  [ ] Call audio over Bluetooth works
  [ ] Media controls over Bluetooth work
  [ ] Metadata / track info displays correctly
  [ ] Multiple paired devices behave correctly
  [ ] Smartwatch pairing works
  [ ] Nearby device permission behavior is correct

## 9) NFC / wallet / payments
  [ ] NFC toggles on/off
  [ ] Tag reading works
  [ ] NDEF read works
  [ ] NDEF write works
  [ ] Android Beam replacement / sharing equivalent works, if used
  [ ] Host card emulation works, if supported
  [ ] Contactless payment/wallet behavior is as e pected
  [ ] Transit / access card apps detect NFC correctly
  [ ] Reader mode works

## 10) GPS / GNSS / location
  [ ] Location toggle works
  [ ] GPS gets first fi 
  [ ] Cold start lock works
  [ ] Warm start lock works
  [ ] Accuracy is reasonable outdoors
  [ ] Speed / heading update correctly
  [ ] Multiple constellations show up, if supported
  [ ] Network based location works
  [ ] Indoor coarse location behaves normally
  [ ] Location permission prompts work
  [ ] Background location behavior is correct
  [ ] Emergency / high priority location behavior is sane

## 11) Sensors
  [ ] Accelerometer works
  [ ] Gyroscope works
  [ ] Magnetometer / compass works
  [ ] Pro imity sensor works
  [ ] Light sensor works
  [ ] Barometer works, if present
  [ ] Hall sensor works, if present
  [ ] Step counter works, if present
  [ ] Step detector works, if present
  [ ] Significant motion works, if present
  [ ] Sensor calibration is stable
  [ ] Sensor values survive suspend/resume
  [ ] No stuck sensor readings
  [ ] Auto rotate and pro imity in call both behave correctly

## 12) Audio
  [ ] Main speaker works
  [ ] Earpiece works
  [ ] Stereo channels are correct
  [ ] Loudspeaker volume range is normal
  [ ] Headphone audio works via 3.5 mm jack, if present
  [ ] USB audio works
  [ ] Bluetooth audio works
  [ ] Mic records properly
  [ ] Secondary / noise cancel mic works
  [ ] Voice recorder works
  [ ] Video recording audio works
  [ ] In call audio routing works
  [ ] Alarm sound works
  [ ] Notification sound works
  [ ] Media playback works
  [ ] Low latency / gaming audio feels normal
  [ ] No popping / crackling / distortion
  [ ] Audio effects / equalizer / Dolby / spatial audio work, if included

## 13) Camera / flashlight
  [ ] Camera app opens
  [ ] Rear main camera works
  [ ] Front camera works
  [ ] Ultrawide camera works, if present
  [ ] Telephoto camera works, if present
  [ ] Macro camera works, if present
  [ ] Flashlight toggle works
  [ ] Flash works in camera
  [ ] Photo capture works
  [ ] HDR works
  [ ] Portrait mode works
  [ ] Night mode works
  [ ] Panorama works
  [ ] Video recording works
  [ ] 60 fps recording works, if supported
  [ ] 4K recording works, if supported
  [ ] Slow motion works, if supported
  [ ] Stabilization works
  [ ] Autofocus works
  [ ] Tap to focus works
  [ ] E posure control works
  [ ] Zoom works
  [ ] Camera switching is stable
  [ ] Third party camera apps work
  [ ] QR scanning works
  [ ] Camera works after suspend/resume
  [ ] Camera works after repeated open/close cycles
  [ ] No green tint / crash / black preview

## 14) Storage / files / SD card
  [ ] Internal storage mounts correctly
  [ ] Correct capacity shown
  [ ] Read / write works
  [ ] MTP file transfer works
  [ ] SAF / file picker works
  [ ] App install works
  [ ] App updates work
  [ ] ADB push / pull works
  [ ] OTG storage works
  [ ] microSD detected, if present
  [ ] microSD read/write works
  [ ] Adoptable storage works, if used
  [ ] E FAT / NTFS behavior is as e pected, if supported

## 15) USB / OTG / peripherals
  [ ] USB connection detected reliably
  [ ] File transfer mode works
  [ ] Charge only mode works
  [ ] USB debugging authorization works
  [ ] OTG works
  [ ] USB keyboard works
  [ ] USB mouse works
  [ ] USB DAC works
  [ ] USB camera works, if supported
  [ ] Host/device role switching works
  [ ] Fast charging negotiates correctly
  [ ] PC recognizes device consistently

## 16) Media / codecs / streaming
  [ ] Hardware video decode works
  [ ] Hardware video encode works
  [ ] H.264 playback works
  [ ] HEVC playback works
  [ ] VP9 playback works
  [ ] AV1 playback works, if supported
  [ ] Widevine level is reported as e pected
  [ ] YouTube playback works
  [ ] Local high bitrate playback works
  [ ] Recording and playback sync is correct
  [ ] No codec crashes / OM  / Codec2 issues

## 17) Power / battery / thermals
  [ ] Battery percentage is correct
  [ ] Charging animation works
  [ ] Slow / normal / fast charging are detected correctly
  [ ] Battery health info is shown correctly, if supported
  [ ] Deep sleep works
  [ ] Idle drain is normal
  [ ] Screen on battery drain is reasonable
  [ ] Thermal throttling works
  [ ] Device does not overheat abnormally
  [ ] Thermal warnings appear correctly
  [ ] Charging while using camera/navigation/gaming is stable

## 18) Sleep / wake / doze
  [ ] Screen turns off normally
  [ ] Device enters sleep
  [ ] Device wakes with power button
  [ ] Device wakes with fingerprint
  [ ] Device wakes with double tap, if supported
  [ ] Notifications arrive during doze as e pected
  [ ] Alarms fire correctly in idle
  [ ] Wi Fi / mobile data recover after wake
  [ ] Bluetooth recovers after wake

## 19) Apps / permissions / U 
  [ ] Permission prompts show correctly
  [ ] Camera permission works
  [ ] Mic permission works
  [ ] Location permission works
  [ ] Nearby devices permission works
  [ ] Notification permission works
  [ ] Scoped storage behavior is normal
  [ ] Split screen works
  [ ] Picture in picture works
  [ ] Recents screen works
  [ ] App pinning works
  [ ] Clipboard / share sheet work
  [ ] WebView works
  [ ] Play Store works, if included
  [ ] Play Services behave normally, if included
  [ ] Banking / work / auth apps behave as e pected for your bootloader/root state

## 20) Recovery / OTA / partitions
  [ ] Dirty flash update succeeds
  [ ] Clean flash still boots after format data
  [ ] OTA package installs, if your ROM supports OTA
  [ ] Post OTA reboot succeeds
  [ ] Data is preserved after OTA, when e pected
  [ ] Slot switching works on A/B devices
  [ ] Rollback / fallback behavior works if an update fails
  [ ] Recovery sideload works
  [ ] Dynamic partitions behave correctly
  [ ] Vendor / boot / dtbo / vbmeta handling is correct

## 21) Root / modding sanity (if relevant)
  [ ] Magisk boots
  [ ] Modules don’t break boot
  [ ] Zygisk behavior is normal
  [ ] DenyList / root hiding behavior matches e pectations
  [ ] ADB root works on userdebug/eng builds only
  [ ] KernelSU / APatch behavior is stable, if used
  [ ] Root does not break biometrics, NFC, or calls une pectedly

## 22) Final stability checks
  [ ] 10+ reboots without issue
  [ ] 24 hour idle test passes
  [ ] Long call test passes
  [ ] Long camera recording test passes
  [ ] Long GPS navigation test passes
  [ ] Long Bluetooth audio session passes
  [ ] Charging overnight is stable
  [ ] No major memory leaks
  [ ] No severe UI jank
  [ ] No reproducible crash in everyday use

## 23) Validation / compatibility pass
  [ ] Feature flags match actual hardware
  [ ] CTS basic pass
  [ ] CTS Verifier smoke pass
  [ ] VTS/HAL sanity pass, if you’re doing device side bring up work
  [ ] Camera ITS pass / major items pass
  [ ] SELinu  denials reviewed
  [ ] Encryption / Direct Boot behavior reviewed
  [ ] Verified Boot / AVB status reviewed
  [ ] Logs reviewed for missing services / dead HALs / crashes

## Notes / bugs
  [ ] Bug 1:
  [ ] Bug 2:
  [ ] Bug 3:
  [ ] Needs vendor blob fi 
  [ ] Needs sepolicy fi 
  [ ] Needs kernel fi 
  [ ] Needs overlay/config fi 

---

## Device tree vs stock firmware verification report

Reference: stock itel P661N `P661N-H334IJKLN-T-GL-250723V610` (Android 13 / TP1A.220624.014), root adb. Tree branch `testing`. Kernel modules intentionally out of scope. Byte-compares done against live `/vendor/etc` on the device (stock files pulled to a scratch dir, not committed).

Legend: **[OK]** matches stock / sane  **[WARN]** deviation, needs decision/verification  **[DEFECT]** wrong config

### Verified identical to stock (byte-for-byte)
- `configs/audio/audio_device.xml` == `/vendor/etc/audio_device.xml`
- `configs/audio/aurisys_config.xml`, `aurisys_config_rv.xml`, `audio_em.xml`
- `configs/wifi/*` (3 files) — `wpa_supplicant.conf`/overlay + `p2p_supplicant_overlay.conf`
- `configs/sensors/hals.conf`
- `configs/seccomp/*` (5 policies)
- `rootdir/etc/ueventd.mt6833.rc`, `rootdir/etc/init.insmod.mt6833.cfg`
- `rootdir/etc/fstab.mt6833` + `fstab.emmc` userdata lines (and all mount entries — only additive dual erofs/ext4 fallback lines for system/system_ext/vendor/product)

### Verified OK (validated against live hardware)
- **powerhint.json**: every node path exists on device; all CPU freq values exactly match live `scaling_available_frequencies` (policy0=16, policy6=16). GPU nodes hit the DVFSRC devfreq domain and match live max/min (`4266000000`/`400000000`). `GpuPwrLevel` OPP comments are slightly stale (max 1003000 vs real Mali 1068000) but index table is valid.
- **firmware**: all 12 `proprietary-firmware.txt` partitions exist on device (`dpm/gz/lk/logo/mcupm/md1img/pi_img/scp/spmfw/sspm/tee/tkv`, A/B slots) with plausible sizes.
- **overlays (display)**: cutout path `M -24,0 L -24,36 L 24,36 L 24,0 Z @dp` matches stock live `cutoutSpec`; 720x1612, density 320, peak refresh 90 all match stock.
- **overlays (tethering)**: interface regexs (`wlan\d`, `ap\d`, `rndis\d`, `bt-pan`) match live interfaces (`wlan0`, `ap0`, `p2p0`).
- **vintf**: flat device manifest + runtime-merged `/vendor/etc/vintf/manifest/*.xml` fragments is the standard GKI pattern; HALs absent from the flat manifest (sensors/thermal/boot/MTK vendor HALs) are provided by ROM-built packages' own fragments.

### [DEFECT] overlay/FrameworksResTarget/res/xml/power_profile.xml is broken
- `cpu.speeds.cluster1` declared **twice** (lines 47 and 83); the second block holds power values and must be renamed `cpu.active.cluster1`.
- CPU freq tables are **fabricated** — they don't match the device. Cluster0 max 1700000 vs real **2000000**; cluster1 max 2000000 vs real **2400000**; most entries don't exist in the real OPP tables. Use the live tables from `powerhint.json` (which are correct) instead.
- `cpu.active.cluster0` == `cpu.core_power.cluster0` (should differ).
- Battery capacity 5000 mAh is correct; cluster cores 6/2 is correct.

### [WARN] media_codecs_c2.xml removed MTK audio decoders
- Tree drops all `c2.mtk.*` audio decoders (alac/ape/wma/mp3/adpcm-ms/adpcm-dvi-ima) that the vendor tree still ships (`libcodec2_soft_mtk_alacdec.so`, `_apedec.so`, `_mp3dec.so`, `_imaadpcmdec.so`, `_msadpcmdec.so`) and advertises via `ro.vendor.mtk_audio_alac_support=1` / `ape_support=1`. `c2.android.*` removal is fine (ROM provides SW codecs); the MTK lossless/WMA decoders have no AOSP fallback. Decide: keep stripped (drop the props) or restore the c2.mtk audio entries + `<Include href="media_codecs_mediatek_audio.xml">`-style block.

### [WARN] audio_policy_configuration.xml drops a2dp input
- Stock includes `a2dp_in_audio_policy_configuration.xml` (BT A2DP *capture*); tree removed it and doesn't ship the file. Main `bluetooth_audio_policy_configuration.xml` + primary module are otherwise identical to stock. `audio_policy_configuration_bluetooth_legacy_hal.xml` (fallback path) likewise omits the a2dp module include. Expected outcome: no A2DP-input recording on the ROM. Confirm intentional.

### [WARN] audio_effects.xml is a Dolby/DTS swap — verify blob presence
- Tree: AOSP `libaudiopreprocessing.so` (AOSP uuids) + `libswgamedap.so`/`libswvqe.so`/`libswdap.so` (Dolby). Stock: `libaudiopreprocessing_mtk.so` + `libdtsaudio.so` (DTS).
- `vendor/sony/dolby/setup.mk` is inherited (device.mk:109) and must supply the three `libsw*.so` + the Dolby HIDL (`vendor.dolby.hardware.dms` listed in manifest + compat matrix). Verify those blobs land in the ROM; if not, gamedap/dap effects silently no-op.

### [WARN] media_profiles_V1_0.xml — minor capability loss
- `highspeedlow` (slow-mo) dropped the 1280x720@120 tier (tree keeps only 640x480@120). 720p@120 still present via `highspeed720p`/`highspeedhigh`. Encoding profiles otherwise equivalent (same cameras, h264/h263/m4v caps).

### [WARN] props diverging from stock (all deliberate InfinityOS tuning, sanity-checked)
- LMK retuning: `ro.lmk.psi_complete_stall_ms` 150→300, `swap_free_low_percentage` 10→20, `thrashing_limit` 20→30, `thrashing_limit_decay` 60→50.
- `ro.surface_flinger.set_idle_timer_ms` 1200→3000; `media.c2.dmabuf.padding` 3072→512; `ro.vendor.composer_version` 2.1→2.3 (matches manifest @2.3-service).
- `ro.vendor.mtk_log_hide_gps` 0→1; `ro.vendor.mtk_thermal_2_0` 0→1; `ro.vendor.mediatek.rsc_name`/rsc_path `default`→`GL` — **verify the ROM ships `/system/etc/rsc/GL` and `/vendor/etc/rsc/GL`** (stock has neither dir; wrong path breaks RSC lookups).
- `persist.vendor.connsys.chipid`/`patch.version` `-1` are placeholders the connsys driver overwrites at runtime (stock reports `0x6833` / `240724112957000`) — harmless.

### [WARN] lk.img pinned SHA1 mismatch
- `proprietary-firmware.txt` pins `lk.img` = `c10b8313...`; live `lk_a` on device = `0131f1fd...`. Git log shows `pin lk patch`, so the mismatch is expected if the pin corresponds to a patched/older LK. Re-pin to the blob actually shipped by `-kernel`/vendor if the hash is meant to match the stock LK.

### [FIXED] WifiResTarget disables SAE/WPA3
- Overlay now sets `config_wifiSaeUpgradeEnabled=true` + `config_wifiSaeH2eSupported=true`. The "Hardware limitations" comment was wrong: stock runs `mIsWpa3SaeUpgradeEnabled=true` / `mIsWpa3SaeH2eSupported=true` and `wpa_supplicant.conf` has `pmf=1` + `sae_pwe=2` (byte-identical to the tree's copy).

## Prop audit (`configs/props/{system,vendor}.prop` vs live stock `getprop`)

Reference: stock `P661N-H334IJKLN-T-GL-250723V610` (6 GB RAM, `MemTotal` 5749816 kB; zram 3 GB + swapfile 4 GB). All 292 tree props compared against live device values.

### [OK] 227 props identical to stock
All hardware/feature flags match the running device byte-for-byte, including: dalvik heap config, camera3 pipeline bufnum, all `ro.vendor.mtk_*` platform flags, `ro.vendor.pq.*`, IMS/VoLTE/WFC/ViLTE set, radio RAT config (`c6m_1rild`, `md1_support=22`, dsds), audio (`aaudio.mmap*=2`, `ro.audio.*`), BT profile enables, `ro.hardware.*` (egl=meow, hwcomposer=mtk_common, vulkan=mali), `ro.opengles.version=196610`, netflix bsp_rev, `ro.crypto.volume.filenames_mode=aes-256-cts`, `ro.vendor.mediatek.version.*`.

### [OK] 35 of 50 added props are ROM feature enablement (sane, no stock equivalent)
- InfinityOS branding: `ro.product.marketname`, `ro.infinity.{soc,camera}`, `ro.lunaris.maintainer`.
- Display/UX: `ro.sf.blurs_are_expensive=1`, `ro.surface_flinger.supports_background_blur=1`, `ro.surface_flinger.game_default_frame_rate_override=90`, `use_content_detection_for_refresh_rate=true`, `enable_frame_rate_override=false`, `set_touch_timer_ms=500`, `uclamp.min=328`, vsync offsets, `debug.sf.high_fps_*` (all match 90 Hz panel, `primaryRefreshRateRange=[60 90]`), `debug.sf.treat_170m_as_sRGB=1`, `debug.sf.enable_adpf_cpu_hint=true`, `debug.sf.disable_client_composition_cache=1`, `debug.sf.auto_latch_unsignaled=0`, `debug.sf.enable_gl_backpressure=1`, `debug.sf.frame_rate_multiple_threshold=90`.
- Performance: `persist.sys.perf.scroll_opt=true` (+heavy_app), `zygote.critical_window.minute=10`.
- Media: `media.c2.hal.selection=aidl` (matches ROM codec2 AIDL), `media.c2.dmabuf.padding=3072` (restored to stock).
- Bluetooth LE Audio profile enables (`bluetooth.profile.bap.*`, `csip`, `hap.client`, `mcp.server`, `vcp.controller`) — stock doesn't set them but runs LE Audio broadcaster; stack-driven, OK.
- Defaults: `ro.config.{alarm=13,media=13,system=15,vc_call=11}_vol_default`, `ro.apk_verity.mode=2` (GKI), `bluetooth.device.class_of_device=90,2,12`, `bluetooth.hardware.power.operating_voltage_mv=3300`.
- SIM/modem fallbacks: `ro.vendor.mtk_external_sim_support=1`, `ro.vendor.mtk_sim_card_onoff=3`, `ro.vendor.mtk_uicc_clf=1`, `ro.vendor.mtk_md3_support=0` (single-modem `md1=22`, md3 off is correct), `ro.vendor.mtk_fast_charging_support=1`, `ro.vendor.mtk_hifiaudio_support=1`, `ro.mtk_cam_dualzoom_support=1`, `ro.mtk_cam_stereo_camera_support=1`, `ro.mtk_key_manager_support=1`.

### [OK] 6 of 15 divergent props are benign / runtime-set
- `persist.vendor.connsys.chipid=-1` / `patch.version=-1`: placeholders — wmt driver overwrites at runtime (stock reports `0x6833` / `240724112957000`).
- `vendor.connsys.driver.ready=no`: correct boot default — kernel driver flips to `yes` (stock shows `yes` because the driver already loaded; `init.bt_drv.rc`/`init.fmradio_drv.rc` key off both values).
- `ro.vendor.composer_version` 2.1→2.3: consistent with tree manifest + `@2.3-service`; vendor blob is HWC2 (`g_hwc2_api`) so version comes from the ROM service wrapper — deliberate InfinityOS bump.
- `ro.vendor.mtk_log_hide_gps` 0→1: hides GPS debug logs — intentional.
- LMK retuning (all consistent with 6 GB + zram/swap): `psi_complete_stall_ms` 150→300, `swap_free_low_percentage` 10→20, `thrashing_limit` 20→30, `thrashing_limit_decay` 60→50.

### [FIXED] remaining divergent / added props
- `ro.surface_flinger.has_wide_color_display=true`: **removed** — stock panel is sRGB-only 720p (no HDR, `mSupportedHdrTypes=[]`, `supportedColorModes [0]`); stock doesn't set it.
- `media.c2.dmabuf.padding` 512→**3072**: restored to stock (MTK vendor alignment).
- `ro.vendor.mediatek.rsc_name`/`rsc_path` → **`default`**: reverted to stock (stock uses `default`; no `/system/etc/rsc` or `/vendor/etc/rsc` dirs on device).
- `ro.vendor.mtk_thermal_2_0=1`: **kept intentionally** — tree ships `configs/thermal_info_config.json` (2.0 format, absent from stock) + `android.hardware.thermal-service.mediatek`; prop gates `libpowerhal.so` between `.tp/thermal.conf` (1.0, stock) and `thermal_info_config.json` (2.0, tree). Verify thermald starts on first boot.

### [OK] Miscellaneous
- `extract-files.py`/`proprietary-files.txt` soname fixups cover all `vndk/` prebuilts (v32/v33) and the `libcodec2_soft_mtk_*.so` set.
- `vendor_logtag.mk` levels (S on user / I on eng) confirmed as the deliberate spam-silencing scheme.
- sepolicy split (`sepolicy/{private,public,vendor}`) + `device/mediatek/sepolicy_vndr` consistent with BoardConfig; enforcing default (no `androidboot.selinux=permissive`).

### Action items (highest priority first)
1. ~~Rewrite `power_profile.xml` using the real CPU OPP tables (copy from `powerhint.json`) and fix the duplicate `cpu.speeds.cluster1` → `cpu.active.cluster1`.~~ **DONE**: real OPP tables now match device (`policy0` max 2000000, `policy6` max 2400000), duplicate array renamed to `cpu.active.cluster1`, `cpu.core_power.*` now per-core (active/cores) instead of duplicating `cpu.active.*`.
2. Decide on MTK audio decoders in `media_codecs_c2.xml` (restore or drop the now-misleading `alac/ape` props).
3. Confirm Dolby `libsw*.so` + DMS HAL actually ship from `vendor/sony/dolby`.
4. ~~Revert rsc props.~~ **DONE**: `ro.vendor.mediatek.rsc_name`/`rsc_path` set to `default` (matches stock).
5. Reconcile `lk.img` pin hash with the shipped blob.
6. ~~Re-verify SAE.~~ **DONE**: SAE upgrade + H2E enabled in `WifiResTarget` (matches stock supplicant `pmf=1`/`sae_pwe=2` and framework flags).
7. ~~Review `ro.surface_flinger.has_wide_color_display=true`.~~ **DONE**: removed (panel is sRGB-only, no HDR; stock doesn't set it).
8. ~~Watch `media.c2.dmabuf.padding=512`.~~ **DONE**: restored to stock `3072`. Watch `ro.vendor.mtk_thermal_2_0=1` (thermald start) on first boot.