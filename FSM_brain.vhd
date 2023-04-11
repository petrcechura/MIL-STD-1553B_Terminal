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
        data_in : in std_logic_vector(15 downto 0);
        MEM_WR : out std_logic;
        MEM_DATA_OUT : out std_logic_vector(15 downto 0);
        MEM_RD : out std_logic
        --mem_read
    );
end entity;


architecture rtl of FSM_brain is

    type t_state is (s_IDLE,
                    s_mode_code,
                    s_data_rx,
                    s_mem_wr,
                    s_mem_wr_ok,
                    s_mem_wr_err,
                    s_data_tx,
                    s_mem_rd_ok,
                    s_mem_read,
                    s_mem_rd_err,
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
                            state_d <= s_mem_read;
                        else
                            state_d <= s_data_rx;
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

                
            when s_data_rx =>

            when s_mem_wr =>

            when s_mem_wr_err =>

            when s_mem_wr_ok =>

            when s_mem_read =>

            when s_mem_rd_err =>

            when s_mem_rd_ok =>

            when s_NFM =>

            when s_mode_code =>

        end case;

    end process;



end architecture;