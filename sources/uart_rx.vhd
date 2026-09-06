------------------------------------------------------------------------------
-- uart receiver module
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_rx is
    generic (
        CLK_FREQ : integer := 100_000_000;
        BAUD_RATE : integer := 115_200
    );
    port (
        clk : in  std_logic;
        rst : in  std_logic;
        rx_serial : in  std_logic;
        rx_data : out std_logic_vector(7 downto 0);
        rx_valid : out std_logic
    );
end entity uart_rx;

architecture rtl of uart_rx is

    constant CLKS_PER_BIT : integer := CLK_FREQ / BAUD_RATE;

    type rx_state_t is (IDLE, START_BIT, DATA_BITS, STOP_BIT, CLEANUP);
    signal state : rx_state_t := IDLE;

    signal clk_cnt : integer range 0 to CLKS_PER_BIT-1 := 0;
    signal bit_idx : integer range 0 to 7 := 0;
    signal rx_shift : std_logic_vector(7 downto 0) := (others => '0');

    signal rx_sync_0 : std_logic := '1';
    signal rx_sync_1 : std_logic := '1';

begin

    process(clk)
    begin
        if rising_edge(clk) then
            rx_sync_0 <= rx_serial;
            rx_sync_1 <= rx_sync_0;
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= IDLE;
                clk_cnt <= 0;
                bit_idx <= 0;
                rx_valid <= '0';
                rx_data <= (others => '0');
            else
                rx_valid <= '0';
                case state is
                    when IDLE =>
                        clk_cnt <= 0;
                        bit_idx <= 0;
                        if rx_sync_1 = '0' then
                            state <= START_BIT;
                        end if;
                    when START_BIT =>
                        if clk_cnt = (CLKS_PER_BIT-1)/2 then
                            if rx_sync_1 = '0' then
                                clk_cnt <= 0;
                                state   <= DATA_BITS;
                            else
                                state <= IDLE;
                            end if;
                        else
                            clk_cnt <= clk_cnt + 1;
                        end if;
                    when DATA_BITS =>
                        if clk_cnt < CLKS_PER_BIT-1 then
                            clk_cnt <= clk_cnt + 1;
                        else
                            clk_cnt <= 0;
                            rx_shift(bit_idx) <= rx_sync_1;
                            if bit_idx < 7 then
                                bit_idx <= bit_idx + 1;
                            else
                                bit_idx <= 0;
                                state <= STOP_BIT;
                            end if;
                        end if;
                    when STOP_BIT =>
                        if clk_cnt < CLKS_PER_BIT-1 then
                            clk_cnt <= clk_cnt + 1;
                        else
                            rx_data <= rx_shift;
                            rx_valid <= '1';
                            clk_cnt <= 0;
                            state <= CLEANUP;
                        end if;
                    when CLEANUP =>
                        state <= IDLE;
                end case;
            end if;
        end if;
    end process;

end architecture rtl;

