------------------------------------------------------------------------------
-- Implement the connection between UART RX/TX and the algorithm.
--
-- Sends 1 byte representing the marked state to search
-- Receives 1 byte representing the state obtained by the algorithm
--
-- uart_rx_pin: A9
-- uart_tx_pin: D10
------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.grover_pkg.all;

entity arty_top is
    port (
        CLK100MHZ : in  std_logic;
        ck_rst : in  std_logic;
        uart_rx_pin : in  std_logic;
        uart_tx_pin : out std_logic;
        led : out std_logic_vector(3 downto 0)
    );
end entity arty_top;

architecture rtl of arty_top is

    signal clk : std_logic;
    signal rst : std_logic;

    signal rx_data : std_logic_vector(7 downto 0);
    signal rx_valid : std_logic;

    signal tx_data : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_start : std_logic := '0';
    signal tx_busy : std_logic;

    signal grv_start : std_logic := '0';
    signal grv_marked : integer range 0 to N-1 := 0;
    signal grv_done : std_logic;
    signal grv_result : integer range 0 to N-1;
    signal grv_psi : state_vec_t;

    type proto_state_t is (
        WAIT_BYTE, 
        START_GROVER, 
        RUN_GROVER,
        SEND_RESULT, 
        WAIT_TX_BUSY, 
        WAIT_TX_DONE
    );
    signal proto_state : proto_state_t := WAIT_BYTE;

    signal busy_led : std_logic := '0';

begin

    clk <= CLK100MHZ;
    rst <= not ck_rst;

    u_rx : entity work.uart_rx
        generic map (CLK_FREQ => 100_000_000, BAUD_RATE => 115_200)
        port map (
            clk => clk, 
            rst => rst, 
            rx_serial => uart_rx_pin,
            rx_data => rx_data, 
            rx_valid => rx_valid
        );

    u_tx : entity work.uart_tx
        generic map (CLK_FREQ => 100_000_000, BAUD_RATE => 115_200)
        port map (
            clk => clk, 
            rst => rst, 
            tx_data => tx_data,
            tx_start => tx_start, 
            tx_serial => uart_tx_pin, 
            tx_busy => tx_busy
        );

    u_grover : entity work.grover_top
        port map (
            clk => clk, 
            rst => rst, 
            start => grv_start,
            marked_in => grv_marked, 
            done => grv_done,
            result => grv_result, 
            psi_out => grv_psi
        );

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                proto_state <= WAIT_BYTE;
                grv_start <= '0';
                tx_start <= '0';
                busy_led <= '0';
            else
                grv_start <= '0';
                tx_start <= '0';

                case proto_state is

                    when WAIT_BYTE =>
                        busy_led <= '0';
                        if rx_valid = '1' then
                            grv_marked <= to_integer(unsigned(rx_data)) mod N;
                            proto_state <= START_GROVER;
                        end if;

                    when START_GROVER =>
                        busy_led <= '1';
                        grv_start <= '1';
                        proto_state <= RUN_GROVER;

                    when RUN_GROVER =>
                        if grv_done = '1' then
                            tx_data <= std_logic_vector(to_unsigned(grv_result, 8));
                            proto_state <= SEND_RESULT;
                        end if;

                    when SEND_RESULT =>
                        tx_start <= '1';
                        proto_state <= WAIT_TX_BUSY;

                    when WAIT_TX_BUSY =>
                        if tx_busy = '1' then
                            proto_state <= WAIT_TX_DONE;
                        end if;

                    when WAIT_TX_DONE =>
                        if tx_busy = '0' then
                            busy_led <= '0';
                            proto_state <= WAIT_BYTE;
                        end if;

                end case;
            end if;
        end if;
    end process;

    led(0) <= busy_led;
    led(3 downto 1) <= std_logic_vector(to_unsigned(grv_result mod 8, 3));

end architecture rtl;
