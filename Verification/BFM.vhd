library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.Verification_package.all;


entity BFM is
    port (
        --terminal & BFM
        data_in : in std_logic;
        pos_data_out : out std_logic;
        neg_data_out : out std_logic;

        --enviroment & BFM
        command : in t_bfm_com
    );
end entity;



architecture rtl of BFM is
    signal cmd_word : std_logic := '1';
    signal data_word : std_logic := '0';

begin

    MAIN: process
    begin
        pos_data_out <= '0';
        neg_data_out <= '0';
        while (command.test_done /= '1') loop

            if command.command_number = 1 then
                -- TEST NO. xx
            elsif command.command_number = 2 then
                -- TEST NO. xx
            elsif command.command_number = 3 then
                -- TEST NO. xx
            elsif command.command_number = 4 then
                -- TEST NO. xx
            elsif command.command_number = 5 then
                -- TEST NO. xx
            elsif command.command_number = 6 then
                -- TEST NO. xx
            elsif command.command_number = 7 then
                -- TEST NO. xx
            elsif command.command_number = 8 then
                -- TEST NO. xx


            wait until command.start='1';
            Make_sync(cmd_word, pos_data_out, neg_data_out);
            Make_manchester(command.word, pos_data_out, neg_data_out);
            pos_data_out <= '0';
            neg_data_out <= '0';
            wait for 0.5 us;
            Make_sync(data_word, pos_data_out, neg_data_out);
            Make_manchester(command.word, pos_data_out, neg_data_out);
        end loop;
        wait;
    end process;


end architecture;
