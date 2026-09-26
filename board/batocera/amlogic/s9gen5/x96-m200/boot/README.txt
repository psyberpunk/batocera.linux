Batocera for Amlogic S905X5M (S7D) tv boxes - tested on X96 M200

First boot from this SD card:
  - with Android running: adb shell reboot update
  - or power off, keep the reset button (inside the AV jack) pressed,
    plug the power and release after ~5 seconds.
The aml_autoscript on this card makes the box try the SD/USB card first on
every boot and fall back to Android when there is no card.

The reset button boots recovery.img (from CoreELEC), which sets the boot
order from aml_autoscript and reboots into Batocera.

Device tree: dtb.img is a copy of device_trees/s7d_s905x5m_2g_1gbit_s905a.dtb
(the X96 M200 is an S905A: its CPU speed tables go up to 2.5 GHz).
If the box does not boot or has no network, replace dtb.img with another
file from device_trees/ (s7d_s905a_bm221.dtb is the X96 M200 board id).
