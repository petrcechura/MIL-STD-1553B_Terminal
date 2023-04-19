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

        data_in <= "0000000000000001";
        -- write to subaddress = "11000" 4xblock 
        for i in 0 to 3 loop
            report "data_in: " & to_string(data_in);
            subaddress <= "11000";
            write_en <= '1';
            wait until write_done = '1';
            write_en <= '0';
            wait for 31.25 ns;
        end loop;

        -- read from subaddress = "11000" 4 blocks of memory
        for i in 0 to 4 loop
            subaddress <= "11000";
            read_en <= '1';
            wait until read_done = '1';
            read_en <= '0';
            wait for 31.25 ns;
            report "DATA FROM |11000| : " & to_string(data_out);
        end loop;

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