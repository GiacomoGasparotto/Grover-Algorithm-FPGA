------------------------------------------------------------------------------
-- Runs Grover algorithm N_RUNS times with the same marked state and counts the
-- distribution of outcomes. It should approach the theoretical
-- probability as N_RUNS grows.
------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.grover_pkg.all;
entity tb_measure_statistics is
end entity tb_measure_statistics;
architecture sim of tb_measure_statistics is
    constant CLK_PERIOD  : time := 10 ns;
    constant N_RUNS : integer := 1000;
    constant MARKED_TEST : integer := 3;
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal start : std_logic := '0';
    signal marked_tb : integer range 0 to N-1 := MARKED_TEST;
    signal done : std_logic;
    signal result : integer range 0 to N-1;
    type conteggio_t is array(0 to N-1) of integer;
    signal conteggio : conteggio_t := (others => 0);
begin
    dut : entity work.grover_top
        port map (
            clk => clk, 
            rst => rst, 
            start => start, 
            marked_in => marked_tb,
            done => done, 
            result => result, 
            psi_out => open
        );
    clk <= not clk after CLK_PERIOD/2;
    process
        variable l : line;
    begin
        rst <= '1'; start <= '0';
        wait for 5 * CLK_PERIOD;
        rst <= '0';
        wait for 3 * CLK_PERIOD;
        write(l, string'("Running ")); write(l, N_RUNS);
        write(l, string'("Probabilistic measurements, marked state = |"));
        write(l, MARKED_TEST); write(l, string'(">"));
        writeline(output, l);
        for run in 1 to N_RUNS loop
            wait until rising_edge(clk);
            start <= '1';
            wait until rising_edge(clk);
            start <= '0';
            wait until done = '1';
            conteggio(result) <= conteggio(result) + 1;
            wait until rising_edge(clk);
        end loop;
        wait for 5 * CLK_PERIOD;
        write(l, string'("")); writeline(output, l);
        write(l, string'("STATE,COUNT,PERCENT_FREQUENCY")); writeline(output, l);
        for i in 0 to N-1 loop
            write(l, i); write(l, string'(","));
            write(l, conteggio(i)); write(l, string'(","));
            write(l, real(conteggio(i)) / real(N_RUNS) * 100.0, right, 0, 2);
            writeline(output, l);
        end loop;
        wait for 5 * CLK_PERIOD;
        std.env.stop;
    end process;
end architecture sim;
