library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;


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

    -- TERMINAL CONSTANTS
    constant PARITY : std_logic := '1';
    constant TERMINAL_ADDRESS : unsigned(4 downto 0) := "11100";
    constant BUS_PERIOD : integer := 32;

    -- MEMORY CONSTANTS
    constant ADDR_CNT : integer := 30;
    constant ADDR_SIZE : integer := 31;
    --total stored bits = ADDR_CNT * ADDR_SIZE * 16



end package;