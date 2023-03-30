library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
    use work.verification_package.all;

--Model is divided into two parts - Synchronize detector and Manchester decoder; first part is used for detection of synchronize waveform which stands
--for 3 bits. Detection is realized by state machine and timer; every bit period there is a check if the signal is in the right polarity - if so, state
--goes forward. Whenever a full synchronize waveform is detected, data are sent to the second part, but only for 17 bit periods; after that time, state
--is returned to the default.
--Second part is free of any state machine and just gets log. value in every 3/4 period of data; output is then decoded signal.

--Sync type carries information how synchronization begins (data word begins with neg waveform, command with pos waveform)

entity ManchesterDecoder is
    -- for frequency 1 MHz
    port (
        clk   : in std_logic;
        reset : in std_logic;
        in_positive, in_negative : in std_logic;
        word_out : out std_logic_vector(bus_width-1 downto 0); --whole word is output
        sync_type : out std_logic; -- '1' for command word, '0' for data word
        state_out : out std_logic_vector(2 downto 0)
    );
end entity;



architecture rtl of ManchesterDecoder is
    --synchronize detector--
    type t_state is (s_awaiting,
                     s_logic_one1, -- sync begins with '1' (command word)
                     s_logic_one2,
                     s_logic_one3,
                     s_logic_two1, -- sync begins with '1' (data word)
                     s_logic_two2,
                     s_logic_two3,
                     s_synchronize); -- sync was fully detected, now sample data

    signal state : t_state;
    --timer
    signal timer_d, timer_q : unsigned(4 downto 0);
    signal timer_max : std_logic;


    
    --manchester decoder--
    signal cnt_sig : unsigned(4 downto 0);
    signal data : std_logic := '0';
    signal clk_en : std_logic := '0';
    
    
begin

    -- state machine show
    state_out <=        "000" when state=s_awaiting
                else    "001" when state=s_logic_one1
                else    "010" when state=s_logic_one2
                else    "011" when state=s_logic_one3
                else    "100" when state=s_logic_two1
                else    "101" when state=s_logic_two2
                else    "110" when state=s_logic_two3
                else    "111" when state=s_synchronize;


    -- TIMER (5 BIT)
    --seq part
    process (clk)
    begin
        if rising_edge(clk) then
            timer_q <= timer_d;
        end if;
    end process;
    
    --comb part
    process (timer_q)
    begin
        timer_d <= timer_q + 1;
        if timer_q = (others => '1') then
            timer_max <= '1';
        else
            timer_max <= '0';
        end if;
    end process;


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
