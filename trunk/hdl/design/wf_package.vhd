--	Package File Template
--
--	Purpose: This package defines supplemental types, subtypes, 
--		     constants, and functions 

--------------------------------------------------------------------------------------------------- 
--
--!   \n\n<b>Last changes:</b>\n
--!     -> egousiou: base_addr unsigned(8 downto 0) instead of std_logic_vector (9 downto 0), 
--!                  to simplify calculations
--
--------------------------------------------------------------------------------------------------- 



library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.ALL;

package wf_package is

  constant C_QUARTZ_PERIOD : real := 24.8;


  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --
  -- constants regarding the manchester coding
  constant VP : std_logic_vector (1 downto 0)   := "11";
  constant VN : std_logic_vector (1 downto 0)   := "00";
  constant ONE : std_logic_vector (1 downto 0)  := "10";
  constant ZERO : std_logic_vector (1 downto 0) := "01";


  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --
  -- constants regarding the ID_DAT and RP_DAT frame structure
  constant PREAMBLE :    std_logic_vector (15 downto 0) :=  ONE&ZERO&ONE&ZERO&ONE&ZERO&ONE&ZERO;
  constant FRAME_START : std_logic_vector (15 downto 0) :=  ONE&VP&VN&ONE&ZERO&VN&VP&ZERO;
  constant FRAME_END :   std_logic_vector (15 downto 0) :=  ONE&VP&VN&VP&VN&ONE&ZERO&ONE; 
  constant FSS :         std_logic_vector (31 downto 0) :=  PREAMBLE&FRAME_START;


  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --
  -- constants concerning the control byte of an ID_DAT and RP_DAT frames and the PDU_TYPE byte of
  -- a condumed or produced variable
  constant c_ID_DAT_CTRL_BYTE :        std_logic_vector (7 downto 0) := "00000011";
  constant c_RP_DAT_CTRL_BYTE :        std_logic_vector (7 downto 0) := "00000010";
  constant c_PROD_CONS_PDU_TYPE_BYTE : std_logic_vector (7 downto 0) := "01000000";


  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- -- 
  --constants concerning the nanoFIP status bits
  constant c_U_CACER_INDEX : integer := 2; 
  constant c_U_PACER_INDEX : integer := 3; 
  constant c_R_BNER_INDEX :  integer := 4; 
  constant c_R_FCSER_INDEX : integer := 5; 
  constant c_T_TXER_INDEX :  integer := 6; 
  constant c_T_WDER_INDEX :  integer := 7; 


  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- -- 
  --constants concerning the MPS status bits
  constant c_REFRESHMENT_INDEX :  integer := 0; 
  constant c_SIGNIFICANCE_INDEX : integer := 2; 


  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- -- 
  --constants concerning the position of certain bytes in the frame structure
  constant c_CTRL_BYTE_INDEX :     std_logic_vector (7 downto 0) := "00000000"; -- 0
  constant c_PDU_BYTE_INDEX :      std_logic_vector (7 downto 0) := "00000001"; -- 1
  constant c_LENGTH_BYTE_INDEX :   std_logic_vector (7 downto 0) := "00000010"; -- 2
  constant c_1st_DATA_BYTE_INDEX : std_logic_vector (7 downto 0) := "00000011"; -- 3
  constant c_2nd_DATA_BYTE_INDEX : std_logic_vector (7 downto 0) := "00000100"; -- 4 

  constant c_CONSTR_BYTE_INDEX :  std_logic_vector (7 downto 0) := "00000110"; -- 6
  constant c_MODEL_BYTE_INDEX :   std_logic_vector (7 downto 0) := "00000111"; -- 7
  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --
  -- construction of a table for the P3_LGTH[2:0] settings
  type t_unsigned_array is array (natural range <>) of unsigned(7 downto 0);

  constant c_P3_LGTH_TABLE : t_unsigned_array(0 to 7) := 
    (0 => "00000010",     -- 2 bytes
     1 => "00001000",     -- 8 bytes
     2 => "00010000",     -- 16 bytes
     3 => "00100000",     -- 32 bytes
     4 => "01000000",     -- 64 bytes 
     5 => "01111100",     -- 124 bytes
     others => "00000000" -- reserved
     );  


  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- -- 
  -- construction of a table with the timeout and silence times for each bit rate
  -- the table contains the number of uclk tick corresponding to the respone/ silence times
  type t_timeouts is 
  record
    response : integer;
    silence : integer;
  end record;

  constant c_31K25_INDEX :   integer := 0; 
  constant c_1M_INDEX :      integer := 1; 
  constant c_2M5_INDEX :     integer := 2; 
  constant c_RESERVE_INDEX : integer := 3; 

  type t_timeouts_table is array (natural range <>) of t_timeouts;


  constant c_TIMEOUTS_TABLE : t_timeouts_table(0 to 3) :=

                              (c_31K25_INDEX =>   (response => integer(640000.0/C_QUARTZ_PERIOD), 
                                                   silence => integer(5160000.0/C_QUARTZ_PERIOD)),

                               c_1M_INDEX =>      (response => integer(10000.0/C_QUARTZ_PERIOD),
                                                   silence => integer(150000.0/C_QUARTZ_PERIOD)),
                                              
                               c_2M5_INDEX =>     (response => integer(16000.0/C_QUARTZ_PERIOD),
                                                   silence => integer(100000.0/C_QUARTZ_PERIOD)),

                               c_RESERVE_INDEX => (response => integer(640000.0/C_QUARTZ_PERIOD),
                                                   silence => integer(5160000.0/C_QUARTZ_PERIOD))
                                );


  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  -- construction of a table with that gathers all the main information for all the variables
 
  type t_var is (presence_var, identif_var, var_1, var_2, var_3, reset_var, var_whatever);

  type t_byte_array is array (natural range <>) of std_logic_vector (7 downto 0);

  type t_var_response is (produce, consume, reset);

  type t_var_record is record
    response :     t_var_response;
    hexvalue :     std_logic_vector (7 downto 0);
    var :          t_var;
    base_addr :    unsigned (8 downto 0);
    last_addr :    std_logic_vector (8 downto 0);
    array_length : unsigned (7 downto 0);
    byte_array :   t_byte_array (0 to 15);
  end record;

  type t_var_array is array (natural range <>) of t_var_record;
  
  constant c_PRESENCE_VAR_INDEX : integer := 0;
  constant c_IDENTIF_VAR_INDEX :  integer := 1;
  constant c_VAR_3_INDEX :        integer := 2;
  constant c_VAR_1_INDEX :        integer := 3;
  constant c_VAR_2_INDEX :        integer := 4;
  constant c_RESET_VAR_INDEX :    integer := 5;


  constant c_VARS_ARRAY : t_var_array(0 to 5) := 

    (c_PRESENCE_VAR_INDEX => (var          => presence_var,
                              hexvalue     => x"14", 
                              response     => produce,
                              base_addr    => "---------",
                              last_addr    => "---------",
                              array_length => "00000111", -- 8 bytes in total including the Control byte
                                                          -- (counting starts from 0)
                              byte_array   => (0 => c_RP_DAT_CTRL_BYTE, 1 => x"50", 2 => x"05", 
                                               3 => x"80", 4 => x"03", 5 => x"00", 6 => x"f0",
                                               7 => x"00", others => x"ff")),
 
    
     c_IDENTIF_VAR_INDEX  => (var          => identif_var,
                              hexvalue     => x"10",
                              response     => produce,
                              array_length => "00001010", -- 11 bytes in total including the Control byte
                                                          -- (counting starts from 0)
                              base_addr    => "---------",
                              last_addr    => "---------",
                              byte_array   => (0 => c_RP_DAT_CTRL_BYTE, 1 => x"52", 2 => x"08",
                                               3 => x"01", 4 => x"00", 5 => x"00", 6 => x"ff",
                                               7 => x"ff", 8 => x"00", 9 => x"00", 10 => x"00",
                                               others => x"ff")),

     
     c_VAR_3_INDEX        => (var          => var_3,
                              hexvalue     => x"06", 
                              response     => produce,
                              base_addr    => "100000000",
                              last_addr    => "101111101",
                              array_length => "00000001", -- only the Control and PDU type bytes are
                                                          -- predefined (counting starts from 0)  
                              byte_array   => (0 => c_RP_DAT_CTRL_BYTE, 1 => c_PROD_CONS_PDU_TYPE_BYTE,
                                               others => x"ff")),


     c_VAR_1_INDEX        => (var => var_1,
                              hexvalue     => x"05", 
                              response     => consume,
                              base_addr    => "000000000",
                              last_addr    => "001111111",
                              array_length => "00000001", -- only the Control and PDU type bytes are
                                                 -- predefined (counting starts from 0)  
                              byte_array   => (0 => c_RP_DAT_CTRL_BYTE, 1 => c_PROD_CONS_PDU_TYPE_BYTE,
                                                   others => x"ff")),


     c_VAR_2_INDEX        => (var          => var_2,
                              hexvalue     => x"04", 
                              response     => consume,
                              base_addr    => "010000000",
                              last_addr    => "011111111",
                              array_length => "00000001", -- only the Control and PDU type bytes are
                                                          -- predefined (counting starts from 0)   
                              byte_array   => (0 => c_RP_DAT_CTRL_BYTE, 1 => c_PROD_CONS_PDU_TYPE_BYTE,
                                               others => x"ff")),

     c_RESET_VAR_INDEX    => (var          => reset_var,
                              hexvalue     => x"e0", 
                              response     => reset,
                              base_addr    => "010000000",
                              last_addr    => "011111111",
                              array_length => "00000001", -- only the Control byte is predefined
                                                          -- (counting starts from 0)
                              byte_array   => (0 => c_RP_DAT_CTRL_BYTE, 1 => c_PROD_CONS_PDU_TYPE_BYTE,
                                               others => x"ff")));



---------------------------------------------------------------------------------------------------
--                                      Components definitions:                                  --
---------------------------------------------------------------------------------------------------

component wf_rx 

  port (
    uclk_i :                in std_logic;
    nFIP_rst_i :            in std_logic;
    reset_rx_unit_p_i :     in std_logic;
    signif_edge_window_i :  in std_logic;
    adjac_bits_window_i :   in std_logic;
    rx_data_r_edge_i :      in std_logic;
    rx_data_f_edge_i :      in std_logic;
    rx_data_filtered_i :    in std_logic;
    sample_manch_bit_p_i :  in std_logic; 
    sample_bit_p_i  :       in std_logic;    
 
    byte_ready_p_o :        out std_logic;
    byte_o :                out std_logic_vector (7 downto 0);
    crc_wrong_p_o :         out std_logic;
    crc_ok_p_o :            out std_logic;
    last_byte_p_o :         out std_logic;
    fss_decoded_p_o :       out std_logic;
    code_violation_p_o :    out std_logic;
    wait_d_first_f_edge_o : out std_logic	
       );
  end component wf_rx;


---------------------------------------------------------------------------------------------------
  component wf_tx 

  generic (C_CLKFCDLENTGTH : natural := 4 );
  port (
    uclk_i :            in std_logic;
    nFIP_rst_i :        in std_logic;
    start_produce_p_i : in std_logic;
    byte_ready_p_i :    in std_logic; 
    last_byte_p_i :     in std_logic;
    byte_i :            in std_logic_vector (7 downto 0);
    tx_clk_p_buff_i :   in std_logic_vector (C_CLKFCDLENTGTH -1 downto 0);
      
    request_byte_p_o :  out std_logic;
    tx_data_o :         out std_logic;
    tx_enable_o :       out std_logic
       );
  end component wf_tx;


---------------------------------------------------------------------------------------------------  
  component wf_rx_tx_osc 
    generic (C_COUNTER_LENGTH : integer := 11;
             C_QUARTZ_PERIOD : real := 24.8;
             C_CLKFCDLENTGTH :  natural := 4 
             );

    port (
      uclk_i :                  in std_logic; 
      rate_i :                  in std_logic_vector (1 downto 0);
      nFIP_rst_i :              in std_logic;
      d_edge_i :                in std_logic;
      rx_data_f_edge_i :        in std_logic;
      wait_d_first_f_edge_i :   in std_logic;	
 
      rx_manch_clk_p_o :        out std_logic;
      rx_bit_clk_p_o  :         out std_logic;
      rx_signif_edge_window_o : out std_logic;
      rx_adjac_bits_window_o :  out std_logic;
      tx_clk_o :                out std_logic;
      tx_clk_p_buff_o :         out std_logic_vector (C_CLKFCDLENTGTH -1 downto 0)

      );
  end component wf_rx_tx_osc;


---------------------------------------------------------------------------------------------------
  component wf_tx_rx

    port (
      uclk_i :             in std_logic; 
      rate_i :             in std_logic_vector (1 downto 0);
      nFIP_rst_i :         in std_logic;
      reset_rx_unit_p_i :  in std_logic; 
      start_produce_p_i :  in std_logic;
      request_byte_p_o :   out std_logic;
      byte_ready_p_i :     in std_logic;
      last_byte_p_i :      in std_logic;
      d_a_i :              in std_logic;
      byte_i :             in std_logic_vector (7 downto 0);      

      tx_enable_o :        out std_logic;
      d_clk_o :            out std_logic;
      tx_data_o :          out std_logic;      
      byte_ready_p_o :     out std_logic;
      last_byte_p_o :      out std_logic;
      fss_decoded_p_o :    out std_logic;
      code_violation_p_o : out std_logic;
      crc_wrong_p_o :      out std_logic;
      crc_ok_p_o :         out std_logic;
      byte_o :             out std_logic_vector (7 downto 0)
      );
  end component wf_tx_rx;


---------------------------------------------------------------------------------------------------
  component wf_consumed_vars 
    port (
      uclk_i :              in std_logic;
      subs_i :              in std_logic_vector (7 downto 0); 
      slone_i :             in std_logic; 
      nFIP_rst_i :          in std_logic;
      wb_clk_i :            in std_logic;
      wb_adr_i :            in std_logic_vector (9 downto 0); 
      wb_stb_r_edge_p_i :   in std_logic; 
      wb_cyc_i :            in std_logic; 
      byte_ready_p_i :      in std_logic;
      byte_index_i :        in std_logic_vector (7 downto 0);
      var_i :               in t_var;
      byte_i :              in std_logic_vector (7 downto 0);
      data_o :              out std_logic_vector (15 downto 0);
      wb_ack_cons_p_o :     out std_logic; 
      reset_nFIP_and_FD_o : out std_logic;
      reset_RSTON_o :       out std_logic;
      rx_Ctrl_byte_o :      out std_logic_vector (7 downto 0);
      rx_PDU_byte_o :       out std_logic_vector (7 downto 0);           
      rx_Length_byte_o :    out std_logic_vector (7 downto 0)
      );

  end component wf_consumed_vars;

---------------------------------------------------------------------------------------------------
  component wf_produced_vars is
    port (
      uclk_i :             in std_logic; 
      slone_i :            in std_logic; 
      nostat_i :           in std_logic; 
      nFIP_rst_i :         in std_logic;
      m_id_dec_i :         in std_logic_vector (7 downto 0); 
      c_id_dec_i :         in std_logic_vector (7 downto 0); 
      wb_clk_i :           in std_logic; 
      wb_data_i :          in std_logic_vector (7 downto 0); 
      wb_adr_i :           in std_logic_vector (9 downto 0); 
      wb_stb_r_edge_p_i :  in std_logic; 
      wb_we_p_i :          in std_logic;  
      wb_cyc_i :           in std_logic;
      slone_data_i :       in std_logic_vector (15 downto 0);
      nFIP_status_byte_i : in std_logic_vector (7 downto 0);
      mps_status_byte_i :  in std_logic_vector (7 downto 0);
      var_i :              in t_var;
      data_length_i :      in std_logic_vector (7 downto 0);
      byte_index_i :       in std_logic_vector (7 downto 0);
      var3_rdy_i :         in std_logic;
        
      sending_mps_o :      out std_logic; 
      byte_o :             out std_logic_vector (7 downto 0);
      wb_ack_prod_p_o :    out std_logic                  
      );
  end component wf_produced_vars;


---------------------------------------------------------------------------------------------------  
  component wf_engine_control 
    generic( C_QUARTZ_PERIOD : real := 24.8);

    port (
      uclk_i :               in std_logic; 
      nFIP_rst_i :           in std_logic;
      rate_i :               in std_logic_vector (1 downto 0);
      subs_i :               in  std_logic_vector (7 downto 0); 
      p3_lgth_i :            in  std_logic_vector (2 downto 0); 
      slone_i :              in  std_logic; 
      nostat_i :             in  std_logic; 
      tx_request_byte_p_i :  in std_logic;
      rx_fss_decoded_p_i :   in std_logic; 
      rx_byte_ready_p_i :    in std_logic;
      rx_byte_i :            in std_logic_vector (7 downto 0);  
      rx_CRC_FES_ok_p_i :         in std_logic;   
      tx_sending_mps_i :       in std_logic;
      rx_Ctrl_byte_i :   in std_logic_vector (7 downto 0);
      rx_PDU_byte_i :    in std_logic_vector (7 downto 0);           
      rx_Length_byte_i : in std_logic_vector (7 downto 0);

      var1_rdy_o:            out std_logic; 
      var2_rdy_o:            out std_logic; 
      var3_rdy_o:        out std_logic; 
      tx_byte_ready_p_o :    out std_logic;
      tx_last_byte_p_o :     out std_logic;
      tx_start_produce_p_o : out std_logic;
      tx_rx_byte_index_o :   out std_logic_vector (7 downto 0);
      tx_data_length_o :     out std_logic_vector (7 downto 0);
      rx_byte_ready_p_o :    out std_logic;
      reset_status_bytes_o : out std_logic;
      reset_rx_unit_p_o :    out std_logic;
      var_o :                out t_var
      );

  end component wf_engine_control;


---------------------------------------------------------------------------------------------------  
  component wf_reset_unit 
    generic(c_rstin_c_length : integer := 4); 

    port (
      uclk_i :              in std_logic; 
      rstin_i :             in  std_logic; 
      reset_nFIP_and_FD_i : in std_logic;
      reset_RSTON_i :       in std_logic;
 
      rston_o :             out std_logic;
      nFIP_rst_o :          out std_logic; 
      fd_rstn_o :           out std_logic 
      );
  end component wf_reset_unit;


---------------------------------------------------------------------------------------------------
  component wf_DualClkRAM_clka_rd_clkb_wr
  generic (c_data_length : integer := 8; 		
           c_addr_length : integer := 9);   
                                          

  port (
    clk_A_i :      in std_logic; 		
    addr_A_i :     in std_logic_vector (c_addr_length - 1 downto 0);
    clk_B_i :      in std_logic;
    addr_B_i :     in std_logic_vector (c_addr_length - 1 downto 0);
    data_B_i :     in std_logic_vector (c_data_length - 1 downto 0);
    write_en_B_i : in std_logic;
 
    data_A_o :     out std_logic_vector (c_data_length -1 downto 0)
       );
  end component wf_DualClkRAM_clka_rd_clkb_wr; 


---------------------------------------------------------------------------------------------------
  component  wf_crc 
  generic (c_GENERATOR_POLY_length :  natural := 16);
  port (
    uclk_i :             in std_logic;
    nFIP_rst_i :         in std_logic;
    start_crc_p_i :      in std_logic;
    data_bit_i :         in std_logic;
    data_bit_ready_p_i : in std_logic;

    crc_ok_p :           out std_logic;
    crc_o :              out std_logic_vector (c_GENERATOR_POLY_length - 1 downto 0)
       );
  end component wf_crc;


---------------------------------------------------------------------------------------------------
  component wf_rx_deglitcher 
  generic (C_ACULENGTH : integer := 10);
  port (
    uclk_i :               in std_logic;
    nFIP_rst_i :           in std_logic; 
    rx_data_i :            in std_logic;
    sample_manch_bit_p_i : in std_logic;
    sample_bit_p_i :       in std_logic;

    sample_manch_bit_p_o : out std_logic;
    rx_data_filtered_o :   out std_logic;
    sample_bit_p_o :       out std_logic
       );
  end component wf_rx_deglitcher;


---------------------------------------------------------------------------------------------------
  component wf_status_bytes_gen 

    port (
      uclk_i :               in std_logic; 
      slone_i :              in std_logic; 
      nFIP_rst_i :           in std_logic;
      fd_wdgn_i :            in std_logic; 
      fd_txer_i :            in std_logic; 
      var1_access_a_i :      in std_logic; 
      var2_access_a_i :      in std_logic; 
      var3_access_a_i :      in std_logic; 
      var_i :                in t_var;  
      var1_rdy_i :           in std_logic; 
      var2_rdy_i :           in std_logic; 
      var3_rdy_i :           in std_logic; 
      code_violation_p_i :   in std_logic; 
      crc_wrong_p_i :        in std_logic;
      reset_status_bytes_i : in std_logic;
      
      nFIP_status_byte_o :   out std_logic_vector (7 downto 0); 
      mps_status_byte_o :    out std_logic_vector (7 downto 0)
      );
  end component wf_status_bytes_gen;


---------------------------------------------------------------------------------------------------
  component nanofip

  port (
    rate_i    : in  std_logic_vector (1 downto 0); 
    subs_i    : in  std_logic_vector (7 downto 0); 
    m_id_i    : in  std_logic_vector (3 downto 0); 
    c_id_i    : in  std_logic_vector (3 downto 0); 
    p3_lgth_i : in  std_logic_vector (2 downto 0); 
    fd_wdgn_i : in  std_logic; 
    fd_txer_i : in  std_logic; 
    fx_rxa_i  : in  std_logic; 
    fx_rxd_i  : in  std_logic; 
    uclk_i    : in  std_logic; 
    slone_i   : in  std_logic;
    nostat_i  : in  std_logic;
    rstin_i   : in  std_logic; 
    var1_acc_i: in  std_logic;
    var2_acc_i: in  std_logic; 
    var3_acc_i: in  std_logic; 
    wclk_i    : in  std_logic; 
    dat_i     : in  std_logic_vector (15 downto 0);
    adr_i     : in  std_logic_vector ( 9 downto 0); 
    rst_i     : in  std_logic;
    stb_i     : in  std_logic; 
    cyc_i     : in std_logic;
    we_i      : in  std_logic; 

    rston_o   : out std_logic; 
    s_id_o    : out std_logic_vector (1 downto 0); 
    fd_rstn_o : out std_logic; 
    fd_txena_o: out std_logic; 
    fd_txck_o : out std_logic; 
    fx_txd_o  : out std_logic; 
    var1_rdy_o: out std_logic; 
    var2_rdy_o: out std_logic; 
    var3_rdy_o: out std_logic; 
    ack_o     : out std_logic;
    dat_o     : out std_logic_vector (15 downto 0)
       );


  end component nanofip;


---------------------------------------------------------------------------------------------------
component wf_model_constr_decoder 

  port (
    uclk_i :     in std_logic; 
    nFIP_rst_i : in std_logic;
    m_id_i :     in std_logic_vector (3 downto 0); 
    c_id_i :     in std_logic_vector (3 downto 0); 

    s_id_o :     out std_logic_vector (1 downto 0);  
    m_id_dec_o : out std_logic_vector (7 downto 0); 
    c_id_dec_o : out std_logic_vector (7 downto 0)
    );
end component wf_model_constr_decoder;
---------------------------------------------------------------------------------------------------

end wf_package;
package body wf_package is
end wf_package;
--=================================================================================================
--                                         package end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------
