#!/bin/bash
set -e

# Configuration
BOARD="nice_nano"
LEFT_SHIELD="corne_left nice_view_adapter nice_view"
RIGHT_SHIELD="corne_right nice_view_adapter nice_view"
DOCKER_IMAGE="zmkfirmware/zmk-build-arm:stable"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}Building Miryoku ZMK Firmware${NC}"
echo -e "${BLUE}=====================================${NC}"

# Get absolute paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="${SCRIPT_DIR}"

# Create output directory
OUTPUT_DIR="${WORKSPACE}/firmware"
mkdir -p "$OUTPUT_DIR"

# Step 1: Setup ZMK environment if needed
if [ ! -d "zmk/.west" ] || [ ! -d "zmk/zephyr" ]; then
  echo -e "\n${BLUE}Step 1: Setting up ZMK environment (this may take 10-15 minutes on first run)...${NC}"
  docker run --rm \
    -v "${WORKSPACE}:/workspace" \
    -w /workspace \
    "$DOCKER_IMAGE" \
    /bin/bash -c "
      set -e
      
      # Clone ZMK if not present
      if [ ! -d zmk ]; then
        echo 'Cloning ZMK repository...'
        git clone -b main --depth 1 https://github.com/zmkfirmware/zmk.git zmk
      fi
      
      # Setup ZMK
      cd zmk
      if [ ! -f .west/config ]; then
        echo 'Initializing west...'
        west init -l app/ 2>/dev/null || true
      fi
      echo 'Updating dependencies (this is the slow part)...'
      west update
      echo 'Exporting Zephyr environment...'
      west zephyr-export
      
      echo 'ZMK environment setup complete!'
    "
  
  if [ $? -ne 0 ]; then
    echo -e "${RED}Setup failed. Please check errors above.${NC}"
    exit 1
  fi
else
  echo -e "\n${BLUE}ZMK environment already set up, skipping...${NC}"
fi

# Step 2: Build left half
echo -e "\n${GREEN}Step 2: Building left half...${NC}"
docker run --rm \
  -v "${WORKSPACE}:/workspace" \
  -w /workspace \
  "$DOCKER_IMAGE" \
  /bin/bash -c "
    set -e
    cd zmk/app
    west build -p -d build/left -b ${BOARD} -- \
      -DSHIELD='${LEFT_SHIELD}' \
      -DZMK_CONFIG=/workspace/config
    cp build/left/zephyr/zmk.uf2 /workspace/firmware/corne_left-nice_nano_v2.uf2
  "

if [ $? -ne 0 ]; then
  echo -e "${RED}Left build failed. Please check errors above.${NC}"
  exit 1
fi

# Step 3: Build right half
echo -e "\n${GREEN}Step 3: Building right half...${NC}"
docker run --rm \
  -v "${WORKSPACE}:/workspace" \
  -w /workspace \
  "$DOCKER_IMAGE" \
  /bin/bash -c "
    set -e
    cd zmk/app
    west build -p -d build/right -b ${BOARD} -- \
      -DSHIELD='${RIGHT_SHIELD}' \
      -DZMK_CONFIG=/workspace/config
    cp build/right/zephyr/zmk.uf2 /workspace/firmware/corne_right-nice_nano_v2.uf2
  "

if [ $? -ne 0 ]; then
  echo -e "${RED}Right build failed. Please check errors above.${NC}"
  exit 1
fi

echo -e "\n${GREEN}=====================================${NC}"
echo -e "${GREEN}Build complete!${NC}"
echo -e "${GREEN}=====================================${NC}"
echo -e "Firmware files saved to: ${OUTPUT_DIR}"
echo -e "  - corne_left-nice_nano_v2.uf2"
echo -e "  - corne_right-nice_nano_v2.uf2"
echo -e "\n${BLUE}To flash:${NC}"
echo -e "1. Put keyboard in bootloader mode (double-tap reset)"
echo -e "2. Copy the corresponding .uf2 file to the bootloader drive"
