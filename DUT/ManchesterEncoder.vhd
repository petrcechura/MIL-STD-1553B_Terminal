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
        TX_en : in std_logic_vector(1 downto 0);        -- 01 = status word, 10 = data word -> enables transfer; "00" -> stops transfer
        out_pos : out std_logic;  
        out_neg : out std_logic;
        TX_DONE : out std_logic                         -- signalization to a terminal that transfer has been completed succesfully
    );
end entity;

architecture rtl of ManchesterEncoder is

    -- STATE MACHINE
    type t_state is (S_IDLE,        -- encoder not in use
                     S_SYNC_POS,    -- transmitting positive synchronize waveform part
                     S_SYNC_NEG,    -- transmitting megative synchronize waveform part
                     S_ENCODE);     -- transmitting data + parity (with manchester coding)
    signal state_d, state_q : t_state;

    -- FREQUENCY DIVIDER (32 to 1 MHz)
    signal freq_divider_d, freq_divider_q : unsigned(4 downto 0);
    signal freq_divider_en : std_logic;
    signal bus_clock : std_logic;
    
    -- TIMER
    signal timer_d, timer_q : unsigned(5 downto 0);
    signal timer_sync : std_logic; -- signalizes end of synchronize waveform (1.5*bus period)
    signal timer_max : std_logic; -- signalizes one bus period
    signal timer_en : std_logic;

    -- DATA COUNTER
    --counts amount of sent bits
    signal data_cntr_d, data_cntr_q : unsigned(4 downto 0);
    signal data_cntr_max : std_logic; -- 17-bit (data + parity)
    signal data_cntr_en : std_logic;

    -- SHIFT REGISTER
    --stores input data to be sent; when transmitting, register is shifting and current bit to be sent is at position (15)
    signal data_register_d, data_register_q : std_logic_vector(15 downto 0); -- data + parite

    -- PARITY GENERATOR
    --parity is calculated sequently when transmitting (shifting register)
    signal parity_bit_d, parity_bit_q : std_logic;


begin

    --SEQ PART
    process (clk, reset)
    begin
        if reset = '1' then
            state_q <= S_IDLE;
            timer_q <= (others => '0'); 
            data_cntr_q <= (others => '0') ;
            data_register_q <= (others => '0'); 
            freq_divider_q <= (others => '0');
            parity_bit_q <= '0';
        elsif rising_edge(clk) then
            state_q <= state_d;
            timer_q <= timer_d;
            data_cntr_q <= data_cntr_d;
            data_register_q <= data_register_d;
            freq_divider_q <= freq_divider_d;
            parity_bit_q <= parity_bit_d;
        end if;
    end process;

    -- STATE MACHINE
    --comb part
    process (TX_en, state_q, data_cntr_q, timer_sync, bus_clock, parity_bit_q, data_register_q, data_cntr_max)
    begin
        data_cntr_en <= '0';
        timer_en <= '0';
        freq_divider_en <= '0';
        out_pos <= '0';
        out_neg <= '0';
        TX_DONE <= '0';
        state_d <= state_q;

        case state_q is
            when S_IDLE =>  

                if TX_en = "01" then        -- command word to be sent
                    state_d <= S_SYNC_POS;
                elsif TX_en = "10" then     -- data word to be sent
                    state_d <= S_SYNC_NEG;
                end if;
            when S_SYNC_POS =>
                timer_en <= '1';
                out_pos <= '1';

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
                out_neg <= '1';

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
                data_cntr_en <= '1';
                timer_en <= '1';
                freq_divider_en <= '1';

                --manchester coding
                out_pos <= not bus_clock xor data_register_q(15);
                out_neg <= (bus_clock xor data_register_q(15));

                -- when data are sent, mark FSM_Brain that it's done & go to idle
                if data_cntr_max = '1' then
                    TX_DONE <= '1';
                    state_d <= S_IDLE;
                end if;
        end case;
    end process;


    -- TIMER
    --comb part
    process (timer_en, timer_q, data_cntr_en)
    begin
        if timer_en = '1' then
            timer_d <= timer_q + 1;
        else
            timer_d <= (others => '0');
        end if;

        -- synchronize waveform stands for 3 bus periods -> one half is 1.5*bus period
        if timer_q = 3 * BUS_PERIOD/2 - 1 then
            timer_sync <= '1';
            timer_d <= (others => '0'); 
        else
            timer_sync <= '0';
        end if;

        -- when data are being sent (data_counter_en = '1'), signalize each end of bus period
        if timer_q = BUS_PERIOD - 1 and data_cntr_en = '1' then
            timer_max <= '1';
            timer_d <= (others => '0'); 
        else
            timer_max <= '0';
        end if;

    end process;


    -- DATA COUNTER
    --comb part
    process (data_cntr_q, data_cntr_en, timer_max)
    begin
        -- each bus period (-> timer_max = '1') one bit is sent -> data_counter++
        if data_cntr_en = '1' and timer_max = '1' then
            data_cntr_d <= data_cntr_q + 1;
        elsif data_cntr_en = '1' then
            data_cntr_d <= data_cntr_q;
        else
            data_cntr_d <= (others => '0'); 
        end if;

        -- data + parity
        if data_cntr_q = 17 then
            data_cntr_max <= '1';
        else
            data_cntr_max <= '0';
        end if;
    end process;

    -- DATA REGISTER
    --comb part
    process (data_wr, data_in, parity_bit_q, timer_max, data_cntr_q, data_cntr_en, data_register_q)
    begin
        parity_bit_d <= parity_bit_q;

        
        -- when data come to an encoder (signalized by data_wr), store them to data_register
        if data_wr = '1' then
            data_register_d(15 downto 0) <= data_in;
        else
            data_register_d <= data_register_q;
        end if;

        -- when data transmitting, each bus period shift register; when sending last value (data_counter_q = 16), set parity bit to an output
        if data_cntr_en = '1' and timer_max = '1' and data_cntr_q = 15 then -- last bit to be sent is parity bit
            if PARITY = '1' then
                data_register_d(15) <=  parity_bit_q xor data_register_q(15);       -- xor last sent bit with (currently calculated) parity bit, then send it
            else
                data_register_d(15) <=  not (parity_bit_q xor data_register_q(15));
            end if;
            
        elsif data_cntr_en = '1' and timer_max = '1' then -- shift register
            data_register_d <= data_register_q(14 downto 0) & '0';
            parity_bit_d <= parity_bit_q xor data_register_q(15);

        elsif data_cntr_en = '0' then    -- erase parity bit for future transfers (when not transfering)
            parity_bit_d <= '0';
        end if;

    end process;

    -- FREQUENCY DIVIDER
    --comb part
    process (freq_divider_q, freq_divider_en)
    begin
        if freq_divider_en = '1' then
            freq_divider_d <= freq_divider_q + 1;
        else
            freq_divider_d <= (others => '0');
        end if; 
    end process;

    -- 1 MHz
    bus_clock <= not freq_divider_q(4);

end architecture;