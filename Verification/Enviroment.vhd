library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.Verification_package.all;

entity Enviroment is
end entity;


architecture rtl of Enviroment is

    --TODO                               
    signal s_data_in, s_pos_data_out, s_neg_data_out : std_logic := '0';
    signal data : std_logic_vector(15 downto 0);
    signal response : std_logic := '0';

    --clock
    constant clk_period : time := 31.25 ns; 
    signal clk : std_logic := '0';
    signal rst : std_logic := '0';

    -- routing signals between components
    signal MEM_TO_TU : t_MEM_TO_TU;
    signal TU_TO_BFM : t_TU_TO_BFM;

    -- Enviroment & BFM
    signal com : t_bfm_com;

    -- COMMAND WORD SETTINGS
    signal address : unsigned(4 downto 0) := "11100";
    signal TR_bit : std_logic := '0';
    signal subaddress : unsigned(4 downto 0) := "10100";
    signal data_word_count : unsigned(4 downto 0) := "00101";

    -- DATA WORD SETTINGS
    signal bits : unsigned(15 downto 0) := "1111000010100101";

begin

    BFM_I: entity work.BFM(rtl)
        port map (
            data_in => s_data_in,
            pos_data_out => TU_TO_BFM.in_pos,
            neg_data_out => TU_TO_BFM.in_neg,
            command => com,
            response => response
        );

    TU_I: entity work.Terminal_unit(rtl)
        port map (
            clk =>    clk,
            reset =>  rst,
            in_pos => TU_TO_BFM.in_pos,
            in_neg =>  TU_TO_BFM.in_neg,
            out_pos => TU_TO_BFM.out_pos,
            out_neg =>  TU_TO_BFM.out_neg,
            mem_wr_en => MEM_TO_TU.write_en ,
            mem_rd_en =>  MEM_TO_TU.read_en,
            mem_wr_done => MEM_TO_TU.wr_done,
            mem_rd_done => MEM_TO_TU.rd_done,
            data_in =>  MEM_TO_TU.data_in,
            data_out =>  MEM_TO_TU.data_out,
            mem_subaddr => MEM_TO_TU.subaddr
        );

    MEMORY_I : entity work.Memory(rtl)
        port map (
            clk => clk,
            reset => rst,
            write_en => MEM_TO_TU.write_en,
            read_en => MEM_TO_TU.read_en,
            write_done => MEM_TO_TU.wr_done,
            read_done => MEM_TO_TU.rd_done,
            data_in => MEM_TO_TU.data_out,
            data_out => MEM_TO_TU.data_in,
            subaddress => MEM_TO_TU.subaddr
        );
    



















    MAIN: process

    begin
        rst <= '1';
        wait for 2 us;
        rst <= '0';
        wait for 2 us;

        Send_command_word(address, TR_bit, subaddress, data_word_count, com, response);
        for i in 0 to 4 loop
            Send_data_word(bits, com, response);
        end loop;
        wait;

        



    end process;









































    CLK_P: process
    begin
        for i in 0 to 20000 loop
            clk <= '1';
            wait for clk_period/2;
            clk <= '0';
            wait for clk_period/2;
        end loop;
        wait;
    end process;

end architecture;