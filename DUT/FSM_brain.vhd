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
                    s_NFM
                    );
    signal state_d, state_q : t_state;

    -- COMMAND WORD essentials
    signal subaddress_d, subaddress_q : std_logic_vector(4 downto 0);
    signal data_word_count_d, data_word_count_q : std_logic_vector(4 downto 0);

begin

    -- FINITE STATE MACHINE
    --seq part
    process (clk)
    begin
        if rising_edge(clk) then
            state_q <= state_d;
        end if;
    end process;

    --comb part
    process (data_in)
    begin
        case state_q is
            when s_IDLE =>
                if rx_done="01" then -- COMMAND WORD RECEIVED
                
                    if data_in(16 downto 12)=terminal_address then
                        -- save command word essentials


                        if data_in(11)='1' then --T/R bit
                            state_d <= S_MEM_READ;
                        else
                            state_d <= S_DATA_RX;
                        end if;
                    else
                        state_d <= s_NFM;
                    end if;


                elsif rx_done="10" then -- DATA WORD RECEIVED
                    -- shouldnt happen by general

                elsif rx_done="11" then -- ERROR WHILE COLLECTING WORD
                    -- error handle
                else
                    state_d <= s_IDLE;
                end if;

                
            when S_DATA_RX =>

            when S_MEM_WR =>

            when S_MEM_WR_ERR =>

            when S_MEM_WR_OK =>

            when S_MEM_READ =>

            when S_MEM_RD_ERR =>

            when S_MEM_RD_OK =>

            when s_NFM =>

            when S_MODE_CODE =>

        end case;

    end process;



end architecture;