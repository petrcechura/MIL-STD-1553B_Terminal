library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.Terminal_package.all;


entity ManchesterEncoder is
    port (
        clk   : in std_logic;
        reset : in std_logic;
        data_in : in std_logic_vector(16 downto 0);
        data_wr : in std_logic;
        TX_en : in std_logic_vector(1 downto 0);
        OUT_POSITIVE : out std_logic;
        OUT_NEGATIVE : out std_logic;
        TX_DONE : out std_logic
    );
end entity;

architecture rtl of ManchesterEncoder is

    -- Frequency divider (32 to 1 MHz)
    signal freq_divider_d, freq_divider_q : unsigned(4 downto 0);
    signal freq_divider_en : std_logic;
    signal bus_clock_rise, bus_clock_fall : std_logic;
    signal bus_clock : std_logic;

    -- Data counter
    signal data_counter_d, data_counter_q : unsigned(5 downto 0);
    signal data_counter_max, data_counter_sync : std_logic;

    -- data essentials
    signal data_register_d, data_register_q : std_logic_vector(16 downto 0); -- data + parite
    signal parite_bit : std_logic;


begin

    -- OUTPUT ENCODER
    --seq part
    process (clk)
    begin
        if rising_edge(clk) then
            if TX_en = "01" then
                if data_counter_sync = '1' and bus_clock_rise = '1' then
                    
                elsif data_counter_max = '1' then

                else
                
                end if;
            end if;
        end if;
    end process;

    --comb part
    process ()
    begin
        
    end process;

    -- Data counter
    --seq part
    process (clk)
    begin
        if rising_edge(clk) and bus_clock='1' then
            data_counter_q <= data_counter_d;
        end if;
    end process;

    --comb part
    process (data_counter_q, TX_en)
    begin
        if TX_en = "01" or TX_en = "10" then
            data_counter_d <= data_counter_q + 1;
        end if;

        if data_counter_q < 6 then
            data_counter_sync <= '1';
        else
            data_counter_sync <= '0';
        end if;

        if data_counter_q = 34 then
            data_counter_max <= '1';
        else
            data_counter_max <= '0';
        end if;
    end process;

    -- Data register
    --seq part
    process (clk)
    begin
        if reset = '1' then
            data_register_q <= (others => '0'); 
        elsif rising_edge(clk) then
                data_register_q <= data_register_d;
        end if;
    end process;

    --comb part
    process (data_wr, data_in, parite_bit)
    begin
        if data_wr = '1' then
            data_register_d(16 downto 1) <= data_in;
            data_register_d(0) <= parite_bit;
        else
            data_register_d <= data_register_q; 
        end if;
    end process;

    -- Parite generator
    process (data_in)
        variable temp : unsigned(16 downto 1);
    begin
        temp(16) := data_in(16);
        for i in 15 downto 1 loop
            temp(i) := temp(i+1) xor data_in(i);
        end loop;
        if parita = '1' then -- odd parite
            parite_bit <= temp(1);
        else -- even parite
            parite_bit <= not temp(1);
        end if;
    end process;


    -- Frequency divider
    --seq part
    process (clk)
    begin
        if reset = '1' then
            freq_divider_q <= (others => '0'); 
        elsif rising_edge(clk) then
            freq_divider_q <= freq_divider_d;
        end if;
    end process;

    --comb part
    process (freq_divider_q, freq_divider_en)
    begin
        freq_divider_d <= freq_divider_q + 1;

        if freq_divider_q = 0 then
            bus_clock_rise <= '1';
        else
            bus_clock_rise <= '0';
        end if;

        if freq_divider_q = 16 then
            bus_clock_fall <= '1';
        else
            bus_clock_fall <= '0';
        end if;
    end process;

    bus_clock <= not freq_divider_q(4);

end architecture;