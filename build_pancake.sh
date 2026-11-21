#!/usr/bin/env bash
# Local build script for the "Marauder Pancake" target (ESP32-C5 + ST7796 3.5").
# Mirrors the recipe in .github/workflows/build_parallel.yml, but without
# touching the globally installed Arduino libraries: a private user-library
# tree in .localbuild/ is used instead, so Bodmer TFT_eSPI 2.5.34 stays intact.
#
# NOTE (hardware gotcha, cost us a long debug session):
#   User_Setup_marauder_pancake.h must define TFT_MISO as a REAL, otherwise free
#   GPIO even though the ST7796 panel has no SDO line. With "TFT_MISO -1" the
#   TFT_eSPI bus is never set up, so the backlight comes on but nothing is drawn
#   (black screen, no error). Do not point it at a pin used by the flash/PSRAM bus
#   (e.g. GPIO15 on ESP32-C5) - that corrupts code fetch and hard-crashes the chip.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

FQBN="esp32:esp32:esp32c5:FlashSize=8M,PartitionScheme=default_8MB,PSRAM=enabled"
BUILD_PATH=".localbuild/build"
OUT_DIR=".localbuild/out"

UPLOAD=0
MONITOR=0
PORT=""

usage() {
  cat <<'EOF'
Usage: ./build_pancake.sh [options]

  (no option)          build only, artifact lands in .localbuild/out/
  --upload [PORT]      build, then flash to PORT (auto-detected if omitted)
  --monitor            after a successful upload, open the serial monitor
  -p, --port PORT      use PORT for upload/monitor
  -h, --help           show this help

Serial ports on this machine are typically /dev/ttyACM0 (native USB) or
/dev/ttyUSB0 (CH34x/CP210x bridge).
EOF
}

detect_port() {
  local p
  for p in /dev/ttyACM* /dev/ttyUSB*; do
    [ -e "$p" ] && { echo "$p"; return 0; }
  done
  return 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --upload)  UPLOAD=1; shift
               if [ $# -gt 0 ] && [ "${1#-}" = "$1" ]; then PORT="$1"; shift; fi ;;
    --monitor) MONITOR=1; shift ;;
    -p|--port) PORT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [ "$UPLOAD" = 0 ] && [ -n "$PORT" ]; then
  echo "--port given without --upload; ignoring" >&2
fi

mkdir -p .localbuild/tft "$OUT_DIR"

# 1. TFT_eSPI fork that supports the ESP32-C5 (upstream Bodmer 2.5.34 does not)
if [ ! -d .localbuild/tft/TFT_eSPI/.git ]; then
  git clone --depth 1 --branch ESP32-C5 https://github.com/H4W9/TFT_eSPI.git .localbuild/tft/TFT_eSPI
fi

# 2. Install + select the panel setup (CI: "Configure TFT_eSPI").
#    The repo's own User_Setup_Select.h must be used: it contains the driver
#    define block (#include "TFT_Drivers/ST7796_Defines.h") that sets TFT_DRIVER,
#    TFT_MADCTL, TFT_CASET, ... A one-line select file breaks the build.
cp -f User*.h .localbuild/tft/TFT_eSPI/
sed -i 's|^//#include <User_Setup_marauder_pancake.h>|#include <User_Setup_marauder_pancake.h>|' \
  .localbuild/tft/TFT_eSPI/User_Setup_Select.h
grep -qx '#include <User_Setup_marauder_pancake.h>' .localbuild/tft/TFT_eSPI/User_Setup_Select.h || {
  echo "ERROR: failed to select User_Setup_marauder_pancake.h" >&2; exit 1; }

# 3. Private Arduino user tree: all real libs symlinked, TFT_eSPI from the fork
mkdir -p .localbuild/arduino-user/libraries
for d in "$HOME"/Arduino/libraries/*/; do
  n="$(basename "$d")"
  [ "$n" = "TFT_eSPI" ] && continue
  ln -sfn "$d" ".localbuild/arduino-user/libraries/$n"
done
ln -sfn "$ROOT/.localbuild/tft/TFT_eSPI" .localbuild/arduino-user/libraries/TFT_eSPI

# 4. Compile
export ARDUINO_DIRECTORIES_USER="$ROOT/.localbuild/arduino-user"
arduino-cli compile \
  --fqbn "$FQBN" \
  --warnings none \
  --build-path "$BUILD_PATH" \
  --build-property "compiler.cpp.extra_flags=-DMARAUDER_PANCAKE -fno-exceptions" \
  --build-property "compiler.c.elf.extra_flags=-Wl,-zmuldefs" \
  esp32_marauder

# 5. Collect artifacts
VERSION="$(grep '#define MARAUDER_VERSION' esp32_marauder/configs.h | sed -E 's/.*"(v[^"]+)".*/\1/')"
STAMP="$(date +%Y%m%d)"
cp -f "$BUILD_PATH/esp32_marauder.ino.bin" "$OUT_DIR/esp32_marauder_${VERSION#v}_${STAMP}_pancake.bin"
cp -f "$BUILD_PATH/esp32_marauder.ino.bootloader.bin" "$OUT_DIR/" 2>/dev/null || true
cp -f "$BUILD_PATH/esp32_marauder.ino.partitions.bin" "$OUT_DIR/" 2>/dev/null || true

echo "OK: $OUT_DIR/esp32_marauder_${VERSION#v}_${STAMP}_pancake.bin"
ls -l "$OUT_DIR"

# 6. Optional: flash to the board
if [ "$UPLOAD" = 1 ]; then
  if [ -z "$PORT" ]; then
    PORT="$(detect_port)" || {
      echo "ERROR: no serial port found (/dev/ttyACM* or /dev/ttyUSB*). Plug the ESP32-C5 in," >&2
      echo "       or pass the port explicitly: ./build_pancake.sh --upload /dev/ttyACM0" >&2
      exit 3
    }
  fi
  echo "Uploading to $PORT ..."
  arduino-cli upload \
    -p "$PORT" \
    --fqbn "$FQBN" \
    --input-dir "$BUILD_PATH" \
    esp32_marauder
  echo "OK: flashed to $PORT"

  if [ "$MONITOR" = 1 ]; then
    echo "Opening serial monitor on $PORT (Ctrl+C to quit) ..."
    exec arduino-cli monitor -p "$PORT" --fqbn "$FQBN" -c baudrate=115200
  fi
fi
