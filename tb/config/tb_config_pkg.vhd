-- Purpose: Define testbench configuration, including coding rate, information block length, file paths, and file formats.

library ieee;
use ieee.std_logic_1164.all;

package tb_config_pkg is

    -- Fixed CCSDS code definitions, not freely selectable test parameters.
    -- Source: CCSDS 131.0-B-5, Issue 5, September 2023,
    -- Section 6.3 h), Figure 6-2 (page 6-5), and page 6-6.
    -- https://ccsds.org/Pubs/131x0b5.pdf
    --
    -- Connection vectors retain the literal order given in Section 6.3 h).
    -- The leftmost literal bit has index 0; the rightmost has index 4.
    -- Verified against Figure 6-2 in the local standard PDF:
    -- index i is the coefficient of D**i (ascending delay order).
    -- G0 feedback taps are the third and fourth delay registers.

    -- G0: feedback for both component encoders.
    constant G0 : std_ulogic_vector(0 to 4) := "10011";

    -- G1: parity output out1a / out1b.
    constant G1 : std_ulogic_vector(0 to 4) := "11011";

    -- G2: parity output out2a / out2b.
    constant G2 : std_ulogic_vector(0 to 4) := "10101";

    -- G3: parity output out3a / out3b.
    constant G3 : std_ulogic_vector(0 to 4) := "11111";

    -- All parity outputs will be calculated for each encoder.
    -- Code rate controls subsequent output selection and puncturing only.

end package tb_config_pkg;
