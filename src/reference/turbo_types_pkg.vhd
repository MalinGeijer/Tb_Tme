-- Purpose: Define shared data types for the behavioral Turbo Encoder reference model.

library ieee;
use ieee.std_logic_1164.all;

package turbo_types_pkg is

    -- Temporary local byte-array type until the DUT's shared type is available.
    -- Each byte uses bits 7 downto 0; stream order is MSB first.
    -- The caller chooses the array bounds; its length is not fixed to 892.
    -- Replace this declaration with the shared type when integrating the DUT:
    -- separately declared array types are distinct even with the same name.
    type ByteVec_T is array (natural range <>) of std_ulogic_vector(7 downto 0);

    -- Coding rates supported by this project; rate 1/3 is excluded.
    type coding_rate_t is (RATE_1_2, RATE_1_4, RATE_1_6);

    -- One-based source bit positions for the Turbo interleaver.
    -- Entry s identifies the original input bit to read at step s.
    type permutation_t is array (positive range <>) of positive;

    -- Component encoder memory, indexed by delay (Figure 6-2).
    -- Index 1 is the newest stored bit; index 4 is the oldest.
    -- These are internal feedback-XOR results, not raw information bits.
    subtype d_state_t is std_ulogic_vector(1 to 4);

    -- All three parity outputs belong to the current encoding step.
    -- next_state is the memory to use for the following step.
    type encoder_step_result_t is record
        next_state : d_state_t;
        out1       : std_ulogic;
        out2       : std_ulogic;
        out3       : std_ulogic;
    end record;

end package turbo_types_pkg;
