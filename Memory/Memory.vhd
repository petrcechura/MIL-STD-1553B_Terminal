library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.terminal_package.all;


entity Memory is
    port (
        clk   : in std_logic;
        reset : in std_logic;
        write_en : in std_logic;
        read_en : in std_logic;
        write_done : out std_logic;
        read_done : out std_logic;
        data_in : in std_logic_vector(15 downto 0);
        data_out : out std_logic_vector(15 downto 0);
        subaddress : in std_logic_vector(4 downto 0)
    );
end entity;


    -- FIRST IN, FIRST OUT
architecture rtl of Memory is
    type t_memory is array(ADDR_CNT-1 downto 0) of std_logic_vector(511 downto 0);  -- there are 30 subaddresses
                                                                                    -- each has sr of 512 bits (32 * 16)
    
    --MEMORY 
    signal memory_arr_d, memory_arr_q : t_memory := (others => (others => '0') );   --
    signal working_memory : std_logic_vector(511 downto 0) := (others => '0') ; -- current working memory (set by input subaddress)

    -- Flip flop of sending short signal to a terminal that data handling is completed
    signal wr_done_d, wr_done_q : std_logic;
    signal rd_done_d, rd_done_q : std_logic;

begin

    
    process (clk, reset)
    begin
        if reset = '1' then
            memory_arr_q <= (others => (others => '0') );   -- clear whole memory
            wr_done_q <= '0';
            rd_done_q <= '0';
        elsif rising_edge(clk) then
            wr_done_q <= wr_done_d;
            rd_done_q <= rd_done_d;
            memory_arr_q <= memory_arr_d;
        end if;
    end process;


    process (write_en, read_en, reset, working_memory, memory_arr_d, wr_done_d, wr_done_q)
    begin
        wr_done_d <= '0';
        rd_done_d <= '0';
        memory_arr_d <= memory_arr_q;
        working_memory <= memory_arr_d(to_integer(unsigned(subaddress)));

        if write_en = '1' then
            working_memory <= data_in & working_memory(511 downto 16);   -- shift register; input data are set to the front; end of stack is erased
            wr_done_d <= '1';
        elsif read_en = '1' then
            data_out <= working_memory(511 downto 511-16);          -- data are gathered from a front of shift register
            working_memory <= working_memory(511-16 downto 0) & '0';       -- gathered data are erased (shift register)
            rd_done_d <= '1';
            
        end if;
    end process;

    
    write_done <= wr_done_q;
    read_done <= rd_done_q;

end architecture;