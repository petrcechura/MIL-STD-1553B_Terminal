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
        data_out : out std_logic_vector(15 downto 0);
        mode_code : out std_logic_vector(4 downto 0);
        synchronize : out std_logic_vector(15 downto 0)

    );
end entity;


architecture rtl of Terminal_unit is


    component ManchesterDecoder is
        port (
            clk   : in std_logic;
            reset : in std_logic;
            in_pos, in_neg : in std_logic;
            DATA_OUT : out std_logic_vector(15 downto 0);
            RX_DONE : out std_logic_vector(1 downto 0);
            RX_flag : out std_logic
        );
    end component;

    component ManchesterEncoder is
        port (
            clk   : in std_logic;
            reset : in std_logic;
            data_in : in std_logic_vector(15 downto 0);    
            data_wr : in std_logic;                         
            TX_en : in std_logic_vector(1 downto 0);       
            out_pos : out std_logic;  
            out_neg : out std_logic;
            TX_DONE : out std_logic                        
        );
    end component;

    component FSM_brain is
        port (
            clk   : in std_logic;
            reset : in std_logic;
            rx_done : in std_logic_vector(1 downto 0);
            rx_flag : in std_logic;
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
            mem_subaddr : out std_logic_vector(4 downto 0);
            sram_data_out : out std_logic_vector(15 downto 0);
            sram_data_in : in std_logic_vector(15 downto 0);
            sram_wr : out std_logic;
            sram_rd : out std_logic;
            sram_erase : out std_logic;
            mode_code : out std_logic_vector(4 downto 0);
            synchronize : out std_logic_vector(15 downto 0)
        );
    end component;

    component SRAM is
        port (
            clk   : in std_logic;
            reset : in std_logic;
            wr_en : in std_logic;
            wr_data : in std_logic_vector(16 - 1 downto 0);
            erase_data : in std_logic;
            rd_en : in std_logic;
            rd_data : out std_logic_vector(16 - 1 downto 0)
        );
    end component;

    component DFF is
        port (
            clk   : in std_logic;
            reset : in std_logic;
            input : in std_logic;
            output : out std_logic
        );
    end component;




    type t_MD_TO_FSM is record
        DATA_OUT :  std_logic_vector(15 downto 0);
        RX_DONE : std_logic_vector(1 downto 0);
        RX_flag : std_logic;
    end record;
    signal MD_TO_FSM : t_MD_TO_FSM;

    type t_ME_TO_FSM is record
        data_in : std_logic_vector(15 downto 0);    
        data_wr : std_logic;                         
        TX_en : std_logic_vector(1 downto 0);       
        out_pos : std_logic;  
        out_neg : std_logic;
        TX_DONE : std_logic;
    end record;
    signal ME_TO_FSM : t_ME_TO_FSM;

    type t_FSM_TO_SRAM is record
        sram_data_out : std_logic_vector(15 downto 0);
        sram_data_in : std_logic_vector(15 downto 0);
        sram_wr : std_logic;
        sram_rd : std_logic;
        sram_erase : std_logic;
    end record;
    signal FSM_TO_SRAM : t_FSM_TO_SRAM;

    -- DFF routing signals
    signal dff_sig_in_pos : std_logic;
    signal dff_sig_in_neg : std_logic;
    signal dff_sig_out_pos : std_logic;
    signal dff_sig_out_neg : std_logic;

begin

    MD: ManchesterDecoder
        port map (
            clk   => clk,
            reset => reset,
            in_pos => dff_sig_in_pos,
            in_neg => dff_sig_in_neg,
            DATA_OUT =>  MD_TO_FSM.DATA_OUT,
            RX_DONE =>  MD_TO_FSM.RX_DONE,
            RX_flag => MD_TO_FSM.RX_flag
        );

    ME: ManchesterEncoder
        port map (
            clk =>  clk,  
            reset => reset,
            data_in =>  ME_TO_FSM.data_in,    
            data_wr =>  ME_TO_FSM.data_wr,                           
            TX_en =>    ME_TO_FSM.TX_en,     
            out_pos =>  dff_sig_out_pos,  
            out_neg =>  dff_sig_out_neg,
            TX_DONE =>       ME_TO_FSM.TX_DONE
        );

    FSM: FSM_brain
        port map (
            clk => clk,
            reset => reset,

            rx_done => MD_TO_FSM.RX_DONE,
            rx_flag => MD_TO_FSM.RX_FLAG,
            decoder_data_in => MD_TO_FSM.DATA_OUT,
            
            tx_done => ME_TO_FSM.TX_DONE,
            encoder_data_out => ME_TO_FSM.data_in,
            encoder_data_wr => ME_TO_FSM.data_wr,
            TX_enable =>    ME_TO_FSM.TX_en,
            
            mem_wr =>       mem_wr_en,
            mem_data_out => data_out,
            mem_rd =>       mem_rd_en,
            mem_data_in =>  data_in,
            mem_rd_done =>  mem_rd_done,
            mem_wr_done =>  mem_wr_done,
            mem_subaddr => mem_subaddr,

            sram_data_out => FSM_TO_SRAM.sram_data_out,
            sram_data_in => FSM_TO_SRAM.sram_data_in,
            sram_wr => FSM_TO_SRAM.sram_wr,
            sram_rd => FSM_TO_SRAM.sram_rd,
            sram_erase => FSM_TO_SRAM.sram_erase,

            mode_code => mode_code,
            synchronize => synchronize
        );

    SRAM_I: SRAM
        port map (
            clk   => clk,
            reset => reset,
            wr_en => FSM_TO_SRAM.sram_wr,
            wr_data => FSM_TO_SRAM.sram_data_out,
            rd_en => FSM_TO_SRAM.sram_rd,
            rd_data => FSM_TO_SRAM.sram_data_in,
            erase_data => FSM_TO_SRAM.sram_erase
        );





    DFF_in_pos: DFF
        port map (
            clk   => clk,
            reset => reset,
            input => in_pos,
            output => dff_sig_in_pos
        );

    DFF_in_neg: DFF
        port map (
            clk   => clk,
            reset => reset,
            input => in_neg,
            output => dff_sig_in_neg
        );
    DFF_out_pos: DFF
        port map (
            clk   => clk,
            reset => reset,
            input => dff_sig_out_pos,
            output => out_pos
        );
    DFF_out_neg: DFF
        port map (
            clk   => clk,
            reset => reset,
            input => dff_sig_out_neg,
            output => out_neg
        );

end architecture;