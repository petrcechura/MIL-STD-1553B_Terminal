library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.Terminal_package.all;




entity ManchesterEncoder is
    port (
        clk   : in std_logic;
        reset : in std_logic;
        data_in : in std_logic_vector(15 downto 0);     -- data to be sent
        data_wr : in std_logic;                         -- data to be sent are written to a register via this wr_en bit
        TX_en : in std_logic_vector(1 downto 0);        -- 01 = command word, 10 = data word -> enables transfer; "00" -> stops transfer
        OUT_POSITIVE : out std_logic;  
        OUT_NEGATIVE : out std_logic;
        TX_DONE : out std_logic                         -- signalization to a terminal that transfer has been completed succesfully
    );
end entity;

architecture rtl of ManchesterEncoder is

    -- State machine
    type t_state is (S_IDLE,
                     S_SYNC_POS,
                     S_SYNC_NEG,
                     S_ENCODE);
    signal state_d, state_q : t_state;


    -- Frequency divider (32 to 1 MHz)
    signal freq_divider_d, freq_divider_q : unsigned(4 downto 0);
    signal freq_divider_en : std_logic;
    signal bus_clock : std_logic;
    
    -- Sync counter
    signal timer_d, timer_q : unsigned(5 downto 0);
    signal timer_sync, timer_max : std_logic;
    signal timer_en : std_logic;

    -- Data counter
    signal data_counter_d, data_counter_q : unsigned(4 downto 0);
    signal data_counter_max : std_logic;
    signal data_counter_en : std_logic;

    -- data essentials
    signal data_register_d, data_register_q : std_logic_vector(15 downto 0); -- data + parite

    -- Parity generator
    signal parity_bit_d, parity_bit_q : std_logic;
    signal parity_bit_en : std_logic;


begin

    -- STATE MACHINE
    --seq part
    process (clk)
    begin
        if reset = '1' then
            state_q <= S_IDLE;
            timer_q <= (others => '0'); 
            data_counter_q <= data_counter_d;
            data_register_q <= (others => '0'); 
            freq_divider_q <= (others => '0');
            parity_bit_q <= '0';
        elsif rising_edge(clk) then
            state_q <= state_d;
            timer_q <= timer_d;
            data_counter_q <= data_counter_d;
            data_register_q <= data_register_d;
            freq_divider_q <= freq_divider_d;
            parity_bit_q <= parity_bit_d;
        end if;
    end process;

    --comb part
    process (TX_en, state_q, data_counter_q, timer_sync, bus_clock)
    begin
        data_counter_en <= '0';
        timer_en <= '0';
        freq_divider_en <= '0';
        parity_bit_en <= '0';
        OUT_POSITIVE <= '0';
        OUT_NEGATIVE <= '0';
        TX_DONE <= '0';
        state_d <= state_q;

        case state_q is
            when S_IDLE =>  

                if TX_en = "01" then
                    state_d <= S_SYNC_POS;
                elsif TX_en = "10" then
                    state_d <= S_SYNC_NEG;
                end if;
            when S_SYNC_POS =>
                timer_en <= '1';
                OUT_POSITIVE <= '1';

                if TX_en = "01" and timer_sync = '1' then
                    state_d <= S_SYNC_NEG;
                elsif TX_en = "10" and timer_sync = '1' then
                    state_d <= S_ENCODE;
                elsif TX_en = "01" or TX_en = "10" then
                    state_d <= S_SYNC_POS;
                else
                    state_d <= S_IDLE;
                end if;
                    
            when S_SYNC_NEG =>
                timer_en <= '1';
                OUT_NEGATIVE <= '1';

                if TX_en = "10" and timer_sync = '1' then
                    state_d <= S_SYNC_POS;
                elsif TX_en = "01" and timer_sync = '1' then
                    state_d <= S_ENCODE;
                elsif TX_en = "01" or TX_en = "10" then
                    state_d <= S_SYNC_NEG;
                else
                    state_d <= S_IDLE;
                end if;

            when S_ENCODE =>
            data_counter_en <= '1';
            timer_en <= '1';
            freq_divider_en <= '1';
            parity_bit_en <= '1';

            --manchester coding
            OUT_POSITIVE <= bus_clock xor data_register_q(15);
            OUT_NEGATIVE <= not (bus_clock xor data_register_q(15));

            if data_counter_max = '1' then
                state_d <= S_IDLE;
                TX_DONE <= '1';
            else
                state_d <= S_ENCODE;
            end if;
        end case;
    end process;


    -- Sync counter
    --comb part
    process (timer_en, timer_q)
    begin
        if timer_en = '1' then
            timer_d <= timer_q + 1;
        else
            timer_d <= (others => '0');
        end if;

        if timer_q = 3 * BUS_PERIOD/2 - 1 then
            timer_sync <= '1';
            timer_d <= (others => '0'); 
        else
            timer_sync <= '0';
        end if;

        if timer_q = BUS_PERIOD - 1 and data_counter_en = '1' then
            timer_max <= '1';
            timer_d <= (others => '0'); 
        else
            timer_max <= '0';
        end if;

    end process;


    -- Data counter 
    --comb part
    process (data_counter_q, data_counter_en, timer_max)
    begin
        if data_counter_en = '1' and timer_max = '1' then
            data_counter_d <= data_counter_q + 1;
        elsif data_counter_en = '1' then
            data_counter_d <= data_counter_q;
        else
            data_counter_d <= (others => '0'); 
        end if;

        if data_counter_q = 17 then
            data_counter_max <= '1';
        else
            data_counter_max <= '0';
        end if;
    end process;

    -- Data register
    --comb part
    process (data_wr, data_in, parity_bit_q, timer_max, data_counter_q, data_counter_en)
    begin
        if data_wr = '1' then
            data_register_d(15 downto 0) <= data_in;
        else
            data_register_d <= data_register_q;
        end if;

        if data_counter_en = '1' and timer_max = '1' and data_counter_q = 16 then -- last bit to be sent is parity bit
            if PARITY = '1' then
                data_register_d(15) <=  parity_bit_q;
            else
                data_register_d(15) <=  not parity_bit_q;
            end if;
        elsif data_counter_en = '1' and timer_max = '1' then -- shift register
            data_register_d <= data_register_d(14 downto 0) & '0';
            parity_bit_d <= parity_bit_q xor data_register_d(15);
        else
        end if;
    end process;

    -- Frequency divider
    --comb part

    process (freq_divider_q, freq_divider_en)
    begin
        if freq_divider_en = '1' then
            freq_divider_d <= freq_divider_q + 1;
        else
            freq_divider_d <= (others => '0');
        end if; 
    end process;

    bus_clock <= freq_divider_q(4);

end architecture;