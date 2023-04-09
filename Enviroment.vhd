library ieee;
    use ieee.std_logic_1164.all;

library work;
    use work.Verification_package.all;

entity Enviroment is
end entity;


architecture rtl of Enviroment is

    signal com : t_bfm_com := (word => "01010101111001111",
                               start => '0',
                               test_done => '0');

    --TODO                               
    signal s_data_in, s_pos_data_out, s_neg_data_out : std_logic := '0';
    signal data : std_logic_vector(15 downto 0);

    --clock
    constant clk_period : time := 31.25 ns; 
    signal clk : std_logic := '0';
    signal rst : std_logic := '0';

begin

    BFM_I: entity work.BFM(rtl)
        port map (
            data_in => s_data_in,
            pos_data_out => s_pos_data_out,
            neg_data_out => s_neg_data_out,
            command => com
        );

    MD_I: entity work.ManchesterDecoder(rtl)
        port map (
            clk   => clk,
            reset => rst,
            in_positive => s_pos_data_out,
            in_negative => s_neg_data_out,
            DATA_OUT => data
        );
    
    MAIN: process
    begin
        rst <= '1';
        wait for 2 us;
        rst <= '0';
        wait for 2 us;

        com.start <= '1';
        wait for 1 us;
        com.test_done <= '1';

        wait;

    end process;

    CLK_P: process
    begin
        for i in 0 to 100000 loop
            clk <= '1';
            wait for clk_period/2;
            clk <= '0';
            wait for clk_period/2;
        end loop;
        wait;
    end process;

end architecture;