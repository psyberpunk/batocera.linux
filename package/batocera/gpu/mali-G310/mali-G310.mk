################################################################################
#
# mali-G310
#
################################################################################

# libmali build system (wrappers, headers, pkg-config, GBM hooks), same as
# mali-G610; the actual driver is the Amlogic blob shipped by CoreELEC.
MALI_G310_VERSION = 309268f7a34ca0bba0ab94a0b09feb0191c77fb8
MALI_G310_SITE = $(call github,JeffyCN,mirrors,$(MALI_G310_VERSION))
MALI_G310_LICENSE = Proprietary
MALI_G310_LICENSE_FILES = END_USER_LICENCE_AGREEMENT.txt
MALI_G310_INSTALL_STAGING = YES

# CoreELEC/opengl-meson, as pinned by CoreELEC coreelec-22
MALI_G310_BLOB_VERSION = 2e7fc9325857953a3ced495b752d42e055bc9ddc
MALI_G310_BLOB = libMali_g310_dmaheap.so
# Current Khronos headers, taken from the same mesa release as mesa3d
MALI_G310_MESA_VERSION = 26.2.1
MALI_G310_MESA_SOURCE = mesa-$(MALI_G310_MESA_VERSION).tar.xz
MALI_G310_EXTRA_DOWNLOADS = \
	https://raw.githubusercontent.com/CoreELEC/opengl-meson/$(MALI_G310_BLOB_VERSION)/lib/arm64/valhall/r44p0/wayland/$(MALI_G310_BLOB) \
	https://archive.mesa3d.org/$(MALI_G310_MESA_SOURCE)

MALI_G310_PROVIDES = libegl libgbm libgles libmali
MALI_G310_DEPENDENCIES = host-patchelf libdrm wayland

MALI_G310_GPU = valhall-g310
MALI_G310_VER = r44p0
MALI_G310_PLATFORM = wayland-gbm

# Drop the Rockchip blobs and put the Amlogic one where the libmali
# grabber looks for $(GPU)-$(VER)-$(PLATFORM)
define MALI_G310_INJECT_BLOB
	rm -f $(@D)/lib/aarch64-linux-gnu/libmali-*.so
	$(INSTALL) -D -m 0755 $(MALI_G310_DL_DIR)/$(MALI_G310_BLOB) \
		$(@D)/lib/aarch64-linux-gnu/libmali-$(MALI_G310_GPU)-$(MALI_G310_VER)-$(MALI_G310_PLATFORM).so
endef
MALI_G310_POST_EXTRACT_HOOKS += MALI_G310_INJECT_BLOB

# CoreELEC's blob carries SONAME libMali.so; give it the libmali soname so
# the wrappers/hook (and everything linked through them) find it
define MALI_G310_FIX_SONAME
	$(HOST_DIR)/bin/patchelf --set-soname libmali.so.1 \
		$(@D)/lib/aarch64-linux-gnu/libmali-$(MALI_G310_GPU)-$(MALI_G310_VER)-$(MALI_G310_PLATFORM).so
endef
MALI_G310_PRE_CONFIGURE_HOOKS += MALI_G310_FIX_SONAME

# libmali ships 2019 Khronos headers (EGL_EGLEXT_VERSION 20190808), too old
# for wlroots (>= 20210604). The blob only needs the standard API
# declarations, so install the current ones from mesa instead.
define MALI_G310_USE_MESA_KHRONOS_HEADERS
	rm -rf $(@D)/include/EGL $(@D)/include/KHR $(@D)/include/GLES $(@D)/include/GLES2 $(@D)/include/GLES3
	$(TAR) -xJf $(MALI_G310_DL_DIR)/$(MALI_G310_MESA_SOURCE) -C $(@D)/include \
		--strip-components=2 \
		$(foreach d,EGL KHR GLES GLES2 GLES3,mesa-$(MALI_G310_MESA_VERSION)/include/$(d))
endef
MALI_G310_POST_EXTRACT_HOOKS += MALI_G310_USE_MESA_KHRONOS_HEADERS

MALI_G310_CONF_OPTS += \
	-Dwith-overlay=false \
	-Dopencl-icd=false \
	-Dkhr-header=false \
	-Dgpu=$(MALI_G310_GPU) \
	-Dversion=$(MALI_G310_VER) \
	-Dplatform=$(MALI_G310_PLATFORM) \
	-Dwrappers=auto \
	-Dhooks=true

# The wrappers are empty libraries that only pull libmali in through
# DT_NEEDED, so linking against the bare .so (e.g. Qt's FindEGL) fails with
# "DSO missing from command line". Point the development symlinks straight
# at the blob, like CoreELEC does in its sysroot; the runtime keeps the
# versioned wrappers.
define MALI_G310_LINK_DEV_LIBS_TO_BLOB
	for lib in EGL GLESv1_CM GLESv2 gbm wayland-egl; do \
		ln -sf libmali.so.1 $(STAGING_DIR)/usr/lib/lib$${lib}.so || exit 1; \
	done
endef
MALI_G310_POST_INSTALL_STAGING_HOOKS += MALI_G310_LINK_DEV_LIBS_TO_BLOB

# The kbase CSF driver requests mali_csffw.bin from the firmware root
define MALI_G310_LINK_CSF_FIRMWARE
	ln -sf arm/mali/arch10.8/mali_csffw.bin $(TARGET_DIR)/lib/firmware/mali_csffw.bin
endef
MALI_G310_POST_INSTALL_TARGET_HOOKS += MALI_G310_LINK_CSF_FIRMWARE

$(eval $(meson-package))
