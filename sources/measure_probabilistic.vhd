------------------------------------------------------------------------------
-- Emulator of the measurement statistics of a real quantum circuit.
-- Sample a state with probability proportional to the square of the amplitude.
------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.grover_pkg.all;

entity measure_probabilistic is
    port (
        clk : in  std_logic;
        rst : in  std_logic;
        start : in  std_logic;
        psi_in : in  state_vec_t;
        result : out integer range 0 to N-1;
        done : out std_logic
    );
end entity measure_probabilistic;

architecture rtl of measure_probabilistic is

    signal lfsr : std_logic_vector(31 downto 0) := x"ACE1ACE1";

    type ms_fsm_t is (IDLE, SCAN, FINISH);
    signal fsm : ms_fsm_t := IDLE;

    signal idx : integer range 0 to N-1 := 0;
    signal cum_sum : unsigned(ACC_WIDTH-1 downto 0) := (others => '0');
    signal threshold : unsigned(ACC_WIDTH-1 downto 0) := (others => '0');
    signal found : boolean := false;
    signal found_idx : integer range 0 to N-1 := 0;

begin

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                lfsr <= x"ACE1ACE1";
            else
                lfsr <= lfsr(30 downto 0) & (lfsr(31) xor lfsr(21) xor lfsr(1) xor lfsr(0));
            end if;
        end if;
    end process;

    process(clk)
        variable sq_signed : signed(2*FP_WIDTH-1 downto 0);
        variable sq_unsigned : unsigned(2*FP_WIDTH-1 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                fsm <= IDLE;
                done <= '0';
                result <= 0;
            else
                done <= '0';
                case fsm is
                    when IDLE =>
                        if start = '1' then
                            threshold <= resize(unsigned(lfsr(29 downto 0)), ACC_WIDTH);
                            idx <= 0;
                            cum_sum <= (others => '0');
                            found <= false;
                            found_idx <= 0;
                            fsm <= SCAN;
                        end if;

                    when SCAN =>
                        sq_signed := psi_in(idx) * psi_in(idx);
                        sq_unsigned := unsigned(sq_signed);
                        if (not found) and
                           (cum_sum + resize(sq_unsigned, ACC_WIDTH) > threshold) then
                            found <= true;
                            found_idx <= idx;
                        end if;
                        cum_sum <= cum_sum + resize(sq_unsigned, ACC_WIDTH);
                        if idx = N-1 then
                            fsm <= FINISH;
                        else
                            idx <= idx + 1;
                        end if;

                    when FINISH =>
                        if found then
                            result <= found_idx;
                        else
                            result <= N-1;
                        end if;
                        done <= '1';
                        fsm  <= IDLE;
                end case;
            end if;
        end if;
    end process;

end architecture rtl;

