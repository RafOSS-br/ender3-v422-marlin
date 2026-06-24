# Marlin builder for Ender-3 / Creality V4.2.2 board (STM32F103RET6)
# Base image widely used for PlatformIO/Marlin builds: the official Python image.
# No dependency is installed on the host: everything lives inside this container.
FROM python:3.11-bookworm

# git to clone Marlin; the STM32 toolchain is downloaded by PlatformIO itself.
RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Pinned PlatformIO Core for a reproducible build (compatible with Marlin 2.1.2.x).
RUN pip install --no-cache-dir platformio==6.1.16

# The PlatformIO cache (platforms/toolchains) lives inside the mounted workspace,
# so re-runs reuse the download and the build becomes faster/reproducible.
ENV PLATFORMIO_CORE_DIR=/workspace/.pio_cache \
    PYTHONUNBUFFERED=1

WORKDIR /workspace

# The build script lives in the mounted directory (reproducible and editable
# without rebuilding the image).
CMD ["bash", "/workspace/build.sh"]
