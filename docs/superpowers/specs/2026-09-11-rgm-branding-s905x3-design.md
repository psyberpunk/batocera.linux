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
| `RGM-bco.svg` / `RGM-bco.png` (white, transparent) | logo inside the Carbon theme (dark background) |
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
| Version string | `RGM-1.0` |
| Splash video | trimmed to ~15 s keeping the final RGM card, H.264 `yuv420p` 1080p 30 fps AAC |
| Online updates | disabled (`updates.enabled=0`) so ES never offers to overwrite the build with upstream Batocera |
| Theme | Carbon, vendored locally, only the Batocera logo swapped for RGM; colours unchanged |

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
- Version subtitle (`splash.srt`) keeps working unchanged; it will read `RGM-1.0 <date>`.
- The other three upstream videos are left in place (unused by this target).

### 2. U-Boot boot logo (`board/batocera/amlogic/s905gen3/tvbox-gen3/boot/boot-logo.bmp.gz`)

- Replace with `Castillo.png` converted to the same geometry/format as the current file
  (verify with `gzip -dc | file`: expected 24-bit BMP; keep identical width×height and bit
  depth so the vendor U-Boot accepts it), then gzip. `create-boot-script.sh` already copies it.

### 3. EmulationStation

#### 3a. Theme (`package/batocera/emulationstation/es-theme-carbon`)

- Switch from `github` download to a vendored snapshot: `es-theme-carbon.mk` gets
  `ES_THEME_CARBON_SITE_METHOD = local`, `ES_THEME_CARBON_SITE = $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulationstation/es-theme-carbon/src`.
- `src/` = checkout of upstream commit `b921e1734d88d6bc7b9e8cb97dd8f8b91ba2058a` with the
  Batocera logo asset(s) replaced by `RGM-bco.svg` (same filename(s) and viewBox aspect so
  every view that references them keeps its layout). Exact files identified at implementation
  by grepping the theme for the logo references (`art/logo*.svg` and any `batocera` named art).
- Theme `theme.xml` `<name>`/description strings untouched.

#### 3b. ES splash (`package/batocera/emulationstation/batocera-emulationstation`)

- ES shows its own splash (`resources/splash.svg`) while loading gamelists (no `--no-splash`
  on this target). Replace it with `Castillo.png`:
  - install `splash.png` (1920×1080) into `/usr/share/emulationstation/resources/`;
  - add a small patch to the ES sources changing the splash resource path from
    `:/splash.svg` to `:/splash.png` (exact file confirmed at implementation; expected
    `es-core/src/Window.cpp` or equivalent). If batocera-ES already supports a raster splash
    or a theme-driven splash view, prefer that and skip the patch.

### 4. System identity

- `package/batocera/core/batocera-system/batocera-system.mk`: `BATOCERA_SYSTEM_VERSION = RGM-1.0`.
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

### 6. Not changed

- `SHARE` label, `/userdata`, `/boot` layout, package/config names, `batocera-*` command names.
- Strings hard-coded inside the ES binary (e.g. "batocera.linux" in some menus).
- Kernel, emulators, drivers.

## Build

```
git submodule update --init buildroot
make s905gen3-build            # Docker; first run takes hours, ~60–80 GB disk
```
Output: `output/s905gen3/images/batocera/images/s905gen3/batocera-s905gen3-*.img.gz`.

Commits on branch `rgm`, one per component (splash video, U-Boot logo, theme, ES splash,
identity, partition label).

## Verification

Before building:
- `ffprobe` on the new video: `yuv420p`, 1920×1080, ≤ 16 s, h264 + aac.
- `gzip -dc boot-logo.bmp.gz | file -` matches the original's geometry/depth.
- `grep -c RETROGAMERS` on the four label files = expected hits; `uEnv.txt` and `genimage.cfg` agree.
- `make s905gen3-config` completes with no Kconfig warnings about the splash group.

After building / flashing an SD:
- Power-on sequence: RGM U-Boot logo → RGM video → RGM "CARGANDO…" ES splash → Carbon with RGM logo.
- `hostname` = `RETROGAMERSMEXICO`; ES → System settings shows `RGM-1.0`.
- `blkid` on the SD shows `LABEL="RETROGAMERS"` for the boot partition; system boots to ES.
- Plugging a USB stick still auto-mounts (storage-manager regex OK).
- ES does not prompt for an update.
