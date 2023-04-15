 library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.terminal_package.all;
    
-- SYNCHRONIZE DETECTOR
    -- (mealy) state machine
    -- detects synchronize waveform via /sync_timer/
    -- if the full synchronize waveform is detected, the state s_synchronize is on (-> sampling by manchester decoder)

-- MANCHESTER DECODER
    -- log. value is sampled in 3/4 period via /manchester_timer/
    -- amount of periods is counted by /data_counter/
        -- when the maximum (17) is detected, state goes to default (and data are valid)
    -- if an error occures (wrong parite, unrecognized coding), data are invalid and error is reported to terminal via RX_DONE output
        -- data_error means failed sampling (detected by /manchester timer/)
        -- error_timer_max means invalid length of manchester coding (detected by /error_timer/)
        -- POSSIBLE ERROR HANDELINGS
            -- 2 synchronize waveforms next to each other -- tested, works
            -- wrong parite -- tested, works
            -- transfer interrupted -- to do test (should work)
            -- transfer started without synchronize waveform -- tested, works (error isn't reported -> this can be changed easily)
            -- valid word is sent right after (invalid) word, thats without sync waveform -- tested, doesnt work -- is it neccesary? 

-- RX DONE (2-bit)
    -- 00 = idle state (no data)
    -- 01 = command word
    -- 10 = data word
    -- 11 = error ocurred

entity ManchesterDecoder is
    -- for frequency 1 MHz
    port (
        clk   : in std_logic;
        reset : in std_logic;
        in_positive, in_negative : in std_logic;
        DATA_OUT : out std_logic_vector(15 downto 0);
        RX_DONE : out std_logic_vector(1 downto 0)
    );
end entity;



architecture rtl of ManchesterDecoder is
    -- SYNCHRONIZE DETECTOR --
    type t_state is (S_IDLE, --default state, terminal is waiting for signal
                     S_CMD_SYNC_1, --
                     S_CMD_SYNC_2,
                     S_CMD_SYNC_3, 
                     S_DATA_SYNC_1, 
                     S_DATA_SYNC_2,
                     S_DATA_SYNC_3, 
                     S_DATA_REC);
    signal state_q, state_d : t_state;

    --timer for sync sample
    signal sync_timer_en, sync_timer_mid_en : std_logic;
    signal sync_timer_d, sync_timer_q : unsigned(5 downto 0); --64-bit
    signal sync_timer_max, sync_timer_mid : std_logic;
    
    --sync type holder
    signal sync_type_d, sync_type_q : std_logic;

    -- MANCHESTER DECODER --
    --timer for data sample
    signal manchester_timer_en : std_logic;
    signal manchester_timer_d, manchester_timer_q : unsigned(4 downto 0);
    signal manchester_timer_sample, manchester_timer_max : std_logic;

    --counter for data count
    signal data_counter_en : std_logic;
    signal data_counter_d, data_counter_q : unsigned(4 downto 0); -- counts to 32 (17-bit word)
    signal data_counter_max : std_logic;
    
    --timer for error detection
    signal error_timer_pos_d, error_timer_pos_q, error_timer_neg_d, error_timer_neg_q : unsigned(5 downto 0);
    signal error_timer_en : std_logic;
    signal error_timer_max : std_logic;

    --data register
    signal decoded_data : unsigned(16 downto 0); -- 17-bit (data + parite)
    signal data_error : std_logic;

    --parity flip flop
    signal parity_bit_d, parity_bit_q : std_logic;
    signal parity_bit_en : std_logic;


    --JUST FOR SIMULATION
    signal state_d_show, state_q_show : unsigned(2 downto 0);
    
begin

    --*** SYNCHRONIZE DETECTOR ***--

    -- MAIN STATE MACHINE
    --seq part
    process (clk)
    begin
        if reset='1' then
            state_q <= S_IDLE;
            sync_type_q <= '0';
            sync_timer_q <= (others => '0'); 
            manchester_timer_q <= (others => '0'); 
            data_counter_q <= (others => '0'); 
            error_timer_pos_q <= (others => '0');
            error_timer_neg_q <= (others => '0');
            parity_bit_q <= '0';
        elsif rising_edge(clk) then
            state_q <= state_d;              
            sync_type_q <= sync_type_d;     -- info about synchronization type ('1' = command word, '0' = data word)
            sync_timer_q <= sync_timer_d;
            manchester_timer_q <= manchester_timer_d;
            data_counter_q <= data_counter_d; 
            error_timer_pos_q <= error_timer_pos_d;
            error_timer_neg_q <= error_timer_neg_d;
            parity_bit_q <= parity_bit_d;
        end if;
    end process;

    --comb part
    process (state_q, in_positive, in_negative, sync_timer_max, sync_timer_mid, data_counter_max, sync_type_q, decoded_data, data_error, error_timer_max)
    begin
        sync_timer_en <= '0';
        sync_timer_mid_en <= '0';
        manchester_timer_en <= '0';
        data_counter_en <= '0';
        error_timer_en <= '0';
        parity_bit_en <= '0';
        RX_DONE <= "00";
        state_d <= state_q;

        case state_q is 
            
            when S_IDLE =>

                if in_positive = '1' and in_negative = '0' then
                    state_d <= S_CMD_SYNC_1;
                elsif in_negative = '1' and in_positive = '0' then
                    state_d <= S_DATA_SYNC_1;
                end if;
            when S_CMD_SYNC_1 =>
                sync_timer_en <= '1';

                if sync_timer_max = '1' then
                    state_d <= S_CMD_SYNC_2;
                elsif in_positive = '1' and in_negative = '0' then
                    state_d <= S_CMD_SYNC_1;
                else
                    state_d <= S_IDLE;
                end if;

            when S_CMD_SYNC_2 =>
                sync_timer_mid_en <= '1';

                if sync_timer_mid='1' then
                    state_d <= S_CMD_SYNC_3;
                else
                    state_d <= S_CMD_SYNC_2;
                end if;

            when S_CMD_SYNC_3 =>
                sync_timer_en <= '1';

                if sync_timer_max='1' then
                    state_d <= S_DATA_REC;
                    sync_type_d <= '0';
                elsif in_positive='0' and in_negative='1' then
                    state_d <= S_CMD_SYNC_3;
                else
                    state_d <= S_IDLE;
                end if;

            when S_DATA_SYNC_1 =>
                sync_timer_en <= '1';

                if sync_timer_max='1' then
                    state_d <= S_DATA_SYNC_2;
                elsif in_positive='0' and in_negative='1' then
                    state_d <= S_DATA_SYNC_1;
                else
                    state_d <= S_IDLE;
                end if;
            when S_DATA_SYNC_2 =>
                sync_timer_mid_en <= '1';

                if sync_timer_mid='1' then
                    state_d <= S_DATA_SYNC_3;
                else
                    state_d <= S_DATA_SYNC_2;
                end if;
            when S_DATA_SYNC_3 =>
                sync_timer_en <= '1';

                if sync_timer_max='1' then
                    state_d <= S_DATA_REC;
                    sync_type_d <= '1';
                elsif in_positive='1' and in_negative='0' then
                    state_d <= S_DATA_SYNC_3;
                else
                    state_d <= S_IDLE;
                end if;

            when S_DATA_REC =>
                manchester_timer_en <= '1';
                data_counter_en <= '1';
                error_timer_en <= '1';
                parity_bit_en <= '1';

                if data_counter_max = '1' and sync_type_q = '0' and decoded_data(0) = parity_bit_q then
                    RX_DONE <= "01"; --command word

                    -- if the next message is right next to previous one, skip idle state
                    if in_positive = '1' and in_negative = '0' then
                        state_d <= S_CMD_SYNC_1;
                    elsif in_negative = '1' and in_positive = '0' then
                        state_d <= S_DATA_SYNC_1;
                    else
                        state_d <= S_IDLE;
                    end if;


                elsif data_counter_max = '1' and sync_type_q = '1' and decoded_data(0) = parity_bit_q then
                    RX_DONE <= "10"; --data word
                    
                    -- if the next message is right next to previous one, skip idle state
                    if in_positive = '1' and in_negative = '0' then
                        state_d <= S_CMD_SYNC_1;
                    elsif in_negative = '1' and in_positive = '0' then
                        state_d <= S_DATA_SYNC_1;
                    else
                        state_d <= S_IDLE;
                    end if;
                
                elsif data_error = '1' or error_timer_max = '1' or (data_counter_max = '1' and decoded_data(0) /= parity_bit_q) then
                    RX_DONE <= "11"; --error

                    -- if the next message is right next to previous one, skip idle state
                    if in_positive = '1' and in_negative = '0' then
                        state_d <= S_CMD_SYNC_1;
                    elsif in_negative = '1' and in_positive = '0' then
                        state_d <= S_DATA_SYNC_1;
                    else
                        state_d <= S_IDLE;
                    end if;
                        
                else
                    state_d <= S_DATA_REC;
                end if;
        end case;
    end process;

    DATA_OUT <= std_logic_vector(decoded_data(16 downto 1));


    --PARITY CALCULATION
    -- comb part
    process (parity_bit_q, manchester_timer_sample, in_positive, in_negative, data_counter_max)
    begin
        if parity_bit_en = '1' then
            if manchester_timer_sample = '1' and in_positive = '1' and data_counter_q < 16 then
                parity_bit_d <= ('1' xor parity_bit_q);
            elsif manchester_timer_sample = '1' and in_negative = '1' and data_counter_q < 16 then
                parity_bit_d <= ('0' xor parity_bit_q);
            else
                parity_bit_d <= parity_bit_q;
            end if;
        else
            parity_bit_d <= '0';
        end if;
    end process;


    -- SYNC TIMER SAMPLE
    -- comb part
    process (sync_timer_q, sync_timer_en, sync_timer_mid_en)
    begin
        if sync_timer_en = '1' or sync_timer_mid_en = '1' then
            sync_timer_d <= sync_timer_q+1;
        else
            sync_timer_d <= (others => '0');
        end if; 

        if sync_timer_q = 42 and sync_timer_en = '1' then
            sync_timer_max <= '1';
            sync_timer_d <= (others => '0'); 
        else
            sync_timer_max <= '0';
        end if;

        if sync_timer_q = BUS_PERIOD/4 and sync_timer_mid_en = '1' then
            sync_timer_mid <= '1';
            sync_timer_d <= (others => '0'); 
        else
            sync_timer_mid <= '0';
        end if;

    end process;

    --- *** MANCHESTER SAMPLE *** ---

    -- MANCHESTER TIMER SAMPLE
    --comb part
    process (manchester_timer_q, manchester_timer_en)
    begin
        if manchester_timer_en = '1' then
            manchester_timer_d <= manchester_timer_q + 1;
        else
            manchester_timer_d <= (others => '0'); 
        end if;

        if manchester_timer_q = (3 * BUS_PERIOD/4) then
            manchester_timer_sample <= '1';
        else
            manchester_timer_sample <= '0';
        end if;

        if manchester_timer_q = BUS_PERIOD-1 then
            manchester_timer_max <= '1';
        else
            manchester_timer_max <= '0';
        end if;
    end process;

    -- DATA REGISTER
    process (clk)
    begin
        if reset = '1' then
            decoded_data <= (others => '0');
            data_error <= '0';
        elsif rising_edge(clk) then
            if state_q = S_DATA_REC and manchester_timer_sample = '1' then
                if in_positive = '1' and in_negative = '0' then
                    data_error <= '0';
                    for i in 0 to 15 loop
                        decoded_data(i+1) <= decoded_data(i);
                    end loop;
                        decoded_data(0) <= '1';
                elsif in_negative = '1' and in_positive = '0' then
                    data_error <= '0';
                    for i in 0 to 15 loop
                        decoded_data(i+1) <= decoded_data(i);
                    end loop;
                        decoded_data(0) <= '0';
                else
                    data_error <= '1';
                    decoded_data <= (others => '0');
                end if;
            end if;
        end if;
    end process;

    -- DATA COUNTER
    --comb part
    process (data_counter_q, data_counter_en, manchester_timer_max)
    begin
        if data_counter_en = '1' and manchester_timer_max = '1' then
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

    -- ERROR TIMER
    --comb part
    process (error_timer_en, error_timer_en, error_timer_pos_q, error_timer_neg_q, in_positive, in_negative)
    begin
        if error_timer_en = '1' and in_positive = '1' then
            error_timer_pos_d <= error_timer_pos_q + 1;
        else
            error_timer_pos_d <= (others => '0');
        end if;

        if error_timer_en = '1' and in_negative = '1' then
            error_timer_neg_d <= error_timer_neg_q + 1;
        else
            error_timer_neg_d <= (others => '0');
        end if;
        
        if error_timer_pos_q = (3 * BUS_PERIOD/2) or error_timer_neg_q = (3 * BUS_PERIOD/2) then
            error_timer_max <= '1';
        else
            error_timer_max <= '0';
        end if;

    end process;

    --SIMULATION
    state_d_show <= "000" when state_d = S_IDLE else
                    "001" when state_d = S_CMD_SYNC_1 else
                    "010" when state_d = S_CMD_SYNC_2 else
                    "011" when state_d = S_CMD_SYNC_3 else
                    "100" when state_d = S_DATA_SYNC_1 else
                    "101" when state_d = S_DATA_SYNC_2 else
                    "110" when state_d = S_DATA_SYNC_3 else
                    "111" when state_d = S_DATA_REC;
 
    state_q_show <= "000" when state_q = S_IDLE else
                    "001" when state_q = S_CMD_SYNC_1 else
                    "010" when state_q = S_CMD_SYNC_2 else
                    "011" when state_q = S_CMD_SYNC_3 else
                    "100" when state_q = S_DATA_SYNC_1 else
                    "101" when state_q = S_DATA_SYNC_2 else
                    "110" when state_q = S_DATA_SYNC_3 else
                    "111" when state_q = S_DATA_REC;


end architecture;
