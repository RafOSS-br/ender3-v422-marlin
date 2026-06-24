#!/usr/bin/env bash
###############################################################################
# build.sh - Reproducible LOCAL build (inside Docker) of ONE variant.
#
# Reuses the same scripts as the CI pipeline (scripts/*.sh), so local behavior
# and GitHub Actions behavior are identical.
#
# Default variant = target printer: Ender-3 / Creality V4.2.2 / pt_br / 5x5 mesh.
# Override via environment variables, e.g.:
#   docker run --rm -e LCD_LANG=en -e MESH_GRID=7 -v "$PWD":/workspace marlin-ender3-v422
#
# Output: output/firmware.bin (+ a copy of the final configs for the record).
###############################################################################
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

export MARLIN_TAG="${MARLIN_TAG:-2.1.2.7}"
export MARLIN_DIR="${MARLIN_DIR:-${HERE}/Marlin}"
export LCD_LANG="${LCD_LANG:-pt_br}"
export LEVELING="${LEVELING:-manual_mesh}"   # manual_mesh | none
export MESH_GRID="${MESH_GRID:-5}"
export MOTHERBOARD="${MOTHERBOARD:-BOARD_CREALITY_V422}"
export MACHINE_NAME="${MACHINE_NAME:-Ender-3}"
export PIO_ENV="${PIO_ENV:-STM32F103RE_creality}"

OUT="${OUT_DIR:-${HERE}/output}"
export OUT_BIN="${OUT}/firmware.bin"

bash "${HERE}/scripts/fetch-marlin.sh"
bash "${HERE}/scripts/apply-config.sh"
bash "${HERE}/scripts/compile.sh"

# Keep the final configs next to the binary (build documentation).
cp "${MARLIN_DIR}/Marlin/Configuration.h" \
   "${MARLIN_DIR}/Marlin/Configuration_adv.h" "${OUT}/"

echo
echo "================================================================"
echo " FIRMWARE: ${OUT_BIN}"
echo " Variant: language=${LCD_LANG}  leveling=${LEVELING}  mesh=${MESH_GRID}x${MESH_GRID}  board=${MOTHERBOARD}"
echo "================================================================"
