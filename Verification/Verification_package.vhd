library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;


package verification_package is
    
    constant bus_period : time := 1 us; -- 1 MHz frequency
    constant bus_width : integer := 17;

    type t_MEM_TO_TU is record
        -- unit -> memory
        write_en : std_logic;
        read_en : std_logic;
        data_in : std_logic_vector(15 downto 0);
        subaddr : std_logic_vector(4 downto 0);
        -- memory -> unit
        wr_done : std_logic;
        rd_done : std_logic;
        data_out : std_logic_vector(15 downto 0);
    end record;

    type t_TU_TO_BFM is record
        in_pos : std_logic;
        in_neg : std_logic;
        out_pos : std_logic;
        out_neg : std_logic;
    end record;



    
    -- MESSAGES
    --procedure RT_to_BC( variable data : in integer;
    --                    variable address : in unsigned(4 downto 0);
    --                    variable subaddress : in unsigned(4 downto 0));
    --procedure BC_to_RT( variable data_count : in integer;
    --                    variable address : in unsigned(4 downto 0);
    --                    variable subaddress : in unsigned(4 downto 0));




    -- enviroment procedures
    procedure Send_command_word(signal address : in unsigned(4 downto 0);
                                signal TR_bit : in std_logic;
                                signal subaddress : in unsigned(4 downto 0);
                                signal data_word_count : in unsigned(4 downto 0));
    procedure Send_data_word(signal bits : in unsigned(16 downto 0));
    procedure Send_invalid_word(variable data_length : in integer;
                                variable parite : std_logic; -- '1' = odd, '0' = even
                                variable sync_type : std_logic); -- '1' = com_word, '0' = data_word


    -- BFM procedures
    procedure Make_sync(signal sync_type : in std_logic; -- '1' = com_word, '0' = data_word
                        signal sync_pos, sync_neg : out std_logic);
    procedure Make_manchester(  signal bits : in std_logic_vector(bus_width-1 downto 0);
                                signal manchester_pos, manchester_neg : out std_logic);


    type t_bfm_com is record
        word : std_logic_vector(bus_width-1 downto 0);
        start : std_logic;
        test_done : std_logic;
        command_number : integer;
    end record;


end package;

package body Verification_package is
    





    procedure Send_command_word(signal address : in unsigned(4 downto 0);
                                signal TR_bit : in std_logic;
                                signal subaddress : in unsigned(4 downto 0);
                                signal data_word_count : in unsigned(4 downto 0);
                                signal to_bfm : out t_bfm_com) is
    begin
        






    end procedure;


    procedure Send_data_word (signal bits : in unsigned(16 downto 0)) is
    begin
        


    end procedure;

    procedure Send_invalid_word(variable data_length : in integer;
                                variable parite : std_logic; 
                                variable sync_type : std_logic) is
    begin



    end procedure;


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

    procedure Make_sync (signal sync_type : in std_logic;
                         signal sync_pos, sync_neg : out std_logic) is
    begin
        if sync_type='1' then
            sync_pos <= '1';
            sync_neg <= '0';
            wait for 1.5*bus_period;
            sync_pos <= '0';
            sync_neg <= '1';
            wait for 1.5*bus_period;
        else
            sync_pos <= '0';
            sync_neg <= '1';
            wait for 1.5*bus_period;
            sync_pos <= '1';
            sync_neg <= '0';
            wait for 1.5*bus_period;
        end if;
    end procedure;
end package body;