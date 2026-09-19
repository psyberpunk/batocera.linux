# RGM — Mandos PS3 clon por Bluetooth (SHANWAN / GUO HUA) en S905X3

> Guía completa para dejar funcionando los mandos PS3 clon por Bluetooth en la
> caja S905X3 (tvbox-gen3), tanto en **Batocera rgm** como reproduciéndolo en
> **EmuELEC**. Incluye la causa raíz, el arreglo permanente (parche de kernel) y
> el arreglo en caliente (sin recompilar). Redactado tras diagnosticar en vivo
> con `btmon` / `bluetoothd -d`.

Resultado verificado: **4 mandos PS3 clon conectados a la vez por Bluetooth, 0
desconexiones**, cada uno como joystick.

---

## 1. Hardware

- Caja TV **S905X3** (Amlogic sm1), board `s905gen3` / `tvbox-gen3`.
- Bluetooth/WiFi: **Broadcom BCM4335** (BT por UART `hci1`, WiFi por SDIO).
- Mandos: clones de DualShock 3, todos con **VID/PID `054C:0268`**. El nombre
  que reportan varía por firmware:
  - `SHANWAN PS3 GamePad`
  - `GUO HUA PS3 GamePad`
  - `PLAYSTATION(R)3Controller-ghic`, `Sony PLAYSTATION(R)3 Controller`, etc.
- Mando aparte **ShanWan ZD-V+** (`2563:0575` / `045e:028e`): por **cable** es
  Xbox360/DInput; por **Bluetooth** se presenta como clon PS3 (`054C:0268`).
  Por cable úsalo en modo **Xbox 360** (Batocera lo reconoce solo).

---

## 2. Causa raíz de que "el 2º mando se conecta y se apaga a 1-2 s"

`hid-sony` del kernel **6.6** (Batocera) aplica el *quirk* `SHANWAN_GAMEPAD` a
los mandos cuyo nombre es **exactamente** `SHANWAN PS3 GamePad` (o
`ShanWan PS(R) Ga`epad`). Ese quirk manda el reporte de LED/rumble por el
**canal de interrupción**. Los clones RGM **rechazan** eso por Bluetooth:

- los **4 LEDs parpadean** en vez de fijar el número de jugador, y
- el mando **se apaga solo ~1-2 s** después de conectar (HCI `0x13`, el propio
  mando corta el enlace).

El mando `GUO HUA` no sufría esto porque su nombre **no** es "SHANWAN PS3
GamePad", así que nunca tomaba el quirk.

**Por qué en EmuELEC sí funcionaban 4:** EmuELEC usa kernel **4.9**, que **no
tiene** el quirk `SHANWAN_GAMEPAD`. Todos los `054C:0268` se tratan como Sixaxis
oficial (LED por `SET_REPORT` en el canal de control). Ver la nota de EmuELEC:
bluez **5.72** + parche `fake-ps3` en `sixaxis.so` (eso es solo para el *cable
pairing*, no para el runtime).

Descartado que sea: el mando (mismo pad funciona en 4.9), la MAC, el "setup in
progress" de bluez (idéntico en 5.72 y 5.84), sniff mode, uhid vs HIDP.

---

## 3. Arreglo permanente (Batocera rgm) — parche de kernel

Commit `0d676b3`, archivo
`board/batocera/amlogic/s905gen3/linux_patches/004-hid-sony-shanwan-bt-set-report.patch`.

En `sony_probe`, **no** aplicar el quirk SHANWAN cuando el mando trae
`SIXAXIS_CONTROLLER_BT` (es decir, sobre Bluetooth). En USB se mantiene (ahí sí
hace falta: evita rumble descontrolado). Efecto: por BT los clones se comportan
como Sixaxis oficial, igual que en el kernel 4.9.

```diff
-	if (!strcmp(hdev->name, "SHANWAN PS3 GamePad") ||
-	    !strcmp(hdev->name, "ShanWan PS(R) Ga`epad"))
+	if ((!strcmp(hdev->name, "SHANWAN PS3 GamePad") ||
+	     !strcmp(hdev->name, "ShanWan PS(R) Ga`epad")) &&
+	    !(quirks & SIXAXIS_CONTROLLER_BT))
 		quirks |= SHANWAN_GAMEPAD;
```

Relacionados en la misma rama:
- `1be3c95` crea los dts `meson-sm1-tvbox-gen3` y `-intphy`.
- `47684bf` añade el nodo Bluetooth UART (`&uart_A { bluetooth {...} }`) al dtb
  `tvbox-gen3`, para que WiFi + BT funcionen juntos sin usar `h96-max.dtb`.

Tras esto: `make s905gen3-build`, flashear, y los mandos funcionan de fábrica
**sin renombrar nada**.

---

## 4. Arreglo en caliente (imagen ya flasheada, sin recompilar)

Si corres una imagen con kernel 6.6 **sin** el parche `004`, se logra el mismo
efecto **renombrando el mando en BlueZ** para que no coincida con la cadena
exacta del quirk. El nombre que ve `hid-sony` sobre BT es el `Name=` guardado en
`/var/lib/bluetooth/<ADAPTER>/<MAC>/info`.

Por SSH (Batocera: `root` / `linux`):

```sh
A="/var/lib/bluetooth/$(ls /var/lib/bluetooth | grep :)"

# renombrar los mandos SHANWAN a un nombre que NO sea "SHANWAN PS3 GamePad"
for d in "$A"/*/info; do
  sed -i 's/^Name=SHANWAN PS3 GamePad.*/Name=Sony PLAYSTATION(R)3 Controller/' "$d"
done

/etc/init.d/S32bluetooth restart
batocera-bluetooth save     # persiste en /userdata/system/bluetooth
```

Restricción: el `Name=` no debe ser literal `SHANWAN PS3 GamePad` ni
`ShanWan PS(R) Ga`epad`. Cualquier otro nombre sirve (usé el de PS3 oficial).
El número de jugador lo asigna Batocera por **orden de conexión**, no por el
nombre.

> Importante: `/userdata` debe estar en la partición real (ext4 `SHARE`), no en
> tmpfs, o el `save` se pierde al reiniciar. Verifica con `mount | grep userdata`.

---

## 5. Emparejar (primera vez) y reconectar

> Prerrequisito: el dtb debe levantar el BT por UART (`hciconfig` muestra un
> `hci` con `Bus: UART`, no solo el `SDIO` con BD Address `00:00:...`). En la
> X96 Max+ (AP6335) el dtb que funciona es **`meson-sm1-h96-max.dtb`** — ver
> sección 0 de `README-RGM-tvbox-gen3.md`.
>
> Mandos multi-modo (ZD-V+): si por USB aparecen como `Microsoft X-Box 360 pad`
> están en modo Xbox y **no** hacen cable pairing. Cambiar a modo PS3 primero.

1. **Primera vez, por cable USB**: conecta el mando al box con cable. El plugin
   `sixaxis` de bluez hace *cable pairing* (graba la MAC del adaptador en el
   mando y crea el emparejamiento). En rgm el fallback para nombres desconocidos
   está en `board/batocera/patches/bluez5_utils/003-sixaxis-clone-fallback.patch`.
2. Desconecta el cable y pulsa el botón **PS**: reconecta por Bluetooth.
3. Los siguientes arranques: solo botón **PS** (ya quedó emparejado y guardado).

Diagnóstico en vivo:
```sh
# ver conexiones BT activas
hcitool con
# capturar HCI (btmon subido a /userdata/system/btmon; o instalar bluez-tools)
/userdata/system/btmon -i hci1 -w /tmp/bt.btsnoop &
/userdata/system/btmon -r /tmp/bt.btsnoop | grep -E "Connect Complete|Disconnect Complete|Reason"
# log de bluetoothd con debug
batocera-settings-set controllers.bluetooth.debug 1   # luego reinicia el servicio BT
```

---

## 6. Reproducirlo en EmuELEC (si se perdió el respaldo)

EmuELEC (kernel 4.9) **no necesita** el parche del punto 3: 4.9 ya trata a todos
los `054C:0268` como Sixaxis oficial. Lo que EmuELEC sí lleva:

- **bluez 5.72** con parche `fake-ps3` en `/usr/lib/bluetooth/plugins/sixaxis.so`:
  fuerza que cualquier `054C:0268` con nombre desconocido resuelva como una
  entrada válida de la tabla `devices[]` para que el *cable pairing* funcione.
  (Equivalente en Batocera rgm: `003-sixaxis-clone-fallback.patch`.)
- Servicio por-dispositivo `sixaxis@.service` + `sixaxis-helper.sh` (udev lanza
  uno por cada mando conectado; hace calibración y timeout de inactividad).
- Regla udev `99-sixaxis.rules` que matchea nombres `*PS3 GamePad`,
  `*PS(R) Gamepad`, `PLAYSTATION(R)3*`, etc.
- Acceso: SSH root con **clave personalizada** (hash SHA-512 en
  `/storage/.cache/shadow`, no reversible; se resetea dejando el campo vacío o
  con `openssl passwd -6`). Passkey de UI (salir de Kiosk): `uuudddududaaaba`.
- Imágenes de respaldo (en el disco RESPALDO): `EmuELEC-4.5 ORGINAL.img` y
  `EmuELEC-4.7-RGM-devel-20240130-PS3.img` (ambas 125 069 950 976 bytes).

Si reconstruyes EmuELEC desde cero: basta kernel 4.9 (sin quirk) + el parche
`fake-ps3` de cable pairing. No hace falta nada del punto 3/4 (eso es solo para
compensar el kernel 6.6 de Batocera).

---

## 7. Mando multi-modo "Nintendo Co., Ltd." (USB `054C:0268`→`045E:028E`, BT `98:B6:8E:BE:B6:FE`)

Diagnóstico 2026-09-18 por SSH en la X96 Max+ (`h96-max.dtb`, kernel 6.6.56).

**Por USB** enumera como PS3 `054C:0268` durante 0.1 s y **él solo** salta a
Xbox 360 `045E:028E` ("XBOX 360 For Windows", fabricante "Nintendo Co., Ltd.").
El plugin `sixaxis` alcanza a ver el `054C:0268` pero al pedir la BD address el
dispositivo ya no existe (`sixaxis_get_device_bdaddr: No such device`) → **nunca
hace cable pairing**. Con cable malo además se re-enumera cada 1–5 s
(`device descriptor read/64, error -71`). Por USB úsalo en modo Xbox 360 (`xpad`).

**Por Bluetooth** tiene 2 modos:

| Modo | ID | Driver | Estado |
|------|----|--------|--------|
| "Gamepad" (`HOME`+`□`, `HOME`+`X`, `HOME`+`○`) | `1949:0402` | hid-generic | ❌ descriptor HID roto (`unknown main item tag 0x0`): solo ejes/d-pad, botones sin mapear |
| Xbox One S (**`HOME`+`△`**) | `045E:02E0` | `hid_xpadneo` | ✅ **usar este**. Nombre en ES: "Xbox Wireless Controller" |

Procedimiento: mando apagado → mantener **`HOME` + `△`** hasta que parpadee →
emparejar desde ES (Controles → Bluetooth). Las otras combinaciones lo dejan en
modo "Gamepad" y aparece sin botones.

Problema del modo Xbox: xpadneo manda un *welcome rumble* al conectar
(`ff_connect_notify=1`, motores débil/fuerte/gatillos con `sustain/release/loop`).
El clon no entiende los parámetros de pulso y **vibra sin parar**, luego se cae
(~30–90 s). Arreglo: apagar el rumble en el módulo.

- En la imagen (rama `rgm`): `board/batocera/amlogic/s905gen3/fsoverlay/etc/modprobe.d/xpadneo-rgm.conf`
  → `options hid_xpadneo ff_connect_notify=0 rumble_attenuation=100,100`.
- En un box ya flasheado: crear ese archivo en `/etc/modprobe.d/` y
  `batocera-save-overlay` (queda en `/boot/boot/overlay`).

> ⚠️ **No escribir `/sys/module/hid_xpadneo/parameters/*` en caliente** con un
> mando conectando: el write de `quirks` se quedó en estado `D`, arrastró a
> `bluetoothd` y al subsistema HID (ni BT ni USB detectaban mandos) y hubo que
> reiniciar con `sysrq b`. Por eso va en `modprobe.d`, no en `custom.sh`.
> Sintaxis de `quirks`, por si hiciera falta: `MAC+3` (suma decimal), no `MAC:1+2`.

**"Remove all" en ES → bluetoothd muerto.** Al borrar los dispositivos BT desde
el menú, Batocera reinicia `bluetoothd`; el nuevo arrancó antes de que el viejo
soltara D-Bus (`Unable to get on D-Bus`) y murió: `hci0 DOWN`, sin plugin
`sixaxis`, cable pairing imposible, "no detecta ningún mando". Fix:
`/etc/init.d/S32bluetooth restart` (o reiniciar el box). Comprobar con
`ps | grep bluetoothd` y `hciconfig hci0` → `UP RUNNING`.

**Icono en la lista BT de ES.** Lo decide la *Class of Device* que anuncia el
mando: Xbox `0x0508` (minor gamepad) → `input-gaming` 🎮; clon GUO HUA
`0x0540` (minor keyboard) → `input-keyboard` ⌨️. Cosmético; el kernel lo maneja
igual con `hid-sony`.

**Reinicios.** Antes de `reboot` por SSH: `sync` y esperar; un reinicio sucio
perdió `custom.sh` y el emparejamiento recién hecho (`EXT4-fs: recovery
complete`). Tras emparejar: `batocera-bluetooth save`.

---

## 8. Notas del ShanWan ZD-V+ (`2563:0575` / `045e:028e`)

- Multi-modo por combinación de botones. Modos vistos: **Xbox 360** (`045e:028e`,
  driver xpad) y **DirectInput/Switch** (`2563:0575`, hid-generic). Por
  **Bluetooth** se presenta como clon **PS3** (`054C:0268`) — usar ese por BT.
- Si por USB se **re-enumera solo** cada pocos segundos (`xpad ... usb_submit_urb
  failed -19`, disconnects seguidos): es **cable/puerto** malo, no software.
  Cambiar cable de datos / puerto.
- Recomendado: por cable en **Xbox 360**; inalámbrico en **PS3/BT**.

---

## 9. Sesión 2026-09-19 — hallazgos verificados en hardware

### 8.1 Trampa de orden de compilación

La imagen `batocera-s905gen3-tvbox-gen3-1.0-20260919.img` **no lleva** los
parches de `hid-sony`: su kernel se compiló antes que los commits.

| | UTC |
|---|---|
| kernel de la imagen (`Sat Sep 12 01:12:13 CEST 2026`) | 2026-09-11 23:12 |
| `1eaf3d7` *SET_REPORT over BT* | 2026-09-12 06:51 |
| `0d676b3` *skip SHANWAN quirk over BT* | 2026-09-12 12:44 |

Con el quirk aún activo los SHANWAN parpadeaban los 4 LEDs. Comprobar antes de
dar por bueno un arreglo:

```sh
uname -v        # fecha de compilación del kernel en la caja
git log -1 --format=%cd --date=iso <commit-del-parche>
```

Como el parche vive en `linux_patches/`, el rebuild tiene que **rehacer el
kernel**, no reusar el de `output/build/linux-*`.

### 8.2 El cable *sí* empareja aunque no lo parezca

Los mandos con descriptor USB `Nintendo Co., Ltd.` / `USB Gamepad` (vistos:
`98:B6:8E:BE:B6:FE` y `98:B6:66:7A:97:C5`) hacen esto en **cada** conexión:

```
054c:0268  modo PS3        <- aquí bluez completa el cable pairing
   ~120 ms
045e:028e  XBOX 360 For Windows   <- el mando se pasa solo a X-input
```

El salto lo hace el **firmware del mando**. Descartado que lo dispare el host:
pasa igual con `hid-sony`, con `hid-generic`
(`echo 1 > /sys/module/hid/parameters/ignore_special_drivers`) y manteniendo el
`hidraw` abierto (equivalente al `tail -f` de `sixaxis-helper.sh` de EmuELEC).

Consecuencia: al desconectar el cable el mando ya está en modo X-input, no
auto-reconecta como PS3 y parece que el emparejado falló. **No falló** — se
verifica leyendo del propio mando:

```sh
# feature 0xF2 -> MAC del mando (bytes 4..9); 0xF5 -> MAC del host (bytes 2..7)
python3 - <<'PY'
import fcntl, os
def IOC(d,t,nr,sz): return (d<<30)|(sz<<16)|(ord(t)<<8)|nr
def getf(p, rep, sz):
    fd = os.open(p, os.O_RDWR); b = bytearray(sz); b[0] = rep
    try: fcntl.ioctl(fd, IOC(3,'H',0x07,sz), b, True); return bytes(b)
    finally: os.close(fd)
m = lambda b: ":".join("%02X" % x for x in b)
print("mando:", m(getf("/dev/hidraw0",0xF2,17)[4:10]),
      "host:",  m(getf("/dev/hidraw0",0xF5,8)[2:8]))
PY
```

La ventana son ~120 ms, así que hay que sondear `/sys/class/hidraw` cada 5 ms
(el `HID_ID` del uevent viene como `0003:0000054C:00000268`, con ceros).

**Rutina para estos mandos: cable → desconectar → pulsar PS una vez.** Después
reconectan solos. Verificado: L2CAP psm 17 + 19 OK, `js0`, LED de jugador fijo.

### 8.3 Correcciones a secciones anteriores

- **`btmon` no viene en la imagen.** Sí está `/usr/bin/hcidump`:
  `hcidump -i hci1 -t -X` (ojo: no acepta `-V`).
- El quirk `SHANWAN_GAMEPAD` compara con `strcmp` **exacto**, así que **no**
  aplica a los mandos que se anuncian como `PLAYSTATION(R)3Controller-ghic`.
  El parche del punto 3 solo arregla a los SHANWAN.
- `batocera-bluetooth save` deja los nombres renombrados en
  `/userdata/system/bluetooth/bluetooth.tar`, y `restore` (desde `S32bluetooth`)
  los repone en cada arranque. Hay que repetir el renombrado si se re-empareja
  un SHANWAN.

### 8.4 Descartado (no repetir)

- **xpadneo**: EmuELEC *también* lo lleva, con el mismo alias `045E:02E0`.
- **`ClassicBondedOnly`**: `S32bluetooth` ya lo pone en `false` cuando
  `controllers.ps3.enabled=1` (valor por defecto).
- **Tabla `sixaxis` de bluez**: la de Batocera es más completa que la de EmuELEC
  (incluye `GUO HUA PS3 GamePad` más el fallback del parche 003).
- **`tail -f` sobre el evdev** de `sixaxis-helper.sh`: no evita el cambio de modo.

### 8.5 Gotcha de diagnóstico por SSH

`pkill -f <patrón>` mata el propio shell remoto, porque su línea de comando
contiene el patrón. Usar `pkill -f "[p]atrón"`.
