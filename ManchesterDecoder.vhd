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
        data_out : out std_logic;
        data_change : out std_logic;
        sync_type : out std_logic;
        state_out : out std_logic_vector(2 downto 0)
    );
end entity;



architecture rtl of ManchesterDecoder is
    --synchronize detector--
    type t_state is (s_default, --default state, terminal is waiting for signal
                     s_logic_one1, -- pos input is detected; state is held until 3/2 period or when input changes its value (invalid sync)
                     s_logic_one2, -- neg input is detected after previous pos stood still for 3/2 period; when this value remains unchanged for 3/2 period, sync was succesful
                     s_logic_two1, -- same but viceversa
                     s_logic_two2, -- same but viceversa
                     s_synchronize); -- stands for 17 manchester bit periods (measured just by time and known frequency); then goes to default

    signal timer_sig : unsigned(5 downto 0);
    signal timer_enable : std_logic;
    signal timer_max : std_logic;
    signal state : t_state := s_default;
    --synchronize word count; how many bits are after sync
    signal word_count : unsigned(4 downto 0) := (others => '0');
    constant word_size : integer := 17; 
    
    --manchester decoder--
    signal cnt_sig : unsigned(4 downto 0);
    signal data : std_logic := '0';
    signal clk_en : std_logic := '0';
    
    
begin

    ---SYNCHRONIZE DETECTOR---
    process (clk, reset)
    begin
        if reset='1' then
            state <= s_default;
        elsif rising_edge(clk) then
            case state is 
                when s_default =>
                    if in_positive='1' then
                        state <= s_logic_one1;
                    elsif in_negative='1' then
                        state <= s_logic_two1;
                    else
                        state <= s_default;
                    end if;
                when s_logic_one1 =>
                    if timer_max='1' then
                        state <= s_logic_one2;
                    elsif in_positive='1' then
                        state <= s_logic_one1;
                    else
                        state <= s_default;
                    end if;
                when s_logic_one2 =>
                    if timer_max='1' then
                        state <= s_synchronize;
                        sync_type <= '0'; --com word
                    elsif in_negative='1' then
                        state <= s_logic_one2;
                    else
                        state <= s_default;
                    end if;
                when s_logic_two1 =>
                    if timer_max='1' then
                        state <= s_logic_two2;
                    elsif in_negative = '1' then
                        state <= s_logic_two1;
                    else
                        state <= s_default;
                    end if;
                when s_logic_two2 =>
                    if timer_max='1' then
                        state <= s_synchronize;
                    elsif in_positive='1' then
                        state <= s_logic_two2;
                    else 
                        state <= s_default;
                    end if;
                when s_synchronize =>
                    if word_count = word_size then
                        state <= s_default;
                        sync_type <= '0';
                    else
                        state <= s_synchronize;
                    end if;
            end case;
        end if;
    end process;

    process (state, in_positive, in_negative)
    begin
        timer_enable <= '0' when state=s_default
                        else '1';

        if state=s_synchronize and in_positive /= in_negative then
            data <= '1' when in_positive='1'
                    else '0';
            clk_en <= '1';
        else
            data <= 'Z';
            clk_en <= '0';
        end if;

    end process;

    --timer
    process (clk)
    begin
        if reset = '1' then
            timer_sig <= (others => '0');
        elsif rising_edge(clk) then
            if timer_enable='1' and timer_sig=46 then
                timer_sig <= (others => '0');
            elsif timer_enable='1' then
                timer_sig <= timer_sig+1;
            else
                timer_sig <= (others => '0');
            end if;
        end if;
    end process;

    timer_max <= '1' when timer_sig=46 else '0';

    --word count
    process (clk, timer_max)
    begin
        if reset = '1' then
            word_count <= (others => '0');
        elsif rising_edge(clk) then
            if timer_max='1' and state=s_synchronize then
                word_count <= word_count+1;
            elsif timer_max='1' then
                word_count <= (others => '0');
            else
                word_count <= word_count;
            end if;
        end if;
    end process;


    -- state machine show
    state_out <=        "000" when state=s_default
                else    "001" when state=s_logic_one1
                else    "010" when state=s_logic_one2
                else    "011" when state=s_logic_two1
                else    "100" when state=s_logic_two2
                else    "111" when state=s_synchronize;

    ---MANCHESTER DECODER---
    process (clk)
    begin
        if reset = '1' then
            cnt_sig <= (others => '0');
        elsif rising_edge(clk) then
            if clk_en='1' then
                cnt_sig <= cnt_sig + 1;
            else
                cnt_sig <= cnt_sig;
            end if;
        end if;
    end process;

    process (cnt_sig, reset)
    begin
        if reset = '1' then
            data_out <= '0';
            data_change <= '0';
        elsif cnt_sig = 24 then --get value in 3/4 period
            data_out <= data;
            data_change <= '1';
        else
            data_out <= data_out;
            data_change <= '0';
        end if;
    end process;
    

end architecture;
