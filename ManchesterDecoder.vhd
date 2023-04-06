library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--Model is divided into two parts - Synchronize detector and Manchester decoder; first part is used for detection of synchronize waveform which stands
--for 3 bits. Detection is realized by state machine and timer; when a pos or neg input occurs, timer runs until 3/2 period (see Word Formats),
--then state is changed and opposite value is required. Whenever anything unexpected happens, state returns to default. Whenever a full synchronize waveform is detected, 
--data are sent to the second part, but only for 17 bit periods; after that time, state is returned to the default.
--Second part is free of any state machine and just gets log. value in every 3/4 period of data; output is then decoded signal.

--Sync type carries information how synchronization begins (data word begins with neg waveform, command with pos waveform)

entity ManchesterDecoder is
    -- for frequency 1 MHz
    port (
        clk   : in std_logic;
        reset : in std_logic;
        in_positive, in_negative : in std_logic;
        DATA_OUT : out std_logic_vector(15 downto 0);
        RX_DONE : out std_logic
    );
end entity;



architecture rtl of ManchesterDecoder is
    -- SYNCHRONIZE DETECTOR --
    type t_state is (s_default, --default state, terminal is waiting for signal
                     s_logic_one1, --
                     s_logic_one2,
                     s_logic_one3, 
                     s_logic_two1, 
                     s_logic_two2,
                     s_logic_two3, 
                     s_synchronize); -- stands for 17 manchester bit periods (measured just by time and known frequency); then goes to default
    signal state_q, state_d : t_state;

    --timer for sync sample
    signal sync_timer_en : std_logic;
    signal sync_timer_d, sync_timer_q : unsigned(5 downto 0); --64-bit
    signal sync_timer_max : std_logic;

    -- MANCHESTER DECODER --
    --timer for data sample
    signal manchester_timer_en : std_logic;
    signal manchester_timer_d, manchester_timer_q : unsigned(4 downto 0);
    signal manchester_timer_sample : std_logic;

    --counter for data count
    signal data_counter_en : std_logic;
    signal data_counter_d, data_counter_q : unsigned(3 downto 0); -- counts to 16 (16-bit word)
    signal data_counter_max : std_logic;
    
    --data register
    signal decoded_data : unsigned(16 downto 0); -- 17-bit (data + parite)
    signal parit_bit : std_logic;


    --JUST FOR SIMULATION
    signal state_d_show, state_q_show : unsigned(2 downto 0);


    
begin

    --*** SYNCHRONIZE DETECTOR ***--

    -- MAIN STATE MACHINE
    --seq part
    process (clk)
    begin
        if reset='1' then
            state_q <= s_default;
        elsif rising_edge(clk) then
            state_q <= state_d;
        end if;
    end process;

    --comb part
    process (state_q, in_positive, in_negative, sync_timer_max, data_counter_max)
    begin
        case state_q is 
            when s_default =>
                sync_timer_en <= '0';
                manchester_timer_en <= '0';
                data_counter_en <= '0';
                if in_positive= '1' and in_negative='0' then
                    state_d <= s_logic_one1;
                elsif in_negative = '1' and in_positive = '0' then
                    state_d <= s_logic_two1;
                else
                    state_d <= s_default;
                end if;
            when s_logic_one1 =>
                sync_timer_en <= '1';
                manchester_timer_en <= '0';
                data_counter_en <= '0';

                if sync_timer_max='1' then
                    state_d <= s_logic_one2;
                elsif in_positive='1' and in_negative='0' then
                    state_d <= s_logic_one1;
                else
                    state_d <= s_default;
                end if;

            when s_logic_one2 =>
                sync_timer_en <= '1';
                manchester_timer_en <= '0';
                data_counter_en <= '0';

                if sync_timer_max='1' then
                    state_d <= s_logic_one3;
                else
                    state_d <= s_logic_one2;
                end if;

            when s_logic_one3 =>
                sync_timer_en <= '1';
                manchester_timer_en <= '0';
                data_counter_en <= '0';

                if sync_timer_max='1' then
                    state_d <= s_synchronize;
                elsif in_positive='0' and in_negative='1' then
                    state_d <= s_logic_one3;
                else
                    state_d <= s_default;
                end if;

            when s_logic_two1 =>
                sync_timer_en <= '1';
                manchester_timer_en <= '0';
                data_counter_en <= '0';

                if sync_timer_max='1' then
                    state_d <= s_logic_two2;
                elsif in_positive='0' and in_negative='1' then
                    state_d <= s_logic_two1;
                else
                    state_d <= s_default;
                end if;
            when s_logic_two2 =>
                sync_timer_en <= '1';
                manchester_timer_en <= '0';
                data_counter_en <= '0';

                if sync_timer_max='1' then
                    state_d <= s_logic_two3;
                else
                    state_d <= s_logic_two2;
                end if;
            when s_logic_two3 =>
                sync_timer_en <= '1';
                manchester_timer_en <= '0';
                data_counter_en <= '0';

                if sync_timer_max='1' then
                    state_d <= s_synchronize;
                elsif in_positive='1' and in_negative='0' then
                    state_d <= s_logic_two3;
                else
                    state_d <= s_default;
                end if;

            when s_synchronize =>
                sync_timer_en <= '0';
                manchester_timer_en <= '1';
                data_counter_en <= '1';

                if data_counter_max='1' then
                    RX_DONE <= '1';
                    state_d <= s_default;
                else
                    state_d <= s_synchronize;
                end if;
        end case;
    end process;

    -- SYNC TIMER SAMPLE
    --seq part
    process (clk)
    begin
        if reset='1' then
            sync_timer_q <= (others => '0'); 
        elsif rising_edge(clk) then
            sync_timer_q <= sync_timer_d;
        end if;
    end process;

    -- comb part
    process (sync_timer_q, sync_timer_en)
    begin
        if sync_timer_en='1' then
            sync_timer_d <= sync_timer_q+1;
        else
            sync_timer_d <= (others => '0');
        end if; 

        if sync_timer_q=32 then
            sync_timer_max <= '1';
            sync_timer_d <= (others => '0'); 
        else
            sync_timer_max <= '0';
        end if;

    end process;

    --- *** MANCHESTER SAMPLE *** ---

    -- MANCHESTER TIMER SAMPLE
    --seq part
    process (clk)
    begin
        if reset='1' then
            manchester_timer_q <= (others => '0'); 
        elsif rising_edge(clk) then
            manchester_timer_q <= manchester_timer_d;
        end if;
    end process;

    --comb part
    process (manchester_timer_q, manchester_timer_en)
    begin
        if manchester_timer_en='1' then
            manchester_timer_d <= manchester_timer_q + 1;
        else
            manchester_timer_d <= (others => '0'); 
        end if;

        if manchester_timer_q=24 then
            manchester_timer_sample <= '1';
        else
            manchester_timer_sample <= '0';
        end if;

    end process;

    -- DATA REGISTER
    process (clk)
    begin
        if reset='1' then
            decoded_data <= (others => '0');
        elsif rising_edge(clk) then
            if state_q=s_synchronize and manchester_timer_sample='1' then
                if in_positive='1' and in_negative='0' then
                    for i in 0 to 15 loop
                        decoded_data(i+1) <= decoded_data(i);
                    end loop;
                        decoded_data(0) <= '1';
                elsif in_negative='1' and in_positive='0' then
                    for i in 0 to 15 loop
                        decoded_data(i+1) <= decoded_data(i);
                    end loop;
                        decoded_data(0) <= '0';
                else
                    --ERROR HANDLE TODO 
                    decoded_data(0) <= 'Z';
                end if;
            end if;
        end if;
    end process;

    -- DATA COUNTER
    --seq part
    process (clk)
    begin
        if reset='1' then
            data_counter_q <= (others => '0'); 
        elsif rising_edge(clk) then
            data_counter_q <= data_counter_d; 
        end if;
    end process;

    --comb part
    process (data_counter_q, data_counter_en, manchester_timer_sample)
    begin
        if data_counter_en='1' and manchester_timer_sample='1' then
            data_counter_d <= data_counter_q+1;
        elsif data_counter_en='1' then
            data_counter_d <= data_counter_q;
        else
            data_counter_d <= (others => '0');
        end if;

        if data_counter_q="1111" then
            data_counter_max <= '1';
        else
            data_counter_max <= '0';
        end if;
    end process;



    --SIMULATION
    state_d_show <= "000" when state_d=s_default else
                    "001" when state_d=s_logic_one1 else
                    "010" when state_d=s_logic_one2 else
                    "011" when state_d=s_logic_one3 else
                    "100" when state_d=s_logic_two1 else
                    "101" when state_d=s_logic_two2 else
                    "110" when state_d=s_logic_two3 else
                    "111" when state_d=s_synchronize;

    state_q_show <= "000" when state_q=s_default else
                    "001" when state_d=s_logic_one1 else
                    "010" when state_d=s_logic_one2 else
                    "011" when state_d=s_logic_one3 else
                    "100" when state_d=s_logic_two1 else
                    "101" when state_d=s_logic_two2 else
                    "110" when state_d=s_logic_two3 else
                    "111" when state_d=s_synchronize;


end architecture;
