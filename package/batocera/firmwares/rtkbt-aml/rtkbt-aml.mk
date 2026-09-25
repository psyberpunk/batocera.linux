################################################################################
#
# rtkbt-aml
#
################################################################################
# rtk_hciattach and firmware as pinned by CoreELEC coreelec-22
RTKBT_AML_VERSION = 3d0ed39cfdd24343715057e93134cd63b7321827
RTKBT_AML_SITE = $(call github,Caesar-github,rkwifibt,$(RTKBT_AML_VERSION))
RTKBT_AML_LICENSE = GPL-2.0

RTKBT_AML_FW_VERSION = 492de5f2c6afbe51cb0ed120373ccdc4b0f36982
RTKBT_AML_EXTRA_DOWNLOADS = \
	https://github.com/CoreELEC/rtkbt-firmware-aml/archive/$(RTKBT_AML_FW_VERSION).tar.gz

RTKBT_AML_HCIATTACH_DIR = $(@D)/realtek/rtk_hciattach

define RTKBT_AML_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(RTKBT_AML_HCIATTACH_DIR) CC="$(TARGET_CC)"
endef

define RTKBT_AML_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(RTKBT_AML_HCIATTACH_DIR)/rtk_hciattach \
		$(TARGET_DIR)/usr/bin/rtk_hciattach
	mkdir -p $(TARGET_DIR)/lib/firmware/rtlbt
	$(TAR) -xzf $(RTKBT_AML_DL_DIR)/$(RTKBT_AML_FW_VERSION).tar.gz \
		-C $(TARGET_DIR)/lib/firmware/rtlbt --strip-components=1 \
		--wildcards '*_fw' '*_config'
endef

$(eval $(generic-package))
