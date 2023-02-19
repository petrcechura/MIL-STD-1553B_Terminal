library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity test is
end entity;


architecture rtl of test is
    signal sclk_period : time := 1 us;
    signal clk_period : time := 31.25 ns;

    signal clk, reset, data, data_out : std_logic := '0';
    signal data_change : std_logic := '0';
    signal sclk : std_logic;
    signal data_pos, data_neg : std_logic := '0';
    signal state : std_logic_vector(2 downto 0);

    component ManchesterDecoder is
        -- for frequency 1 MHz
        port (
            clk   : in std_logic;
            reset : in std_logic;
            in_positive, in_negative : in std_logic;
            data_out : out std_logic;
            data_change : out std_logic;
            state_out : out std_logic_vector(2 downto 0)
        );
    end component;

begin
        TES : ManchesterDecoder
            port map (
                clk   => clk,
                reset => reset,
                in_positive => data_pos,
                in_negative => data_neg,
                data_out => data_out,
                data_change => data_change,
                state_out => state
            );
        process
        begin
            for i in 0 to 10000 loop
                clk <= '1';
                wait for clk_period/2;
                clk <= '0';
                wait for clk_period/2;
            end loop;
            wait;
        end process;

        process
        begin
            for i in 0 to 1000 loop
                sclk <= '1';
                wait for sclk_period/2;
                sclk <= '0';
                wait for sclk_period/2;
            end loop;
            wait;
        end process;

        process
        begin
            reset <= '1';
            wait for 2 us;
            reset <= '0';
            wait for 2 us;
            
            --synchronize waveform
            data_neg <= '0';
            data_pos <= '1';
            wait for sclk_period*1.5;
            data_pos <= '0';
            data_neg <= '1';
            wait for sclk_period*1.5;

            --data
            data_pos <= '1';
            data_neg <= '0';

            wait for sclk_period*3;
            data_pos <= '0';
            data_neg <= '1';

            wait;
        end process;

        --data_in <= data xor sclk;

end architecture;