#!/usr/bin/env bash
###############################################################################
# apply-config.sh - Apply the customizations on top of the official config.
#
# Reusable per variant (language x mesh size). Always starts from the official
# config freshly downloaded by fetch-marlin.sh.
#
# Environment variables:
#   MARLIN_DIR    (required)
#   LCD_LANG      (optional)  Marlin language code        (default: pt_br)
#   LEVELING      (optional)  manual_mesh | none          (default: manual_mesh)
#   MESH_GRID     (optional)  N of the manual NxN mesh     (default: 5; ignored if none)
#   MOTHERBOARD   (optional)  board                        (default: BOARD_CREALITY_V422)
#   MACHINE_NAME  (optional)  printer name                 (default: Ender-3)
#
# NOTE: LCD_LANG must be lowercase (e.g. pt_br, en, de). Marlin builds the
# include as language_<LCD_LANG>.h and the files are lowercase.
###############################################################################
set -euo pipefail
: "${MARLIN_DIR:?set MARLIN_DIR}"
LCD_LANG="${LCD_LANG:-pt_br}"
LEVELING="${LEVELING:-manual_mesh}"
MESH_GRID="${MESH_GRID:-5}"
MOTHERBOARD="${MOTHERBOARD:-BOARD_CREALITY_V422}"
MACHINE_NAME="${MACHINE_NAME:-Ender-3}"

cd "${MARLIN_DIR}/Marlin"

# uncomment: turn "//#define X" into "#define X" (in both files).
uncomment(){ sed -i "s|^\([[:space:]]*\)//#define ${1}\b|\1#define ${1}|" \
             Configuration.h Configuration_adv.h; }

echo "==> Applying: board=${MOTHERBOARD} language=${LCD_LANG} leveling=${LEVELING} mesh=${MESH_GRID}x${MESH_GRID} name='${MACHINE_NAME}'"

# Board: the official base ships BOARD_CREALITY_V4 -> target is V4.2.2.
sed -i "s|^\([[:space:]]*#define MOTHERBOARD[[:space:]]*\)BOARD_CREALITY_V4[[:space:]]*$|\1${MOTHERBOARD}|" Configuration.h

# Interface language (en -> LCD_LANG).
sed -i "s|^\(#define LCD_LANGUAGE[[:space:]]*\)en[[:space:]]*$|\1${LCD_LANG}|" Configuration.h

# Printer name.
sed -i "s|^#define CUSTOM_MACHINE_NAME .*|#define CUSTOM_MACHINE_NAME \"${MACHINE_NAME}\"|" Configuration.h

case "${LEVELING}" in
  manual_mesh)
    # MANUAL Mesh Bed Leveling (no probe).
    uncomment "MESH_BED_LEVELING"          # manual mesh: adjust Z at each point
    uncomment "RESTORE_LEVELING_AFTER_G28" # re-apply the mesh after each homing
    uncomment "LCD_BED_LEVELING"           # guided submenu on the display
    uncomment "MESH_EDIT_MENU"             # edit mesh points from the knob
    # Mesh size NxN: change ONLY the GRID_MAX_POINTS_X inside the MBL block,
    # uniquely identified by the comment "more than 7 points".
    sed -i "/more than 7 points/ s|GRID_MAX_POINTS_X [0-9]\+|GRID_MAX_POINTS_X ${MESH_GRID}|" Configuration.h
    ;;
  none)
    # Stock baseline: no bed-leveling compensation (leave the official defaults).
    echo "    leveling=none -> no bed compensation (stock baseline)"
    ;;
  *)
    echo "ERROR: unknown LEVELING='${LEVELING}' (use manual_mesh|none)" >&2
    exit 1
    ;;
esac

echo "==> Verification:"
grep -nE '^[[:space:]]*#define MOTHERBOARD '   Configuration.h
grep -nE '^#define LCD_LANGUAGE '              Configuration.h
grep -nE '^#define CUSTOM_MACHINE_NAME '       Configuration.h
if [ "${LEVELING}" = "manual_mesh" ]; then
  grep -nE '^#define MESH_BED_LEVELING'        Configuration.h
  grep -nE "GRID_MAX_POINTS_X ${MESH_GRID} "   Configuration.h
fi
