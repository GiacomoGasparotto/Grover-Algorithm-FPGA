------------------------------------------------------------------------------
-- Matrix-vector multiplier.
-- Full version: N^2 DSP, every multiplication done in a single cycle.
-- Followed by a per-row reduction (sum) stage.
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.grover_pkg.all;

entity matvec_mult_full is
    port (
        clk : in std_logic;
        rst : in std_logic;
        start : in std_logic;
        matrix : in matrix_t;
        in_vec : in state_vec_t;
        out_vec : out state_vec_t;
        done : out std_logic
    );
end entity matvec_mult_full;

architecture rtl of matvec_mult_full is

    type mv_fsm_t is (IDLE, MULT, REDUCE, FINISH);
    signal fsm : mv_fsm_t := IDLE;

    type prod_array_t is array(0 to N-1, 0 to N-1) of signed(ACC_WIDTH-1 downto 0);
    signal prod : prod_array_t := (others => (others => (others => '0')));

    signal result_reg : state_vec_t := (others => (others => '0'));

begin

    process(clk)
        variable sum : signed(ACC_WIDTH-1 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                fsm <= IDLE;
                done <= '0';
                out_vec <= (others => (others => '0'));
            else
                done <= '0';
                case fsm is
                    when IDLE =>
                        if start = '1' then
                            fsm <= MULT;
                        end if;

                    when MULT =>
                        for r in 0 to N-1 loop
                            for c in 0 to N-1 loop
                                prod(r, c) <= resize(matrix(r)(c) * in_vec(c), ACC_WIDTH);
                            end loop;
                        end loop;
                        fsm <= REDUCE;

                    when REDUCE =>
                        for r in 0 to N-1 loop
                            sum := (others => '0');
                            for c in 0 to N-1 loop
                                sum := sum + prod(r, c);
                            end loop;
                            result_reg(r) <= sum(FP_FRAC+FP_WIDTH-1 downto FP_FRAC);
                        end loop;
                        fsm <= FINISH;

                    when FINISH =>
                        out_vec <= result_reg;
                        done <= '1';
                        fsm <= IDLE;
                end case;
            end if;
        end if;
    end process;

end architecture rtl;
