#!/usr/bin/env python3
"""Minimal Android boot image (header v0) writer for the Amlogic u-boot bootm.

Produces the same layout as CoreELEC's `mkbootimg --base 0x0
--kernel_offset 0x2000000` kernel.img: page size 2048, no second stage,
no dtb in the image (dtb.img is loaded separately by cfgload).
"""

import argparse
import hashlib
import struct

BOOT_MAGIC = b"ANDROID!"
PAGE_SIZE = 2048


def pad(data: bytes) -> bytes:
    return data + b"\0" * (-len(data) % PAGE_SIZE)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--kernel", required=True)
    parser.add_argument("--ramdisk", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--base", type=lambda x: int(x, 0), default=0x0)
    parser.add_argument("--kernel_offset", type=lambda x: int(x, 0), default=0x2000000)
    parser.add_argument("--ramdisk_offset", type=lambda x: int(x, 0), default=0x1000000)
    parser.add_argument("--second_offset", type=lambda x: int(x, 0), default=0xF00000)
    parser.add_argument("--tags_offset", type=lambda x: int(x, 0), default=0x100)
    args = parser.parse_args()

    with open(args.kernel, "rb") as f:
        kernel = f.read()
    with open(args.ramdisk, "rb") as f:
        ramdisk = f.read()

    # same id as AOSP mkbootimg v0: sha1 over each part and its size
    sha = hashlib.sha1()
    for blob in (kernel, ramdisk, b""):
        sha.update(blob)
        sha.update(struct.pack("<I", len(blob)))

    header = struct.pack(
        "<8s10I16s512s32s1024s",
        BOOT_MAGIC,
        len(kernel),
        args.base + args.kernel_offset,
        len(ramdisk),
        args.base + args.ramdisk_offset,
        0,
        args.base + args.second_offset,
        args.base + args.tags_offset,
        PAGE_SIZE,
        0,  # header version
        0,  # os version
        b"",  # board name
        b"",  # cmdline (cfgload builds bootargs)
        sha.digest().ljust(32, b"\0"),
        b"",  # extra cmdline
    )

    with open(args.output, "wb") as f:
        f.write(pad(header))
        f.write(pad(kernel))
        f.write(pad(ramdisk))


if __name__ == "__main__":
    main()
