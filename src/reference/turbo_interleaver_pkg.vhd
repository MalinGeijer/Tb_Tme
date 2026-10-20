-- Purpose: Calculate the Turbo interleaver permutation for supported information block lengths.

use work.turbo_types_pkg.all;

package turbo_interleaver_pkg is

    -- k is the information block length in BITS, not bytes.
    -- Return indices 1..k such that input_b(s) = input(permutation(s)).
    -- The caller maps these bit positions to its MSB-first byte storage.
    function interleaver_permutation(k : positive) return permutation_t;

end package turbo_interleaver_pkg;

-- Interleaver overview
-- 1. Validate the information block length and select k1 and k2.
-- 2. Calculate the source position pi(s) for each output position s.
-- 3. Return the complete address list; no input data is modified here.
-- Encoder A reads the original block in order. Encoder B reads the same
-- block using this list. Both s and pi(s) are one-based, as in the standard.
-- The permutation depends on block length only, not on coding rate.
-- Only information bits are permuted; termination is handled separately.
package body turbo_interleaver_pkg is

    function interleaver_permutation(k : positive) return permutation_t is
        -- CCSDS 131.0-B-5, Issue 5, September 2023,
        -- Section 6.3 g), Table 6-3, and Figure 6-1 (pages 6-3..6-5).
        constant k1 : positive := 8;
        type prime_array_t is array (1 to 8) of positive;
        constant primes : prime_array_t := (31, 37, 43, 47, 53, 59, 61, 67);
        variable k2     : positive;
        variable m      : natural;
        variable i      : natural;
        variable j      : natural;
        variable t      : natural;
        variable q      : positive;
        variable c      : natural;
        variable result : permutation_t(1 to k) := (others => 1);
    begin
        -- Table 6-3: reject unsupported lengths before doing the arithmetic.
        case k is
            when 1784 => k2 := 223;
            when 3568 => k2 := 223 * 2;
            when 7136 => k2 := 223 * 4;
            when 8920 => k2 := 223 * 5;
            when others =>
                assert false
                    report "Unsupported Turbo information block length: "
                           & integer'image(k) & " bits"
                    severity failure;
                -- Defensive exit if the simulator continues after failure.
                return result;
        end case;

        -- Keep the standard's variable names and evaluation order.
        -- All operands are nonnegative: integer division implements floor.
        for s in 1 to k loop
            m := (s - 1) mod 2;
            i := (s - 1) / (2 * k2);
            j := (s - 1) / 2 - i * k2;
            t := (19 * i + 1) mod (k1 / 2);
            q := (t mod 8) + 1;
            c := (primes(q) * j + 21 * m) mod k2;
            result(s) := 2 * (t + c * (k1 / 2) + 1) - m;
        end loop;

        -- This is a read-address mapping, not its inverse:
        -- the s-th input bit of encoder B is original bit result(s).
        return result;
    end function interleaver_permutation;

end package body turbo_interleaver_pkg;
