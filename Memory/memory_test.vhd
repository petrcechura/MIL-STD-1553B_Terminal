library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.terminal_package.all;


entity memory_test is
end entity;



architecture rtl of memory_test is


    signal clk   : std_logic := '0';
    signal reset : std_logic := '0';

    constant clk_period : time := 31.25 ns;

    signal write_en : std_logic := '0';
    signal read_en : std_logic := '0';
    signal write_done : std_logic := '0';
    signal read_done : std_logic := '0';
    signal data_in : std_logic_vector(15 downto 0) := (others => '0'); 
    signal data_out : std_logic_vector(15 downto 0) := (others => '0'); 
    signal subaddress : std_logic_vector(4 downto 0) := "11100";

begin

    


    M: entity work.Memory
        port map (
            clk   => clk, 
            reset => reset, 
            write_en => write_en, 
            read_en => read_en, 
            write_done => write_done, 
            read_done => read_done, 
            data_in => data_in, 
            data_out  => data_out, 
            subaddress  => subaddress 
        );

    MAIN: process
    begin
        reset <= '1';
        wait for 1 us;
        reset <= '0';
        wait for 1 us;

        -- write to subaddres = "11000" three blocks
        for i in 0 to 2 loop
            subaddress <= "11000";
            data_in <= "1010101010101010";
            write_en <= '1';
            wait until write_done = '1';
            write_en <= '0';
            wait for 0.5 us;
        end loop;
        write_en <= '0';
        wait for 2 us;

        
        -- write to subaddres = "10000" five blocks
        for i in 0 to 4 loop
            subaddress <= "10000";
            data_in <= "1010101010101010";
            write_en <= '1';
            wait until write_done = '1';
            write_en <= '0';
            wait for 0.5 us;
        end loop;
        write_en <= '0';
        wait for 2 us;

        -- write to subaddres = "11010" 2 blocks
        for i in 0 to 1 loop
            subaddress <= "11010";
            data_in <= "1010101010101010";
            write_en <= '1';
            wait until write_done = '1';
            write_en <= '0';
            wait for 0.5 us;
        end loop;
        write_en <= '0';
        wait for 2 us;

        subaddress <= "11000";

        wait for 10 us;
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