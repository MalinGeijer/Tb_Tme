-- Purpose: Calculate one component encoding step, shared by Turbo encoders A and B.

library ieee;
use ieee.std_logic_1164.all;

use work.turbo_types_pkg.all;
use work.tb_config_pkg.all;

package turbo_encoder_pkg is

    -- One component encoding step, shared by encoders A and B.
    -- The caller owns separate states and initializes each to all zeros.
    -- No clock, delay, interleaving, termination control, or rate selection.
    function encoder_step(
        input_bit : std_ulogic;
        d_state   : d_state_t
    ) return encoder_step_result_t;

end package turbo_encoder_pkg;

-- Component encoder overview
-- This function processes one bit at a time:
-- 1. Receive an input bit and the four memory bits in d_state.
-- 2. Calculate feedback from memory positions 3 and 4.
-- 3. XOR the input bit with the feedback to obtain a new internal bit.
-- 4. Calculate three parity bits from the internal bit and the old memory.
-- 5. Return the parity bits and the next memory state, with the new
--    internal bit inserted at position 1.
-- Memory allows earlier input bits to affect the parity outputs.
-- This is one component encoder. The complete Turbo model will use the
-- same function for A and B, with separate memories and interleaved input
-- for B.
package body turbo_encoder_pkg is

    function encoder_step(
        input_bit : std_ulogic;
        d_state   : d_state_t
    ) return encoder_step_result_t is
        variable feedback : std_ulogic := '0';
        variable taps     : std_ulogic_vector(0 to 4);
        variable result   : encoder_step_result_t;
    begin
        -- CCSDS 131.0-B-5, September 2023, 6.3 h), Figure 6-2.
        -- G0(D) = 1 + D**3 + D**4: feedback uses OLD delays 3 and 4.
        -- The D**0 term represents the internal bit, not a memory tap.
        for i in 1 to 4 loop
            feedback := feedback xor (G0(i) and d_state(i));
        end loop;

        -- taps(0) is the current internal bit after the feedback XOR.
        -- taps(1..4) are the OLD memory values throughout parity calculation.
        taps(0) := input_bit xor feedback;
        taps(1 to 4) := d_state;

        -- G1(D) = 1 + D + D**3 + D**4.
        -- G2(D) = 1 + D**2 + D**4.
        -- G3(D) = 1 + D + D**2 + D**3 + D**4.
        -- Calculate every parity output, independently of the coding rate.
        result.out1 := '0';
        result.out2 := '0';
        result.out3 := '0';
        for i in 0 to 4 loop
            result.out1 := result.out1 xor (G1(i) and taps(i));
            result.out2 := result.out2 xor (G2(i) and taps(i));
            result.out3 := result.out3 xor (G3(i) and taps(i));
        end loop;

        -- Shift only after calculating parity: new bit enters position 1;
        -- old positions 1..3 move to 2..4 and the oldest bit is discarded.
        result.next_state(1) := taps(0);
        result.next_state(2 to 4) := d_state(1 to 3);
        return result;
    end function encoder_step;

end package body turbo_encoder_pkg;
