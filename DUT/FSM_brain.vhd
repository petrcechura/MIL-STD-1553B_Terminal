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
        TX_enable : out std_logic;
        MEM_WR : out std_logic;
        MEM_DATA_OUT : out std_logic_vector(15 downto 0);
        MEM_RD : out std_logic;
        mem_data_in : in std_logic_vector(15 downto 0)
    );
end entity;


architecture rtl of FSM_brain is

    type t_state is (s_IDLE,
                    S_MODE_CODE,
                    S_DATA_RX,
                    S_MEM_WR,
                    S_MEM_WR_DONE,
                    S_STAT_WRD_TX,
                    S_DATA_TX,
                    S_MEM_RD_OK,
                    S_MEM_READ,
                    S_MEM_RD_ERR,
                    s_BROADCAST
                    );
    signal state_d, state_q : t_state;

    -- COMMAND WORD essentials
    signal subaddress_d, subaddress_q : std_logic_vector(4 downto 0);     
    signal data_word_count_d, data_word_count_q : unsigned(4 downto 0); -- also carries mode code

    -- STATUS WORD 
    signal status_word_d, status_word_q : unsigned(15 downto 0);

    -- MEMORY MANAGEMENT
    signal mem_wr_done : std_logic; -- memory write done

    -- STATE MACHINE CONTROLL
    signal data_wr_d, data_wr_q : std_logic;


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

        end if;
    end process;

    --comb part
    process (decoder_data_in)
    begin
        state_d <= state_q;
        subaddress_d <= subaddress_q;
        data_word_count_d <= data_word_count_q;
        status_word_d <= status_word_q;

        data_wr_d <= '0';


        case state_q is
            when s_IDLE =>
                if rx_done="01" then -- COMMAND WORD RECEIVED
                
                    if decoder_data_in(15 downto 11) = std_logic_vector(terminal_address) then
                        status_word_d(4) <= '0';                                    -- broadcast flag is set to zero
                        subaddress_q <= decoder_data_in(9 downto 5);                -- save subaddress 
                        data_word_count_d <= unsigned(decoder_data_in(4 downto 0)); -- save data word count/mode code

                        if decoder_data_in(9 downto 5) = "00000" or decoder_data_in(9 downto 5) = "11111" then -- Mode code 
                            state_d <= S_MODE_CODE;
                            -- TODO mode code broadcast handle !
                        
                        elsif decoder_data_in(10)='1' then --T/R bit
                            state_d <= S_MEM_READ;
                        else
                            state_d <= S_DATA_RX;
                        end if;
                    elsif decoder_data_in(15 downto 11) = "00000" or decoder_data_in(15 downto 11) = "11111" then -- Broadcast
                        status_word_d(4) <= '1';                                    -- broadcast flag is set
                        subaddress_q <= decoder_data_in(9 downto 5);                -- save subaddress    
                        data_word_count_d <= unsigned(decoder_data_in(4 downto 0)); -- save data word count/mode code
                        
                        state_d <= S_BROADCAST;
                    end if;


                elsif rx_done="10" then -- DATA WORD RECEIVED
                    -- shouldnt happen by general

                elsif rx_done="11" then -- ERROR WHILE COLLECTING WORD
                    -- error handle
                else
                    state_d <= s_IDLE;
                end if;

                


            when S_DATA_RX =>   -- terminal is receiving data from decoder



                if rx_done = "10" and data_word_count_q = 0 then
                    state_d <= S_MEM_WR;
                elsif rx_done = "10" then
                    data_word_count_d <= data_word_count_d - 1;
                elsif rx_done = "01" then
                    -- error handle (unexpected – too low – amount of data words)
                end if;




            when S_MEM_WR =>    -- terminal communicates with memory and tries to save recieved data
                -- memory management
                -- 
                --

                if mem_wr_done = '1' and status_word_q(4) = '1' then    -- when recieving via broadcast, do not send status word
                    state_d <= S_IDLE;
                elsif mem_wr_done = '1' then                            -- memory write completed successfuly -> status word
                    status_word_d(10) <= '0';    -- msg error = '0'
                    state_d <= S_MEM_WR_DONE;
                elsif 1=1 then                                          -- TODO error handle when memory write is error
                    status_word_d(10) <= '1';    -- msg error = '1'
                    state_d <= S_MEM_WR_DONE;
                end if;




            when S_MEM_WR_DONE =>                                       -- status word is set
                -- set status word
                encoder_data_out <= std_logic_vector(status_word_q);

                data_wr_d <= '1';
                state_d <= S_STAT_WRD_TX;
                
            when S_STAT_WRD_TX =>                                       -- transmitting status word                                  
                TX_enable <= '1';

                if tx_done = '1' then -- when transmitting is done, go to IDLE state
                    state_d <= S_IDLE;
                end if;
                
            when S_MEM_READ =>

            when S_MEM_RD_ERR =>

            when S_MEM_RD_OK =>

            when S_BROADCAST =>

            when S_MODE_CODE =>

        end case;

    end process;



    encoder_data_wr <= data_wr_q;

end architecture;