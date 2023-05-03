library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.terminal_package.all;

entity FSM_brain is
    port (
        clk   : in std_logic;
        reset : in std_logic;

        -- FSM & decoder
        rx_done : in std_logic_vector(1 downto 0);
        rx_flag : in std_logic;
        decoder_data_in : in std_logic_vector(15 downto 0);   

        -- FSM & encoder
        tx_done : in std_logic;
        encoder_data_out : out std_logic_vector(15 downto 0); 
        encoder_data_wr : out std_logic;
        TX_enable : out std_logic_vector(1 downto 0);

        -- FSM & SRAM
        sram_data_out : out std_logic_vector(15 downto 0);
        sram_data_in : in std_logic_vector(15 downto 0);
        sram_wr : out std_logic;
        sram_rd : out std_logic;
        sram_erase : out std_logic;

        -- FSM & memory
        mem_wr : out std_logic;
        mem_data_out : out std_logic_vector(15 downto 0);
        mem_rd : out std_logic;
        mem_data_in : in std_logic_vector(15 downto 0);
        mem_rd_done : in std_logic;
        mem_wr_done : in std_logic;
        mem_subaddr : out std_logic_vector(4 downto 0);

        -- Mode code outputs
        mode_code : out std_logic_vector(4 downto 0);
        synchronize : out std_logic_vector(15 downto 0)
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
                    S_BROADCAST,
                    S_MC_BROADCAST
                    );
    signal state_d, state_q : t_state;

    -- COMMAND WORD essentials
    signal saddr_d, saddr_q : std_logic_vector(4 downto 0);     
    signal dw_cnt_d, dw_cnt_q : unsigned(4 downto 0); -- also carries mode code

    -- STATUS WORD 
    signal stat_w_d, stat_w_q : unsigned(15 downto 0);

    -- STATE MACHINE CONTROLL
    signal data_wr_d, data_wr_q : std_logic;

    -- Counter
    signal cntr_d, cntr_q : unsigned(4 downto 0);

    -- msg error flag
    signal msg_err_d, msg_err_q : std_logic;

    -- mode code outputs flip flops
    signal mode_c_d, mode_c_q : std_logic_vector(4 downto 0);
    signal sync_d, sync_q : std_logic_vector(15 downto 0);

    -- INTERNAL ERROR TIMER 
    --some states shouldn't last longer than for 50 us; if that happens, there must be an error;
    signal err_tmr_d, err_tmr_q : unsigned(10 downto 0);
    signal err_tmr_max : std_logic;
    signal err_tmr_mem : std_logic;
    signal err_tmr_en : std_logic;

    -- JUST FOR SIMULATION
    signal state_d_show, state_q_show : unsigned(3 downto 0);

begin

    -- FINITE STATE MACHINE
    --seq part
    process (clk, reset)
    begin
        if reset = '1' then
            state_q <= S_IDLE; 
            saddr_q <= (others => '0'); 
            dw_cnt_q <= (others => '0'); 
            data_wr_q <= '0';
            cntr_q <= (others => '0') ;
            err_tmr_q <= (others => '0'); 
            msg_err_q <= '0';
            mode_c_q <= (others => '0');
            sync_q <= (others => '0');  

            -- status word default set
            stat_w_q(15 downto 11) <= TERMINAL_ADDRESS;    -- terminal address set     
            stat_w_q(10) <= '0';                           -- message error flag       (received data are invalid; rx_done = "11")
            stat_w_q(9 downto 8) <= (others => '0') ;      -- unused bits
            stat_w_q(7 downto 5) <= (others => '0') ;      -- "reserved" bits
            stat_w_q(4) <= '0';                            -- broadcast flag           (previous communication was done via broadcast option)
            stat_w_q(3 downto 1) <= (others => '0');       -- unused bits               
            stat_w_q(0) <= '0';                            -- terminal error flag      (error timer overflow)                

        elsif rising_edge(clk) then
            state_q <= state_d;
            saddr_q <= saddr_d;
            dw_cnt_q <= dw_cnt_d;
            stat_w_q <= stat_w_d;
            data_wr_q <= data_wr_d;
            cntr_q <= cntr_d;
            err_tmr_q <= err_tmr_d;
            msg_err_q <= msg_err_d;
            mode_c_q <= mode_c_d;
            sync_q <= sync_d;

        end if;
    end process;

    process (decoder_data_in, rx_done, cntr_q, err_tmr_max, mem_wr_done, mem_rd_done, stat_w_q, tx_done, err_tmr_q, err_tmr_en, saddr_q, dw_cnt_q, state_d, state_q, sram_data_in, mem_data_in, stat_w_d, msg_err_q, rx_flag, sync_q, mode_c_q)
    begin
        state_d <= state_q;
        saddr_d <= saddr_q;
        dw_cnt_d <= dw_cnt_q;
        stat_w_d <= stat_w_q;
        cntr_d <= cntr_q;
        mode_c_d <= mode_c_q;
        sync_d <= sync_q;
        
        err_tmr_en <= '0';
        sram_erase <= '0';
        mem_wr <= '0';
        mem_rd <= '0';
        data_wr_d <= '0';
        TX_enable <= "00";
        sram_wr <= '0';
        sram_rd <= '0';
        msg_err_d <= '0';

        sram_data_out <= decoder_data_in;
        mem_data_out <= sram_data_in;
        encoder_data_out <= sram_data_in;
        

        case state_q is
            when S_IDLE =>
                if rx_done = "01" then                        -- COMMAND WORD RECEIVED
                    if decoder_data_in(15 downto 11) = std_logic_vector(terminal_address) then
                        stat_w_d(4) <= '0';                                    -- broadcast flag is set to zero
                        saddr_d <= decoder_data_in(9 downto 5);                -- save subaddress 
                        dw_cnt_d <= unsigned(decoder_data_in(4 downto 0)); -- save data word count/mode code


                        if decoder_data_in(9 downto 5) = "00000" or decoder_data_in(9 downto 5) = "11111" then -- Mode code 
                            state_d <= S_MODE_CODE;
                        
                        elsif decoder_data_in(10) = '1' then --T/R bit
                            cntr_d <= cntr_q + 1;
                            state_d <= S_MEM_READ;
                        else
                            state_d <= S_DATA_RX;
                        end if;
                    elsif decoder_data_in(15 downto 11) = "00000" or decoder_data_in(15 downto 11) = "11111" then -- BROADCAST
                        stat_w_d(4) <= '1';                                    -- broadcast flag is set
                        saddr_d <= decoder_data_in(9 downto 5);                -- save subaddress    
                        dw_cnt_d <= unsigned(decoder_data_in(4 downto 0)); -- save data word count/mode code
                        
                        if decoder_data_in(9 downto 5) = "00000" or decoder_data_in(9 downto 5) = "11111" then  -- mode code broadcast
                            state_d <= S_MC_BROADCAST;
                        else
                            state_d <= S_BROADCAST;
                        end if;
                    end if;

                elsif rx_done="11" then     -- ERROR WHILE COLLECTING WORD
                    stat_w_d(10) <= '1';                                       -- message error flag -> '0'
                end if;

            

            when S_DATA_RX =>   -- terminal is receiving data from decoder
                msg_err_d <= msg_err_q;
                err_tmr_en <= '1';

                if cntr_q = dw_cnt_q then                -- expected amount of data words has been received, now save it
                    cntr_d <= cntr_q - 1;
                    if msg_err_q = '0' then
                        state_d <= S_MEM_WR;
                    else                            -- if an error occured in data words (wrong parity etc, do not save data and send status word)
                        sram_erase <= '1';          -- data are invalid -> erase them
                        stat_w_d(10) <= '1';        -- msg err flag    
                        state_d <= S_MEM_WR_DONE;   
                    end if;

                elsif rx_done = "10" and rx_flag = '1' then                   -- still receiving data
                    sram_wr <= '1';                 -- write to an sram
                    err_tmr_en <= '0';          -- erase error_timer
                    cntr_d <= cntr_q + 1;     -- increment amount of data words received

                elsif rx_done = "11" then           -- data word with error has been received
                    sram_wr <= '1';                 -- write to an sram
                    err_tmr_en <= '0';          -- erase error_timer
                    cntr_d <= cntr_q + 1;     -- increment amount of data words received  
                    msg_err_d <= '1';    
                    
                elsif (cntr_q /= 0 and rx_flag = '0') or err_tmr_max = '1' then            -- data rec ended too soon or data didnt appear in 50 us -> error
                    stat_w_d(10) <= '1';
                    state_d <= S_IDLE;
                end if;

            when S_MEM_WR =>                        -- terminal communicates with memory and tries to save recieved data
                mem_wr <= '1';
                err_tmr_en <= '1';
                
                if err_tmr_mem = '1' or RX_done /= "00" then                                        -- either write took too long or unexpected word occured -> error
                    stat_w_d(0) <= '1';                                                            -- terminal flag error -> '1'
                    state_d <= S_MEM_WR_DONE;                                                       -- send status word about an error

                elsif (cntr_q /= 0 and mem_wr_done = '1') then                                       -- send all data in internal cache (-> while counter != 0, keep sending)
                    mem_wr <= '0';  
                    sram_rd <= '1';
                    cntr_d <= cntr_q - 1;                                                         -- every time write to memory was succesful, decrement counter 
                    err_tmr_en <= '0';

                elsif mem_wr_done = '1' and cntr_q = 0  and stat_w_q(4) = '1' then              -- when recieving via broadcast, do not send status word
                    mem_wr <= '0';
                    sram_rd <= '1';
                    state_d <= S_IDLE;

                elsif mem_wr_done = '1' and cntr_q = 0  then                                         -- memory write completed successfuly -> status word
                    mem_wr <= '0';
                    sram_rd <= '1';
                    stat_w_d(10) <= '0';                                                           -- msg error -> '0'

                    state_d <= S_MEM_WR_DONE;
                end if;

            when S_MEM_WR_DONE =>                                       -- status word is set
                -- set status word
                encoder_data_out <= std_logic_vector(stat_w_q);
                data_wr_d <= '1';
                state_d <= S_STAT_WRD_TX;
                
            when S_STAT_WRD_TX =>                                       -- transmitting status word                                
                TX_enable <= "01";
                encoder_data_out <= std_logic_vector(stat_w_q);
                if tx_done = '1' then                                   -- when transmitting is done, go to IDLE state
                    if decoder_data_in(9 downto 5) = "00000" and dw_cnt_q = MC_SEND_SW then   -- for MC_SEND_SW, status word shall not be reset after transmit
                        state_d <= S_IDLE;
                    else
                        stat_w_d(10 downto 0) <= (others => '0');      -- reset error flags (they have already been sent)
                        state_d <= S_IDLE;
                    end if;
                end if;
                
            when S_MEM_READ =>                                                              -- read from memory all data that is needed
                mem_rd <= '1';
                err_tmr_en <= '1';
                sram_data_out <= mem_data_in;
                
                if err_tmr_mem = '1' then                                               -- write took too long, there must be an error
                    stat_w_d(0) <= '1';                                                -- set status word error flag to '1'
                    state_d <= S_MEM_RD_DONE;
                
                elsif mem_rd_done = '1' and cntr_q = dw_cnt_q  then             -- memory read completed successfuly -> status word
                    mem_rd <= '0';
                    sram_wr <= '1';
                    stat_w_d(10) <= '0';    -- msg error = '0'
                    encoder_data_out <= std_logic_vector(stat_w_q);
                    data_wr_d <= '1';

                    if stat_w_q(4) = '1' then                                          -- if it's broadcast mode, start sending data...
                        state_d <= S_DATA_TX;
                        encoder_data_out <= sram_data_in;
                        data_wr_d <= '1'; 
                    else                                                                    -- ...otherwise send status word first 
                        state_d <= S_MEM_RD_DONE;                                          
                        stat_w_d(10) <= '0';    -- msg error = '0'
                        encoder_data_out <= std_logic_vector(stat_w_q);
                        data_wr_d <= '1';
                    end if;

                elsif mem_rd_done = '1' then                                                -- send all data to sram (-> while counter != 0, keep sending)
                    mem_rd <= '0';  
                    sram_wr <= '1';

                    cntr_d <= cntr_q + 1;                                             -- every time write to memory was succesful, increment counter 
                    err_tmr_en <= '0';
                end if;
    
            when S_MEM_RD_DONE =>                                               -- send status word
                TX_enable <= "01";
                encoder_data_out <= std_logic_vector(stat_w_q);
                
                if tx_done = '1' and  stat_w_d(0) = '1' then               -- TX of SW is done; if an error ocurred during memory read, go to idle
                    state_d <= S_IDLE;
                    stat_w_d(10 downto 0) <= (others => '0');      -- reset error flags (they have already been sent)

                elsif tx_done = '1' then                                        -- TX of SW is done; now TX loaded data
                    encoder_data_out <= sram_data_in;
                    data_wr_d <= '1';                                           -- write enable to encoder
                    stat_w_d(10 downto 0) <= (others => '0');      -- reset error flags (they have already been sent)

                    state_d <= S_DATA_TX;
                end if;

            when S_DATA_TX =>
                TX_enable <= "10";
                encoder_data_out <= sram_data_in;
                
                if tx_done = '1' and cntr_q = 1 then  -- data has been transmitted succesfully -> go to idle
                    state_d <= S_IDLE;
                    cntr_d <= cntr_q -1;
                
                elsif tx_done = '1' then    -- while there are data to be transmitted, transmit
                    sram_rd <= '1';
                    data_wr_d <= '1';
                    cntr_d <= cntr_q - 1;
                
                end if;

            when S_BROADCAST =>
                err_tmr_en <= '1';

                if err_tmr_max = '1' then
                    stat_w_d(10) <= '1';
                    state_d <= S_IDLE;

                elsif RX_done = "01" and                                                        -- terminal should send data to all other terminals
                    decoder_data_in(10) = '1' and   -- T/R bit
                    decoder_data_in(15 downto 11) = std_logic_vector(TERMINAL_ADDRESS)  then 
                    
                    dw_cnt_d <= unsigned(decoder_data_in(4 downto 0));                 -- save data word count/mode code
                    cntr_d <= cntr_q + 1;
                    state_d <= S_MEM_READ;
                elsif RX_done = "10" then                                                       -- terminal will be recieving data to all terminals
                    state_d <= S_DATA_RX;
                    sram_wr <= '1';                 -- write to an sram
                    err_tmr_en <= '0';          -- erase error_timer
                    cntr_d <= cntr_q + 1;     -- increment amount of data words received
                end if;
            when S_MODE_CODE =>
                mode_c_d <= std_logic_vector(dw_cnt_q);

                if dw_cnt_q = "10001" then                         -- MC synchronize (with data word)
                    err_tmr_en <= '1';

                    if err_tmr_max = '1' then                           -- no data word received
                        stat_w_d(10) <= '1';
                        state_d <= S_IDLE;
                    elsif RX_DONE = "10" then                               -- data word received
                        sync_d <= decoder_data_in;
                        state_d <= S_STAT_WRD_TX;                           -- after valid synchronization -> send status word
                        encoder_data_out <= std_logic_vector(stat_w_q);
                        data_wr_d <= '1';
                    end if;

                else                                                        -- all other mode codes -> send status word
                    encoder_data_out <= std_logic_vector(stat_w_q);
                    data_wr_d <= '1';
                    state_d <= S_STAT_WRD_TX;
                end if;

            when S_MC_BROADCAST =>
                mode_c_d <= std_logic_vector(dw_cnt_q);

                if dw_cnt_q = "10001" then                         -- MC synchronize (with data word)
                    err_tmr_en <= '1';

                    if err_tmr_max = '1' then                           -- no data word received
                        stat_w_d(10) <= '1';
                        state_d <= S_IDLE;
                    elsif RX_DONE = "10" then                               -- data word received
                        sync_d <= decoder_data_in;
                        state_d <= S_IDLE;                           -- after valid synchronization -> go to idle
                    end if;

                else                                                        -- all other mode codes -> go to idle
                    encoder_data_out <= std_logic_vector(stat_w_q);
                    data_wr_d <= '1';
                    state_d <= S_IDLE;
                end if;
        end case;

    end process;


    -- output signals taken from flip flops
    encoder_data_wr <= data_wr_q;
    mem_subaddr <= saddr_q;
    mode_code <= mode_c_q;
    synchronize <= sync_q;

    -- ERROR TIMER (9-bit)
    --comb part
    process (err_tmr_en, err_tmr_q)
    begin
        if err_tmr_en = '1' then
            err_tmr_d <= err_tmr_q + 1;
        else
            err_tmr_d <= (others => '0'); 
        end if;

        if err_tmr_q = 1600-1 then -- 50 us
            err_tmr_max <= '1';
        else
            err_tmr_max <= '0';
        end if;

        if err_tmr_q = 96-1 then -- 3 us
            err_tmr_mem <= '1';
        else
            err_tmr_mem <= '0';
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