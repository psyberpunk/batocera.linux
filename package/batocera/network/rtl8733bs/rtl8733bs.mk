################################################################################
#
# rtl8733bs
#
################################################################################
# Version: as pinned by CoreELEC coreelec-22
RTL8733BS_VERSION = 6b522b308fb7482cb43be290d639cfdf2bfd1838
RTL8733BS_SITE = $(call github,smp79,rtl8733BS_WiFi_linux_v5.15.17-113,$(RTL8733BS_VERSION))
RTL8733BS_LICENSE = GPL-2.0

RTL8733BS_MODULE_MAKE_OPTS = \
	CONFIG_RTL8733BS=m \
	KSRC=$(LINUX_DIR) \
	USER_EXTRA_CFLAGS="-Wno-error"

$(eval $(kernel-module))
$(eval $(generic-package))
