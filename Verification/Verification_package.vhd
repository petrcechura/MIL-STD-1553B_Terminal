library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;


package verification_package is

    constant BUS_PERIOD : time := 1 us; -- 1 MHz frequency
    constant BUS_WIDTH : integer := 17;


    --************************************************--
    -- ** CUSTOM DATA TYPES FOR ROUTING COMPONENTS ** --
    --************************************************--
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
        -- BFM -> unit
        in_pos : std_logic;
        in_neg : std_logic;
        -- unit -> BFM
        out_pos : std_logic;
        out_neg : std_logic;
    end record;

    type t_DEC_TO_BFM is record
        -- decoder -> BFM
        data_from_TU : std_logic_vector(15 downto 0);
        RX_done : std_logic_vector(1 downto 0);
    end record;

    type t_bfm_com is record
        -- environment -> BFM
        bits : unsigned(bus_width-1 downto 0);
        bits_length : integer;
        start : std_logic;
        sync : Boolean;
        command_number : integer; -- *(1)
    end record;

    -- *(1) COMMAND NUMBER
        -- 1 = Command word (synchronize + word)
        -- 2 = Data word (synchronize + word)
        -- 3 = Word without synchronize
        -- 4 = Invalid word (synchronize + short word)
        -- 7 = Receive word (print to console)
    
    --************************************************--
    --   ** WORD TRANSMITTING/RECEIVING PROCEDURES  **--
    --************************************************--
    procedure Send_command_word(variable address : in unsigned(4 downto 0);
                                variable TR_bit : in std_logic;
                                variable subaddress : in unsigned(4 downto 0);
                                variable data_word_count : in unsigned(4 downto 0);
                                signal to_bfm : out t_bfm_com;
                                signal from_bfm : in std_logic);

    procedure Send_data_word(variable bits : in unsigned(15 downto 0);
                             signal to_bfm : out t_bfm_com;
                             signal from_bfm : in std_logic);

    procedure Send_invalid_command_word(variable bits : in unsigned(15 downto 0);
                             data_length : integer;
                             wrong_parite : Boolean; 
                             sync : Boolean;
                             signal to_bfm : out t_bfm_com;
                             signal from_bfm : in std_logic);

    procedure Send_invalid_data_word(   variable bits : in unsigned(15 downto 0);
                             data_length : integer;
                             wrong_parite : Boolean; 
                             sync : Boolean;
                             signal to_bfm : out t_bfm_com;
                             signal from_bfm : in std_logic);

    procedure Receive_word (signal to_bfm : out t_bfm_com;
                            signal from_bfm : in std_logic);
        


    --************************************************--
    --    ** PROCEDURES USED IN BFM TO MAKE WORD **   --
    --************************************************--
    procedure Make_sync(signal sync_type : in std_logic; -- '1' = com_word, '0' = data_word
                        signal sync_pos, sync_neg : out std_logic);
    procedure Make_manchester(  variable data_bit : std_logic;
                                signal manchester_pos, manchester_neg : out std_logic);

end package;

package body Verification_package is

    procedure Send_command_word(variable address : in unsigned(4 downto 0);
                                variable TR_bit : in std_logic;
                                variable subaddress : in unsigned(4 downto 0);
                                variable data_word_count : in unsigned(4 downto 0);
                                signal to_bfm : out t_bfm_com;
                                signal from_bfm : in std_logic) is
        variable parity_bit : std_logic := '0';
        variable v_bits : unsigned(15 downto 0);
    begin

        to_bfm.command_number <= 1;
        v_bits := address & TR_bit & subaddress & data_word_count;

        -- parity calculation
        parity_bit := v_bits(15);
        for i in 14 downto 0 loop
            parity_bit := parity_bit xor v_bits(i); 
        end loop;
        
        to_bfm.bits <= v_bits & parity_bit;
        to_bfm.bits_length <= 17;
        --START TEST
        report "SENDING COMMAND WORD... (" & to_string(v_bits) & ")";

        to_bfm.start <= '1';
        wait for 1 ns;
        to_bfm.start <= '0';

        wait until from_bfm = '1';

    end procedure;


    procedure Send_data_word (variable bits : in unsigned(15 downto 0);
                              signal to_bfm : out t_bfm_com;
                              signal from_bfm : in std_logic) is
        variable parity_bit : std_logic := '0';
        variable v_bits : unsigned(15 downto 0);
    begin
        to_bfm.command_number <= 2;
        v_bits := bits;

        -- parity calculation
        parity_bit := v_bits(15);
        for i in 14 downto 0 loop
            parity_bit := parity_bit xor v_bits(i); 
        end loop;
        
        to_bfm.bits <= v_bits & parity_bit;
        to_bfm.bits_length <= 17;
        
        --START TEST
        report "SENDING DATA WORD... (" & to_string(v_bits) & ")";
        to_bfm.start <= '1';
        wait for 1 ns;
        to_bfm.start <= '0';

        wait until from_bfm = '1';

    end procedure;

    procedure Send_invalid_command_word(variable bits : in unsigned(15 downto 0);
                                        data_length : integer;
                                        wrong_parite : Boolean; 
                                        sync : Boolean;
                                        signal to_bfm : out t_bfm_com;
                                        signal from_bfm : in std_logic) is
        variable parity_bit : std_logic := '0';
    begin

        to_bfm.command_number <= 4;
        to_bfm.sync <= sync;

        -- parity calculation
        parity_bit := bits(15);
        for i in 14 downto 0 loop
            parity_bit := parity_bit xor bits(i); 
        end loop;
        parity_bit := (not parity_bit) when wrong_parite = true else parity_bit;
        
        to_bfm.bits <= bits & parity_bit;
        to_bfm.bits_length <= data_length;
        wait for 1 ns;

        --START TEST
        report "SENDING INVALID COMMAND WORD... (" & to_string(bits) & ")";
        report "...with bits length: " & to_string(data_length);
        report "... and parity is: "  & to_string(parity_bit);
        to_bfm.start <= '1';
        wait for 1 ns;
        to_bfm.start <= '0';

        wait until from_bfm = '1';

    end procedure;

    procedure Send_invalid_data_word(   variable bits : in unsigned(15 downto 0);
                                        data_length : integer;
                                        wrong_parite : Boolean;
                                        sync : Boolean; 
                                        signal to_bfm : out t_bfm_com;
                                        signal from_bfm : in std_logic) is
        variable parity_bit : std_logic := '0';
    begin

        to_bfm.command_number <= 5;
        to_bfm.sync <= sync;
        
        -- parity calculation
        parity_bit := bits(15);
        for i in 14 downto 0 loop
            parity_bit := parity_bit xor bits(i); 
        end loop;
        parity_bit := (not parity_bit) when wrong_parite = true else parity_bit;
        
        to_bfm.bits <= bits & parity_bit;
        to_bfm.bits_length <= data_length;
        wait for 1 ns;

        --START TEST
        report "SENDING INVALID DATA WORD... (" & to_string(bits) & ")";
        report "...with bits length: " & to_string(data_length);
        report "... and parity is: "  & to_string(parity_bit);
        to_bfm.start <= '1';
        wait for 1 ns;
        to_bfm.start <= '0';

        wait until from_bfm = '1';

    end procedure;

    procedure Receive_word (signal to_bfm : out t_bfm_com;
                            signal from_bfm : in std_logic) is
    begin
        to_bfm.command_number <= 7;
        to_bfm.start <= '1';
        wait for 1 ns;
        to_bfm.start <= '0';

        wait until from_bfm = '1';
    end procedure;


    -- ********************** --
    --- ***BFM PROCEDURES*** ---
    -- ********************** --
    procedure Make_manchester (  variable data_bit : std_logic;
                                 signal manchester_pos, manchester_neg : out std_logic) is
    begin
        if data_bit = '1' then
            manchester_pos <= '1';
            manchester_neg <= '0';
            wait for bus_period/2;
            manchester_neg <= '1';
            manchester_pos <= '0';
            wait for bus_period/2;
        else
            manchester_neg <= '1';
            manchester_pos <= '0';
            wait for bus_period/2;
            manchester_pos <= '1';
            manchester_neg <= '0';
            wait for bus_period/2;
        end if;
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
