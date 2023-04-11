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
        TX_en : in std_logic;
        OUT_POSITIVE : out std_logic;
        OUT_NEGATIVE : out std_logic;
        TX_DONE : out std_logic
    );
end entity;


architecture rtl of ManchesterEncoder is

    -- Frequency divider (32 to 1 MHz)
    signal freq_divider_d, freq_divider_q : unsigned(4 downto 0);
    signal freq_divider_en : std_logic;
    signal bus_clock : std_logic;

    -- data essentials
    signal data_register : std_logic_vector(16 downto 0); -- data + parite
    signal parite_bit : std_logic;


begin

    process (clk)
    begin
        if rising_edge(clk) then
            if TX_en = '1' then
                
            end if;
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
        if parita='1' then -- odd parite
            parite_bit <= temp(1);
        else -- even parite
            parite_bit <= not temp(1);
        end if;
    end process;


    -- Frequency divider
    --seq part
    process (clk)
    begin
        if reset='1' then
            freq_divider_q <= (others => '0'); 
        elsif rising_edge(clk) then
            freq_divider_q <= freq_divider_d;
        end if;
    end process;

    --comb part
    process (freq_divider_q, freq_divider_en)
    begin
        freq_divider_d <= freq_divider_q + 1;
    end process;

    bus_clock <= std_logic(freq_divider_q(4));

end architecture;