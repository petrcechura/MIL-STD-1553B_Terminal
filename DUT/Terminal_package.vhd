library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;


package Terminal_package is

    -- TERMINAL CONSTANTS
    constant PARITY : std_logic := '1';
    constant TERMINAL_ADDRESS : unsigned(4 downto 0) := "11011";
    constant BROADCAST_ADDR : unsigned(4 downto 0) := "00000";
    constant MODECODE_SUBADDR : unsigned(4 downto 0) := "00000";
    constant MC_SEND_SW : unsigned(4 downto 0) := "00010";
    constant MC_SYNC : unsigned(4 downto 0) := "10001";
    constant BUS_PERIOD : integer := 32;    -- for f(FPGA) = 32 MHz

    -- MEMORY CONSTANTS
    constant ADDR_CNT : integer := 30;
    constant ADDR_SIZE : integer := 31;
    --total stored bits = ADDR_CNT * ADDR_SIZE * 16

end package;