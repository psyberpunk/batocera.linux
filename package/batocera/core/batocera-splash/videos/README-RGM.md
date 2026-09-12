# RETRO GAMERS MEXICO splash video (not in this repository)

The RGM branding branch replaces `splash-h264-1080p30.mp4` with a custom
intro video that is **not** published here. This public branch keeps the
upstream Batocera video at that path so the build still works.

To build with the RGM intro, overwrite the file before running `make`:

    cp /path/to/your/splash-rgm.mp4 \
       package/batocera/core/batocera-splash/videos/splash-h264-1080p30.mp4

Required format (see `docs/superpowers/specs/2026-09-11-rgm-branding-s905x3-design.md`):
H.264 High profile, `yuv420p`, 1920x1080, 30 fps, AAC audio, `+faststart`,
about 15 s. Encode example:

    ffmpeg -i input.mp4 -c:v libx264 -profile:v high -pix_fmt yuv420p -r 30 -crf 20 \
      -c:a aac -b:a 128k -ac 2 -movflags +faststart splash-h264-1080p30.mp4
