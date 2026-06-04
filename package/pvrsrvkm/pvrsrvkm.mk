################################################################################
#
# pvrsrvkm — Imagination PowerVR BXM-4-64 kernel module for Allwinner A733
#
# The GPU driver source lives in the allwinner-bsp overlay that was already
# cloned by scripts/setup-kernel-66.sh into linux/kernel-66/bsp/.
# We build it out-of-tree against the built kernel using the parameters
# documented by Allwinner for the sun60iw2 (A733) platform.
#
################################################################################

PVRSRVKM_VERSION = cubie-aiot-v1.4.8
PVRSRVKM_SITE = $(BR2_EXTERNAL_BATOCERA_PATH)/../linux/kernel-66/bsp/modules/gpu/img-bxm/linux/rogue_km
PVRSRVKM_SITE_METHOD = local
PVRSRVKM_LICENSE = MIT

# pvrsrvkm depends on the kernel being fully built
PVRSRVKM_DEPENDENCIES = linux

PVRSRVKM_KERNEL_SRC = $(LINUX_DIR)
PVRSRVKM_MODULE_DIR = $(PVRSRVKM_KERNEL_SRC)/bsp/modules/gpu

define PVRSRVKM_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) \
		-C $(PVRSRVKM_KERNEL_SRC) \
		M=$(PVRSRVKM_MODULE_DIR) \
		KERNEL_SRC_DIR=$(PVRSRVKM_KERNEL_SRC) \
		KERNEL_OUT_DIR=$(PVRSRVKM_KERNEL_SRC) \
		ARCH=arm64 \
		CROSS_COMPILE=$(TARGET_CROSS) \
		PVR_SYSTEM=rgx_sunxi \
		RGX_BVNC=36.56.104.183 \
		WINDOW_SYSTEM=nulldrmws \
		CONFIG_OS_TYPE=linux \
		modules
endef

define PVRSRVKM_INSTALL_TARGET_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) \
		-C $(PVRSRVKM_KERNEL_SRC) \
		M=$(PVRSRVKM_MODULE_DIR) \
		KERNEL_SRC_DIR=$(PVRSRVKM_KERNEL_SRC) \
		ARCH=arm64 \
		CROSS_COMPILE=$(TARGET_CROSS) \
		INSTALL_MOD_PATH=$(TARGET_DIR) \
		INSTALL_MOD_STRIP=1 \
		modules_install
endef

$(eval $(generic-package))
