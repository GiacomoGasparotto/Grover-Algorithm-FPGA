------------------------------------------------------------------------------
-- Testbench for the full Grover algorithm.
-- Controls "grover_top" without UART
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.textio.all;
use work.grover_pkg.all;

entity tb_grover is
end entity tb_grover;

architecture sim of tb_grover is

    constant CLK_PERIOD : time := 10 ns;

    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal start : std_logic := '0';
    signal done : std_logic;
    signal result : integer range 0 to N-1;
    signal psi_out : state_vec_t;

    constant MARKED_TEST : integer := 3;
    signal   marked_tb : integer range 0 to N-1 := MARKED_TEST;

    signal cycle_count : integer := 0;
    signal cycles_start : integer := 0;

begin

    dut : entity work.grover_top
        port map (
            clk => clk, 
            rst => rst, 
            start => start, 
            marked_in => marked_tb,
            done => done, 
            result => result,
            psi_out => psi_out
        );

    clk <= not clk after CLK_PERIOD/2;

    process(clk)
    begin
        if rising_edge(clk) then
            cycle_count <= cycle_count + 1;
        end if;
    end process;

    process
        variable l : line;
        variable elapsed : integer;
        variable p_marked, p_max : real;
        variable idx_max : integer;
    begin
        rst <= '1';
        start <= '0';
        wait for 5 * CLK_PERIOD;
        rst <= '0';
        wait for 3 * CLK_PERIOD;
        
        write(l, string'("Testbench results:")); writeline(output, l);
        write(l, string'("N_QUBITS = ")); write(l, N_QUBITS); writeline(output, l);
        write(l, string'("N = ")); write(l, N); writeline(output, l);
        write(l, string'("k = ")); write(l, k); writeline(output, l);
        write(l, string'("Marked index = ")); write(l, MARKED_TEST);
        writeline(output, l);

        wait until rising_edge(clk);
        cycles_start <= cycle_count;
        start <= '1';
        wait until rising_edge(clk);
        start <= '0';

        wait until done = '1';
        wait until rising_edge(clk);

        elapsed := cycle_count - cycles_start;

        write(l, string'("Clock cycles: ")); write(l, elapsed); writeline(output, l);
        write(l, string'("Time (100 MHz): ")); write(l, elapsed*10); write(l, string'(" ns")); writeline(output, l);
        writeline(output, l);
        write(l, string'("Marked state: |")); write(l, MARKED_TEST); write(l, string'(">")); writeline(output, l);
        write(l, string'("Measured state: |")); write(l, result); write(l, string'(">")); writeline(output, l);
        writeline(output, l);

        idx_max := 0;
        p_max := 0.0;
        for i in 0 to N-1 loop
            if (real(to_integer(psi_out(i))) / real(FP_SCALE))**2 > p_max then
                p_max := (real(to_integer(psi_out(i))) / real(FP_SCALE))**2;
                idx_max := i;
            end if;
        end loop;
        p_marked := (real(to_integer(psi_out(MARKED_TEST))) / real(FP_SCALE))**2;

        write(l, string'("Prob. on marked state: ")); write(l, p_marked*100.0, right, 0, 3); write(l, string'(" %")); writeline(output, l);
        write(l, string'("Max prob. on state |")); write(l, idx_max); write(l, string'(">: "));
        write(l, p_max*100.0, right, 0, 3); write(l, string'(" %")); writeline(output, l);
        writeline(output, l);

        if idx_max = MARKED_TEST then
            write(l, string'("State vector shape correct!"));
        else
            write(l, string'(" ERROR: marked state not found"));
        end if;
        writeline(output, l);

        write(l, string'("Final state vector:")); writeline(output, l);
        for i in 0 to N-1 loop
            write(l, string'("   |")); write(l, i); write(l, string'(">  amplitude ="));
            write(l, to_integer(psi_out(i)), right, 8);
            write(l, string'("   P = "));
            write(l, (real(to_integer(psi_out(i))) / real(FP_SCALE))**2 * 100.0, right, 0, 3);
            write(l, string'(" %"));
            writeline(output, l);
        end loop;
        
        wait for 10*CLK_PERIOD;
        std.env.stop;
    end process;

end architecture sim;
