#!/bin/bash

# HOST_DIR = host dir
# BOARD_DIR = board specific dir
# BUILD_DIR = base dir/build
# BINARIES_DIR = images dir
# TARGET_DIR = target dir
# BATOCERA_BINARIES_DIR = batocera binaries sub directory

HOST_DIR=$1
BOARD_DIR=$2
BUILD_DIR=$3
BINARIES_DIR=$4
TARGET_DIR=$5
BATOCERA_BINARIES_DIR=$6

# DTB used by default: the CoreELEC 2g_1gbit board with the S905A OPP tables
# (validated on the X96 M200, CPU up to 2.5 GHz)
DEFAULT_DTB=s7d_s905x5m_2g_1gbit_s905a.dtb

DTBs=(
    s7d_s905x5m_2g_1gbit_s905a.dtb
    s7d_s905a_bm221.dtb
    s7d_s905x5m_2g_1gbit.dtb
    s7d_s905x5m_2g.dtb
    s7d_s905x5m_4g_1gbit.dtb
    s7d_s905x5m_4g.dtb
)

mkdir -p "${BATOCERA_BINARIES_DIR}/boot/boot"         || exit 1
mkdir -p "${BATOCERA_BINARIES_DIR}/boot/device_trees" || exit 1

# Android boot image (kernel + initramfs) for the stock Amlogic u-boot bootm.
# The S7D u-boot only takes a zstd ramdisk here (a gzip one makes bootm
# fail and fall back to Android), as in CoreELEC's kernel.img.
gzip -dc "${BINARIES_DIR}/initrd.gz" | "${HOST_DIR}/bin/zstd" -q -3 -f -o "${BINARIES_DIR}/initrd.zst" || exit 1
python3 "${BOARD_DIR}/mkbootimg.py" \
    --kernel  "${BINARIES_DIR}/Image.lzo" \
    --ramdisk "${BINARIES_DIR}/initrd.zst" \
    --output  "${BATOCERA_BINARIES_DIR}/boot/kernel.img" || exit 1

cp "${BINARIES_DIR}/rootfs.squashfs" "${BATOCERA_BINARIES_DIR}/boot/boot/batocera.update"         || exit 1
cp "${BINARIES_DIR}/rufomaculata"    "${BATOCERA_BINARIES_DIR}/boot/boot/rufomaculata.update"     || exit 1

for DTB in "${DTBs[@]}"
do
    cp "${BINARIES_DIR}/${DTB}" "${BATOCERA_BINARIES_DIR}/boot/device_trees/" || exit 1
done
cp "${BINARIES_DIR}/${DEFAULT_DTB}" "${BATOCERA_BINARIES_DIR}/boot/dtb.img" || exit 1

cp "${BOARD_DIR}/boot/README.txt" "${BATOCERA_BINARIES_DIR}/boot/" || exit 1
# This u-boot does not run scripts (source/autoscr): the CoreELEC bootcmd
# only uses cfgload to detect the card, then "env import"s cfgload_env and
# runs its ceboot.
cp "${BOARD_DIR}/boot/cfgload_env" "${BATOCERA_BINARIES_DIR}/boot/" || exit 1
# With the reset button held, u-boot boots recovery.img from the card: this
# CoreELEC (22.0-Piers_beta2, aml_recovery) mini system fw_setenv's the
# aml_autoscript lines and reboots. Without it the box falls to Android
# recovery and never learns to boot from the card.
cp "${BOARD_DIR}/boot/recovery.img" "${BATOCERA_BINARIES_DIR}/boot/" || exit 1

"${HOST_DIR}/bin/mkimage" -A arm64 -O linux -T script -C none -d "${BOARD_DIR}/boot/aml_autoscript.txt" "${BATOCERA_BINARIES_DIR}/boot/aml_autoscript" || exit 1
"${HOST_DIR}/bin/mkimage" -A arm64 -O linux -T script -C none -d "${BOARD_DIR}/boot/cfgload.txt"        "${BATOCERA_BINARIES_DIR}/boot/cfgload"        || exit 1

exit 0
