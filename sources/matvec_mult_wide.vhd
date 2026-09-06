------------------------------------------------------------------------------
-- Matrix-vector multiplier.
-- Wide version: N*LANES DSP, a parametric middle ground between par and full.
-- LANES elements of each row are processed together per cycle.
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.grover_pkg.all;

entity matvec_mult_wide is
    generic (
        LANES : integer := 4
    );
    port (
        clk : in std_logic;
        rst : in std_logic;
        start : in std_logic;
        matrix : in matrix_t;
        in_vec : in state_vec_t;
        out_vec : out state_vec_t;
        done : out std_logic
    );
end entity matvec_mult_wide;

architecture rtl of matvec_mult_wide is

    constant GROUPS : integer := (N + LANES - 1) / LANES;

    type mv_fsm_t is (IDLE, MAC, STORE, FINISH);
    signal fsm : mv_fsm_t := IDLE;
    signal grp : integer range 0 to GROUPS-1 := 0;

    type acc_array_t is array(0 to N-1) of signed(ACC_WIDTH-1 downto 0);
    signal acc : acc_array_t := (others => (others => '0'));
    signal result_reg : state_vec_t := (others => (others => '0'));

begin

    process(clk)
        variable col_idx : integer range 0 to N-1;
        variable partial : signed(ACC_WIDTH-1 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                fsm <= IDLE; grp <= 0; done <= '0';
                out_vec <= (others => (others => '0'));
                for i in 0 to N-1 loop
                    acc(i) <= (others => '0');
                end loop;
            else
                done <= '0';
                case fsm is
                    when IDLE =>
                        if start = '1' then
                            grp <= 0;
                            for i in 0 to N-1 loop
                                acc(i) <= (others => '0');
                            end loop;
                            fsm <= MAC;
                        end if;

                    when MAC =>
                        for row in 0 to N-1 loop
                            partial := (others => '0');
                            for lane in 0 to LANES-1 loop
                                col_idx := grp*LANES + lane;
                                if col_idx < N then
                                    partial := partial + resize(matrix(row)(col_idx) * in_vec(col_idx), ACC_WIDTH);
                                end if;
                            end loop;
                            acc(row) <= acc(row) + partial;
                        end loop;
                        if grp = GROUPS-1 then
                            fsm <= STORE;
                        else
                            grp <= grp + 1;
                        end if;

                    when STORE =>
                        for row in 0 to N-1 loop
                            result_reg(row) <= acc(row)(FP_FRAC+FP_WIDTH-1 downto FP_FRAC);
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
