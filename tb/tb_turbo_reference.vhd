-- Purpose: Run one configured GOLDEN test and write calculated hex data and verification.log.
library ieee;
use ieee.std_logic_1164.all;
use std.textio.all;
use std.env.all;
use work.turbo_types_pkg.all;
use work.tb_config_pkg.all;
use work.turbo_block_pkg.all;
use work.utils.all;

entity tb_turbo_reference is
    generic (
        -- Configuration defaults live in tb/config; command-line generics
        -- can select another test without changing the encoding algorithm.
        BLOCK_BYTES : positive := CFG_BLOCK_BYTES;
        RATE_DENOMINATOR : positive := CFG_RATE_DENOMINATOR;
        INPUT_PATH : string := CFG_INPUT_PATH;
        GOLDEN_PATH : string := CFG_GOLDEN_PATH;
        OUTPUT_PATH : string := CFG_OUTPUT_PATH;
        LOG_PATH : string := CFG_LOG_PATH
    );
end entity;

-- GOLDEN flow overview
-- Validate configuration, read one information block, calculate its codeword,
-- write the result, then read and compare the independent golden file.
-- Close the log before reporting failure so diagnostics remain available.
-- No clock or DUT is required; all calculations take zero simulated time.
architecture golden of tb_turbo_reference is
begin
    verify : process
        file log_file : text;
        variable status : file_open_status;
        variable rate : coding_rate_t;
        variable input_data : ByteVec_T(0 to BLOCK_BYTES - 1);
        variable calculated, golden_data : ByteVec_T(
            0 to ((BLOCK_BYTES * 8 + 4) * RATE_DENOMINATOR) / 8 - 1);
        variable ok, passed : boolean;

        procedure finish_failure is
        begin
            file_close(log_file);
            report "Verification failed; see " & LOG_PATH severity error;
            finish(1);
        end procedure;
    begin
        -- Check before opening any output file, since write_mode truncates it.
        assert OUTPUT_PATH /= INPUT_PATH and OUTPUT_PATH /= GOLDEN_PATH and
               LOG_PATH /= INPUT_PATH and LOG_PATH /= GOLDEN_PATH and LOG_PATH /= OUTPUT_PATH
            report "Input, golden, result and log paths must be distinct"
            severity failure;
        file_open(status, log_file, LOG_PATH, write_mode);
        assert status = open_ok report "Cannot open verification log: " & LOG_PATH severity failure;
        log_message(log_file, "Mode: GOLDEN; block count: 1");
        log_message(log_file, "Information bytes: " & integer'image(BLOCK_BYTES));
        log_message(log_file, "Coding rate: 1/" & integer'image(RATE_DENOMINATOR));
        log_message(log_file, "Byte bit order: MSB first; no ASM or randomization added");
        if BLOCK_BYTES /= 223 and BLOCK_BYTES /= 446 and
           BLOCK_BYTES /= 892 and BLOCK_BYTES /= 1115 then
            log_message(log_file, "FAIL: Unsupported information byte length");
            finish_failure;
        end if;
        case RATE_DENOMINATOR is
            when 2 => rate := RATE_1_2;
            when 4 => rate := RATE_1_4;
            when 6 => rate := RATE_1_6;
            when others =>
                log_message(log_file, "FAIL: Supported rate denominators are 2, 4, 6");
                finish_failure;
        end case;
        log_message(log_file, "Input: " & INPUT_PATH);
        log_message(log_file, "Golden: " & GOLDEN_PATH);
        log_message(log_file, "Calculated output: " & OUTPUT_PATH);
        read_hex(INPUT_PATH, input_data, log_file, ok);
        if not ok then finish_failure; end if;
        calculated := encode_block(input_data, rate);
        log_message(log_file, "Calculated output bytes: " & integer'image(calculated'length));
        write_hex(OUTPUT_PATH, calculated, log_file, ok);
        if not ok then finish_failure; end if;
        read_hex(GOLDEN_PATH, golden_data, log_file, ok);
        if not ok then finish_failure; end if;
        compare_bytes(calculated, golden_data, log_file, passed);
        if not passed then finish_failure; end if;
        file_close(log_file);
        report "PASS; see " & LOG_PATH severity note;
        finish(0);
        wait;
    end process;
end architecture;
