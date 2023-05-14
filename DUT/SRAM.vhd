library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
library work;
    use work.terminal_package.all;


entity SRAM is
    port (
        clk   : in std_logic;
        reset : in std_logic;

        --  WRITE DATA
        wr_en : in std_logic;
        wr_data : in std_logic_vector(16 - 1 downto 0);
        erase_data : in std_logic;

        -- READ DATA
        rd_en : in std_logic;
        rd_data : out std_logic_vector(16 - 1 downto 0)
    );
end entity;


architecture rtl of SRAM is

    -- sram type declaration
    type t_sram is array (32 - 1 downto 0) of std_logic_vector(16 - 1 downto 0);
    signal sram : t_sram;

    -- memory pointers
    signal head : unsigned(4 downto 0);    -- write pointer
    signal tail : unsigned(4 downto 0);    -- read pointer

begin

	-- tail seq
	process(clk)
	begin
		if rising_edge(clk) then
			if reset = '1' or erase_data = '1' then
				tail <= (others => '0');
			else
				if rd_en = '1' then
					tail <= tail + 1;
				end if;
			end if;
		end if;
	end process;
	
	-- head seq
	process(clk)
	begin
		if rising_edge(clk) then
			if reset = '1' or erase_data = '1' then
				head <= (others => '0');
			else
				if wr_en = '1' then
					head <= head + 1;
				end if;
			end if;
		end if;
	end process;

	-- data read/write
   process(clk)
   begin
		if rising_edge(clk) then
			sram(to_integer(head)) <= wr_data;
			rd_data <= sram(to_integer(tail));
		end if;
	end process;
	
end architecture;
