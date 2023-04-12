library ieee;
    use ieee.std_logic_1164.all;


entity testencoder is
end entity;


architecture rtl of testencoder is

    signal clk   : std_logic := '0';
    signal reset : std_logic := '0';
    signal data_in :  std_logic_vector(15 downto 0) := "1110001010100101";
    signal data_wr : std_logic := '0';
    signal TX_en : std_logic_vector(1 downto 0) := "00";
    signal OUT_POSITIVE : std_logic := '0';
    signal OUT_NEGATIVE : std_logic := '0';
    signal TX_DONE : std_logic := '0'; 

    constant clk_period : time := 31.25 ns;

begin


    ME: entity work.ManchesterEncoder(rtl)
        port map (
            clk => clk, 
            reset => reset, 
            data_in => data_in, 
            data_wr => data_wr, 
            TX_en => TX_en, 
            OUT_POSITIVE => OUT_POSITIVE, 
            OUT_NEGATIVE => OUT_NEGATIVE, 
            TX_DONE => TX_DONE
        );
    
    MAIN: process
    begin
        reset <= '1';
        wait for 1 us;
        reset <= '0';
        wait for 1 us;

        TX_en <= "01";
        data_wr <= '1';
        wait for 1 us;
        data_wr <= '0';

        wait for 50 us;
        wait;

    end process;







    process
    begin
        for i in 0 to 1000 loop
            clk <= '1';
            wait for clk_period/2;
            clk <= '0';
            wait for clk_period/2;
        end loop;
        wait;
    end process;
    

end architecture;