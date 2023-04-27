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
        rd_data : out std_logic_vector(16 - 1 downto 0);

        -- FLAGS 
        empty : out std_logic;
        full : out std_logic;

        -- amount of filled cells in SRAM
        data_count : out std_logic_vector(4 downto 0)
    );
end entity;


architecture rtl of SRAM is

    -- sram type declaration
    type t_sram is array (32 - 1 downto 0) of std_logic_vector(16 - 1 downto 0);
    signal sram_d, sram_q : t_sram;

    -- memory pointers
    signal head_d, head_q : unsigned(4 downto 0);    -- write pointer
    signal tail_d, tail_q : unsigned(4 downto 0);    -- read pointer

begin

    -- seq part
    process (clk, reset)
    begin
        if reset = '1' then
            sram_q <= (others => (others => '0') ); 
            head_q <= (others => '0');
            tail_q <= (others => '0'); 
        elsif rising_edge(clk) then
            if erase_data = '1' then
                sram_q <= (others => (others => '0') ); 
                head_q <= (others => '0');
                tail_q <= (others => '0'); 
            else
                sram_q <= sram_d;
                head_q <= head_d;
                tail_q <= tail_d;
            end if;
        end if;
    end process;


    -- data handle (write/read)
    process (wr_en, rd_en, sram_q, head_q, tail_q, wr_data)
    begin
        head_d <= head_q;
        tail_d <= tail_q;
        sram_d <= sram_q;
        
        -- write part
        if wr_en = '1' then
            head_d <= head_q + 1;
            sram_d(to_integer(head_q)) <= wr_data;
        end if;

        -- read part
        if rd_en = '1' then
            tail_d <= tail_q + 1;
        end if;
    end process;
    rd_data <= sram_q(to_integer(tail_q));

    -- flag handle (empty/full/data count)
    process (head_q, tail_q)
    begin
        empty <= '0';
        full <= '0';

        if head_q = tail_q then
            empty <= '1';
        elsif head_q = tail_q - 1 then
            full <= '1';
        end if;

        if head_q > tail_q then
            data_count <= std_logic_vector(head_q - tail_q);
        else
            data_count <= std_logic_vector(32 + head_q - tail_q);
        end if;
    end process;

end architecture;
