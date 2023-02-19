library ieee;
    use ieee.std_logic_1164.all;


package Terminal_package is
    
    -- WORDCHECK
    type t_command_word is record
        t_r : std_logic;
        subaddress : std_logic_vector(4 downto 0);
        data_count_mc : std_logic_vector(4 downto 0); -- also carries mode code
        mode_code_check : std_logic; -- '1' if data_count_mc is mode_code
    end record;

    type t_data_word is record
        data : std_logic_vector(17-1 downto 0);
    end record;

    type t_status_word is record
        msg_error : std_logic;
        instrumentation : std_logic;
        service_req : std_logic;
        broadcast_rec : std_logic;
        busy_bit : std_logic;
        subsystem_flag : std_logic;
        DBC_accept : std_logic;
        terminal_flag : std_logic;
    end record;

    constant parita : std_logic := '1';



end package;