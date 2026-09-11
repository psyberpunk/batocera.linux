# RGM Branding for S905X3 (tvbox-gen3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce a Batocera image for Amlogic S905X3 TV boxes branded RETRO GAMERS MEXICO from U-Boot logo to EmulationStation, with boot partition label `RETROGAMERS`.

**Architecture:** Batocera is a Buildroot external tree; every change is either a replaced binary asset inside a package/board directory or a one-line edit to a Makefile/Kconfig/shell file. No C++ is patched; the theme stays upstream. Assets are derived once from `~/iaapps/retrogamersmexico/` with ffmpeg/ImageMagick and committed into the tree.

**Tech Stack:** Buildroot (Docker build via `make s905gen3-build`), Kconfig, GNU Make, bash, ffmpeg, ImageMagick (`convert`), gzip.

**Spec:** `docs/superpowers/specs/2026-09-11-rgm-branding-s905x3-design.md`

## Global Constraints

- Target only: `s905gen3`, board dir `board/batocera/amlogic/s905gen3/tvbox-gen3`. Do not edit other boards.
- Boot partition label: `RETROGAMERS` (11 chars max, FAT32). Userdata label `SHARE` unchanged.
- Hostname: `RETROGAMERSMEXICO`. Version string: `1.0` (ES footer renders `<about.info> V<version> <date>`, so the name lives in `about.info`, not in the version). `updates.enabled=0`.
- Splash video: H.264 High, `yuv420p`, 1920×1080, 30 fps, AAC 128k, `+faststart`, ~15 s, ends on the RGM card.
- U-Boot logo must stay 1280×720, 24-bit BMP, gzip-compressed (vendor U-Boot expects the same geometry as the current file).
- Source assets (read-only): `~/iaapps/retrogamersmexico/{Castillo.png,RGM-bco.svg,retrogamersmexico.mp4}`.
- Work on branch `rgm`; one commit per task. Commit messages end with:
  ```
  Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01RKEkmYSW3qee8pxSFTtew4
  ```
- Never touch `label=BATOCERA` outside the tvbox-gen3 board dir; never rename packages, commands or `/userdata` paths.
- All commands run from `/home/retrogamex/batocera.linux` unless stated.

---

## File map

| Path | Task | Responsibility |
|---|---|---|
| `package/batocera/core/batocera-splash/videos/splash-h264-1080p30.mp4` | 1 | boot video played by mpv (replaced) |
| `package/batocera/core/batocera-splash/Config.in` | 1 | put S905GEN3 in the H.264 1080p30 group |
| `package/batocera/core/batocera-splash/images/logo.png` | 2 | `/usr/share/batocera/splash/boot-logo.png` (replaced) |
| `board/batocera/amlogic/s905gen3/tvbox-gen3/boot/boot-logo.bmp.gz` | 3 | U-Boot logo (replaced) |
| `package/batocera/emulationstation/batocera-emulationstation/rgm/logo.png` | 4 | ES splash background (new) |
| `package/batocera/emulationstation/batocera-emulationstation/rgm/splash.svg` | 4 | ES fallback splash (new) |
| `package/batocera/emulationstation/batocera-emulationstation/rgm/about.info` | 4 | ES application name shown in the main-menu footer (new) |
| `package/batocera/emulationstation/batocera-emulationstation/batocera-emulationstation.mk` | 4 | hook installing the three files above |
| `package/batocera/core/batocera-system/batocera-system.mk` | 5 | version string |
| `package/batocera/core/batocera-system/batocera.conf` | 5 | hostname, updates |
| `board/batocera/fsoverlay/etc/profile.d/30-welcome.sh` | 5 | SSH banner |
| `board/batocera/fsoverlay/etc/profile.d/40-prompt.sh` | 5 | terminal title |
| `board/batocera/amlogic/s905gen3/tvbox-gen3/genimage.cfg` | 6 | FAT label at image creation |
| `board/batocera/amlogic/s905gen3/tvbox-gen3/boot/uEnv.txt` | 6 | kernel cmdline `label=` |
| `package/batocera/core/batocera-scripts/scripts/batocera-storage-manager` | 6 | system-partition regex |
| `package/batocera/core/batocera-scripts/scripts/batocera-install-internal` | 6 | internal install label |

---

### Task 1: Boot video splash

**Files:**
- Modify: `package/batocera/core/batocera-splash/videos/splash-h264-1080p30.mp4` (binary replace)
- Modify: `package/batocera/core/batocera-splash/Config.in:56-68`

**Interfaces:**
- Consumes: `~/iaapps/retrogamersmexico/retrogamersmexico.mp4` (1920×1080, 15 fps, yuv444p, 32.47 s).
- Produces: `splash-h264-1080p30.mp4` selected by `batocera-splash.mk` when `BR2_PACKAGE_BATOCERA_SPLASH_VIDEO_1080P30=y`.

- [ ] **Step 1: Confirm the target currently falls through to the HEVC file (baseline)**

Run:
```bash
grep -n "S905GEN3" package/batocera/core/batocera-splash/Config.in || echo "not in any group"
```
Expected: `not in any group`

- [ ] **Step 2: Transcode + trim the video into the scratch dir**

Run:
```bash
S=/tmp/claude-1000/-home-retrogamex/f2289cce-87c4-458c-bff0-9314bde91d31/scratchpad
mkdir -p "$S/build"
ffmpeg -y -v error -ss 17.5 -i ~/iaapps/retrogamersmexico/retrogamersmexico.mp4 \
  -vf "fade=t=in:st=0:d=0.5,format=yuv420p" -af "afade=t=in:st=0:d=0.5" \
  -c:v libx264 -profile:v high -pix_fmt yuv420p -r 30 -crf 20 -preset slow \
  -c:a aac -b:a 128k -ac 2 -movflags +faststart \
  "$S/build/splash-h264-1080p30.mp4"
```
Expected: no output (success).

- [ ] **Step 3: Verify the encoded file**

Run:
```bash
S=/tmp/claude-1000/-home-retrogamex/f2289cce-87c4-458c-bff0-9314bde91d31/scratchpad
ffprobe -v error -show_entries stream=codec_name,profile,width,height,pix_fmt,r_frame_rate:format=duration -of default=nw=1 "$S/build/splash-h264-1080p30.mp4"
```
Expected (video stream): `codec_name=h264`, `profile=High`, `width=1920`, `height=1080`, `pix_fmt=yuv420p`, `r_frame_rate=30/1`; audio `codec_name=aac`; `duration=14.9…15.0`.

- [ ] **Step 4: Visually confirm the last frame is the RGM card**

Run:
```bash
S=/tmp/claude-1000/-home-retrogamex/f2289cce-87c4-458c-bff0-9314bde91d31/scratchpad
ffmpeg -y -v error -sseof -0.5 -i "$S/build/splash-h264-1080p30.mp4" -frames:v 1 -vf scale=480:-1 "$S/build/lastframe.png"
```
Then Read `$S/build/lastframe.png`. Expected: white card with "RETRO GAMERS MEXICO" text.

- [ ] **Step 5: Replace the file in the tree**

Run:
```bash
S=/tmp/claude-1000/-home-retrogamex/f2289cce-87c4-458c-bff0-9314bde91d31/scratchpad
cp "$S/build/splash-h264-1080p30.mp4" package/batocera/core/batocera-splash/videos/splash-h264-1080p30.mp4
git status --short package/batocera/core/batocera-splash/videos/
```
Expected: ` M package/batocera/core/batocera-splash/videos/splash-h264-1080p30.mp4`

- [ ] **Step 6: Add S905GEN3 to the 1080p30 H.264 group in Config.in**

Edit `package/batocera/core/batocera-splash/Config.in`. Replace:
```
   BR2_PACKAGE_BATOCERA_TARGET_RK3588  || \
   BR2_PACKAGE_BATOCERA_TARGET_RK3588_SDIO
config BR2_PACKAGE_BATOCERA_SPLASH_VIDEO_1080P30
```
with:
```
   BR2_PACKAGE_BATOCERA_TARGET_RK3588  || \
   BR2_PACKAGE_BATOCERA_TARGET_RK3588_SDIO || \
   BR2_PACKAGE_BATOCERA_TARGET_S905GEN3
config BR2_PACKAGE_BATOCERA_SPLASH_VIDEO_1080P30
```

- [ ] **Step 7: Verify the edit**

Run:
```bash
sed -n 56,69p package/batocera/core/batocera-splash/Config.in
```
Expected: the `if` block lists `…RK3588_SDIO || \` then `BR2_PACKAGE_BATOCERA_TARGET_S905GEN3` on its own line, followed by `config BR2_PACKAGE_BATOCERA_SPLASH_VIDEO_1080P30`.

- [ ] **Step 8: Commit**

```bash
git add package/batocera/core/batocera-splash/videos/splash-h264-1080p30.mp4 package/batocera/core/batocera-splash/Config.in
git commit -m "splash: RGM boot video for s905gen3 (h264 1080p30 group)

Replace the 1080p30 H.264 splash with the RETRO GAMERS MEXICO intro
(trimmed to ~15 s, yuv420p) and put S905GEN3 in that video group so the
TV-box build uses it instead of the x86 HEVC file.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RKEkmYSW3qee8pxSFTtew4"
```

---

### Task 2: Static splash image (`boot-logo.png`)

**Files:**
- Modify: `package/batocera/core/batocera-splash/images/logo.png` (binary replace)

**Interfaces:**
- Consumes: `~/iaapps/retrogamersmexico/Castillo.png` (8000×4500, alpha).
- Produces: `logo.png` 1920×1080 RGB (no alpha) → installed as `/usr/share/batocera/splash/boot-logo.png` by `BATOCERA_SPLASH_INSTALL_BOOT_LOGO`.

- [ ] **Step 1: Generate the 1920×1080 PNG**

Run:
```bash
S=/tmp/claude-1000/-home-retrogamex/f2289cce-87c4-458c-bff0-9314bde91d31/scratchpad
convert ~/iaapps/retrogamersmexico/Castillo.png -background black -alpha remove -alpha off \
  -resize 1920x1080 -strip "$S/build/castillo-1080.png"
identify "$S/build/castillo-1080.png"
```
Expected: `castillo-1080.png PNG 1920x1080 …` (8000×4500 is exactly 16:9, so no padding is needed).

- [ ] **Step 2: Replace the file and verify**

Run:
```bash
S=/tmp/claude-1000/-home-retrogamex/f2289cce-87c4-458c-bff0-9314bde91d31/scratchpad
cp "$S/build/castillo-1080.png" package/batocera/core/batocera-splash/images/logo.png
identify -format "%wx%h alpha=%A\n" package/batocera/core/batocera-splash/images/logo.png
```
Expected: `1920x1080 alpha=False` (or `Undefined`).

- [ ] **Step 3: Commit**

```bash
git add package/batocera/core/batocera-splash/images/logo.png
git commit -m "splash: RGM static boot logo image

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RKEkmYSW3qee8pxSFTtew4"
```

---

### Task 3: U-Boot boot logo

**Files:**
- Modify: `board/batocera/amlogic/s905gen3/tvbox-gen3/boot/boot-logo.bmp.gz` (binary replace)

**Interfaces:**
- Consumes: `~/iaapps/retrogamersmexico/Castillo.png`.
- Produces: gzip of a 1280×720 24-bit Windows BMP, copied verbatim to the boot partition by `create-boot-script.sh:25`.

- [ ] **Step 1: Record the current format (baseline)**

Run:
```bash
gzip -dc board/batocera/amlogic/s905gen3/tvbox-gen3/boot/boot-logo.bmp.gz | file -
```
Expected: `PC bitmap, Windows 95/NT4 and newer format, 1280 x 720 x 24`.

- [ ] **Step 2: Build the BMP**

Run:
```bash
S=/tmp/claude-1000/-home-retrogamex/f2289cce-87c4-458c-bff0-9314bde91d31/scratchpad
convert ~/iaapps/retrogamersmexico/Castillo.png -background black -alpha remove -alpha off \
  -resize 1280x720 -type TrueColor -define bmp:format=bmp3 -compress none "$S/build/boot-logo.bmp"
file "$S/build/boot-logo.bmp"
```
Expected: `PC bitmap, Windows 3.x format, 1280 x 720 x 24` (bmp3 = BITMAPINFOHEADER, which vendor U-Boot decodes; the original's "95/NT4" header is a superset — both are fine for U-Boot's `bmp display`).

- [ ] **Step 3: Gzip and replace**

Run:
```bash
S=/tmp/claude-1000/-home-retrogamex/f2289cce-87c4-458c-bff0-9314bde91d31/scratchpad
gzip -9 -n -c "$S/build/boot-logo.bmp" > board/batocera/amlogic/s905gen3/tvbox-gen3/boot/boot-logo.bmp.gz
gzip -t board/batocera/amlogic/s905gen3/tvbox-gen3/boot/boot-logo.bmp.gz && echo gzip-ok
gzip -dc board/batocera/amlogic/s905gen3/tvbox-gen3/boot/boot-logo.bmp.gz | file -
```
Expected: `gzip-ok` and `1280 x 720 x 24`.

- [ ] **Step 4: Commit**

```bash
git add board/batocera/amlogic/s905gen3/tvbox-gen3/boot/boot-logo.bmp.gz
git commit -m "tvbox-gen3: RGM U-Boot boot logo

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RKEkmYSW3qee8pxSFTtew4"
```

---

### Task 4: EmulationStation splash resources and application name

**Files:**
- Create: `package/batocera/emulationstation/batocera-emulationstation/rgm/logo.png`
- Create: `package/batocera/emulationstation/batocera-emulationstation/rgm/splash.svg`
- Create: `package/batocera/emulationstation/batocera-emulationstation/rgm/about.info`
- Modify: `package/batocera/emulationstation/batocera-emulationstation/batocera-emulationstation.mk:244-251`

**Interfaces:**
- Consumes: `castillo-1080.png` from Task 2 (`$S/build/castillo-1080.png`), `~/iaapps/retrogamersmexico/RGM-bco.svg`.
- Produces: post-install hook `BATOCERA_EMULATIONSTATION_RGM_BRANDING` that overwrites `/usr/share/emulationstation/resources/logo.png` and `/usr/share/emulationstation/resources/splash.svg`, and installs `/usr/share/emulationstation/about.info`. Carbon's `_splash.xml` references `:/logo.png`, so the ES splash shows Castillo without any theme change. `ApiSystem::getApplicationName()` (es-app/src/ApiSystem.cpp:190) returns the content of `about.info` when present; `GuiMenu.cpp:276` then renders the footer as `<name> V<version><date>` instead of `BATOCERA.LINUX ES V…`.

- [ ] **Step 1: Add the assets**

Run:
```bash
S=/tmp/claude-1000/-home-retrogamex/f2289cce-87c4-458c-bff0-9314bde91d31/scratchpad
D=package/batocera/emulationstation/batocera-emulationstation/rgm
mkdir -p "$D" "$S/build"
# regenerate if Task 2's scratch file is gone (same command as Task 2 Step 1)
[ -f "$S/build/castillo-1080.png" ] || convert ~/iaapps/retrogamersmexico/Castillo.png -background black -alpha remove -alpha off -resize 1920x1080 -strip "$S/build/castillo-1080.png"
cp "$S/build/castillo-1080.png" "$D/logo.png"
cp ~/iaapps/retrogamersmexico/RGM-bco.svg "$D/splash.svg"
printf 'RETRO GAMERS MEXICO' > "$D/about.info"
identify "$D/logo.png" "$D/splash.svg"
cat "$D/about.info"; echo
```
Expected: `logo.png PNG 1920x1080`, `splash.svg SVG <square dims>`, `RETRO GAMERS MEXICO` (no trailing newline needed; ES strips CR/LF anyway).

- [ ] **Step 2: Add the hook to the .mk**

Edit `package/batocera/emulationstation/batocera-emulationstation/batocera-emulationstation.mk`. Replace:
```
BATOCERA_EMULATIONSTATION_POST_INSTALL_TARGET_HOOKS += BATOCERA_EMULATIONSTATION_RESOURCES
BATOCERA_EMULATIONSTATION_POST_INSTALL_TARGET_HOOKS += BATOCERA_EMULATIONSTATION_BOOT

$(eval $(cmake-package))
```
with:
```
BATOCERA_EMULATIONSTATION_POST_INSTALL_TARGET_HOOKS += BATOCERA_EMULATIONSTATION_RESOURCES
BATOCERA_EMULATIONSTATION_POST_INSTALL_TARGET_HOOKS += BATOCERA_EMULATIONSTATION_BOOT

# RETRO GAMERS MEXICO branding: override the built-in splash resources
# (:/logo.png is what the Carbon splash view displays)
define BATOCERA_EMULATIONSTATION_RGM_BRANDING
	$(INSTALL) -m 0644 -D $(BATOCERA_EMULATIONSTATION_PKGDIR)/rgm/logo.png \
		$(TARGET_DIR)/usr/share/emulationstation/resources/logo.png
	$(INSTALL) -m 0644 -D $(BATOCERA_EMULATIONSTATION_PKGDIR)/rgm/splash.svg \
		$(TARGET_DIR)/usr/share/emulationstation/resources/splash.svg
	$(INSTALL) -m 0644 -D $(BATOCERA_EMULATIONSTATION_PKGDIR)/rgm/about.info \
		$(TARGET_DIR)/usr/share/emulationstation/about.info
endef
BATOCERA_EMULATIONSTATION_POST_INSTALL_TARGET_HOOKS += BATOCERA_EMULATIONSTATION_RGM_BRANDING

$(eval $(cmake-package))
```
The hook is appended after `BATOCERA_EMULATIONSTATION_RESOURCES`, so it runs after the upstream resources are installed and wins.

- [ ] **Step 3: Verify Make syntax (tabs, hook order)**

Run:
```bash
grep -n "RGM_BRANDING" package/batocera/emulationstation/batocera-emulationstation/batocera-emulationstation.mk
grep -nP "^\t\$\(INSTALL\) -m 0644 -D \$\(BATOCERA_EMULATIONSTATION_PKGDIR\)/rgm/" package/batocera/emulationstation/batocera-emulationstation/batocera-emulationstation.mk | wc -l
```
Expected: 3 lines mentioning `RGM_BRANDING` (define, endef is separate, hook append) and `3` recipe lines starting with a real tab.

- [ ] **Step 4: Commit**

```bash
git add package/batocera/emulationstation/batocera-emulationstation/rgm package/batocera/emulationstation/batocera-emulationstation/batocera-emulationstation.mk
git commit -m "emulationstation: RGM splash resources and app name

Override resources/logo.png (shown by the Carbon splash view) and the
resources/splash.svg fallback with RETRO GAMERS MEXICO artwork, and
install about.info so the main-menu footer reads RETRO GAMERS MEXICO
instead of BATOCERA.LINUX ES.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RKEkmYSW3qee8pxSFTtew4"
```

---

### Task 5: System identity

**Files:**
- Modify: `package/batocera/core/batocera-system/batocera-system.mk:9`
- Modify: `package/batocera/core/batocera-system/batocera.conf:104,228`
- Modify: `board/batocera/fsoverlay/etc/profile.d/30-welcome.sh`
- Modify: `board/batocera/fsoverlay/etc/profile.d/40-prompt.sh`

**Interfaces:**
- Produces: `/usr/share/batocera/batocera.version` = `1.0 <date>`; splash subtitle `1.0 <date>`; ES footer `RETRO GAMERS MEXICO V1.0 <date>`; default `system.hostname=RETROGAMERSMEXICO`; `updates.enabled=0`.

- [ ] **Step 1: Version string**

Edit `package/batocera/core/batocera-system/batocera-system.mk`. Replace:
```
BATOCERA_SYSTEM_VERSION = 44-dev
```
with:
```
BATOCERA_SYSTEM_VERSION = 1.0
```

- [ ] **Step 2: Hostname and updates in batocera.conf**

Edit `package/batocera/core/batocera-system/batocera.conf`. Replace:
```
system.hostname=BATOCERA
```
with:
```
system.hostname=RETROGAMERSMEXICO
```
and replace:
```
updates.enabled=1
```
with:
```
updates.enabled=0
```

- [ ] **Step 3: Welcome banner**

Overwrite `board/batocera/fsoverlay/etc/profile.d/30-welcome.sh` with:
```bash
# Add RETRO GAMERS MEXICO banner, sourcing of $HOME/.bashrc can be added to $HOME/.profile
echo '
  ____  _____ _____ ____   ___     ____    _    __  __ _____ ____  ____
 |  _ \| ____|_   _|  _ \ / _ \   / ___|  / \  |  \/  | ____|  _ \/ ___|
 | |_) |  _|   | |  | |_) | | | | | |  _  / _ \ | |\/| |  _| | |_) \___ \
 |  _ <| |___  | |  |  _ <| |_| | | |_| |/ ___ \| |  | | |___|  _ < ___) |
 |_| \_\_____| |_|  |_| \_\\___/   \____/_/   \_\_|  |_|_____|_| \_\____/
                          M  E  X  I  C  O
'
echo
batocera-info 2>/dev/null
echo "OS version: $(batocera-version)"
echo
```
(The two `batocera-check-updates` hint lines are dropped because updates are disabled.)

- [ ] **Step 4: Prompt title**

Edit `board/batocera/fsoverlay/etc/profile.d/40-prompt.sh`. Replace:
```
    PS1='\[\e]2;BATOCERA - $PWD\a\][\u@\h $(p=${PWD/#"$HOME"/~};((${#p}>30))&&echo "${p::10}…${p:(-19)}"||echo "\w")]\$ '
```
with:
```
    PS1='\[\e]2;RGM - $PWD\a\][\u@\h $(p=${PWD/#"$HOME"/~};((${#p}>30))&&echo "${p::10}…${p:(-19)}"||echo "\w")]\$ '
```

- [ ] **Step 5: Verify**

Run:
```bash
grep -n "^BATOCERA_SYSTEM_VERSION" package/batocera/core/batocera-system/batocera-system.mk
grep -n "^system.hostname=\|^updates.enabled=" package/batocera/core/batocera-system/batocera.conf
bash -n board/batocera/fsoverlay/etc/profile.d/30-welcome.sh && bash board/batocera/fsoverlay/etc/profile.d/30-welcome.sh 2>/dev/null | head -8
grep -c "RGM - " board/batocera/fsoverlay/etc/profile.d/40-prompt.sh
```
Expected: `BATOCERA_SYSTEM_VERSION = 1.0`; `system.hostname=RETROGAMERSMEXICO`; `updates.enabled=0`; the banner prints 6 art lines without shell errors; `1`.

- [ ] **Step 6: Commit**

```bash
git add package/batocera/core/batocera-system/batocera-system.mk package/batocera/core/batocera-system/batocera.conf board/batocera/fsoverlay/etc/profile.d/30-welcome.sh board/batocera/fsoverlay/etc/profile.d/40-prompt.sh
git commit -m "system: RGM identity (version, hostname, banner, updates off)

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RKEkmYSW3qee8pxSFTtew4"
```

---

### Task 6: Boot partition label `RETROGAMERS`

**Files:**
- Modify: `board/batocera/amlogic/s905gen3/tvbox-gen3/genimage.cfg:3`
- Modify: `board/batocera/amlogic/s905gen3/tvbox-gen3/boot/uEnv.txt:4`
- Modify: `package/batocera/core/batocera-scripts/scripts/batocera-storage-manager:402`
- Modify: `package/batocera/core/batocera-scripts/scripts/batocera-install-internal:108,224`

**Interfaces:**
- Produces: FAT partition labelled `RETROGAMERS`; kernel cmdline `label=RETROGAMERS` (the initramfs `init:42` turns this into `mount LABEL=RETROGAMERS`).

- [ ] **Step 1: genimage.cfg**

Edit `board/batocera/amlogic/s905gen3/tvbox-gen3/genimage.cfg`. Replace:
```
                extraargs = "-F 32 -n BATOCERA"
```
with:
```
                extraargs = "-F 32 -n RETROGAMERS"
```

- [ ] **Step 2: uEnv.txt**

Edit `board/batocera/amlogic/s905gen3/tvbox-gen3/boot/uEnv.txt`. Replace:
```
APPEND=label=BATOCERA rootwait quiet loglevel=0 console=tty3 console=ttyAML0,115200n8 vt.global_cursor_default=0 video=Composite-1:d
```
with:
```
APPEND=label=RETROGAMERS rootwait quiet loglevel=0 console=tty3 console=ttyAML0,115200n8 vt.global_cursor_default=0 video=Composite-1:d
```

- [ ] **Step 3: storage-manager regex**

Edit `package/batocera/core/batocera-scripts/scripts/batocera-storage-manager`. Replace:
```
    if [[ "$label" =~ ^(SHARE|BATOCERA)$ ]] && is_system_disk "$parent"; then
```
with:
```
    if [[ "$label" =~ ^(SHARE|BATOCERA|RETROGAMERS)$ ]] && is_system_disk "$parent"; then
```

- [ ] **Step 4: install-internal**

Edit `package/batocera/core/batocera-scripts/scripts/batocera-install-internal`. Replace:
```
  if [[ "$name" == "BATOCERA" || "$name" == "SHARE" ]]; then
```
with:
```
  if [[ "$name" == "BATOCERA" || "$name" == "RETROGAMERS" || "$name" == "SHARE" ]]; then
```
and replace:
```
mkfs.vfat -F 32 -n BATOCERA "${BT_PART_DEV}" &>/dev/null
```
with:
```
mkfs.vfat -F 32 -n RETROGAMERS "${BT_PART_DEV}" &>/dev/null
```

- [ ] **Step 5: Verify agreement and syntax**

Run:
```bash
grep -n "RETROGAMERS" board/batocera/amlogic/s905gen3/tvbox-gen3/genimage.cfg board/batocera/amlogic/s905gen3/tvbox-gen3/boot/uEnv.txt package/batocera/core/batocera-scripts/scripts/batocera-storage-manager package/batocera/core/batocera-scripts/scripts/batocera-install-internal | wc -l
grep -c "BATOCERA" board/batocera/amlogic/s905gen3/tvbox-gen3/genimage.cfg board/batocera/amlogic/s905gen3/tvbox-gen3/boot/uEnv.txt
bash -n package/batocera/core/batocera-scripts/scripts/batocera-storage-manager && bash -n package/batocera/core/batocera-scripts/scripts/batocera-install-internal && echo syntax-ok
echo -n RETROGAMERS | wc -c
```
Expected: `5`; both board files report `0`; `syntax-ok`; `11`.

- [ ] **Step 6: Commit**

```bash
git add board/batocera/amlogic/s905gen3/tvbox-gen3/genimage.cfg board/batocera/amlogic/s905gen3/tvbox-gen3/boot/uEnv.txt package/batocera/core/batocera-scripts/scripts/batocera-storage-manager package/batocera/core/batocera-scripts/scripts/batocera-install-internal
git commit -m "tvbox-gen3: boot partition label RETROGAMERS

genimage.cfg and uEnv.txt must agree (initramfs mounts by LABEL=).
storage-manager and install-internal learn the new label so the boot
partition is still treated as a system partition.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RKEkmYSW3qee8pxSFTtew4"
```

---

### Task 7: Configure and build the image

**Files:** none modified (build output goes to `output/s905gen3/`, git-ignored).

**Interfaces:**
- Consumes: everything above.
- Produces: `output/s905gen3/images/batocera/images/s905gen3/batocera-s905gen3-*.img.gz`.

- [ ] **Step 1: Fetch the Buildroot submodule**

Run:
```bash
git submodule update --init buildroot 2>&1 | tail -2
ls buildroot | head -3
```
Expected: `Makefile`, `package/`, … present in `buildroot/`.

- [ ] **Step 2: Docker image + config (fast, catches Kconfig mistakes)**

Run:
```bash
make s905gen3-config 2>&1 | tail -15
```
Expected: ends without `error`/`warning: … undefined symbol`; `output/s905gen3/.config` exists.

- [ ] **Step 3: Confirm the splash group took effect**

Run:
```bash
grep -n "BATOCERA_SPLASH_VIDEO\|BATOCERA_SPLASH_MPV=" output/s905gen3/.config
```
Expected: `BR2_PACKAGE_BATOCERA_SPLASH_VIDEO_1080P30=y` and `BR2_PACKAGE_BATOCERA_SPLASH_MPV=y`. No `HEVC_1080P60=y`.

- [ ] **Step 4: Full build (background, hours)**

Run:
```bash
make s905gen3-build > /home/retrogamex/rgm-brand/build-s905gen3.log 2>&1
```
Run in background; poll `tail -3 /home/retrogamex/rgm-brand/build-s905gen3.log`. Expected end of log: genimage lines and no `make: *** … Error`.

- [ ] **Step 5: Verify the produced image**

Run:
```bash
IMG=$(ls output/s905gen3/images/batocera/images/s905gen3/batocera-s905gen3-*.img.gz | head -1); echo "$IMG"
gzip -dc "$IMG" > /home/retrogamex/rgm-brand/rgm-s905gen3.img
sudo blkid /home/retrogamex/rgm-brand/rgm-s905gen3.img 2>/dev/null; sudo losetup -Pf --show /home/retrogamex/rgm-brand/rgm-s905gen3.img
```
Then with the loop device `$LOOP` printed by `losetup`:
```bash
sudo blkid ${LOOP}p1 ${LOOP}p2
mkdir -p /tmp/rgmboot && sudo mount -o ro ${LOOP}p1 /tmp/rgmboot
grep label= /tmp/rgmboot/uEnv.txt; gzip -dc /tmp/rgmboot/boot-logo.bmp.gz | file -
sudo umount /tmp/rgmboot; sudo losetup -d $LOOP
```
Expected: `p1: LABEL="RETROGAMERS" TYPE="vfat"`, `p2: LABEL="SHARE" TYPE="ext4"`; `label=RETROGAMERS`; BMP `1280 x 720 x 24`.

- [ ] **Step 6: Inspect the rootfs (squashfs) for the branding files**

Run:
```bash
cd /tmp && rm -rf rgmroot && sudo unsquashfs -q -d rgmroot -f /tmp/rgmboot/boot/batocera usr/share/batocera/batocera.version usr/share/batocera/splash usr/share/emulationstation/resources/logo.png usr/share/emulationstation/about.info usr/share/batocera/datainit/system/batocera.conf 2>/dev/null
cat rgmroot/usr/share/batocera/batocera.version
ls -la rgmroot/usr/share/batocera/splash/
ffprobe -v error -show_entries stream=pix_fmt,width -of default=nw=1 rgmroot/usr/share/batocera/splash/splash.mp4
identify rgmroot/usr/share/emulationstation/resources/logo.png
cat rgmroot/usr/share/emulationstation/about.info; echo
grep "^system.hostname=\|^updates.enabled=" rgmroot/usr/share/batocera/datainit/system/batocera.conf
cd /home/retrogamex/batocera.linux
```
(Mount `${LOOP}p1` again first if it was unmounted.) Expected: `1.0 <date>`; `splash.mp4` + `boot-logo.png` + `splash.srt`; `pix_fmt=yuv420p`, `width=1920`; `logo.png PNG 1920x1080`; `about.info` = `RETRO GAMERS MEXICO`; `system.hostname=RETROGAMERSMEXICO`, `updates.enabled=0`.

---

### Task 8: Flash and verify on the TV box (manual)

**Files:** none.

- [ ] **Step 1: Flash the SD card**

Identify the card with `lsblk` (must NOT be `sda`, `nvme*`, or the `RECALBOX` card unless intended), then:
```bash
sudo dd if=/home/retrogamex/rgm-brand/rgm-s905gen3.img of=/dev/sdX bs=4M status=progress conv=fsync
```

- [ ] **Step 2: Set the DTB for the box**

Mount the `RETROGAMERS` partition and edit `uEnv.txt` `FDT=` to the box model (default `/boot/meson-sm1-h96-max.dtb`; X96 Max+ → `/boot/meson-sm1-x96-max-plus.dtb`, A95X F3 → `/boot/meson-sm1-a95xf3-air.dtb`). First boot may need the reset-button trick (see `boot/README.txt`).

- [ ] **Step 3: Observe the boot sequence**

Expected in order: Castillo U-Boot logo → RGM video (~15 s, ends on RGM card) → Castillo "CARGANDO…" ES splash with progress bar → Carbon menu.

- [ ] **Step 4: Check identity from ES / SSH**

- ES → Main menu: footer reads `RETRO GAMERS MEXICO V1.0 <date>`; System settings → Information shows `1.0 …`.
- `ssh root@<ip>` (password `linux`): banner shows RETRO GAMERS MEXICO; `hostname` → `RETROGAMERSMEXICO`; `blkid | grep -i retrogamers` shows the boot partition.
- Insert a USB stick: it auto-mounts under `/media` (storage-manager regex OK).
- ES shows no update prompt after boot.

- [ ] **Step 5: Record results**

Append a "Verified on device" note (model, DTB used, date, any issues) to `docs/superpowers/specs/2026-09-11-rgm-branding-s905x3-design.md` and commit:
```bash
git add docs/superpowers/specs/2026-09-11-rgm-branding-s905x3-design.md
git commit -m "docs: RGM s905gen3 on-device verification notes

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RKEkmYSW3qee8pxSFTtew4"
```
