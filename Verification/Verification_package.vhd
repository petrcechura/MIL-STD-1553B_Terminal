library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;


package verification_package is
    
    constant bus_period : time := 1 us; -- 1 MHz frequency
    constant bus_width : integer := 17;
    
    -- enviroment procedures
    --procedure Send_word(signal bits : in std_logic_vector(bus_width-1 downto 0));


    -- BFM procedures
    procedure Make_sync(signal sync_pos, sync_neg : out std_logic);
    procedure Make_manchester(  signal bits : in std_logic_vector(bus_width-1 downto 0);
                                signal manchester_pos, manchester_neg : out std_logic);


    type t_bfm_com is record
        word : std_logic_vector(bus_width-1 downto 0);
        start : std_logic;
        test_done : std_logic;
    end record;


end package;

package body Verification_package is
    
    procedure Make_manchester (  signal bits : in std_logic_vector(bus_width-1 downto 0);
                                 signal manchester_pos, manchester_neg : out std_logic) is
    begin
        for i in bits'length-1 downto 0 loop --MSB is sent first
            if bits(i) = '1' then
                manchester_neg <= '1';
                manchester_pos <= '0';
                wait for bus_period/2;
                manchester_neg <= '0';
                manchester_pos <= '1';
                wait for bus_period/2;
            else
                manchester_neg <= '0';
                manchester_pos <= '1';
                wait for bus_period/2;
                manchester_neg <= '1';
                manchester_pos <= '0';
                wait for bus_period/2;
            end if;
        end loop;
    end procedure;

    procedure Make_sync (signal sync_pos, sync_neg : out std_logic) is
    begin
        sync_pos <= '1';
        sync_neg <= '0';
        wait for 1.5*bus_period;
        sync_pos <= '0';
        sync_neg <= '1';
        wait for 1.5*bus_period;
    end procedure;
end package body;