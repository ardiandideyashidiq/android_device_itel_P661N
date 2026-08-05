# AGENTS.md

Android device tree for the itel P55 5G (**P661N**, a.k.a. P665L), MediaTek Dimensity 6080 (`mt6833`), used for **InfinityOS** builds. This is one repo in a full Android source tree — it is **not** buildable standalone.

## Build context

- Lunch target: `infinity_P661N` (see `infinity_P661N.mk`; `PRODUCT_NAME := infinity_P661N`). Build from the ROM root, never from here: `lunch infinity_P661N-userdebug && mka bacon`.
- Companion repos are **outside this tree** — do not expect them here. Required (per `local_manifest-P661N/manifest.xml` in the parent dir):
  - `device/itel/P661N-kernel` — prebuilt `dtbo.img`, `dtb/`, vendor `*.ko`, `ramdisk/modules.load`
  - `device/gki/common-kernel` — GKI `Image.gz` (this is the kernel; **no kernel source exists here**)
  - `vendor/itel/P661N` — extracted proprietary blobs (output of extract-files)
  - `vendor/infinity`, `vendor/mediatek/ims`, `vendor/sony/dolby`, `hardware/mediatek`, `device/mediatek/sepolicy_vndr`
- Current branch is `testing`; origin manifest pins `lineage-23.2`.

## Hardware / build facts that change behavior

- **GKI + boot header v4**: kernel comes from `device/gki/common-kernel`, DTBO/DTB + vendor modules from `device/itel/P661N-kernel`. Never edit kernel config here; edit `BoardConfig.mk`/the `-kernel` repo instead.
- **64-bit only** device (`core_64_bit_only.mk`, `ZYGOTE_FORCE_64`).
- `infinity_P661N.mk` sets `WITH_GMS := true` → **all partitions erofs** (see the `WITH_GMS` branch in `BoardConfig.mk`). Sparse images are disabled everywhere.
- AVB uses `external/avb/test/data/testkey_rsa2048.pem` test keys.
- Shipping API level 31; A/B + virtual A/B + dynamic partitions (`mtk_dynamic_partitions`).

## Blob / proprietary workflow (LineageOS extract-utils)

- `./extract-files.py` — shebang self-sets `PYTHONPATH=../../../tools/extract-utils`, so run it as `./extract-files.py` **from this repo root** (the relative path resolves against the ROM tree).
- `setup-makefiles.py` is a stub that re-runs `./extract-files.py --regenerate_makefiles`.
- `update-sha1sums.py` (and `-c` to strip hashes) computes SHA1s from files under `../../../vendor/itel/P661N/proprietary`.
- `proprietary-files.txt` uses the `src:dest;FIX_SONAME` syntax. `proprietary-firmware.txt` holds unpinned firmware blobs (A/B partitions).
- Stock firmware source is `sys_tssi_64_armv82_itel-user 13` (TP1A.220624.014) — blob names/versions must stay consistent with what the vendor tree holds.
- `extract-files.py` contains all the soname fixups; the ROM-side convention is that version-suffixed libs (`libbinder-v32`, `libhidlbase-v32`, `libutils-v32`, `libtinyxml2-v34`, `libssl-v33`/`libcrypto-v33`, `libstagefright_foundation-v33`, …) are matched by these fixups and the `vndk/` prebuilts.

## Repo layout gotchas

- `libshims/` — only `libjni_shim` (engineering mode) lives here. `libbinder_shim`, `libbase_shim`, `libprocessgroup_shim`, `libhidlbase_shim`, `libcamera_metadata_shim` are referenced from `device.mk`/blob fixups but provided by `hardware/mediatek`.
- `vndk/` — pinned prebuilt VNDK libs (v32/v33, arm64). Don't "fix" versions without matching blob fixups.
- `edgefixd/` — custom C daemon (`cc_binary`, `-Werror`) enforcing Chipone touch edge restraint. Only self-built component besides shims.
- `rootdir/` — `Android.bp` `prebuilt_etc` modules; when adding an `*.rc`, both the `Android.bp` entry and the `device.mk` `PRODUCT_PACKAGES` line are required.
- `overlay/` vs `overlay-lineage/` — `PRODUCT_ENFORCE_RRO_TARGETS := *`; lineage overlays (`ApertureResTarget`) live in `overlay-lineage/`.
- `vendor_logtag.mk` — RIL/vendor log level is **S (silent) on user builds, I on eng** (`persist.log.tag.*`). This is deliberate "spammy log" silencing; don't re-add logs without following this pattern.
- `configs/props/{system,vendor}.prop` feed `TARGET_SYSTEM_PROP`/`TARGET_VENDOR_PROP`.
- sepolicy split across `sepolicy/{private,public,vendor}`; also includes `device/mediatek/sepolicy_vndr/SEPolicy.mk`. SELinux defaults to **enforcing** (the `androidboot.selinux=permissive` line is commented out in `BoardConfig.mk`).
- `dev/BUG.md` — bring-up validation checklist (boot, telephony, sensors, etc.); `logs/` and `bringup_reports/` are gitignored.
