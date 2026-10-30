-- Purpose: Define testbench configuration, including coding rate, information block length, file paths, and file formats.

package tb_config_pkg is

    -- Initial GOLDEN test configuration, overridable by testbench generics.
    -- Information byte lengths: 223, 446, 892, 1115; rate denominators: 2, 4, 6.
    -- Select a matching independent golden file whenever changing the rate
    -- or information length. Current supplied vectors cover 892 bytes only.
    constant CFG_BLOCK_BYTES : positive := 892;
    constant CFG_RATE_DENOMINATOR : positive := 2;
    constant CFG_INPUT_PATH : string := "testvectors/input/input892bytes.hex";
    constant CFG_GOLDEN_PATH : string := "testvectors/golden/outRate2.hex";
    constant CFG_OUTPUT_PATH : string := "output/reference_output.hex";
    constant CFG_LOG_PATH : string := "output/verification.log";

end package tb_config_pkg;
