------------------------------------------------------------------------------
-- Package to fix all the types, constants and functions for the simulation of
-- the Grover algorithm
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

package grover_pkg is
    -- Algorithm fixed parameters
    constant N_QUBITS : integer := 3;          
    constant N : integer := 2**N_QUBITS;  -- Hilbert space dimension, i.e., total number of states N = 2^n
    constant k : integer := integer(floor(MATH_PI / 4.0 * sqrt(real(N)))); -- Optimal number of iterations k ~= pi/4 * sqrt(N)

    -- Fixed-point format
    constant FP_WIDTH : integer := 18;
    constant FP_FRAC : integer := 15;
    constant FP_SCALE : integer := 2**FP_FRAC;

    subtype fp_t is signed(FP_WIDTH-1 downto 0);
    
    -- 1 and 0 coefficients
    constant FP_ONE : fp_t := to_signed(FP_SCALE, FP_WIDTH); 
    constant FP_ZERO : fp_t := (others => '0');

    -- State vector
    type state_vec_t  is array(0 to N-1) of fp_t;
    -- Quantum gates matrices
    type matrix_row_t is array(0 to N-1) of fp_t;
    type matrix_t  is array(0 to N-1) of matrix_row_t;

    constant ACC_WIDTH : integer := 48;

    -- Helper functions
    function to_fp(x : real) return fp_t;
    function int_and(a, b, nbits : integer) return integer;
    function popcount(x, nbits : integer) return integer;

    -- Generate the matrix that corresponds to the application of an Hadamard port for each
    -- qubit to create superposition: H^xn|0> = (1/sqrt(N)) sum_x |x>
    function get_hadamard return matrix_t;

    -- Generate the diffusion operator matrix: D = H^xn * U * H^xn = 2|psi><psi| - Id
    -- where U = 2|0><0| - Id
    function get_diffusion return matrix_t;

end package grover_pkg;


package body grover_pkg is

    function to_fp(x : real) return fp_t is
        variable scaled : real;
        variable clamped : real;
        constant MAX_POS : real := real(2**(FP_WIDTH-1) - 1);
        constant MAX_NEG : real := real(-2**(FP_WIDTH-1));
    begin
        scaled := x * real(FP_SCALE);
        if scaled > MAX_POS then
            clamped := MAX_POS;
        elsif scaled < MAX_NEG then
            clamped := MAX_NEG;
        else
            clamped := scaled;
        end if;
        return to_signed(integer(clamped), FP_WIDTH);
    end function;

    function int_and(a, b, nbits : integer) return integer is
        variable ua : unsigned(nbits-1 downto 0);
        variable ub : unsigned(nbits-1 downto 0);
    begin
        ua := to_unsigned(a, nbits);
        ub := to_unsigned(b, nbits);
        return to_integer(ua and ub);
    end function;

    function popcount(x, nbits : integer) return integer is
        variable v : unsigned(nbits-1 downto 0);
        variable cnt : integer := 0;
    begin
        v := to_unsigned(x, nbits);
        for i in 0 to nbits-1 loop
            if v(i) = '1' then
                cnt := cnt + 1;
            end if;
        end loop;
        return cnt;
    end function;

    function get_hadamard return matrix_t is
        variable M : matrix_t;
        variable sign : real;
        variable ab : integer;
    begin
        for i in 0 to N-1 loop
            for j in 0 to N-1 loop
                ab := int_and(i, j, N_QUBITS);
                if (popcount(ab, N_QUBITS) mod 2) = 0 then
                    sign := 1.0;
                else
                    sign := -1.0;
                end if;
                M(i)(j) := to_fp(sign / sqrt(real(N)));
            end loop;
        end loop;
        return M;
    end function;

    function get_diffusion return matrix_t is
        variable M : matrix_t;
    begin
        for i in 0 to N-1 loop
            for j in 0 to N-1 loop
                if i = j then
                    M(i)(j) := to_fp(2.0/real(N) - 1.0);
                else
                    M(i)(j) := to_fp(2.0/real(N));
                end if;
            end loop;
        end loop;
        return M;
    end function;

end package body grover_pkg;
