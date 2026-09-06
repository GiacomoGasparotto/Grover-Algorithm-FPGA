------------------------------------------------------------------------------
-- Matrix-vector multiplier.
-- Sequential version: 1 DSP, reused for every (row, column) pair.
-- N^2+N+2 cycles total -- slow, resource-minimal reference baseline.
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.grover_pkg.all;

entity matvec_mult_seq is
    port (
        clk : in  std_logic;
        rst : in  std_logic;
        start : in  std_logic;
        matrix : in  matrix_t;
        in_vec : in  state_vec_t;
        out_vec : out state_vec_t;
        done : out std_logic
    );
end entity matvec_mult_seq;

architecture rtl of matvec_mult_seq is

    type mv_fsm_t is (IDLE, MAC, STORE_ROW, FINISH);
    signal fsm : mv_fsm_t := IDLE;

    signal row, col : integer range 0 to N-1 := 0;
    signal acc : signed(ACC_WIDTH-1 downto 0) := (others => '0');
    signal result_reg : state_vec_t := (others => (others => '0'));

begin

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                fsm <= IDLE;
                row <= 0; col <= 0;
                acc <= (others => '0');
                done <= '0';
                out_vec <= (others => (others => '0'));
            else
                done <= '0';
                case fsm is
                    when IDLE =>
                        if start = '1' then
                            row <= 0; col <= 0;
                            acc <= (others => '0');
                            fsm <= MAC;
                        end if;

                    when MAC =>
                        acc <= acc + resize(matrix(row)(col) * in_vec(col), ACC_WIDTH);
                        if col = N-1 then
                            fsm <= STORE_ROW;
                        else
                            col <= col + 1;
                        end if;

                    when STORE_ROW =>
                        result_reg(row) <= acc(FP_FRAC+FP_WIDTH-1 downto FP_FRAC);
                        if row = N-1 then
                            fsm <= FINISH;
                        else
                            row <= row + 1;
                            col <= 0;
                            acc <= (others => '0');
                            fsm <= MAC;
                        end if;

                    when FINISH =>
                        out_vec <= result_reg;
                        done <= '1';
                        fsm <= IDLE;
                end case;
            end if;
        end if;
    end process;

end architecture rtl;
