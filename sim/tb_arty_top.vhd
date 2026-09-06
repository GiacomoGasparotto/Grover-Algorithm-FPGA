------------------------------------------------------------------------------
-- Full testbench: simulates the entire chain PC -> UART -> Grover -> UART -> PC.
------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.grover_pkg.all;

entity tb_arty_top is
end entity tb_arty_top;

architecture sim of tb_arty_top is

    constant CLK_PERIOD : time := 10 ns;
    constant BAUD_RATE  : integer := 115_200;
    constant BIT_PERIOD : time := 1 sec / BAUD_RATE;

    signal clk : std_logic := '0';
    signal ck_rst : std_logic := '1';
    signal uart_rx_pin : std_logic := '1';
    signal uart_tx_pin : std_logic;
    signal led : std_logic_vector(3 downto 0);

    signal rx_byte_result : std_logic_vector(7 downto 0);
    signal rx_byte_ready : boolean := false;
    signal t_send_start : time;

    procedure uart_send_byte(
        signal line : out std_logic;
        constant data : in  std_logic_vector(7 downto 0)
    ) is
    begin
        line <= '0';
        wait for BIT_PERIOD;
        for i in 0 to 7 loop
            line <= data(i);
            wait for BIT_PERIOD;
        end loop;
        line <= '1';
        wait for BIT_PERIOD;
    end procedure;

    procedure uart_receive_byte(
        signal line : in  std_logic;
        variable data : out std_logic_vector(7 downto 0)
    ) is
    begin
        wait until line = '0';
        wait for BIT_PERIOD/2;
        wait for BIT_PERIOD;
        for i in 0 to 7 loop
            data(i) := line;
            wait for BIT_PERIOD;
        end loop;
    end procedure;

    constant MARKED_TEST : integer := 3;

begin

    dut : entity work.arty_top
        port map (
            CLK100MHZ => clk,
            ck_rst => ck_rst,
            uart_rx_pin => uart_rx_pin,
            uart_tx_pin => uart_tx_pin,
            led => led
        );

    clk <= not clk after CLK_PERIOD/2;

    send_proc : process
        variable l : line;
    begin
        ck_rst <= '0';
        wait for CLK_PERIOD*4;
        ck_rst <= '1';
        wait for CLK_PERIOD*4;

        write(l, string'(""));                                          writeline(output, l);
        write(l, string'("Full chain PC -> UART -> Grover -> UART -> PC")); writeline(output, l);
        write(l, string'("Baud rate = ")); write(l, BAUD_RATE); writeline(output, l);
        write(l, string'("Marked index sent = ")); write(l, MARKED_TEST); writeline(output, l);

        t_send_start <= now;
        wait for 0 ns;

        uart_send_byte(uart_rx_pin, std_logic_vector(to_unsigned(MARKED_TEST, 8)));

        write(l, string'("[PC] byte sent, waiting for response...")); writeline(output, l);
        wait;
    end process;

    receive_proc : process
        variable rx_byte : std_logic_vector(7 downto 0);
    begin
        uart_receive_byte(uart_tx_pin, rx_byte);
        rx_byte_result <= rx_byte;
        rx_byte_ready  <= true;
        wait;
    end process;

    report_proc : process
        variable l          : line;
        variable t_recv_end : time;
    begin
        wait until rx_byte_ready;
        t_recv_end := now;

        write(l, string'("[PC] byte received = ")); write(l, to_integer(unsigned(rx_byte_result))); writeline(output, l);
        write(l, string'("Total time (UART included): "));
        write(l, (t_recv_end - t_send_start) / 1 us);
        write(l, string'(" us"));
        writeline(output, l);

        if to_integer(unsigned(rx_byte_result)) = MARKED_TEST then
            write(l, string'("UART round-trip correct: received byte matches the marked index"));
        else
            write(l, string'("Received byte differs from the marked index (remember that the measurement is probabilistic)"));
            writeline(output, l);
        end if;

        wait for 20*CLK_PERIOD;
        std.env.stop;
    end process;

end architecture sim;