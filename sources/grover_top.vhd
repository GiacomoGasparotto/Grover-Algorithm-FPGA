---------------------------------------------------------------------------------
-- FSM to run the Grover algorithm.
--
-- Steps:
-- 1. Initial vector initialization
-- 2. Apply Oracle operator
-- 3. Apply Diffuion operator
-- 4. Repeat k times
-- 5. Measure the outcome
---------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.grover_pkg.all;

entity grover_top is
    port (
        clk : in  std_logic;
        rst : in  std_logic;
        start : in  std_logic;
        marked_in : in  integer range 0 to N-1;
        done : out std_logic;
        result : out integer range 0 to N-1;
        psi_out : out state_vec_t
    );
end entity grover_top;

architecture rtl of grover_top is

    type grover_fsm_t is (
        IDLE, 
        INIT_PSI, 
        APPLY_H, WAIT_H, 
        ORACLE,
        APPLY_D, WAIT_D, 
        MEASURE, MEASURE_WAIT, 
        DONE_ST
    );
    signal fsm : grover_fsm_t := IDLE;

    signal psi : state_vec_t := (others => (others => '0'));
    signal marked_reg : integer range 0 to N-1 := 0;

    constant H_MAT : matrix_t := get_hadamard;
    constant D_MAT : matrix_t := get_diffusion;

    signal mv_start : std_logic := '0';
    signal mv_matrix : matrix_t;
    signal mv_out : state_vec_t;
    signal mv_done : std_logic;

    signal iter_cnt : integer range 0 to k := 0;

    signal meas_start : std_logic := '0';
    signal meas_done : std_logic;
    signal meas_result : integer range 0 to N-1;

begin

    u_matvec : entity work.matvec_mult_par  -- change the matrix-multiplication method
        port map (
            clk  => clk, rst => rst, 
            start => mv_start,
            matrix  => mv_matrix, 
            in_vec => psi,
            out_vec => mv_out, 
            done => mv_done
        );

    u_measure : entity work.measure_probabilistic
        port map (
            clk => clk, 
            rst => rst, 
            start => meas_start,
            psi_in => psi, 
            result => meas_result, 
            done => meas_done
        );

    psi_out <= psi;

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                fsm <= IDLE;
                psi <= (others => (others => '0'));
                mv_start <= '0';
                meas_start <= '0';
                iter_cnt <= 0;
                done <= '0';
                result <= 0;
                marked_reg <= 0;
            else
                mv_start <= '0';
                meas_start <= '0';
                done <= '0';

                case fsm is

                    when IDLE =>
                        if start = '1' then
                            marked_reg <= marked_in;
                            fsm <= INIT_PSI;
                        end if;

                    when INIT_PSI =>
                        for i in 0 to N-1 loop
                            if i = 0 then
                                psi(i) <= FP_ONE;
                            else
                                psi(i) <= FP_ZERO;
                            end if;
                        end loop;
                        iter_cnt <= 0;
                        fsm <= APPLY_H;

                    when APPLY_H =>
                        mv_matrix <= H_MAT;
                        mv_start <= '1';
                        fsm <= WAIT_H;

                    when WAIT_H =>
                        if mv_done = '1' then
                            psi <= mv_out;
                            fsm <= ORACLE;
                        end if;

                    when ORACLE =>
                        -- Instead of using a full matrix, we can just negate the marked component
                        psi(marked_reg) <= -psi(marked_reg);
                        fsm <= APPLY_D;

                    when APPLY_D =>
                        mv_matrix <= D_MAT;
                        mv_start  <= '1';
                        fsm <= WAIT_D;

                    when WAIT_D =>
                        if mv_done = '1' then
                            psi <= mv_out;
                            iter_cnt <= iter_cnt + 1;
                            if iter_cnt = k - 1 then
                                fsm <= MEASURE;
                            else
                                fsm <= ORACLE;
                            end if;
                        end if;

                    when MEASURE =>
                        meas_start <= '1';
                        fsm <= MEASURE_WAIT;

                    when MEASURE_WAIT =>
                        if meas_done = '1' then
                            result <= meas_result;
                            fsm <= DONE_ST;
                        end if;

                    when DONE_ST =>
                        done <= '1';
                        fsm  <= IDLE;

                end case;
            end if;
        end if;
    end process;

end architecture rtl;