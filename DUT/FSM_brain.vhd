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
                    S_MEM_WR_OK,
                    S_MEM_WR_ERR,
                    S_DATA_TX,
                    S_MEM_RD_OK,
                    S_MEM_READ,
                    S_MEM_RD_ERR,
                    s_BROADCAST
                    );
    signal state_d, state_q : t_state;

    -- COMMAND WORD essentials
    signal subaddress_d, subaddress_q : std_logic_vector(4 downto 0);
    signal data_word_count_d, data_word_count_q : unsigned(4 downto 0);
    signal mode_code_d, mode_code_q : std_logic_vector(4 downto 0);
    signal brdcast_flag_d, brdcast_flag_q : std_logic;

    -- STATUS WORD 


    -- MEMORY MANAGEMENT
    signal mem_wr_done : std_logic; -- memory write done


begin

    -- FINITE STATE MACHINE
    --seq part
    process (clk)
    begin
        if reset = '1' then
            state_q <= S_IDLE; 
            subaddress_q <= (others => '0'); 
            data_word_count_q <= (others => '0'); 
            brdcast_flag_q <= '0'; 
        
        elsif rising_edge(clk) then
            state_q <= state_d;
            subaddress_q <= subaddress_d;
            data_word_count_q <= data_word_count_d;
            brdcast_flag_q <= brdcast_flag_d;
        end if;
    end process;

    --comb part
    process (decoder_data_in)
    begin
        state_d <= state_q;
        subaddress_d <= subaddress_q;
        data_word_count_d <= data_word_count_q;
        brdcast_flag_d <= brdcast_flag_q;

        case state_q is
            when s_IDLE =>
                if rx_done="01" then -- COMMAND WORD RECEIVED
                
                    if decoder_data_in(15 downto 11) = terminal_address then
                        brdcast_flag_d <= '0';
                        subaddress_q <= decoder_data_in(9 downto 5);
                        data_word_count_d <= unsigned(decoder_data_in(4 downto 0));

                        if decoder_data_in(9 downto 5) = "00000" or decoder_data_in(9 downto 5) = "11111" then -- Mode code 
                            state_d <= S_MODE_CODE;
                            -- TODO mode code broadcast handle !
                        
                        elsif decoder_data_in(10)='1' then --T/R bit
                            state_d <= S_MEM_READ;
                        else
                            state_d <= S_DATA_RX;
                        end if;
                    elsif decoder_data_in(15 downto 11) = "00000" or decoder_data_in(15 downto 11) = "11111" then -- Broadcast
                        brdcast_flag_d <= '1';
                        subaddress_q <= decoder_data_in(9 downto 5);
                        data_word_count_d <= unsigned(decoder_data_in(4 downto 0));
                        
                        state_d <= S_BROADCAST;
                    end if;


                elsif rx_done="10" then -- DATA WORD RECEIVED
                    -- shouldnt happen by general

                elsif rx_done="11" then -- ERROR WHILE COLLECTING WORD
                    -- error handle
                else
                    state_d <= s_IDLE;
                end if;

                
            when S_DATA_RX =>



                if rx_done = "10" and data_word_count_q = 0 then
                    state_d <= S_MEM_WR;
                elsif rx_done = "10" then
                    data_word_count_d <= data_word_count_d - 1;
                elsif rx_done = "01" then
                    -- error handle (unexpected – too low – amount of data words)
                end if;

            when S_MEM_WR =>
                -- memory management
                -- 
                --

                if mem_wr_done = '1' and brdcast_flag_q = '1' then
                    state_d <= S_IDLE;
                elsif mem_wr_done = '1' then
                    state_d <= S_MEM_WR_OK;
                elsif 1=1 then -- TODO error handle when memory write is error
                    state_d <= S_MEM_WR_ERR;
                end if;
            when S_MEM_WR_ERR =>
                -- send status word

                if tx_done = '1' then
                    state_d <= S_IDLE;

                end if;
                    
            when S_MEM_WR_OK =>
                
            when S_MEM_READ =>

            when S_MEM_RD_ERR =>

            when S_MEM_RD_OK =>

            when S_BROADCAST =>

            when S_MODE_CODE =>

        end case;

    end process;



end architecture;