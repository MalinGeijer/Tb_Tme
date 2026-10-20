-- Purpose: Encode one complete information block independently of files and DUT timing.
library ieee;
use ieee.std_logic_1164.all;
use work.turbo_types_pkg.all;
use work.tb_config_pkg.all;
use work.turbo_encoder_pkg.all;
use work.turbo_interleaver_pkg.all;
use work.turbo_serializer_pkg.all;

package turbo_block_pkg is
    function encoded_byte_count(input_bytes : positive; rate : coding_rate_t)
        return positive;
    function encode_block(data : ByteVec_T; rate : coding_rate_t) return ByteVec_T;
end package;

-- Block encoding overview
-- Read bytes in array order and bits MSB first. Feed A in original order
-- and B through the standard permutation, with separate zeroed states.
-- After the information bits, terminate each encoder with its own feedback.
-- Serialize every step and pack the first transmitted bit into byte bit 7.
-- No ASM, randomization, file handling, or hardware timing is included.
package body turbo_block_pkg is
    function encoded_byte_count(input_bytes : positive; rate : coding_rate_t)
        return positive is
        variable denominator : positive;
    begin
        case rate is
            when RATE_1_2 => denominator := 2;
            when RATE_1_4 => denominator := 4;
            when RATE_1_6 => denominator := 6;
        end case;
        -- CCSDS 131.0-B-5, 6.3 f), Table 6-2: n = (k + 4) / r.
        return ((input_bytes * 8 + 4) * denominator) / 8;
    end function;

    function encode_block(data : ByteVec_T; rate : coding_rate_t) return ByteVec_T is
        constant k : positive := data'length * 8;
        constant addresses : permutation_t(1 to k) := interleaver_permutation(k);
        -- Normalize any caller-supplied array bounds to byte positions 0..N-1.
        constant bytes : ByteVec_T(0 to data'length - 1) := data;
        variable bits : std_ulogic_vector(1 to k);
        variable d_state_a, d_state_b : d_state_t := (others => '0');
        variable a, b : encoder_step_result_t;
        variable input_a, input_b : std_ulogic;
        variable result : ByteVec_T(0 to encoded_byte_count(data'length, rate) - 1)
            := (others => (others => '0'));
        variable position : natural := 0;

        procedure append_bits(value : std_ulogic_vector) is
        begin
            for i in value'range loop
                result(position / 8)(7 - position mod 8) := value(i);
                position := position + 1;
            end loop;
        end procedure;
    begin
        for s in 1 to k loop
            bits(s) := bytes((s - 1) / 8)(7 - (s - 1) mod 8);
            assert bits(s) = '0' or bits(s) = '1'
                report "Non-binary information bit at position " & integer'image(s)
                severity failure;
        end loop;
        for s in 1 to k + 4 loop
            if s <= k then
                input_a := bits(s);
                input_b := bits(addresses(s));
            else
                -- 6.3 j), Figure 6-2: input equals feedback during termination.
                -- This makes the internal feedback-XOR result zero in each encoder.
                input_a := '0';
                input_b := '0';
                for i in 1 to 4 loop
                    input_a := input_a xor (G0(i) and d_state_a(i));
                    input_b := input_b xor (G0(i) and d_state_b(i));
                end loop;
            end if;
            a := encoder_step(input_a, d_state_a);
            b := encoder_step(input_b, d_state_b);
            append_bits(select_and_serialize(input_a, a, b, rate, s));
            d_state_a := a.next_state;
            d_state_b := b.next_state;
        end loop;
        assert d_state_a = "0000" and d_state_b = "0000"
            report "Trellis termination did not reach zero states" severity failure;
        assert position = result'length * 8
            report "Encoded output length mismatch" severity failure;
        return result;
    end function;
end package body;
