#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FIRMWARE_DIR="${SCRIPT_DIR}/firmware"
WEST_CACHE="${SCRIPT_DIR}/.west-cache"
IMAGE="docker.io/zmkfirmware/zmk-dev-arm:stable"

# Use home dir for docker temp files to avoid /var/tmp space issues
export TMPDIR="${HOME}/tmp/zmk-build-tmp"
mkdir -p "${FIRMWARE_DIR}" "${WEST_CACHE}" "${TMPDIR}"

BUILD_START=$SECONDS

echo "=== ZMK Firmware Build: Ferris Sweep ==="
echo "Image: ${IMAGE}"
echo ""

docker run --rm \
    -v "${SCRIPT_DIR}/config:/config:ro,Z" \
    -v "${FIRMWARE_DIR}:/firmware:Z" \
    -v "${WEST_CACHE}:/cache:Z" \
    --network=host \
    "${IMAGE}" \
    /bin/bash -c '
        set -e
        cd /cache

        # Copy fresh config into cache workspace
        rm -rf config
        cp -r /config config

        # Initialize west workspace if needed
        if [ ! -d .west ]; then
            echo ">>> Initializing west workspace..."
            west init -l config
        fi

        echo ">>> Updating west modules..."
        west update

        # Set up Zephyr environment and register cmake package
        source /cache/zephyr/zephyr-env.sh
        west zephyr-export
        echo ">>> ZEPHYR_BASE=${ZEPHYR_BASE}"

        # Patch Z_DEVICE_MAX_NAME_LEN (hardcoded 48 in Zephyr 3.5, too short for ZMK behaviors)
        sed -i "s/#define Z_DEVICE_MAX_NAME_LEN.*48U/#define Z_DEVICE_MAX_NAME_LEN 64U/" \
            /cache/zephyr/include/zephyr/device.h

        # Patch zmk-behavior-battery-typer for ZMK v0.2: header path and function name were renamed upstream
        BAT_TYPER_SRC=/cache/zmk-behavior-battery-typer/src/behavior_bat_print.c
        if [ -f "${BAT_TYPER_SRC}" ]; then
            sed -i "s|<zmk/split/central.h>|<zmk/split/bluetooth/central.h>|" "${BAT_TYPER_SRC}"
            sed -i "s|zmk_split_central_get_peripheral_battery_level|zmk_split_get_peripheral_battery_level|g" "${BAT_TYPER_SRC}"
        fi

        BUILDS=(
            "nice_nano_v2|sweep_left"
            "nice_nano_v2|sweep_right"
            "seeeduino_xiao_ble|sweep_dongle"
            "nice_nano_v2|sweep_dongle_nano"
            "nice_nano_v2|settings_reset"
            "seeeduino_xiao_ble|settings_reset"
        )

        for build_spec in "${BUILDS[@]}"; do
            IFS="|" read -r board shield <<< "${build_spec}"
            build_name="${board}_${shield}"

            echo ""
            echo ">>> Building: board=${board} shield=${shield}"

            west build -s zmk/app -d "build/${build_name}" -b "${board}" -p -- \
                -DSHIELD="${shield}" \
                -DZMK_CONFIG=/cache/config \

            if [ -f "build/${build_name}/zephyr/zmk.uf2" ]; then
                cp "build/${build_name}/zephyr/zmk.uf2" "/firmware/${build_name}.uf2"
                echo "    -> ${build_name}.uf2"
            elif [ -f "build/${build_name}/zephyr/zmk.hex" ]; then
                cp "build/${build_name}/zephyr/zmk.hex" "/firmware/${build_name}.hex"
                echo "    -> ${build_name}.hex"
            fi
        done

        echo ""
        echo ">>> Build complete!"
    '

ELAPSED=$(( SECONDS - BUILD_START ))
echo ""
echo "=== Firmware files ==="
ls -lh "${FIRMWARE_DIR}/"
echo ""
printf "=== Build time: %dm %ds ===\n" $(( ELAPSED / 60 )) $(( ELAPSED % 60 ))
