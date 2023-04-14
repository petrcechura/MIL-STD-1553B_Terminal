library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.terminal_package.all;


entity Terminal_unit is
    port (
        clk   : in std_logic;
        reset : in std_logic;
        in_pos, in_neg : in std_logic;
        out_pos, out_neg : out std_logic;
        mem_wr_en, mem_rd_en : out std_logic;
        mem_wr_done, mem_rd_done : in std_logic;
        mem_subaddr : out std_logic_vector(4 downto 0);
        data_in : in std_logic_vector(15 downto 0);
        data_out : out std_logic_vector(15 downto 0)

    );
end entity;


architecture rtl of Terminal_unit is


    component ManchesterDecoder is
        port (
            clk   : in std_logic;
            reset : in std_logic;
            in_positive, in_negative : in std_logic;
            DATA_OUT : out std_logic_vector(15 downto 0);
            RX_DONE : out std_logic_vector(1 downto 0)
        );
    end component;

    component ManchesterEncoder is
        port (
            clk   : in std_logic;
            reset : in std_logic;
            data_in : in std_logic_vector(15 downto 0);    
            data_wr : in std_logic;                         
            TX_en : in std_logic_vector(1 downto 0);       
            OUT_POSITIVE : out std_logic;  
            OUT_NEGATIVE : out std_logic;
            TX_DONE : out std_logic                        
        );
    end component;

    component FSM_brain is
        port (
            clk   : in std_logic;
            reset : in std_logic;
            rx_done : in std_logic_vector(1 downto 0);
            tx_done : in std_logic;
            decoder_data_in : in std_logic_vector(15 downto 0);
            encoder_data_out : out std_logic_vector(15 downto 0); 
            encoder_data_wr : out std_logic;
            TX_enable : out std_logic_vector(1 downto 0);
            mem_wr : out std_logic;
            mem_data_out : out std_logic_vector(15 downto 0);
            mem_rd : out std_logic;
            mem_data_in : in std_logic_vector(15 downto 0);
            mem_rd_done : in std_logic;
            mem_wr_done : in std_logic;
            mem_subaddr : out std_logic_vector(4 downto 0)
        );
    end component;

    type t_MD_TO_FSM is record
        DATA_OUT :  std_logic_vector(15 downto 0);
        RX_DONE : std_logic_vector(1 downto 0);
    end record;
    signal MD_TO_FSM : t_MD_TO_FSM;

    type t_ME_TO_FSM is record
        data_in : std_logic_vector(15 downto 0);    
        data_wr : std_logic;                         
        TX_en : std_logic_vector(1 downto 0);       
        OUT_POSITIVE : std_logic;  
        OUT_NEGATIVE : std_logic;
        TX_DONE : std_logic;
    end record;
    signal ME_TO_FSM : t_ME_TO_FSM;

begin

    MD: ManchesterDecoder
        port map (
            clk   => clk,
            reset => reset,
            in_positive => in_pos,
            in_negative => in_neg,
            DATA_OUT =>  MD_TO_FSM.DATA_OUT,
            RX_DONE =>  MD_TO_FSM.RX_DONE
        );

    ME: ManchesterEncoder
        port map (
            clk =>  clk,  
            reset => reset,
            data_in =>  ME_TO_FSM.data_in,    
            data_wr =>  ME_TO_FSM.data_wr,                           
            TX_en =>    ME_TO_FSM.TX_en,     
            OUT_POSITIVE =>  out_pos,  
            OUT_NEGATIVE =>  out_neg,
            TX_DONE =>       ME_TO_FSM.TX_DONE
        );

    FSM: FSM_brain
        port map (
            clk => clk,
            reset => reset,
            rx_done => MD_TO_FSM.RX_DONE,
            tx_done => ME_TO_FSM.TX_DONE,
            decoder_data_in => MD_TO_FSM.DATA_OUT,
            encoder_data_out => ME_TO_FSM.data_in,
            encoder_data_wr => ME_TO_FSM.data_wr,
            TX_enable =>    ME_TO_FSM.TX_en,
            mem_wr =>       mem_wr_en,
            mem_data_out => data_out,
            mem_rd =>       mem_rd_en,
            mem_data_in =>  data_in,
            mem_rd_done =>  mem_rd_done,
            mem_wr_done =>  mem_wr_done,
            mem_subaddr => mem_subaddr
        );

end architecture;