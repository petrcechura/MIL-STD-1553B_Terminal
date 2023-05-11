library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.Verification_package.all;
    use work.terminal_package.all;

entity Enviroment is
end entity;


architecture rtl of Enviroment is

    -- clock
    constant clk_period : time := 31.25 ns; 
    signal clk : std_logic := '0';
    signal rst : std_logic := '0';

    -- routing signals between components
    signal MEM_TO_TU : t_MEM_TO_TU;
    signal TU_TO_BFM : t_TU_TO_BFM;
    signal DEC_TO_BFM : t_DEC_TO_BFM;

    -- routing signals (Enviroment & BFM)
    signal com : t_bfm_com;
    signal response : std_logic := '0';

    -- validity of memory
    signal memory_func : boolean := true;

begin

    --*********************************--
    --******ENTITY INITIALIZATION******--
    --*********************************--
    BFM_I: entity work.BFM(behavior)
        port map (
            pos_data_out => TU_TO_BFM.in_pos,
            neg_data_out => TU_TO_BFM.in_neg,
            command => com,
            response => response,
            data_from_TU =>  DEC_TO_BFM.data_from_TU,
            RX_done => DEC_TO_BFM.RX_done
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
            subaddress => MEM_TO_TU.subaddr,
            memory_func => memory_func
        );

    BFM_DECODER_I: entity work.ManchesterDecoder(rtl)
    port map (
        clk   => clk,
        reset => rst,
        in_pos => TU_TO_BFM.out_pos,
        in_neg =>  TU_TO_BFM.out_neg,
        DATA_OUT =>  DEC_TO_BFM.data_from_TU,
        RX_DONE =>  DEC_TO_BFM.RX_done
    );






    --**********************--
    --*****TEST PROCESS*****--
    --**********************--


    MAIN: process
        variable TEST_NUMBER : integer := 10;

        -- COMMAND WORD SETTINGS
        variable address : unsigned(4 downto 0) := "11011";
        variable TR_bit : std_logic := '0';
        variable subaddress : unsigned(4 downto 0) := "10100";
        variable data_word_count : unsigned(4 downto 0) := "00110";

        -- DATA WORD SETTINGS
        variable bits : unsigned(15 downto 0) := "0000000000000001";


    begin
        if TEST_NUMBER = 1 then
            report "TEST NO. 1";
            -- terminal reset (1)
            rst <= '1';
            wait for 2 us;
            rst <= '0';
            wait for 2 us;
            
            -- send command word    (2)
            address := TERMINAL_ADDRESS;
            TR_bit := '0';
            data_word_count := "00111";
            subaddress := "11100";
            wait for 1 ns;
            Send_command_word(address, TR_bit, subaddress, data_word_count, com, response);

            -- send data words  (3)
            bits := "0000000000000001";
            for i in 0 to to_integer(data_word_count)-1 loop
                bits := bits + 1;
                Send_data_word(bits, com, response);
            end loop;
            
            -- receive status word  (4)
            Receive_word(com, response);
            
            wait for 35 us;

            -- send command word    (5)
            address := TERMINAL_ADDRESS;
            TR_bit := '0';
            data_word_count := "00100";
            subaddress := "00101";
            wait for 1 ns;
            Send_command_word(address, TR_bit, subaddress, data_word_count, com, response);

            -- send data words  (6)
            bits := "0000000000000011";
            for i in 0 to to_integer(data_word_count)-1 loop
                bits := bits + 1;
                Send_data_word(bits, com, response);
            end loop;
            
            -- receive status word  (7)
            Receive_word(com, response);

            wait for 35 us;

            
            -- send command word    (8)
            address := TERMINAL_ADDRESS;
            TR_bit := '1';
            data_word_count := "00110";
            subaddress := "11100";
            wait for 1 ns;
            Send_command_word(address, TR_bit, subaddress, data_word_count, com, response);   
            
            -- receive status word  (9)
            Receive_word(com, response);

            -- receive data words (10)
            for i in 0 to to_integer(data_word_count)-1 loop
                Receive_word(com, response);
            end loop;
            
            report "TEST NO. 1 DONE";

            
        elsif TEST_NUMBER = 2 then
            report "TEST NO. 2";
            -- terminal reset (1)
            rst <= '1';
            wait for 2 us;
            rst <= '0';
            wait for 2 us;
            
            -- send invalid command word    (2) -- wrong parity
            address := TERMINAL_ADDRESS;
            TR_bit := '0';
            data_word_count := "00011";
            subaddress := "00010";
            bits := address & TR_bit & subaddress & data_word_count;
            wait for 1 ns;
            Send_invalid_command_word(bits, 17, false, true, com, response);

            -- send data words  (3)
            bits := "0000000000000001";
            for i in 0 to to_integer(data_word_count)-1 loop
                bits := bits + 1;
                Send_data_word(bits, com, response);
            end loop;

            wait for 35 us;

            -- send command word-MODECODE    (4)
            address := TERMINAL_ADDRESS;
            TR_bit := '0';
            subaddress := MODECODE_SUBADDR;
            data_word_count := MC_SEND_SW; -- (send status word mode code)
            wait for 1 ns;
            Send_command_word(address, TR_bit, subaddress, data_word_count, com, response);
                        
            -- receive status word  (5)
            Receive_word(com, response);

            wait for 35 us;

            -- send invalid command word    (6)
            address := TERMINAL_ADDRESS;
            TR_bit := '0';
            data_word_count := "00011";
            subaddress := "00010";
            bits := address & TR_bit & subaddress & data_word_count;
            wait for 1 ns;
            Send_invalid_command_word(bits, 14, true, true, com, response);

            -- send data words  (7)
            bits := "0000000000000001";
            for i in 0 to to_integer(data_word_count)-1 loop
                bits := bits + 1;
                Send_data_word(bits, com, response);
            end loop;

            wait for 35 us;

            -- send command word-MODECODE    (8)
            address := TERMINAL_ADDRESS;
            TR_bit := '0';
            subaddress := MODECODE_SUBADDR;
            data_word_count := MC_SEND_SW; -- (send status word mode code)
            wait for 1 ns;
            Send_command_word(address, TR_bit, subaddress, data_word_count, com, response);
                        
            -- receive status word  (9)
            Receive_word(com, response);


        elsif TEST_NUMBER = 3 then 
            report "TEST NO. 3";
            -- terminal reset (1)
            rst <= '1';
            wait for 2 us;
            rst <= '0';
            wait for 2 us;
            
            -- send command word    (2)
            address := TERMINAL_ADDRESS;
            TR_bit := '0';
            data_word_count := "00010";
            subaddress := "00011";
            wait for 1 ns;
            Send_command_word(address, TR_bit, subaddress, data_word_count, com, response);

            -- send invalid data words    (3)
            bits := "0000000000000001";
            for i in 0 to to_integer(data_word_count)-1 loop
                bits := bits + 1;
                Send_invalid_data_word(bits, 17, false, true, com, response);
            end loop;

            -- receive status word  (4)
            Receive_word(com, response);

            wait for 35 us;

            -- send command word    (6)
            address := TERMINAL_ADDRESS;
            TR_bit := '0';
            data_word_count := "01100";
            subaddress := "00011";
            wait for 1 ns;
            Send_command_word(address, TR_bit, subaddress, data_word_count, com, response);

            -- send invalid data words    (7)
            bits := "0000000000000001";
            for i in 0 to to_integer(data_word_count)-1 loop
                bits := bits + 1;
                Send_invalid_data_word(bits, 17, true, false, com, response);
            end loop;

            -- send command word-MODECODE    (8)
            address := TERMINAL_ADDRESS;
            TR_bit := '0';
            subaddress := MODECODE_SUBADDR;
            data_word_count := MC_SEND_SW; -- (send status word mode code)
            wait for 1 ns;
            Send_command_word(address, TR_bit, subaddress, data_word_count, com, response);

            -- receive status word  (9)
            Receive_word(com, response);

        elsif TEST_NUMBER = 4 then
            report "TEST NO. 3";
            -- terminal reset (1)
            rst <= '1';
            wait for 2 us;
            rst <= '0';
            wait for 2 us;

            -- send command word    (2)
            address := TERMINAL_ADDRESS;
            TR_bit := '0';
            data_word_count := "00101";
            subaddress := "01100";
            wait for 1 ns;
            Send_command_word(address, TR_bit, subaddress, data_word_count, com, response);

            -- send data words  (3)
            bits := "0000000000000001";
            for i in 0 to to_integer(data_word_count)-3 loop
                bits := bits + 1;
                Send_data_word(bits, com, response);
            end loop;            
            
            -- wait (4)
            wait for 35 us;

            -- send command word-MODECODE    (5)
            address := TERMINAL_ADDRESS;
            TR_bit := '0';
            subaddress := MODECODE_SUBADDR;
            data_word_count := MC_SEND_SW; -- (send status word mode code)
            wait for 1 ns;
            Send_command_word(address, TR_bit, subaddress, data_word_count, com, response);
                        
            -- receive status word  (6)
            Receive_word(com, response);            

            elsif TEST_NUMBER = 5 then      
                report "TEST NO. 5";
                -- terminal reset (1)
                rst <= '1';
                wait for 2 us;
                rst <= '0';
                wait for 2 us;
    
                -- send invalid command word    (2)
                address := TERMINAL_ADDRESS;
                TR_bit := '0';
                data_word_count := "00011";
                subaddress := "00010";
                bits := address & TR_bit & subaddress & data_word_count;
                wait for 1 ns;
                Send_invalid_command_word(bits, 17, false, true, com, response);


                -- send command word-MODECODE    (3)
                address := TERMINAL_ADDRESS;
                TR_bit := '0';
                subaddress := MODECODE_SUBADDR;
                data_word_count := MC_SEND_SW; -- (send status word mode code)
                wait for 1 ns;
                Send_command_word(address, TR_bit, subaddress, data_word_count, com, response);  
                
                -- receive status word  (4)
                Receive_word(com, response);
                
                -- send command word-MODECODE (5)
                address := TERMINAL_ADDRESS;
                TR_bit := '0';
                subaddress := MODECODE_SUBADDR;
                data_word_count := MC_SYNC;
                wait for 1 ns;
                Send_command_word(address, TR_bit, subaddress, data_word_count, com, response);

                -- send data word (6)
                bits := "1000111101011010";
                Send_data_word(bits, com, response);

                -- receive status word  (7)
                Receive_word(com, response);
                
                -- send command word-MODECODE (8)
                address := TERMINAL_ADDRESS;
                TR_bit := '0';
                subaddress := MODECODE_SUBADDR;
                data_word_count := "11100";     -- random mode code
                wait for 1 ns;
                Send_command_word(address, TR_bit, subaddress, data_word_count, com, response);
                
                -- receive status word  (9)
                Receive_word(com, response);                

            elsif TEST_NUMBER = 6 then
                report "TEST NO. 6";
                -- terminal reset (1)
                rst <= '1';
                wait for 2 us;
                rst <= '0';
                wait for 2 us;
                
                -- send command word    (2)
                address := unsigned(BROADCAST_ADDR);
                TR_bit := '0';
                subaddress := "10001";
                data_word_count := "00010";
                wait for 1 ns;
                Send_command_word(address, TR_bit, subaddress, data_word_count, com, response);
    
                -- send data words  (3)
                bits := "0000000000000001";
                for i in 0 to to_integer(data_word_count)-1 loop
                    bits := bits + 1;
                    Send_data_word(bits, com, response);
                end loop;

                wait for 10 us;

                -- send command word    (4)
                address := TERMINAL_ADDRESS;
                TR_bit := '1';
                subaddress := "10001";
                data_word_count := "00001";
                wait for 1 ns;
                Send_command_word(address, TR_bit, subaddress, data_word_count, com, response);   
                    
                -- receive status word  (5)
                Receive_word(com, response);

                -- receive data words (6)
                for i in 0 to to_integer(data_word_count)-1 loop
                    Receive_word(com, response);
                end loop;                
        
                elsif TEST_NUMBER = 7 then
                    report "TEST NO. 7";
                    -- terminal reset (1)
                    rst <= '1';
                    wait for 2 us;
                    rst <= '0';
                    wait for 2 us;
                    
                    -- send command word    (2)
                    address := unsigned(BROADCAST_ADDR);
                    TR_bit := '0';
                    data_word_count := "00100";
                    subaddress := "10001";
                    wait for 1 ns;
                    Send_command_word(address, TR_bit, subaddress, data_word_count, com, response);

                    -- send command word    (3)
                    address := TERMINAL_ADDRESS;
                    TR_bit := '1';
                    subaddress := "11100";
                    data_word_count := "00111";
                    wait for 1 ns;
                    Send_command_word(address, TR_bit, subaddress, data_word_count, com, response);   

                    -- receive status word  (4)
                    Receive_word(com, response);

                    -- receive data words (5)
                    for i in 0 to to_integer(data_word_count)-1 loop
                        Receive_word(com, response);
                    end loop;  
                        
                        
                elsif TEST_NUMBER = 8 then
                    -- terminal reset (1)
                    rst <= '1';
                    wait for 2 us;
                    rst <= '0';
                    wait for 2 us;                    
                    
                    -- send command word    (2)
                    address := unsigned(BROADCAST_ADDR);
                    TR_bit := '0';
                    data_word_count := "01110";
                    subaddress := "10010";
                    wait for 1 ns;
                    Send_command_word(address, TR_bit, subaddress, data_word_count, com, response);

                    -- send command word    (3)
                    address := "10001";
                    TR_bit := '1';
                    data_word_count := "01110";
                    subaddress := "10101";
                    wait for 1 ns;
                    Send_command_word(address, TR_bit, subaddress, data_word_count, com, response);             
                    
                    -- send data words  (4)
                    bits := "0000000000000001";
                    for i in 0 to to_integer(data_word_count)-1 loop
                        bits := bits + 1;
                        Send_data_word(bits, com, response);
                    end loop;                    
                    
                    wait for 35 us;

                    -- send command word    (5)
                    address := TERMINAL_ADDRESS;
                    TR_bit := '1';
                    data_word_count := "00101";
                    subaddress := "10010";
                    wait for 1 ns;
                    Send_command_word(address, TR_bit, subaddress, data_word_count, com, response);   

                    -- receive status word  (6)
                    Receive_word(com, response);

                    -- receive data words (7)
                    for i in 0 to to_integer(data_word_count)-1 loop
                        Receive_word(com, response);
                    end loop;

                elsif TEST_NUMBER = 9 then
                    -- terminal reset (1)
                    rst <= '1';
                    wait for 2 us;
                    rst <= '0';
                    wait for 2 us; 
                    
                    -- send command word-MODECODE (2)
                    address := BROADCAST_ADDR;
                    TR_bit := '0';
                    subaddress := MODECODE_SUBADDR;
                    data_word_count := MC_SYNC;
                    wait for 1 ns;
                    Send_command_word(address, TR_bit, subaddress, data_word_count, com, response);
                    
                    -- send data word (3)
                    bits := "1000111101011010";
                    Send_data_word(bits, com, response);
                    
                    -- send command word-MODECODE (4)
                    address := BROADCAST_ADDR;
                    TR_bit := '0';
                    subaddress := MODECODE_SUBADDR;
                    data_word_count := "10010";
                    wait for 1 ns;
                    Send_command_word(address, TR_bit, subaddress, data_word_count, com, response);

                elsif TEST_NUMBER = 10 then
                    -- set memory to invalid state (1)
                    memory_func <= false;

                    -- terminal reset (2)
                    rst <= '1';
                    wait for 2 us;
                    rst <= '0';
                    wait for 2 us;

                    -- send command word    (3)
                    address := TERMINAL_ADDRESS;
                    TR_bit := '0';
                    data_word_count := "00111";
                    subaddress := "11100";
                    wait for 1 ns;
                    Send_command_word(address, TR_bit, subaddress, data_word_count, com, response);

                    -- send data words  (4)
                    bits := "0000000000000001";
                    for i in 0 to to_integer(data_word_count)-1 loop
                        bits := bits + 1;
                        Send_data_word(bits, com, response);
                    end loop;
                    
                    -- receive status word  (5)
                    Receive_word(com, response);
        end if;
        

        
        wait;
    end process;









































    CLK_P: process
    begin
        for i in 0 to 60000 loop
            clk <= '1';
            wait for clk_period/2;
            clk <= '0';
            wait for clk_period/2;
        end loop;
        wait;
    end process;

end architecture;