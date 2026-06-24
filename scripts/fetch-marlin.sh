#!/usr/bin/env bash
###############################################################################
# fetch-marlin.sh - Clone Marlin and download the official Ender-3 V4.2.2 config.
#
# Reusable step: runs ONCE per Marlin version and the result is reused by every
# variant (language x mesh). Idempotent: if the clone already exists, it only
# re-downloads the 4 base config files.
#
# Environment variables:
#   MARLIN_TAG   (required)  e.g. 2.1.2.7
#   MARLIN_DIR   (required)  clone destination
#   CONFIG_TAG   (optional)  tag/branch of the Configurations repo
#                            (default: release-<MARLIN_TAG>)
###############################################################################
set -euo pipefail
: "${MARLIN_TAG:?set MARLIN_TAG}"
: "${MARLIN_DIR:?set MARLIN_DIR}"
CONFIG_TAG="${CONFIG_TAG:-release-${MARLIN_TAG}}"
CONFIG_BASE_URL="https://raw.githubusercontent.com/MarlinFirmware/Configurations/${CONFIG_TAG}/config/examples/Creality/Ender-3/CrealityV422"

# Robust curl: IPv4, timeouts and retries (raw.githubusercontent can be flaky).
DL(){ curl -fsSL -4 --connect-timeout 20 --max-time 180 \
        --retry 8 --retry-delay 3 --retry-all-errors -o "$1" "$2"; }

echo "==> Cloning Marlin ${MARLIN_TAG} (Configurations: ${CONFIG_TAG})"
if [ ! -d "${MARLIN_DIR}/.git" ]; then
  git clone --depth 1 --branch "${MARLIN_TAG}" \
    https://github.com/MarlinFirmware/Marlin.git "${MARLIN_DIR}"
else
  echo "    clone already exists at ${MARLIN_DIR} (reused)"
fi

CFG="${MARLIN_DIR}/Marlin"
echo "==> Downloading official Creality/Ender-3/CrealityV422 configuration"
DL "${CFG}/Configuration.h"     "${CONFIG_BASE_URL}/Configuration.h"
DL "${CFG}/Configuration_adv.h" "${CONFIG_BASE_URL}/Configuration_adv.h"
# Custom boot/status screens are referenced by the official config.
DL "${CFG}/_Bootscreen.h"       "${CONFIG_BASE_URL}/_Bootscreen.h"
DL "${CFG}/_Statusscreen.h"     "${CONFIG_BASE_URL}/_Statusscreen.h"
echo "==> Source ready."
