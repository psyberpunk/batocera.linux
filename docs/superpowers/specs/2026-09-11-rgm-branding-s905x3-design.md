# RETRO GAMERS MEXICO — Batocera fork branding for Amlogic S905X3 (tvbox-gen3)

Date: 2026-09-11
Branch: `rgm`
Target: `s905gen3` (Amlogic S905X3 TV boxes: X96 Max+, H96 Max, HK1, A95X F3 …), board dir `tvbox-gen3`.

## Goal

Build a Batocera image for S905X3 TV boxes whose visible identity — from power-on to the
EmulationStation menu — is RETRO GAMERS MEXICO (RGM) instead of Batocera, without changing
system behaviour, package names or internal paths.

## Inputs (user assets, `~/iaapps/retrogamersmexico/`)

| File | Use |
|---|---|
| `Castillo.png` (8000×4500, alpha) | static splash: U-Boot boot logo, `boot-logo.png`, EmulationStation splash |
| `RGM-bco.svg` (white, transparent) | ES fallback splash `resources/splash.svg` |
| `retrogamersmexico.mp4` (1920×1080, 15 fps, h264 yuv444p, 32.5 s) | boot video splash (mpv) |

`Neon.png`, `CastilloNoche.png`, `RGM-ngo.*` are not used.

Note on the video: it is the user's own edit of a third-party intro. It is integrated as
supplied, for personal use only; its content is not modified beyond transcoding and trimming.

## Fixed decisions

| Item | Value |
|---|---|
| Boot partition label | `RETROGAMERS` (FAT32 limit: 11 chars; `RETROGAMERSMEXICO` does not fit) |
| Userdata partition label | `SHARE` (unchanged) |
| Hostname | `RETROGAMERSMEXICO` |
| Version string | `1.0` (ES footer = `<about.info> V<version> <date>`; the RGM name comes from `about.info`) |
| Splash video | trimmed to ~15 s keeping the final RGM card, H.264 `yuv420p` 1080p 30 fps AAC |
| Online updates | disabled (`updates.enabled=0`) so ES never offers to overwrite the build with upstream Batocera |
| Theme | Carbon, upstream unchanged; RGM branding applied to ES built-in splash resources |

## Components

### 1. Boot video splash (`package/batocera/core/batocera-splash`)

- `Config.in`: add `BR2_PACKAGE_BATOCERA_TARGET_S905GEN3` to the `SPLASH_VIDEO_1080P30` group
  (H.264 1080p30 profile is the right class for this SoC; today it falls through to the
  HEVC 8-bit file meant for x86).
- `videos/splash-h264-1080p30.mp4`: replaced by the transcoded/trimmed RGM video.
  Encode: `-c:v libx264 -profile:v high -pix_fmt yuv420p -r 30 -crf 20 -c:a aac -b:a 128k -movflags +faststart`.
  Trim: cut from the original so the last ~15 s (ending on the RGM card) are kept, with a
  short audio fade-in at the cut.
- `images/logo.png`: replaced by `Castillo.png` downscaled to 1920×1080 (installed as
  `/usr/share/batocera/splash/boot-logo.png`).
- Version subtitle (`splash.srt`) keeps working unchanged; it will read `1.0 <date>`.
- The other three upstream videos are left in place (unused by this target).

### 2. U-Boot boot logo (`board/batocera/amlogic/s905gen3/tvbox-gen3/boot/boot-logo.bmp.gz`)

- Replace with `Castillo.png` converted to the same geometry/format as the current file
  (verify with `gzip -dc | file`: expected 24-bit BMP; keep identical width×height and bit
  depth so the vendor U-Boot accepts it), then gzip. `create-boot-script.sh` already copies it.

### 3. EmulationStation

Finding (plan phase): the Carbon theme at the pinned commit contains no Batocera-branded
asset of its own. The only Batocera logo the user sees inside ES is the built-in resource
`resources/logo.png` (1920×1080), which Carbon's `_splash.xml` shows as the splash
background via `:/logo.png`. Therefore Carbon stays upstream (no vendoring) and the
branding is done at the ES package level:

- `package/batocera/emulationstation/batocera-emulationstation/rgm/logo.png`:
  `Castillo.png` downscaled to 1920×1080. Installed over
  `/usr/share/emulationstation/resources/logo.png` by a new post-install hook
  `BATOCERA_EMULATIONSTATION_RGM_BRANDING` in `batocera-emulationstation.mk`.
- `package/batocera/emulationstation/batocera-emulationstation/rgm/splash.svg`:
  copy of `RGM-bco.svg` (white logo, transparent). Installed over
  `/usr/share/emulationstation/resources/splash.svg` (720×720 fallback splash used when a
  theme has no splash view) by the same hook.
- `package/batocera/emulationstation/batocera-emulationstation/rgm/about.info`: text
  `RETRO GAMERS MEXICO`, installed to `/usr/share/emulationstation/about.info` by the same
  hook. `ApiSystem::getApplicationName()` returns this file's content, and `GuiMenu` then
  renders the main-menu footer as `RETRO GAMERS MEXICO V1.0 <date>` instead of
  `BATOCERA.LINUX ES V…`.
- No C++ patch, no theme edit. `es-theme-carbon.mk` unchanged.

### 4. System identity

- `package/batocera/core/batocera-system/batocera-system.mk`: `BATOCERA_SYSTEM_VERSION = 1.0`.
- `package/batocera/core/batocera-system/batocera.conf`:
  `system.hostname=RETROGAMERSMEXICO`, `updates.enabled=0`.
- `board/batocera/fsoverlay/etc/profile.d/30-welcome.sh`: ASCII banner → "RETRO GAMERS MEXICO",
  drop the two `batocera-check-updates` hint lines.
- `board/batocera/fsoverlay/etc/profile.d/40-prompt.sh`: window title `BATOCERA - $PWD` → `RGM - $PWD`.

### 5. Boot partition label `RETROGAMERS`

| File | Change |
|---|---|
| `board/batocera/amlogic/s905gen3/tvbox-gen3/genimage.cfg` | `-n BATOCERA` → `-n RETROGAMERS` |
| `board/batocera/amlogic/s905gen3/tvbox-gen3/boot/uEnv.txt` | `label=BATOCERA` → `label=RETROGAMERS` |
| `package/batocera/core/batocera-scripts/scripts/batocera-storage-manager` | regex `^(SHARE\|BATOCERA)$` → `^(SHARE\|BATOCERA\|RETROGAMERS)$` |
| `package/batocera/core/batocera-scripts/scripts/batocera-install-internal` | name check accepts `RETROGAMERS`; `mkfs.vfat -n RETROGAMERS` |

`genimage.cfg` and `uEnv.txt` must always agree, otherwise the initramfs waits forever for
`LABEL=…`. Other boards' `label=BATOCERA` lines are not touched.

### 6. PS3 clone controllers (BlueZ)

User-supplied `fake-ps3.patch` (BlueZ 5.61) makes cable pairing accept any pad with Sony's
VID/PID `054c:0268` regardless of its reported name. Batocera builds BlueZ 5.84 and already
carries `board/batocera/patches/bluez5_utils/001-trust-sixaxis.patch` and
`002-input-sixaxis.patch` (adds the "GUO HUA PS3 GamePad" name). The patch is rebased as
`003-sixaxis-clone-fallback.patch`: after the name-matching loop in
`profiles/input/sixaxis.h::get_pairing()`, return `&devices[0]` (reference Sixaxis entry)
for `054c:0268`. Index 0 is used instead of the original `devices[1]` because the table
order differs in 5.84. `BR2_GLOBAL_PATCH_DIR` already includes `board/batocera/patches`.

### 7. Not changed

- `SHARE` label, `/userdata`, `/boot` layout, package/config names, `batocera-*` command names.
- Other strings hard-coded inside the ES binary (menu entries such as "BATOCERA SPLASH IMAGE").
- Kernel, emulators, drivers.

## Build

```
git submodule update --init buildroot
make s905gen3-build            # Docker; first run takes hours, ~60–80 GB disk
```
Output: `output/s905gen3/images/batocera/images/s905gen3/batocera-s905gen3-*.img.gz`.

Commits on branch `rgm`, one per component (splash video, splash image, U-Boot logo,
ES splash, identity, partition label, BlueZ patch).

## Verification

Before building:
- `ffprobe` on the new video: `yuv420p`, 1920×1080, ≤ 16 s, h264 + aac.
- `gzip -dc boot-logo.bmp.gz | file -` matches the original's geometry/depth.
- `grep -c RETROGAMERS` on the four label files = expected hits; `uEnv.txt` and `genimage.cfg` agree.
- `make s905gen3-config` completes with no Kconfig warnings about the splash group.

After building / flashing an SD:
- Power-on sequence: RGM U-Boot logo → RGM video → RGM "CARGANDO…" ES splash → Carbon menu.
- `hostname` = `RETROGAMERSMEXICO`; ES main-menu footer reads `RETRO GAMERS MEXICO V1.0 <date>`.
- `blkid` on the SD shows `LABEL="RETROGAMERS"` for the boot partition; system boots to ES.
- Plugging a USB stick still auto-mounts (storage-manager regex OK).
- ES does not prompt for an update.
- A PS3 clone pad pairs over USB cable and then works over Bluetooth.
