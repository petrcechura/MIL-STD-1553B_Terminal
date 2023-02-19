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

begin

    MAIN: process
    begin
        while (command.test_done /= '1') loop
            wait until command.start='1';
            Make_sync(pos_data_out, neg_data_out);
            Make_manchester(command.word, pos_data_out, neg_data_out);
        end loop;
        wait;
    end process;


end architecture;
