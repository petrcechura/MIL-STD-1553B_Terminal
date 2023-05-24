library ieee;
    use ieee.std_logic_1164.all;

entity DFF is
    port (
        clk   : in std_logic;
        reset : in std_logic;
        input : in std_logic;
        output : out std_logic
    );
end entity;

architecture rtl of DFF is
    signal dff_sig : std_logic;
begin

    process (clk, reset)
    begin
        if reset = '1' then
            dff_sig <= '0';
            output <= '0';
        elsif rising_edge(clk) then
            dff_sig <= input;
            output <= dff_sig;
        end if;
    end process;

end architecture;