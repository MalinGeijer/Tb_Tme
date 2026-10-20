-- Purpose: Select and serialize component encoder outputs for the supported Turbo coding rates.

library ieee;
use ieee.std_logic_1164.all;

use work.turbo_types_pkg.all;

package turbo_serializer_pkg is

    -- Select one step's outputs in transmission order, first bit at index 1.
    -- Return 2, 4, or 6 bits depending on coding_rate; no byte packing here.
    -- step starts at 1 for each block and continues through termination.
    -- systematic_bit is A's input: information, then A's feedback tail bits.
    function select_and_serialize(
        systematic_bit : std_ulogic;
        encoder_a      : encoder_step_result_t;
        encoder_b      : encoder_step_result_t;
        coding_rate    : coding_rate_t;
        step           : positive
    ) return std_ulogic_vector;

end package turbo_serializer_pkg;

-- Output selection and serialization overview
-- 1. Receive the systematic bit and both encoders' current parity bits.
-- 2. Select the outputs required by the configured coding rate.
-- 3. Return those bits in transmission order for this encoding step.
-- At rate 1/2, retain A's out1 on odd steps and B's out1 on even steps.
-- This punctures alternating parity bits; both encoders still advance.
-- At rates 1/4 and 1/6, use the fixed output sequences without puncturing.
-- Apply the same rules during termination, without resetting step parity.
-- This function neither changes encoder states nor adds ASM or padding.
package body turbo_serializer_pkg is

    function select_and_serialize(
        systematic_bit : std_ulogic;
        encoder_a      : encoder_step_result_t;
        encoder_b      : encoder_step_result_t;
        coding_rate    : coding_rate_t;
        step           : positive
    ) return std_ulogic_vector is
        variable result : std_ulogic_vector(1 to 6);
    begin
        -- CCSDS 131.0-B-5, Issue 5, September 2023,
        -- Section 6.3 h)..j), Figures 6-2 and 6-3, pages 6-5..6-8.
        -- out0a is always the first transmitted bit of each step.
        result(1) := systematic_bit;

        case coding_rate is
            when RATE_1_2 =>
                -- Step 1 retains out1a and punctures out1b; step 2 reverses.
                if step mod 2 = 1 then
                    result(2) := encoder_a.out1;
                else
                    result(2) := encoder_b.out1;
                end if;
                return result(1 to 2);

            when RATE_1_4 =>
                -- out0a, out2a, out3a, out1b.
                result(2) := encoder_a.out2;
                result(3) := encoder_a.out3;
                result(4) := encoder_b.out1;
                return result(1 to 4);

            when RATE_1_6 =>
                -- out0a, out1a, out2a, out3a, out1b, out3b.
                result(2) := encoder_a.out1;
                result(3) := encoder_a.out2;
                result(4) := encoder_a.out3;
                result(5) := encoder_b.out1;
                result(6) := encoder_b.out3;
                return result;
        end case;
    end function select_and_serialize;

end package body turbo_serializer_pkg;
