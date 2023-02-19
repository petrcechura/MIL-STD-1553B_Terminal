library ieee;
    use ieee.std_logic_1164.all;

library work;
    use work.Terminal_package.all;

entity WordCheck is
    generic map (
        size : integer := 17
    );
    port (
        clk   : in std_logic;
        reset : in std_logic;
        --paralel word in
        data_in : in std_logic_vector(size-1 downto 0);
        sync_type : in std_logic; -- '1' = data word
        --info about word
        command_word : out t_command_word;
        data_word : out t_data_word;
        word_type : out std_logic --data/command/invalid
        
    );
end entity;


architecture rtl of WordCheck is

begin

    process (data_in, sync_type)
    begin
        if sync_type = '1' then --data word
            word_type <= '1';
            data_word.data <= data_in;
        else --stat/com word
            word_type <= '0';
            command_word.t_r <= data_in(5);
            command_word.subaddress <= data_in(6 to 10);
            command_word.data_count_mc <= data_in(11 to 15);
        end if;
    end process;

end architecture;