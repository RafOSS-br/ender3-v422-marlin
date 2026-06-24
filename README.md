# Marlin Firmware — Ender-3 / Creality V4.2.2 (STM32F103RET6)

**Reproducible** custom Marlin firmware builds for the original Ender-3 with the
**Creality V4.2.2** board, using **manual mesh bed leveling (no probe)**, in
multiple **languages** and **mesh** sizes — via Docker (local) and GitHub Actions
(automated releases).

| Item | Value |
|------|-------|
| Board | Creality V4.2.2 (`BOARD_CREALITY_V422`) |
| MCU | STM32F103RET6 (512K) |
| PlatformIO env | `STM32F103RE_creality` |
| Display | 12864 / knob LCD (`CR10_STOCKDISPLAY` + `RET6_12864_LCD`) |
| Probe | None (no BLTouch / no CR-Touch) |
| Leveling | Manual Mesh Bed Leveling (5×5, 7×7, …) + a no-compensation `default` baseline |
| Default language | Brazilian Portuguese (`pt_br`) — also `en`, etc. |
| Name | `Ender-3` |
| Bootloader | Creality stock (offset `0x7000`) |
| Marlin base | `2.1.2.7` (Configurations `release-2.1.2.7`) |

---

## Repository layout

```
.
├── Dockerfile                 # image with PlatformIO (local build without touching the host)
├── build.sh                   # LOCAL build of 1 variant (thin wrapper)
├── scripts/
│   ├── fetch-marlin.sh        # clone Marlin + download official configs (1x per version)
│   ├── apply-config.sh        # apply board/language/mesh/name  (1x per variant)
│   └── compile.sh             # compile and extract the renamed .bin
└── .github/workflows/
    └── release.yml            # CI pipeline: matrix build + release
```

The same `scripts/*.sh` are used **both in local Docker and in CI** — identical
behavior, no duplicated logic.

> Everything downloaded/generated (`Marlin/`, `.pio_cache/`, `output/`, `dist/`,
> `*.bin`) is in `.gitignore` and is **not** versioned — it is 100% reproducible.

---

## Local build (Docker)

```bash
# 1) image (installs PlatformIO in the container)
docker build -t marlin-ender3-v422 .

# 2) build the default variant (pt_br + 5x5 mesh) -> output/firmware.bin
docker run --rm -v "$PWD":/workspace marlin-ender3-v422

# Other variants via environment variables:
docker run --rm -e LCD_LANG=en  -e MESH_GRID=7      -v "$PWD":/workspace marlin-ender3-v422
docker run --rm -e LEVELING=none                    -v "$PWD":/workspace marlin-ender3-v422
docker run --rm -e MARLIN_TAG=2.1.2.5               -v "$PWD":/workspace marlin-ender3-v422
```

Result: **`output/firmware.bin`** + a copy of the final configs used.

### Accepted variables
| Variable | Default | Description |
|----------|---------|-------------|
| `MARLIN_TAG` | `2.1.2.7` | Marlin version |
| `LCD_LANG` | `pt_br` | language (Marlin code, **lowercase**) |
| `LEVELING` | `manual_mesh` | `manual_mesh` or `none` (stock, no compensation) |
| `MESH_GRID` | `5` | manual mesh NxN (ignored when `LEVELING=none`) |
| `MOTHERBOARD` | `BOARD_CREALITY_V422` | board |
| `MACHINE_NAME` | `Ender-3` | printer name |

---

## CI pipeline (GitHub Actions) — `release.yml`

Builds the **release assets** automatically, versioned by the Marlin version.

### Triggers
- **Manual** (`workflow_dispatch`): pick Marlin version, languages, profiles and `force`.
- **Scheduled** (`schedule`, Mondays 06:00 UTC): detects the **latest stable Marlin
  release**; if no release has been published for that version yet, builds and
  publishes it.

### Profiles
A **profile** is the leveling axis of the matrix:
- `default` — no bed compensation (stock Marlin baseline; level with the bed screws).
- `meshNxN` — manual mesh bed leveling with an N×N grid (e.g. `mesh5x5`, `mesh7x7`).

### Jobs (multi-step, optimized)
1. **resolve** — figures out the Marlin version (input or latest release), builds the
   `language × profile` **matrix** and decides whether to build (skips if the release
   already exists — idempotent).
2. **prepare** — clones Marlin and downloads the configs **once**, **warms the
   toolchain** (`pio pkg install`) and saves the **PlatformIO cache**. Packs the
   source as an artifact for reuse.
3. **build** (matrix) — downloads the prepared source (**no re-clone**), **restores the
   toolchain cache** (**no re-download**), applies the variant config and compiles.
   Uploads each `.bin` as an artifact.
4. **release** — gathers all `.bin` files, generates `SHA256SUMS.txt` and
   **creates/updates** the release with tag = Marlin version.

### Reuse / optimizations
- **Single clone** of Marlin (`prepare` job) → reused by the whole matrix via artifact.
- **Single downloads** of configs and the **ARM toolchain** (`~/.platformio` cache
  keyed by Marlin version) → not repeated per variant nor across runs.
- **pip cache** (`actions/setup-python`).
- Parallel matrix with `fail-fast: false` (a broken variant does not take the others down).

### Output
With the defaults (`languages: en,pt_br,de,es,fr` × `profiles: default,mesh5x5,mesh7x7`)
that is **5 × 3 = 15 variants**. Each `.bin` ships its own `.bin.sha256` (same name), so
the release has **15 `.bin` + 15 `.sha256` = 30 assets**, e.g.:
```
Ender3-V422_Marlin-2.1.2.7_en_default.bin       (+ .bin.sha256)
Ender3-V422_Marlin-2.1.2.7_en_mesh5x5.bin       (+ .bin.sha256)
Ender3-V422_Marlin-2.1.2.7_en_mesh7x7.bin       (+ .bin.sha256)
Ender3-V422_Marlin-2.1.2.7_pt_br_default.bin    (+ .bin.sha256)
Ender3-V422_Marlin-2.1.2.7_pt_br_mesh5x5.bin    (+ .bin.sha256)
... (de, es, fr × default/mesh5x5/mesh7x7)
```
Verify one with: `sha256sum -c <file>.bin.sha256`.

### Adding languages/profiles
On the manual trigger, fill in `languages` (e.g. `en,pt_br,de,es,fr,it`) and `profiles`
(e.g. `default,mesh3x3,mesh5x5,mesh7x7`). The variant count is
`#languages × #profiles`. Scheduled (periodic) runs use the defaults
`en,pt_br,de,es,fr` × `default,mesh5x5,mesh7x7`.

---

## Configuration changes explained

Base = the **official** `config/examples/Creality/Ender-3/CrealityV422` configuration
(MarlinFirmware/Configurations repo). Applied in `scripts/apply-config.sh`:

### `Configuration.h`
| Change | From → To | Reason |
|--------|-----------|--------|
| `MOTHERBOARD` | `BOARD_CREALITY_V4` → `BOARD_CREALITY_V422` | target board V4.2.2 (`pins_CREALITY_V422.h`) |
| `LCD_LANGUAGE` | `en` → `${LCD_LANG}` (e.g. `pt_br`) | interface language |
| `CUSTOM_MACHINE_NAME` | `"Ender-3 4.2.2"` → `"Ender-3"` | requested name |
| `MESH_BED_LEVELING` † | off → **on** | **manual** mesh leveling (no probe) |
| `RESTORE_LEVELING_AFTER_G28` † | off → **on** | re-apply the mesh after each homing |
| `LCD_BED_LEVELING` + `MESH_EDIT_MENU` † | off → **on** | guided menu / mesh editing from the knob |
| `GRID_MAX_POINTS_X` (MBL block) † | `3` → `${MESH_GRID}` | NxN mesh (Y follows X) |

† Only for `meshNxN` profiles. The `default` profile keeps the official values
(no bed compensation).

**Already correct in the base (unchanged):** `CR10_STOCKDISPLAY` + `RET6_12864_LCD`
(12864/knob display for the RET6), `EEPROM_SETTINGS` (stores the mesh), no probe.

### `Configuration_adv.h`
No change needed — kept identical to the official Ender-3 V4.2.2 file.

---

## PlatformIO environment

STM32F103RET6 = the **RE (512K)** variant → env **`STM32F103RE_creality`**, which sets
`board_build.offset = 0x7000` — exactly what the **Creality stock bootloader** expects
(flash via microSD, no need to replace the bootloader).

## Compatibility fixes applied (and why)

1. **`pt_BR` → `pt_br`** — Marlin builds the include `language_<LCD_LANGUAGE>.h` and the
   file is `language_pt_br.h` (lowercase). `pt_BR` breaks the build
   (`fatal error: language_pt_BR.h: No such file or directory`).
2. **`_Bootscreen.h` / `_Statusscreen.h`** — the official config enables custom
   boot/status screens; those 2 headers must be downloaded along with the configs.
3. **Diverging board in the base** — the official example ships `BOARD_CREALITY_V4`;
   the scripts force `BOARD_CREALITY_V422`.
4. **Artifact name** — the Creality env produces `firmware-{date}-{time}.bin`; the
   scripts locate and rename it to the final name.

---

## Flashing the printer
Copy the desired `.bin` to an **empty FAT32 microSD**, insert it with the printer
**off** and power on. The bootloader flashes and renames the file. Always use a **new
file name** for future flashes (the bootloader ignores a file already flashed with the
same name).
