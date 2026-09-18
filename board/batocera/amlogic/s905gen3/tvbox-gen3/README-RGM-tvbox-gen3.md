# RGM — S905X3 tvbox-gen3: DTB, Bluetooth y mandos PS3 clone

> Rama `rgm` de `psyberpunk/batocera.linux`. Personalización RETRO GAMERS MEXICO
> para cajas TV S905X3 (tvbox-gen3). Documento de los cambios de hardware:
> device tree, Bluetooth y emparejamiento de mandos PS3 clon (SHANWAN / GUO HUA).

---

## 0. ⚠️ DTB QUE FUNCIONA — leer antes de flashear

**`FDT=/boot/meson-sm1-h96-max.dtb`** (default en `tvbox-gen3/boot/uEnv.txt` desde 2026-09-18).

Verificado en caja **AMedia X96 Max+** (S905X3, módulo WiFi/BT **AP6335 = BCM4335**,
Ethernet **RGMII gigabit**): con `h96-max.dtb` funcionan **cable de red + Bluetooth**
a la vez (mandos PS3 clon emparejan y reconectan). Es el dtb *upstream* sin tocar
(md5 `8fc8b75ab0402a452832077fcafdcb3a`).

Matriz de lo probado en esa caja (2026-09-18, imagen `20260918`):

| dtb | Ethernet | WiFi | BT (UART) | Veredicto |
|-----|----------|------|-----------|-----------|
| `meson-sm1-h96-max` | ✅ RGMII | no probado (`wifi.enabled=0`) | ✅ | **USAR ESTE** |
| `meson-sm1-tvbox-gen3` (base X96 Air, RMII PHY ext.) | ❌ `deferred probe` | ❌ | ✅ | no |
| `meson-sm1-tvbox-gen3-intphy` (base X96 Max+, PHY interno) | ❌ `deferred probe` | ✅ | ❌ antes / ✅ tras fix nodo BT | no (sin ethernet) |

Los otros dos dtb siguen en `/boot` por si aparece otra variante de caja. Para
cambiar: editar `uEnv.txt` en la partición FAT `RETROGAMERS` de la microSD,
línea `FDT=`, y reiniciar. No hace falta reflashear.

> Regla: si una caja nueva no levanta red/BT, **primero** probar `h96-max`,
> luego `tvbox-gen3`, luego `tvbox-gen3-intphy`. Recoger `dmesg` con el
> `custom.sh` de diagnóstico de la sección 5.

---

## 1. Resumen

La imagen base Batocera para `s905gen3` no traía un dtb propio para estas cajas
y arrastraba dos problemas en el kernel 6.6:

1. El dtb `meson-sm1-x96-air` deja el **Bluetooth UART apagado**, así que la caja
   solo levantaba BT arrancando con `meson-sm1-h96-max.dtb`. En la primera caja
   probada ese dtb rompía el WiFi; en la X96 Max+ del 2026-09-18 `h96-max` es
   justamente el que funciona (ver sección 0).
2. `hid-sony` en 6.6 aplica el *quirk* `SHANWAN_GAMEPAD` a los mandos que se
   llaman exactamente `SHANWAN PS3 GamePad`. Ese quirk manda el reporte de LED /
   rumble por el **canal de interrupción**, cosa que los clones PS3 de RGM
   rechazan por Bluetooth: los 4 LEDs parpadean en vez de fijar el número de
   jugador y el mando **se apaga solo 1–2 s** después de conectarse.

En EmuELEC (kernel **4.9**) esto nunca pasó porque 4.9 **no tiene** el quirk
SHANWAN: todos los clones `054C:0268` se tratan como Sixaxis oficial (reporte por
canal de control, `SET_REPORT`). De ahí que en EmuELEC sí emparejaran 4 mandos.

Estos cambios llevan al kernel 6.6 al mismo comportamiento que 4.9.

---

## 2. Cambios en la rama `rgm`

Todo vive en `board/batocera/amlogic/s905gen3/`:

| Commit | Archivo | Qué hace |
|--------|---------|----------|
| `1be3c95` | `linux_patches/003-add-tvbox-gen3-dts.patch` | Crea los dts `meson-sm1-tvbox-gen3` (base X96 Air + VDDCPU 721–1022 mV, PWM 1250) y `-intphy` (base X96 Max+ con PHY interno RMII). Recuperados del dtb binario original de la tarjeta. Los registra en el Makefile del kernel. |
| `47684bf` | `linux_patches/003-*` (dts) | Añade el nodo `&uart_A` con `bluetooth { compatible = "brcm,bcm43438-bt"; ... }` (igual que h96-max) al dtb `tvbox-gen3`, para que el BCM4335 levante por UART. Así **WiFi y BT funcionan a la vez** sin usar h96-max.dtb. |
| 2026-09-18 | `linux_patches/003-*` (dts `-intphy`) | Sobreescribe el nodo `&bluetooth` heredado de `x96-max-plus` (Realtek `rtl8822cs`, `status = "disabled"`) por `brcm,bcm43438-bt` + `status = "okay"`. Sin esto `intphy` nunca levantaba `hci` por UART. |
| `0d676b3` | `linux_patches/004-hid-sony-shanwan-bt-set-report.patch` | En `sony_probe`, **no aplica** el quirk `SHANWAN_GAMEPAD` cuando el mando trae `SIXAXIS_CONTROLLER_BT`. Sobre Bluetooth se comporta como Sixaxis oficial (como en 4.9); en USB se mantiene el quirk (ahí sí hace falta, evita rumble descontrolado). |

Además, en el board config y en el script de arranque:

- `configs/batocera-s905gen3.board` → los dos dtb nuevos añadidos a
  `BR2_LINUX_KERNEL_INTREE_DTS_NAME`.
- `tvbox-gen3/create-boot-script.sh` → copia los dtb `tvbox-gen3*` a `/boot`.
- `tvbox-gen3/boot/uEnv.txt` → `FDT=/boot/meson-sm1-h96-max.dtb` (antes
  `tvbox-gen3.dtb`; cambiado 2026-09-18, ver sección 0).

---

## 3. Resultado esperado tras recompilar y flashear

- Ethernet + Bluetooth operativos con `meson-sm1-h96-max.dtb` (default). WiFi +
  BT con `tvbox-gen3.dtb` en la primera caja probada.
- Los mandos PS3 clon (SHANWAN y GUO HUA) emparejan por cable y luego conectan
  por Bluetooth con **LED de jugador fijo** y **sin desconexión** a los pocos
  segundos. Verificado que varios conectan a la vez.
- Ya **no** hace falta renombrar los mandos a mano; el parche del kernel quita
  el quirk sobre BT para cualquier nombre.

---

## 4. Workaround en caliente (imagen sin recompilar todavía)

Si corres una imagen con el kernel 6.6 **sin** el parche `004`, el mismo efecto
se logra renombrando el mando en BlueZ para que no coincida con la cadena exacta
del quirk. En el mando ya emparejado:

```sh
A=/var/lib/bluetooth/$(ls /var/lib/bluetooth | grep :)
# cambiar el Name= del/los mando(s) SHANWAN a un nombre que NO sea
# exactamente "SHANWAN PS3 GamePad":
sed -i 's/^Name=SHANWAN PS3 GamePad.*/Name=Sony PLAYSTATION(R)3 Controller/' "$A"/<MAC>/info
/etc/init.d/S32bluetooth restart
batocera-bluetooth save   # persiste en /userdata/system/bluetooth
```

La única restricción en 6.6 es que el `Name=` no sea literal
`SHANWAN PS3 GamePad` ni `ShanWan PS(R) Ga\`epad`. Con el parche `004` esto ya
no es necesario.

---

## 5. Diagnóstico sin red (probar dtb 1 a 1)

Sin red no hay SSH. Se itera desde el PC con la microSD:

1. Copiar el script de abajo a `SHARE/system/custom.sh` (ext4, dueño root; si
   `sudo` no está disponible, usar docker:
   `docker run --rm -v /media/$USER/SHARE/system:/s -v $PWD:/src:ro alpine sh -c 'cp /src/custom.sh /s/ && chmod 755 /s/custom.sh'`).
2. Editar `FDT=` en `RETROGAMERS/uEnv.txt`, arrancar la caja ~1 min, apagar.
3. Leer `SHARE/system/diag/<dtb>-<fecha>.txt`: modelo, `ip link`, ids SDIO
   (`0x02d0:0x4335` = BCM4335), `hciconfig`, `lsmod`, `dmesg`.

```sh
#!/bin/sh
[ "$1" = "start" ] || exit 0
sleep 25
D=/userdata/system/diag; mkdir -p "$D"
DTB=$(grep -o 'FDT=.*' /boot/uEnv.txt | sed 's#.*/##; s#\.dtb##')
OUT="$D/${DTB}-$(date +%Y%m%d-%H%M%S).txt"
{
  echo "### model"; tr -d '\0' < /proc/device-tree/model; echo
  echo "### ip link"; ip link
  echo "### sdio"; for f in /sys/bus/sdio/devices/*; do echo "$f: $(cat $f/vendor):$(cat $f/device)"; done
  echo "### bt"; hciconfig -a
  echo "### lsmod"; lsmod
  echo "### dmesg"; dmesg
} > "$OUT" 2>&1
sync
```

Pistas en el log:
- `ff3f0000.ethernet: deferred probe pending` → el dtb no describe bien el PHY
  → probar otro dtb.
- Solo `hci0 Type: SDIO` con BD Address `00:00:...` → no hay nodo BT por UART
  en el dtb (es el `btsdio` falso).
- Mando USB como `Microsoft X-Box 360 pad` → está en modo Xbox; **no hace
  cable pairing**. Cambiar a modo PS3 antes de conectar el cable.

---

## 6. Recompilar

```sh
make s905gen3-build
```

Luego flashear la imagen resultante a la microSD (ver el `LEEME` de la carpeta
de respaldo para el `dd`). El número de jugador lo asigna Batocera por orden de
conexión, no por el nombre Bluetooth del mando.
