#
# SPDX-FileCopyrightText: The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# Inherit from device makefile.
$(call inherit-product, device/itel/P661N/device.mk)

# Inherit some common Lineage stuff.
$(call inherit-product, vendor/lineage/config/common_full_phone.mk)

# Device identifier. This must come after all inclusions
PRODUCT_NAME := lineage_P661N
PRODUCT_DEVICE := P661N
PRODUCT_MANUFACTURER := itel
PRODUCT_BRAND := Itel
PRODUCT_MODEL := P661N

# Build info
PRODUCT_GMS_CLIENTID_BASE := android-transsion

PRODUCT_BUILD_PROP_OVERRIDES += \
    BuildDesc="vnd_p661n_h334-user 12 SP1A.210812.016 928046 release-keys" \
    BuildFingerprint=Itel/P661N-GL/itel-P661N:12/SP1A.210812.016/250723V610:user/release-keys \
    SystemModel=$(PRODUCT_SYSTEM_DEVICE) \
    SystemName=$(PRODUCT_SYSTEM_NAME) \
    ProductModel=$(PRODUCT_SYSTEM_DEVICE) \
    DeviceProduct=$(PRODUCT_SYSTEM_NAME)

# Time
LINEAGE_VERSION_APPEND_TIME_OF_DAY := true

WITH_GAPPS := true
WITH_GMS := true

# Ship Basic Call Recorder App
WITH_BCR := true

# Surface flinger boosting (Smoother scrolling, fewer frame drops but Keeps CPU slightly “awake”)
SURFACE_FLINGER_BOOST := true

TARGET_BOOT_ANIMATION_RES := 720

TARGET_SUPPORTED_REFRESH_RATES := 60,90

# Animation fix for mtk devices 
PERF_ANIM_OVERRIDE := true

# Enable blur effects
TARGET_ENABLE_BLUR := true

# Enable AxionFx
TARGET_INCLUDE_AXFX := true

# Camera information
AXION_CAMERA_REAR_INFO := 50
AXION_CAMERA_FRONT_INFO := 8

# Maintainer name
AXION_MAINTAINER := R

# Processor name
AXION_PROCESSOR := Mediatek_Dimensity_6080

TARGET_INCLUDES_LOS_PREBUILTS := true
