#!/usr/bin/env bash
###############################################################################
# compile.sh - Compile the already-configured Marlin and extract the renamed .bin.
#
# Environment variables:
#   MARLIN_DIR  (required)
#   OUT_BIN     (required)  final .bin path (will be created)
#   PIO_ENV     (optional)  default: STM32F103RE_creality (STM32F103RET6 512K)
###############################################################################
set -euo pipefail
: "${MARLIN_DIR:?set MARLIN_DIR}"
: "${OUT_BIN:?set OUT_BIN}"
PIO_ENV="${PIO_ENV:-STM32F103RE_creality}"

cd "${MARLIN_DIR}"
echo "==> Compiling (env: ${PIO_ENV})"
pio run -e "${PIO_ENV}"

# The Creality env renames the output to firmware-{date}-{time}.bin (offset 0x7000).
BIN_SRC="$(ls -t ".pio/build/${PIO_ENV}"/firmware*.bin | head -1)"
mkdir -p "$(dirname "${OUT_BIN}")"
cp "${BIN_SRC}" "${OUT_BIN}"

SIZE=$(stat -c%s "${OUT_BIN}")
echo "==> OK: ${OUT_BIN} (${SIZE} bytes, $(awk "BEGIN{printf \"%.1f\",${SIZE}/1024}") KiB)"
