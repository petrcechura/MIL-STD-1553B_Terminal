library ieee;
    use ieee.std_logic_1164.all;


entity RecievePart is
    port (
        clk   : in std_logic;
        reset : in std_logic
        
    );
end entity;


architecture rtl of RecievePart is

begin

    MAN_DEC_I: work.ManchesterDecoder(rtl)
        port map (
            
        );

    

end architecture;