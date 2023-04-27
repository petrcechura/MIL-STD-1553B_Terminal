library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.Verification_package.all;


entity BFM is
    port (
        --terminal & BFM
        pos_data_out : out std_logic;
        neg_data_out : out std_logic;

        -- decoder & BFM
        data_from_TU : in std_logic_vector(15 downto 0);
        RX_done : in std_logic_vector(1 downto 0);

        --enviroment & BFM
        command : in t_bfm_com;
        response : out std_logic
    );
end entity;

architecture rtl of BFM is
    signal cmd_word : std_logic := '1';
    signal data_word : std_logic := '0';

begin

    MAIN: process
        variable d_bit : std_logic;
    begin
        pos_data_out <= '0';
        neg_data_out <= '0';
        while (true) loop
            wait until command.start='1';
            response <= '0';

            if command.command_number = 1 then                      -- TRANSMITT COMMAND WORD
                Make_sync(cmd_word, pos_data_out, neg_data_out);
                for i in command.bits_length - 1 downto 0 loop
                    d_bit := command.bits(i);
                    Make_manchester(d_bit, pos_data_out, neg_data_out);
                end loop;

            elsif command.command_number = 2 then                   -- TRANSMITT DATA WORD
                Make_sync(data_word, pos_data_out, neg_data_out);
                for i in command.bits_length - 1 downto 0 loop
                    d_bit := command.bits(i);
                    Make_manchester(d_bit, pos_data_out, neg_data_out);
                end loop;

            elsif command.command_number = 4 then                   -- TRANSMITT INVALID COMMAND WORD
                if command.sync = true then
                    Make_sync(cmd_word, pos_data_out, neg_data_out);
                end if;

                for i in command.bits_length - 1 downto 0 loop
                    d_bit := command.bits(i);
                    Make_manchester(d_bit, pos_data_out, neg_data_out);
                end loop;

            elsif command.command_number = 5 then                   -- TRANSMITT INVALID DATA WORD
                if command.sync = true then
                    Make_sync(data_word, pos_data_out, neg_data_out);
                end if;
                
                for i in command.bits_length - 1 downto 0 loop
                    d_bit := command.bits(i);
                    Make_manchester(d_bit, pos_data_out, neg_data_out);
                end loop;
            elsif command.command_number = 7 then                   -- RECEIVE WORD FROM TERMINAL
                wait until RX_done /= "00";
                
                if RX_done = "01" then
                    report "BFM: Received Status word: " & to_string(data_from_TU);
                elsif RX_done = "10" then
                    report "BFM: Received Data word: " & to_string(data_from_TU);
                else
                    report "BFM: Received !Error!";
                end if;
                
            else
                assert (true)
                    report "Unrecognized command number!"
                    severity error;
                
                wait;
            end if;

            pos_data_out <= '0';
            neg_data_out <= '0';
            response <= '1';

        end loop;
        wait;
    end process;


end architecture;
