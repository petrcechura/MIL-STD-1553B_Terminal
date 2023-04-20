library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.terminal_package.all;



entity FSM_brain is
    port (
        clk   : in std_logic;
        reset : in std_logic;
        rx_done : in std_logic_vector(1 downto 0);
        tx_done : in std_logic;
        decoder_data_in : in std_logic_vector(15 downto 0);
        encoder_data_out : out std_logic_vector(15 downto 0); 
        encoder_data_wr : out std_logic;
        TX_enable : out std_logic_vector(1 downto 0);
        mem_wr : out std_logic;
        mem_data_out : out std_logic_vector(15 downto 0);
        mem_rd : out std_logic;
        mem_data_in : in std_logic_vector(15 downto 0);
        mem_rd_done : in std_logic;
        mem_wr_done : in std_logic;
        mem_subaddr : out std_logic_vector(4 downto 0)
    );
end entity;


architecture rtl of FSM_brain is

    type t_state is(S_IDLE,
                    S_MODE_CODE,
                    S_DATA_RX,
                    S_MEM_WR,
                    S_MEM_WR_DONE,
                    S_STAT_WRD_TX,
                    S_DATA_TX,
                    S_MEM_READ,
                    S_MEM_RD_DONE,
                    S_BROADCAST
                    );
    signal state_d, state_q : t_state;

    -- COMMAND WORD essentials
    signal subaddress_d, subaddress_q : std_logic_vector(4 downto 0);     
    signal data_word_count_d, data_word_count_q : unsigned(4 downto 0); -- also carries mode code

    -- STATUS WORD 
    signal status_word_d, status_word_q : unsigned(15 downto 0);

    -- MEMORY MANAGEMENT
    signal internal_cache_d, internal_cache_q : std_logic_vector(511 downto 0);

    -- STATE MACHINE CONTROLL
    signal data_wr_d, data_wr_q : std_logic;

    -- Counter
    signal counter_d, counter_q : unsigned(4 downto 0);


    -- INTERNAL ERROR TIMER 
    --some states shouldn't last longer than for 50 us; if that happens, there must be an error;
    signal error_timer_d, error_timer_q : unsigned(10 downto 0);
    signal error_timer_max : std_logic;
    signal error_timer_en : std_logic;

    -- JUST FOR SIMULATION
    signal state_d_show, state_q_show : unsigned(3 downto 0);

begin

    -- FINITE STATE MACHINE
    --seq part
    process (clk)
    begin
        if reset = '1' then
            state_q <= S_IDLE; 
            subaddress_q <= (others => '0'); 
            data_word_count_q <= (others => '0'); 
            data_wr_q <= '0';
            internal_cache_q <= (others => '0'); 
            counter_q <= (others => '0') ;
            error_timer_q <= (others => '0'); 

            -- status word default set
            status_word_q(15 downto 11) <= TERMINAL_ADDRESS;    -- terminal address set     
            status_word_q(10) <= '0';                           -- message error flag       (received data are invalid; rx_done = "11")
            status_word_q(9 downto 8) <= (others => '0') ;      -- unused bits
            status_word_q(7 downto 5) <= (others => '0') ;      -- "reserved" bits
            status_word_q(4) <= '0';                            -- broadcast flag           (previous communication was done via broadcast option)
            status_word_q(3 downto 1) <= (others => '0');       -- unused bits               
            status_word_q(0) <= '0';                            -- terminal error flag      (internal timer overflow)                

        elsif rising_edge(clk) then
            state_q <= state_d;
            subaddress_q <= subaddress_d;
            data_word_count_q <= data_word_count_d;
            status_word_q <= status_word_d;
            data_wr_q <= data_wr_d;
            internal_cache_q <= internal_cache_d;
            counter_q <= counter_d;
            error_timer_q <= error_timer_d;

        end if;
    end process;

    --comb part
    process (decoder_data_in, rx_done, counter_q, error_timer_max, mem_wr_done, mem_rd_done, status_word_q, tx_done, error_timer_q, internal_cache_q, error_timer_en, subaddress_q)
    begin
        state_d <= state_q;
        subaddress_d <= subaddress_q;
        data_word_count_d <= data_word_count_q;
        status_word_d <= status_word_q;
        internal_cache_d <= internal_cache_q;
        counter_d <= counter_q;

        error_timer_en <= '0';
        mem_wr <= '0';
        mem_rd <= '0';
        data_wr_d <= '0';
        TX_enable <= "00";
        

        case state_q is
            when S_IDLE =>
                if rx_done="01" then -- COMMAND WORD RECEIVED
                    if decoder_data_in(15 downto 11) = std_logic_vector(terminal_address) then
                        status_word_d(4) <= '0';                                    -- broadcast flag is set to zero
                        subaddress_d <= decoder_data_in(9 downto 5);                -- save subaddress 
                        data_word_count_d <= unsigned(decoder_data_in(4 downto 0)); -- save data word count/mode code


                        if decoder_data_in(9 downto 5) = "00000" or decoder_data_in(9 downto 5) = "11111" then -- Mode code 
                            state_d <= S_MODE_CODE;
                            -- TODO mode code broadcast handle !
                        
                        elsif decoder_data_in(10) = '1' then --T/R bit

                            counter_d <= counter_q + 1;
                            state_d <= S_MEM_READ;
                        else
                            state_d <= S_DATA_RX;
                        end if;
                    elsif decoder_data_in(15 downto 11) = "00000" or decoder_data_in(15 downto 11) = "11111" then -- BROADCAST
                        status_word_d(4) <= '1';                                    -- broadcast flag is set
                        subaddress_d <= decoder_data_in(9 downto 5);                -- save subaddress    
                        data_word_count_d <= unsigned(decoder_data_in(4 downto 0)); -- save data word count/mode code
                        
                        state_d <= S_BROADCAST;
                    end if;


                elsif rx_done="10" then -- DATA WORD RECEIVED
                    -- shouldnt happen by general

                elsif rx_done="11" then -- ERROR WHILE COLLECTING WORD
                    -- error handle
                else
                    state_d <= S_IDLE;
                end if;

                


            when S_DATA_RX =>   -- terminal is receiving data from decoder
                error_timer_en <= '1';

                if error_timer_max = '1' then
                    -- error occued, set flag TODO
                    state_d <= S_IDLE;
                elsif counter_q = data_word_count_q then    -- expected amount of data words has been received, now save it
                    state_d <= S_MEM_WR;
                    counter_d <= counter_q - 1;

                elsif rx_done = "10" then                   -- still receiving data
                    internal_cache_d <= decoder_data_in & internal_cache_q(511 downto 16);  -- save input data to an internal cache
                    error_timer_en <= '0';          -- erase error_timer
                    counter_d <= counter_q + 1;     -- increment amount of data words received

                elsif rx_done = "01" then
                    -- error handle (unexpected – too low – amount of data words)
                end if;

            when S_MEM_WR =>    -- terminal communicates with memory and tries to save recieved data
                mem_wr <= '1';
                error_timer_en <= '1';
                
                if error_timer_max = '1' then                       -- write took too long, there must be an error
                    -- ERROR WHILE SAVING DATA
                    status_word_d(0) <= '1';
                    state_d <= S_IDLE;

                elsif (counter_q /= 0 and mem_wr_done = '1') then     -- send all data in internal cache (-> while counter != 0, keep sending)
                    mem_wr <= '0';  
                    internal_cache_d <= internal_cache_q(511-16 downto 0) & "0000000000000000";        -- shift register (erase sent data)

                    counter_d <= counter_q - 1;                                                        -- every time write to memory was succesful, decrement counter 
                    error_timer_en <= '0';

                elsif mem_wr_done = '1' and counter_q = 0  and status_word_q(4) = '1' then       -- when recieving via broadcast, do not send status word
                    mem_wr <= '0';
                    internal_cache_d <= internal_cache_q(511-16 downto 0) & "0000000000000000";        -- shift register (erase sent data)
                    
                    state_d <= S_IDLE;

                elsif mem_wr_done = '1' and counter_q = 0  then                                  -- memory write completed successfuly -> status word
                    mem_wr <= '0';
                    internal_cache_d <= internal_cache_q(511-16 downto 0) & "0000000000000000";        -- shift register (erase sent data)
                    status_word_d(10) <= '0';    -- msg error = '0'

                    state_d <= S_MEM_WR_DONE;
                end if;

            when S_MEM_WR_DONE =>                                       -- status word is set
                -- set status word
                encoder_data_out <= std_logic_vector(status_word_q);
                data_wr_d <= '1';
                state_d <= S_STAT_WRD_TX;
                
            when S_STAT_WRD_TX =>                                       -- transmitting status word                                  
                TX_enable <= "01";

                if tx_done = '1' then -- when transmitting is done, go to IDLE state
                    state_d <= S_IDLE;
                end if;
                
            when S_MEM_READ =>                                                              -- read from memory all data that is needed
                mem_rd <= '1';
                error_timer_en <= '1';
                
                if error_timer_max = '1' then                                               -- write took too long, there must be an error
                    status_word_d(0) <= '1';                                                -- set status word error flag to '1'
                    state_d <= S_MEM_RD_DONE;
                

                elsif mem_rd_done = '1' and counter_q = data_word_count_q  then             -- memory read completed successfuly -> status word
                    mem_rd <= '0';
                    internal_cache_d <= mem_data_in & internal_cache_q(511 downto 16);      -- shift register (accept new data)
                    status_word_d(10) <= '0';    -- msg error = '0'
                    encoder_data_out <= std_logic_vector(status_word_q);
                    data_wr_d <= '1';

                    state_d <= S_MEM_RD_DONE;
                    
                elsif mem_rd_done = '1' then                                                -- send all data in internal cache (-> while counter != 0, keep sending)
                    mem_rd <= '0';  
                    internal_cache_d <= mem_data_in & internal_cache_q(511 downto 16);      -- shift register (accept new data)

                    counter_d <= counter_q + 1;                                             -- every time write to memory was succesful, increment counter 
                    error_timer_en <= '0';
                end if;
                
    
            when S_MEM_RD_DONE =>     -- send status word
                TX_enable <= "01";

                if tx_done = '1' and  status_word_d(0) = '1' then               -- TX of SW is done; if an error ocurred during memory read, go to idle
                    state_d <= S_IDLE;

                elsif tx_done = '1' then                                        -- TX of SW is done; now TX loaded data
                    encoder_data_out <= internal_cache_q(511 downto 511-15);    -- sent data are from the front of internal cache
                    data_wr_d <= '1';                                           -- write enable to encoder

                    state_d <= S_DATA_TX;
                end if;

            when S_DATA_TX =>
                TX_enable <= "10";
                
                if tx_done = '1' and counter_q = 0 then  -- data has been transmitted succesfully -> go to idle
                    state_d <= S_IDLE;
                
                elsif tx_done = '1' then    -- while there are data to be transmitted, transmit
                    internal_cache_d <= internal_cache_q(511-16 downto 0) & "0000000000000000"; -- shift register (erase sent data)
                    encoder_data_out <= internal_cache_q(511 downto 511-15);                    -- sent data are from the front of internal cache
                    data_wr_d <= '1';
                    counter_d <= counter_q - 1;
                
                end if;

            when S_BROADCAST =>
                -- TODO
                state_d <= S_IDLE;
            when S_MODE_CODE =>
                -- TODO
                state_d <= S_IDLE;
        end case;

    end process;


    -- output signals taken from flip flops
    encoder_data_wr <= data_wr_q;
    mem_subaddr <= subaddress_q;

    mem_data_out <= internal_cache_q(511 downto 511-15);  

    -- ERROR TIMER (9-bit)
    --comb part
    process (error_timer_en, error_timer_q)
    begin
        if error_timer_en = '1' then
            error_timer_d <= error_timer_q + 1;
        else
            error_timer_d <= (others => '0'); 
        end if;

        if error_timer_q = 1600-1 then -- 50 us
            error_timer_max <= '1';
        else
            error_timer_max <= '0';
        end if;
    end process;


    --SIMULATION
    state_d_show <= "0000" when state_d = S_IDLE else
        "0001" when state_d = S_MEM_RD_DONE else
        "0010" when state_d = S_MODE_CODE  else
        "0011" when state_d = S_DATA_RX  else
        "0100" when state_d = S_MEM_WR  else
        "0101" when state_d = S_MEM_WR_DONE  else
        "0110" when state_d = S_STAT_WRD_TX  else
        "0111" when state_d = S_DATA_TX else
        "1000" when state_d = S_MEM_READ else
        "1010" when state_d = S_BROADCAST;


    state_q_show <= "0000" when state_q = S_IDLE else
        "0001" when state_q = S_MEM_RD_DONE else
        "0010" when state_q = S_MODE_CODE  else
        "0011" when state_q = S_DATA_RX  else
        "0100" when state_q = S_MEM_WR  else
        "0101" when state_q = S_MEM_WR_DONE  else
        "0110" when state_q = S_STAT_WRD_TX  else
        "0111" when state_q = S_DATA_TX else
        "1000" when state_q = S_MEM_READ else
        "1010" when state_q = S_BROADCAST;

end architecture;