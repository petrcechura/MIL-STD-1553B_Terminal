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
    -- log. value is sampled in 1/4 period via /manchester_timer/
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
        RX_pos, RX_neg : in std_logic;
        DATA_OUT : out std_logic_vector(15 downto 0);
        RX_DONE : out std_logic_vector(1 downto 0);
        RX_flag : out std_logic
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
    signal sync_tmr_en, sync_tmr_mid_en : std_logic;
    signal sync_tmr_d, sync_tmr_q : unsigned(5 downto 0); --64-bit
    signal sync_tmr_max, sync_tmr_mid : std_logic;
    
    --sync type holder
    signal sync_type_d, sync_type_q : std_logic;

    -- MANCHESTER DECODER --
    --timer for data sample
    signal mster_tmr_en : std_logic;
    signal mster_tmr_d, mster_tmr_q : unsigned(4 downto 0);
    signal mster_tmr_sample, mster_tmr_max : std_logic;

    --counter for data count
    signal data_cntr_en : std_logic;
    signal data_cntr_d, data_cntr_q : unsigned(4 downto 0); -- counts to 32 (17-bit word)
    signal data_cntr_max : std_logic;
    
    --timer for error detection
    signal err_tmr_pos_d, err_tmr_pos_q, err_tmr_neg_d, err_tmr_neg_q : unsigned(5 downto 0);
    signal err_tmr_en : std_logic;
    signal err_tmr_max : std_logic;

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
    process (clk, reset)
    begin
        if reset = '1' then
            state_q <= S_IDLE;
            sync_type_q <= '0';
            sync_tmr_q <= (others => '0'); 
            mster_tmr_q <= (others => '0'); 
            data_cntr_q <= (others => '0'); 
            err_tmr_pos_q <= (others => '0');
            err_tmr_neg_q <= (others => '0');
            parity_bit_q <= '0';
        elsif rising_edge(clk) then
            state_q <= state_d;              
            sync_type_q <= sync_type_d;     -- info about synchronization type ('1' = command word, '0' = data word)
            sync_tmr_q <= sync_tmr_d;
            mster_tmr_q <= mster_tmr_d;
            data_cntr_q <= data_cntr_d; 
            err_tmr_pos_q <= err_tmr_pos_d;
            err_tmr_neg_q <= err_tmr_neg_d;
            parity_bit_q <= parity_bit_d;
        end if;
    end process;

    --comb part
    process (state_q, RX_pos, RX_neg, sync_tmr_max, sync_tmr_mid, data_cntr_max, sync_type_q, decoded_data, data_error, err_tmr_max, parity_bit_q)
    begin
        sync_tmr_en <= '0';
        sync_tmr_mid_en <= '0';
        mster_tmr_en <= '0';
        data_cntr_en <= '0';
        err_tmr_en <= '0';
        parity_bit_en <= '0';
        sync_type_d <= sync_type_q;
        RX_DONE <= "00";
        state_d <= state_q;
        RX_flag <= '1';

        case state_q is 
            
            when S_IDLE =>
                RX_flag <= '0';
                
                if RX_pos = '1' and RX_neg = '0' then
                    state_d <= S_CMD_SYNC_1;
                elsif RX_neg = '1' and RX_pos = '0' then
                    state_d <= S_DATA_SYNC_1;
                end if;
            when S_CMD_SYNC_1 =>
                sync_tmr_en <= '1';

                if sync_tmr_max = '1' then
                    state_d <= S_CMD_SYNC_2;
                elsif RX_pos = '1' and RX_neg = '0' then
                    state_d <= S_CMD_SYNC_1;
                else
                    state_d <= S_IDLE;
                end if;

            when S_CMD_SYNC_2 =>
                sync_tmr_mid_en <= '1';

                if sync_tmr_mid='1' then
                    state_d <= S_CMD_SYNC_3;
                else
                    state_d <= S_CMD_SYNC_2;
                end if;

            when S_CMD_SYNC_3 =>
                sync_tmr_en <= '1';

                if sync_tmr_max='1' then
                    state_d <= S_DATA_REC;
                    sync_type_d <= '0';
                elsif RX_pos='0' and RX_neg='1' then
                    state_d <= S_CMD_SYNC_3;
                else
                    state_d <= S_IDLE;
                end if;

            when S_DATA_SYNC_1 =>
                sync_tmr_en <= '1';

                if sync_tmr_max='1' then
                    state_d <= S_DATA_SYNC_2;
                elsif RX_pos='0' and RX_neg='1' then
                    state_d <= S_DATA_SYNC_1;
                else
                    state_d <= S_IDLE;
                end if;
            when S_DATA_SYNC_2 =>
                sync_tmr_mid_en <= '1';

                if sync_tmr_mid='1' then
                    state_d <= S_DATA_SYNC_3;
                else
                    state_d <= S_DATA_SYNC_2;
                end if;
            when S_DATA_SYNC_3 =>
                sync_tmr_en <= '1';

                if sync_tmr_max='1' then
                    state_d <= S_DATA_REC;
                    sync_type_d <= '1';
                elsif RX_pos='1' and RX_neg='0' then
                    state_d <= S_DATA_SYNC_3;
                else
                    state_d <= S_IDLE;
                end if;

            when S_DATA_REC =>
                mster_tmr_en <= '1';
                data_cntr_en <= '1';
                err_tmr_en <= '1';
                parity_bit_en <= '1';

                -- all data has been gathered and it's command word -> inform FSM_brain and go to IDLE
                if data_cntr_max = '1' and sync_type_q = '0' and decoded_data(0) = parity_bit_q then
                    RX_DONE <= "01"; --command word

                    -- if the next message is right next to previous one, skip idle state
                    if RX_pos = '1' and RX_neg = '0' then
                        state_d <= S_CMD_SYNC_1;
                    elsif RX_neg = '1' and RX_pos = '0' then
                        state_d <= S_DATA_SYNC_1;
                    else
                        state_d <= S_IDLE;
                    end if;

                    -- all data has been gathered and it's data word -> inform FSM_brain and go to IDLE
                elsif data_cntr_max = '1' and sync_type_q = '1' and decoded_data(0) = parity_bit_q then
                    RX_DONE <= "10"; --data word
                    
                    -- if the next message is right next to previous one, skip idle state
                    if RX_pos = '1' and RX_neg = '0' then
                        state_d <= S_CMD_SYNC_1;
                    elsif RX_neg = '1' and RX_pos = '0' then
                        state_d <= S_DATA_SYNC_1;
                    else
                        state_d <= S_IDLE;
                    end if;

                    -- an error occured while collecting data -> inform FSM_brain and go to idle
                elsif data_error = '1' or err_tmr_max = '1' or (data_cntr_max = '1' and decoded_data(0) /= parity_bit_q) then
                    RX_DONE <= "11"; --error

                    -- if the next message is right next to previous one, skip idle state
                    if RX_pos = '1' and RX_neg = '0' then
                        state_d <= S_CMD_SYNC_1;
                    elsif RX_neg = '1' and RX_pos = '0' then
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
    process (parity_bit_q, mster_tmr_sample, RX_pos, RX_neg, data_cntr_max, parity_bit_en, data_cntr_q)
    begin
        if parity_bit_en = '1' then
            if mster_tmr_sample = '1' and RX_pos = '1' and data_cntr_q < 16 then
                parity_bit_d <= ('1' xor parity_bit_q);
            elsif mster_tmr_sample = '1' and RX_neg = '1' and data_cntr_q < 16 then
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
    process (sync_tmr_q, sync_tmr_en, sync_tmr_mid_en)
    begin
        if sync_tmr_en = '1' or sync_tmr_mid_en = '1' then
            sync_tmr_d <= sync_tmr_q+1;
        else
            sync_tmr_d <= (others => '0');
        end if; 

        if sync_tmr_q = 42 and sync_tmr_en = '1' then
            sync_tmr_max <= '1';
            sync_tmr_d <= (others => '0'); 
        else
            sync_tmr_max <= '0';
        end if;

        if sync_tmr_q = BUS_PERIOD/4 and sync_tmr_mid_en = '1' then
            sync_tmr_mid <= '1';
            sync_tmr_d <= (others => '0'); 
        else
            sync_tmr_mid <= '0';
        end if;

    end process;

    --- *** MANCHESTER SAMPLE *** ---

    -- MANCHESTER TIMER SAMPLE
    --comb part
    process (mster_tmr_q, mster_tmr_en)
    begin
        if mster_tmr_en = '1' then
            mster_tmr_d <= mster_tmr_q + 1;
        else
            mster_tmr_d <= (others => '0'); 
        end if;

        if mster_tmr_q = (BUS_PERIOD/4) then
            mster_tmr_sample <= '1';
        else
            mster_tmr_sample <= '0';
        end if;

        if mster_tmr_q = BUS_PERIOD-1 then
            mster_tmr_max <= '1';
        else
            mster_tmr_max <= '0';
        end if;
    end process;

    -- DATA REGISTER
    process (clk, reset)
    begin
        if reset = '1' then
            decoded_data <= (others => '0');
            data_error <= '0';
        elsif rising_edge(clk) then
            if state_q = S_DATA_REC and mster_tmr_sample = '1' then
                data_error <= '0';
                if RX_pos = '1' and RX_neg = '0' then
                    for i in 0 to 15 loop
                        decoded_data(i+1) <= decoded_data(i);
                    end loop;
                        decoded_data(0) <= '1';
                elsif RX_neg = '1' and RX_pos = '0' then
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
    process (data_cntr_q, data_cntr_en, mster_tmr_max)
    begin
        if data_cntr_en = '1' and mster_tmr_max = '1' then
            data_cntr_d <= data_cntr_q + 1;
        elsif data_cntr_en = '1' then
            data_cntr_d <= data_cntr_q;
        else
            data_cntr_d <= (others => '0');
        end if;

        if data_cntr_q = 17 then
            data_cntr_max <= '1';
        else
            data_cntr_max <= '0';
        end if;
    end process;

    -- ERROR TIMER
    --comb part
    process (err_tmr_en, err_tmr_en, err_tmr_pos_q, err_tmr_neg_q, RX_pos, RX_neg)
    begin
        if err_tmr_en = '1' and RX_pos = '1' then
            err_tmr_pos_d <= err_tmr_pos_q + 1;
        else
            err_tmr_pos_d <= (others => '0');
        end if;

        if err_tmr_en = '1' and RX_neg = '1' then
            err_tmr_neg_d <= err_tmr_neg_q + 1;
        else
            err_tmr_neg_d <= (others => '0');
        end if;
        
        if err_tmr_pos_q = (3 * BUS_PERIOD/2) or err_tmr_neg_q = (3 * BUS_PERIOD/2) then
            err_tmr_max <= '1';
        else
            err_tmr_max <= '0';
        end if;

    end process;

    --Necessary part for simulation via GHDL tool (that I was using)
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
