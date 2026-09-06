------------------------------------------------------------------------------
-- Matrix-vector multiplier. 
-- Parallel version: N DSP, one for each row of the matrix. 
-- At each cycle all the rows shift of one column.
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.grover_pkg.all;


entity matvec_mult_par is
    port (
        clk : in  std_logic;
        rst : in  std_logic;
        start : in  std_logic;
        matrix : in  matrix_t;
        in_vec : in  state_vec_t;
        out_vec : out state_vec_t;
        done : out std_logic
    );
end entity matvec_mult_par;

architecture rtl of matvec_mult_par is

    type mv_fsm_t is (IDLE, MAC, STORE, FINISH);
    signal fsm : mv_fsm_t := IDLE;
    signal col : integer range 0 to N-1 := 0;

    type acc_array_t is array(0 to N-1) of signed(ACC_WIDTH-1 downto 0);
    signal acc : acc_array_t := (others => (others => '0'));

    signal result_reg : state_vec_t := (others => (others => '0'));

begin

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                fsm <= IDLE;
                col <= 0;
                done <= '0';
                out_vec <= (others => (others => '0'));
                for i in 0 to N-1 loop
                    acc(i) <= (others => '0');
                end loop;
            else
                done <= '0';
                case fsm is
                    when IDLE =>
                        if start = '1' then
                            col <= 0;
                            for i in 0 to N-1 loop
                                acc(i) <= (others => '0');
                            end loop;
                            fsm <= MAC;
                        end if;

                    when MAC =>
                        for row in 0 to N-1 loop
                            acc(row) <= acc(row) + resize(matrix(row)(col) * in_vec(col), ACC_WIDTH);
                        end loop;
                        if col = N-1 then
                            fsm <= STORE;
                        else
                            col <= col + 1;
                        end if;

                    when STORE =>
                        for row in 0 to N-1 loop
                            result_reg(row) <= acc(row)(FP_FRAC + FP_WIDTH - 1 downto FP_FRAC);
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
