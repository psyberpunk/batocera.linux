################################################################################
#
# cargo-c
#
################################################################################

CARGO_C_VERSION = v0.10.19
CARGO_C_SITE = $(call github,lu-zero,cargo-c,$(CARGO_C_VERSION))
CARGO_C_LICENSE = MIT License
CARGO_C_LICENSE_FILES = LICENSE

HOST_CARGO_C_DEPENDENCIES = host-pkgconf host-rustc host-openssl

# cargo-c ships no Cargo.lock; make the generated lockfile honour its
# rust-version (1.90) instead of pulling crates that need a newer rustc
# than Buildroot's rust-bin provides.
HOST_CARGO_C_DL_ENV = CARGO_RESOLVER_INCOMPATIBLE_RUST_VERSIONS=fallback

$(eval $(host-cargo-package))
