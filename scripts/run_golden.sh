#!/usr/bin/env bash
# Purpose: Analyze, elaborate and run one configurable GOLDEN verification case.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."

# With no arguments, use the configuration in tb/config/tb_config_pkg.vhd.
# Otherwise: information bytes, rate denominator, input file, golden file.
if [[ $# != 0 && $# != 4 ]]; then
    echo "Usage: bash scripts/run_golden.sh [BLOCK_BYTES RATE_DENOMINATOR INPUT_PATH GOLDEN_PATH]" >&2
    exit 2
fi
mkdir -p build/ghdl output
ghdl -a --std=08 --workdir=build/ghdl \
    tb/config/tb_config_pkg.vhd \
    src/reference/turbo_types_pkg.vhd \
    src/reference/turbo_encoder_pkg.vhd \
    src/reference/turbo_interleaver_pkg.vhd \
    src/reference/turbo_serializer_pkg.vhd \
    src/reference/turbo_block_pkg.vhd \
    tb/packages/utils.pkg \
    tb/tb_turbo_reference.vhd
ghdl -e --std=08 --workdir=build/ghdl tb_turbo_reference
if [[ $# == 0 ]]; then
    ghdl -r --std=08 --workdir=build/ghdl tb_turbo_reference --assert-level=error
else
    ghdl -r --std=08 --workdir=build/ghdl tb_turbo_reference \
        "-gBLOCK_BYTES=$1" "-gRATE_DENOMINATOR=$2" \
        "-gINPUT_PATH=$3" "-gGOLDEN_PATH=$4" --assert-level=error
fi
