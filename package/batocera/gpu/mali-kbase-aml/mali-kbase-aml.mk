################################################################################
#
# mali-kbase-aml
#
################################################################################
# Version: as pinned by CoreELEC coreelec-22
MALI_KBASE_AML_VERSION = 8deb0c1665bfc20fb97e43650510edf3d86b0c00
MALI_KBASE_AML_SITE = $(call github,CoreELEC,gpu-aml,$(MALI_KBASE_AML_VERSION))
MALI_KBASE_AML_LICENSE = GPL-2.0
MALI_KBASE_AML_DEPENDENCIES = linux

MALI_KBASE_AML_SRC = $(@D)/valhall/r44p0/kernel/drivers/gpu/arm

MALI_KBASE_AML_MAKE_OPTS = \
	$(LINUX_MAKE_FLAGS) \
	KERNEL_SRC=$(LINUX_DIR) \
	CONFIG_MALI_DEVFREQ=y \
	CONFIG_MALI_CSF_SUPPORT=y \
	KCFLAGS="-DCONFIG_MALI_LOW_MEM=0"

# The S7D device tree describes the GPU as the CSF front end
define MALI_KBASE_AML_SET_CSF_COMPATIBLE
	$(SED) 's|.compatible = "arm,mali-valhall.*"|.compatible = "arm,mali-valhall-csf"|' \
		$(MALI_KBASE_AML_SRC)/midgard/mali_kbase_core_linux.c
endef
MALI_KBASE_AML_POST_PATCH_HOOKS += MALI_KBASE_AML_SET_CSF_COMPATIBLE

define MALI_KBASE_AML_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(MALI_KBASE_AML_SRC) $(MALI_KBASE_AML_MAKE_OPTS)
endef

define MALI_KBASE_AML_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0644 $(MALI_KBASE_AML_SRC)/midgard/mali_kbase.ko \
		$(TARGET_DIR)/lib/modules/$(LINUX_VERSION_PROBED)/extra/mali_kbase.ko
endef

$(eval $(generic-package))
