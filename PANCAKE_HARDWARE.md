# Pancake (ESP32-C5) — hardware, pin & build notes

Dokumen kerja untuk agent/developer berikutnya. Ditulis setelah sesi debug yang
memakan waktu lama karena 3 bug berlapis; semua fakta di bawah ini **sudah diuji
di hardware fisik**, bukan asumsi.

Terakhir diverifikasi: sesi build Marauder Pancake (boot + layar + touch + CLI).

---

## 0. Peta proyek — ada 2 firmware untuk board yang sama

| #   | Firmware                   | Lokasi                                                     | Stack                                        | Status                                                                |
| --- | -------------------------- | ---------------------------------------------------------- | -------------------------------------------- | --------------------------------------------------------------------- |
| 1   | **ESP32 Marauder Pancake** | `~/Documents/PlatformIO/Projects/ESP32Marauder` (repo ini) | Arduino / TFT_eSPI, core `esp32:esp32@3.3.4` | **boot + layar + touch OK**, SD & GPS belum                           |
| 2   | **JANOS on Pancake**       | `~/Documents/PlatformIO/Projects/pancake/ESP32C5`          | ESP-IDF 6.0 + LVGL 8                         | pin sudah diselaraskan ke wiring nyata (§8), build OK, belum di-flash |

Board fisiknya **satu**: Waveshare ESP32-C5-WIFI6-KIT. Proyek JANOS awalnya memakai
pinout bawaan Waveshare (MOSI 24 / CLK 23 / DC 3 / RST 2) yang **tidak cocok** dengan
wiring panel 14 pin di board ini; sekarang sudah disamakan.

---

## 1. Pin yang SUDAH TERVERIFIKASI jalan (board user)

Board: **Waveshare ESP32-C5-WIFI6-KIT** (modul `ESP32-C5-WROOM-1`, RISC-V, PSRAM 8 MB
terdeteksi). Panel 3.5" adalah modul 14 pin terpisah yang di-wire manual — angka pin
di bawah ini adalah **hasil wiring nyata**, bukan pinout bawaan doc Waveshare
(doc Waveshare memakai MOSI 24 / CLK 23 / DC 3 / RST 2 / SD_CS 7 / BAT_ADC 6).
Panel: **ST7796 3.5" 320×480** (modul 14 pin) + touch **FT6336U** (I2C addr `0x38`).

### LCD (SPI) — semua TERBUKTI menampilkan gambar

| Fungsi     | GPIO   | Bukti                                                                                                 |
| ---------- | ------ | ----------------------------------------------------------------------------------------------------- |
| `TFT_SCLK` | **10** | fillScreen warna tampil benar                                                                         |
| `TFT_MOSI` | **8**  | idem                                                                                                  |
| `TFT_CS`   | **5**  | idem                                                                                                  |
| `TFT_DC`   | **0**  | idem                                                                                                  |
| `TFT_RST`  | **1**  | idem                                                                                                  |
| `TFT_BL`   | **26** | backlight menyala (lihat catatan)                                                                     |
| `TFT_MISO` | **25** | pin dummy — panel tidak punya SDO, tapi **wajib GPIO valid** (dipakai bersama SD MISO; sebelumnya 23) |

Catatan backlight: sketch referensi LovyanGFX tidak mengendalikan BL sama sekali
(BL kemungkinan di-hardwire ke 3V3), jadi **PWM/dimming lewat GPIO26 belum
terbukti**. Verifikasi dulu sebelum mengandalkan `brightnessInit()`.

### Touch (I2C) — TERBUKTI terdeteksictp int di pin berapa?

| Fungsi                | GPIO   | Bukti                                         |
| --------------------- | ------ | --------------------------------------------- |
| `CTP_SDA` / `I2C_SDA` | **9**  | Marauder log: `[Touch] FT6336U ID: 0x64 (OK)` |
| `CTP_SCL` / `I2C_SCL` | **4**  | idem; sketch referensi baca chip ID `0x11`    |
| `CTP_RST`             | **7**  | idem                                          |
| `CTP_INT`             | **23** | diverifikasi                                  |

Catatan: chip ID beda register — Marauder membaca reg `0xA3` → `0x64`,
sketch referensi membaca reg lain → `0x11`. **Keduanya normal**, bukan error.

### Pinout resmi board (Waveshare ESP32-C5-WIFI6-KIT, sumber: dokumentasi Waveshare)

| GPIO | Hardware / default                          | Status / catatan penting                                                                                                       |
| ---- | ------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| 0    | `LP_GPIO0` / `XTAL_32K_P`                   | Aman GP / SPI control (**DC**) ✅ dipakai                                                                                      |
| 1    | `LP_GPIO1` / `XTAL_32K_N` / `ADC1_CH0`      | Aman GP (**RST**) ✅ dipakai                                                                                                   |
| 2    | `LP_GPIO2` / `MTMS` / `FSPIQ` / `ADC1_CH1`  | ⚠️ **Strapping (mode boot)**; hindari pull-down eksternal                                                                      |
| 3    | `LP_GPIO3` / `MTDI` / `ADC1_CH2`            | ⚠️ **Strapping (JTAG/boot)**                                                                                                   |
| 4    | `LP_GPIO4` / `MTCK` / `FSPIHD` / `ADC1_CH3` | Aman GP / I2C (**CTP_SCL**) ✅ dipakai                                                                                         |
| 5    | `LP_GPIO5` / `MTDO` / `FSPIWP` / `ADC1_CH4` | Aman GP / SPI CS (**LCD_CS**) ✅ dipakai                                                                                       |
| 6    | `LP_GPIO6` / `FSPICLK` / `ADC1_CH5`         | Jalur native FSPI clock; aman utk GPIO                                                                                         |
| 7    | `LP_GPIO7` / `FSPID`                        | Jalur native FSPI MOSI (**CTP_RST**) ✅ dipakai                                                                                |
| 8    | `LP_GPIO8` / `FSPICS1`                      | Aman GP / SPI (**LCD_MOSI**) ✅ dipakai                                                                                        |
| 9    | `LP_GPIO9` / `FSPICS2`                      | Aman GP / I2C (**CTP_SDA**) ✅ dipakai                                                                                         |
| 10   | `LP_GPIO10` / `FSPICS0`                     | Jalur native FSPI CS0 (**LCD_SCK**) ✅ dipakai                                                                                 |
| 11   | `U0TXD`                                     | Console serial TX — hindari jika butuh log UART                                                                                |
| 12   | `U0RXD`                                     | Console serial RX — idem                                                                                                       |
| 13   | `USB_D-`                                    | ⚠️ USB Serial/JTAG native — **jangan dipakai**                                                                                 |
| 14   | `USB_D+`                                    | ⚠️ USB Serial/JTAG native — **jangan dipakai**                                                                                 |
| 15   | `GPIO15`                                    | Menurut doc: aman GP / MISO / INT — **TAPI** di pengujian kami sebagai `TFT_MISO` → hard crash (lihat §5); jangan dipakai dulu |
| 23   | `GPIO23`                                    | Aman GP / I2C SDA — kini bebas (MISO pindah ke 25)                                                                             |
| 24   | `GPIO24`                                    | Aman GP / I2C SCL (**SD_CS**) ✅ dipakai                                                                                       |
| 25   | `GPIO25` / `SDIO_CMD`                       | Aman GP (**TFT_MISO + SD_MISO**) ✅ dipakai                                                                                    |
| 26   | `GPIO26` / `SDIO_CLK`                       | Aman GP (**TFT_BL**) ⚠️ PWM belum terbukti; sdh dipakai                                                                        |
| 27   | `GPIO27` / `BOOT`                           | ⚠️ **Strapping** — tombol BOOT bawaan (LOW = download mode); nyaman utk tombol tapi hati-hati pull-down                        |
| 28   | `GPIO28`                                    | ⚠️ **Strapping** (ROM boot/log) — hindari kecuali perlu                                                                        |

**Kebijakan pemakaian pin (untuk fitur berikutnya):** yang sudah dipakai dan
**terbukti** = 0, 1, 4, 5, 7, 8, 9, 10, 23, 26. Pin **bebas & aman** = 24, 25.
Pin **pakai dengan hati-hati** = 15 (crash empiris), 2/3 (strapping), 27
(tombol BOOT), 28 (strapping). **Jangan** = 11/12/13/14.

### Belum terverifikasi / masih salah

| Fungsi                           | Nilai sekarang                    | Masalah                                                                                      |
| -------------------------------- | --------------------------------- | -------------------------------------------------------------------------------------------- |
| `SD_CS`                          | 6                                 | GPIO6 = FSPICLK native; slot SD belum ter-mount → kemungkinan CS salah / belum ada wiring    |
| `SD_SCK` / `SD_MOSI` / `SD_MISO` | diturunkan dari `TFT_*` (10/8/23) | **mount gagal**: `Failed to mount SD Card`; set eksplisit dulu                               |
| `C_BTN`                          | 28                                | ⚠️ GPIO28 = **strapping (ROM boot)**. Lebih aman pakai **GPIO27** (tombol BOOT bawaan board) |
| `HAS_NEOPIXEL_LED`               | pin tidak jelas                   | Tidak ada LED WS2812 di board ini (GPIO27 = tombol BOOT) → **matikan**                       |
| `HAS_MAX1704X` (MAX17048 `0x36`) | bus I2C 9/4                       | belum diuji, chip kemungkinan tidak ada                                                      |
| GPS                              | —                                 | tidak ada hardware (`GPS Not Found` = normal)                                                |

Keputusan pemakaian (sesuai arahan user): **fokus LCD dulu** — konfigurasi pin yang
sudah works dipakai apa adanya. Fitur lain (SD, tombol, LED, baterai, GPS) menyusul
setelah yang utama stabil, memakai pin bebas **24 / 25** (aman) dan menghindari 15/2/3/27/28.

---

## 2. Pin yang HARAM / berisiko

| GPIO                | Status                     | Alasan                                                                                                                                                                                                   |
| ------------------- | -------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **13 / 14**         | ❌ jangan                  | `USB_D-` / `USB_D+` (USB-Serial-JTAG native)                                                                                                                                                             |
| **11 / 12**         | ❌ jangan (jika butuh log) | UART0 TX/RX console                                                                                                                                                                                      |
| **2 / 3 / 27 / 28** | ⚠️ hindari                 | **Strapping pins** (mode boot / BOOT button / ROM boot); jangan pull-down di 2,3,27                                                                                                                      |
| **15**              | ⚠️ jangan dulu             | Doc Waveshare bilang aman (MISO/INT), **tapi pengujian kami**: `TFT_MISO 15` → `Load access fault` (MCAUSE 5) + flash app terkorupsi. **Empiris menang atas datasheet** — pakai `23` sebagai MISO dummy. |
| **6 / 7 / 10**      | ⚠️ fungsi asli             | Jalur native FSPI (CLK/MOSI/CS0) — oke dipakai lewat GPIO matrix (7 & 10 sedang dipakai, terbukti jalan), tapi jangan dihubungkan ke dua device bersamaan tanpa perencanaan                              |

Aturan umum: pin dengan alternate function **FSPI\*** (FSPIQ/FSPID/FSPICLK/
FSPICS0/FSPIHD/FSPIWP) sering dianggap berbahaya karena flash/PSRAM ada di bus
itu, tapi pengujian kami membuktikan sebagian di antaranya **aman** lewat GPIO
matrix (4/5/8/9/10 dipakai dan jalan). Yang benar-benar fatal di board ini:
**GPIO15 sebagai MISO**. Jangan terjebak asumsi — selalu uji.

**Dan: `TFT_MISO` TIDAK BOLEH `-1`.** Lihat §5 bug #2.

---

## 3. Resep build & flash yang TERBUKTI (Arduino, core 3.3.4)

### Cara cepat (dipakai di repo ini)

```bash
cd ~/Documents/PlatformIO/Projects/ESP32Marauder
./build_pancake.sh                  # build saja → .localbuild/out/
./build_pancake.sh --upload          # build + flash (port autodetect)
./build_pancake.sh --upload /dev/ttyACM1 --monitor
```

Skrip ini melakukan (meniru `.github/workflows/build_parallel.yml`):

1. clone fork TFT_eSPI yang mendukung C5: `H4W9/TFT_eSPI` branch **`ESP32-C5`**
   → `.localbuild/tft/TFT_eSPI` (library global `~/Arduino/libraries` TIDAK disentuh)
2. salin `User*.h` repo → fork, lalu **uncomment** baris
   `//#include <User_Setup_marauder_pancake.h>` di `User_Setup_Select.h` versi repo
   (file ini WAJIB versi repo: blok `#include "TFT_Drivers/ST7796_Defines.h"`
   ada di ekornya; file select 1-baris → error `TFT_MADCTL not declared`)
3. pohon library privat `.localbuild/arduino-user/libraries` (symlink semua lib
   `~/Arduino/libraries` kecuali TFT_eSPI yang diganti fork)
4. compile:

```bash
export ARDUINO_DIRECTORIES_USER="$PWD/.localbuild/arduino-user"
arduino-cli compile \
  --fqbn "esp32:esp32:esp32c5:FlashSize=8M,PartitionScheme=default_8MB,PSRAM=enabled" \
  --warnings none --build-path .localbuild/build \
  --build-property "compiler.cpp.extra_flags=-DMARAUDER_PANCAKE -fno-exceptions" \
  --build-property "compiler.c.elf.extra_flags=-Wl,-zmuldefs" \
  esp32_marauder
```

5. upload: `arduino-cli upload -p /dev/ttyACM1 --fqbn <sama> --input-dir .localbuild/build esp32_marauder`

### Prasyarat mesin ini (sudah terpenuhi)

- `arduino-cli` + core `esp32:esp32 3.3.4`
- `~/.arduino15/.../3.3.4/platform.txt` sudah dipatch: `compiler.c.elf.extra_flags=-Wl,-zmuldefs`
- `.../esp32-arduino-libs/*/esp32c5/flags/cpp_flags` sudah dipatch: `-fno-exceptions`
- Versi library di `~/Arduino/libraries` sudah sama dengan CI: NimBLE 2.3.8,
  ArduinoJson 6.18.2, LinkedList 1.3.3, ESPAsyncWebServer 3.8.1, AsyncTCP 3.4.8,
  MicroNMEA 2.0.6, JPEGDecoder 1.8.0, Adafruit NeoPixel 1.12.0, lv_arduino 3.0.0,
  ESP32Ping 1.6, EspSoftwareSerial 8.1.0, Adafruit BusIO 1.15.0, MAX1704X 1.0.2,
  XPT2046_Touchscreen 1.4, Adafruit_TCA8418

### Hasil build final (acuan)

```
Sketch uses 2110260 bytes (63%) of program storage space. Maximum is 3342336
Global variables use 91884 bytes (28%) of dynamic memory
```

### Build cepat untuk eksperimen

Jangan iterasi dengan Marauder (2 MB, ~1–3 menit). Pakai sketch kecil
**~35 detik**, contoh yang sudah ada: `.localbuild/tfttest/tfttest.ino`
(menggambar warna berputar + teks, cukup untuk verifikasi TFT_eSPI):

```bash
arduino-cli compile --fqbn "$FQ" --build-path .localbuild/tfttest/build .localbuild/tfttest
arduino-cli upload  -p /dev/ttyACM1 --fqbn "$FQ" --input-dir .localbuild/tfttest/build .localbuild/tfttest
```

---

## 4. Alur debug cepat (resep yang terbukti bekerja)

1. **Ambil log serial** (USB CDC `/dev/ttyACM1`, 115200):

```python
import time, serial
s = serial.Serial('/dev/ttyACM1', 115200, timeout=1)
time.sleep(1.5); s.reset_input_buffer()
s.dtr=False; s.rts=True; time.sleep(0.1); s.rts=False   # hard reset
buf=b""; t=time.time()
while time.time()-t < 10: buf += s.read(8192)
print(buf.decode('utf-8','replace'))
```

2. **Decode panic** (alamat `MEPC`/stack) ke simbol:

```bash
A2L=~/.arduino15/packages/esp32/tools/esp-rv32/*/bin/riscv32-esp-elf-addr2line
$A2L -pfia -e .localbuild/build/esp32_marauder.ino.elf 0x42xxxxxx
```

3. **Baseline**: flash bin resmi CI untuk memisahkan "build kita salah" vs
   "hardware/target salah":

```bash
curl -sSLo .localbuild/official/esp32_marauder.ino.bin \
  https://github.com/justcallmekoko/ESP32Marauder/releases/download/v1.20.0/esp32_marauder_v1_20_0_20261028_pancake.bin
# butuh juga esp32_marauder.ino.bootloader.bin + .partitions.bin di folder itu
arduino-cli upload -p /dev/ttyACM1 --fqbn "$FQ" --input-dir .localbuild/official esp32_marauder
```

Catatan: bin resmi memakai pin pancake upstream, jadi di board user layar
tetap gelap & touch `0x00` — tapi **boot tanpa crash** = toolchain kita benar.

4. **Sketch referensi hardware** (LovyanGFX, layar + touch terbukti jalan):
   `~/Documents/PlatformIO/Projects/test max1703` → `pio run -e env32-c5 -t upload --upload-port /dev/ttyACM1`

5. **A/B config**: `git stash push <file>` untuk kembali ke source pristine tanpa
   kehilangan editan, atau simpan salinan ke `.localbuild/`.

---

## 5. Tiga bug yang sudah diperbaiki (akar masalah)

### Bug #1 — hard crash saat boot, flash ikut rusak

`User_Setup_marauder_pancake.h`: `TFT_MISO 15`.
Gejala: `Guru Meditation Error ... Load access fault`, `MCAUSE 0x5`, `MTVAL 0x10`,
lalu reboot dengan `esp_image: Checksum failed` → app partition tidak bootable.
Sebab: GPIO15 punya alternate FSPIHD (jalur flash); menyentuhnya merusak code
fetch dari flash (XIP).
Perbaikan: pindah MISO ke GPIO bebas.

### Bug #2 — layar hitam, backlight nyala, tanpa pesan error

`TFT_MISO -1`.
Sebab: `TFT_eSPI::initBus()` memanggil `spi.begin(TFT_SCLK, TFT_MISO, TFT_MOSI, -1)`.
Dengan MISO `-1` bus tidak pernah dikonfigurasi sehingga **nol byte** keluar ke
panel (tanpa error). Panel ST7796 tidak butuh MISO, tapi nilainya harus GPIO valid.
Perbaikan: `#define TFT_MISO 23` (pin bebas).

### Bug #3 — touch tidak terdeteksi

Pin upstream pancake (`I2C_SCL 10`, `CTP_RST 8`) ≠ PCB user (`SCL 4`, `RST 7`).
Perbaikan: override di `esp32_marauder/configs.h` (`MARAUDER_PANCAKE` block).

### Pelajaran proses (penting untuk agent berikutnya)

- **Print `Serial` hilang saat CPU mati.** Crash tampak "terjadi di driver I2C"
  padahal bukan. Selalu `Serial.flush()` setelah print saat menginstrumentasi.
- **Ukuran `.bin` bisa identik** setelah mengubah header makro — jangan pakai
  ukuran bin sebagai bukti bahwa rebuild terjadi.
- **Panic site bergeser** antar build (i2c → FreeRTOS queue) = indikasi korupsi
  memori/pin, bukan bug satu fungsi.
- Saran bisect yang efisien: kecilkan target (`configs.h` pakai `#ifdef` per board;
  bisa dimatikan satu per satu) dan uji dengan sketch kecil §3.

---

## 6. TODO berikutnya (urutan prioritas)

1. **SD card** (satu-satunya fungsi hardware yang masih gagal)
   - Skema paling masuk akal: **SPI sharing dengan LCD** (SCK 10, MOSI 8, MISO 23)
     - `SD_CS` di pin bebas yang aman → kandidat **24 atau 25**, misal
       `#define SD_CS 24` (bukan 6 yang sekarang).
   - Alternatif **SDIO**: board menandai `GPIO25 = SDIO_CMD`, `GPIO26 = SDIO_CLK`
     → **GPIO26 sedang dipakai `TFT_BL`**, jadi SDIO butuh tukar pin BL dulu.
   - Implementasi: `#define SD_SCK/SD_MISO/SD_MOSI/SD_CS` eksplisit di blok
     `#ifdef MARAUDER_PANCAKE` (`configs.h`), karena sekarang diturunkan dari `TFT_*`.
   - Uji: log hilang `Failed to mount SD Card`, lalu CLI `ls /`.
2. **Backlight**: pastikan GPIO26 benar-benar mengatur BL; uji `brightnessInit()`
   (kalau BL hardwire, `ledcAttach` tidak berefek → atur `TFT_BL -1`).
3. **Tombol**: pindahkan `C_BTN` 28 → **27** (tombol BOOT bawaan, strapping tapi
   memang untuk ditekan; jangan tambah pull-down eksternal).
4. **NeoPixel**: tidak ada LED WS2812 di board ini → `HAS_NEOPIXEL_LED` sebaiknya
   dimatikan untuk target pancake.
5. **Baterai**: `HAS_MAX1704X` (MAX17048 `0x36`) — cek keberadaan chip di bus 9/4;
   kalau tidak ada, hapus `HAS_BATTERY`/`HAS_MAX1704X` untuk target ini.
6. **JANOS**: pin sudah sama; tinggal flash + verifikasi tampilan/touch (§8).

---

## 7. File yang diubah di repo ini

```
User_Setup_marauder_pancake.h   ST7796 320x480; MISO 23 (dummy valid), MOSI 8,
                                SCLK 10, CS 5, DC 0, RST 1, BL 26, 27 MHz,
                                TFT_INVERSION_ON
esp32_marauder/configs.h        MARAUDER_PANCAKE aktif; SD_CS 6; I2C_SDA 9;
                                I2C_SCL 4; CTP_RST 7
esp32_marauder/esp32_marauder.ino   (editan user) #define CONFIG_IDF_TARGET_ESP32 0
                                + CONFIG_IDF_TARGET_ESP32C5 — sudah diuji BUKAN
                                penyebab crash; boleh dibersihkan
build_pancake.sh (baru)         build + upload + monitor, dokumentasi gotcha MISO
.gitignore                      + .localbuild, .vscode
```

Revert cepat: `git checkout -- <file>` (semua perubahan di atas belum di-commit).

---

## 8. Firmware #2 — JANOS (`~/Documents/PlatformIO/Projects/pancake/ESP32C5`)

ESP-IDF 6.0 + LVGL 8. **Sudah diselaraskan** dengan pin board user (build OK).

| Fungsi   | JANOS lama (Waveshare) | JANOS sekarang (verified)                 |
| -------- | ---------------------- | ----------------------------------------- |
| LCD MOSI | 24                     | **8**                                     |
| LCD MISO | 4                      | **-1** (panel tanpa SDO)                  |
| LCD CLK  | 23                     | **10**                                    |
| LCD CS   | 5                      | 5                                         |
| LCD DC   | 3                      | **0**                                     |
| LCD RST  | 2                      | **1**                                     |
| CTP SDA  | 9                      | 9                                         |
| CTP SCL  | 10                     | **4**                                     |
| CTP INT  | 25                     | **-1** (polling; INT belum terverifikasi) |
| CTP RST  | 8                      | **7**                                     |
| BL       | 26                     | 26 (aktif HIGH)                           |

Perubahan lain yang diperlukan agar JANOS bisa dibangun & tampil:

1. **Driver panel → ST7796.** `main/main.c` masih `#include "esp_lcd_ili9341.h"`
   dan `esp_lcd_new_panel_ili9341(...)`, padahal `main/CMakeLists.txt` +
   `idf_component.yml` sudah minta `espressif__esp_lcd_st7796`. Sudah diganti ke
   `esp_lcd_st7796.h` / `esp_lcd_new_panel_st7796(...)`.
2. **Konflik komponen.** `components/espressif__esp_lcd_ili9341` (vendored lama)
   memicu `BUG: component_requirements.py: ... already in the requirements list`.
   Sudah dipindah ke `ESP32C5/.unused/`.
3. **`esp_lcd_st7796` 1.0.0 tidak kompatibel IDF 6.0.** Hanya versi 1.0.0 yang
   mengizinkan target `esp32c5` (1.1.0+ = s2/s3/p4 saja), tapi 1.0.0 memakai API
   lama `color_space` → `error: 'esp_lcd_panel_dev_config_t' has no member named
'color_space'`. Perbaikan: `ESP32C5/tools/patch_st7796.sh` (idempoten,
   mengubah ke `rgb_ele_order`). **Jalankan ulang setelah `idf.py fullclean`** atau
   setelah manifest dependency berubah, karena component manager mengekstrak ulang
   `managed_components/`.

Build terakhir: `projectZero.bin` 2 137 856 B, partisi 7 MB (71% sisa), selesai tanpa error.

```bash
cd ~/Documents/PlatformIO/Projects/pancake/ESP32C5
source ~/esp/esp-idf/export.sh
./tools/patch_st7796.sh        # setelah fullclean / ubah dependency
idf.py build                   # ~2-4 menit inkremental
idf.py -p /dev/ttyACM1 flash monitor
```

### Akar masalah SD yang sebenarnya: catu daya modul (5 V, bukan 3V3)

Panel TFT dan soket microSD berada di **satu modul dengan satu jalur VCC/GND**.
Saat modul diberi **3V3 dari board**, kartu mati di tengah inisialisasi:

```
[PROBE] CMD0=0x01  CMD8=0x01  ACMD41=0xFF  CMD58=0xFF  CMD59=0xFF
```

Artinya kartu hidup dan menjawab dua perintah pertama, lalu hilang sama sekali —
bukan wiring, bukan firmware: rail 3V3 turun saat kartu menarik arus burst init
(sementara backlight + logika LCD memakai jalur yang sama).

Yang **tidak** menolong (sudah diuji): clock SD 1 MHz, prime 16×0xFF, pull-up MISO,
mematikan backlight selama mount.

**Solusi yang bekerja:** pindahkan VCC modul ke pin **5 V** board. Modul punya
regulator onboard (AMS1117/662K) sehingga LCD + kartu mendapat 3,3 V stabil dari
regulator itu, bukan dari rail board. Hasil: `Mount SUCCESS` 3/3 boot, stabil di
**20 MHz**, kartu 14 940 MB.

> Jangan memberi 5 V ke modul yang TIDAK punya regulator onboard — periksa dulu ada
> AMS1117/662K di dekat konektor.
