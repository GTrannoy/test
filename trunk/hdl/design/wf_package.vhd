--	Package File Template
--
--	Purpose: This package defines supplemental types, subtypes, 
--		     constants, and functions 

--------------------------------------------------------------------------------------------------- 
--
--!   \n\n<b>Last changes:</b>\n
--!     -> egousiou: base_add unsigned(8 downto 0) instead of std_logic_vector(9 downto 0), 
--!                  to simplify calculations
--
--------------------------------------------------------------------------------------------------- 



library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.ALL;

package wf_package is

  constant C_QUARTZ_PERIOD : real := 24.8;


  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
  -- constants regarding the manchester coding
  constant VP : std_logic_vector(1 downto 0)   := "11";
  constant VN : std_logic_vector(1 downto 0)   := "00";
  constant ONE : std_logic_vector(1 downto 0)  := "10";
  constant ZERO : std_logic_vector(1 downto 0) := "01";

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
  -- constants regarding the ID_DAT and RP_DAT frame structure
  constant PREAMBLE :    std_logic_vector(15 downto 0) :=  ONE&ZERO&ONE&ZERO&ONE&ZERO&ONE&ZERO;
  constant FRAME_START : std_logic_vector(15 downto 0) :=  ONE&VP&VN&ONE&ZERO&VN&VP&ZERO;
  constant FRAME_END :   std_logic_vector(15 downto 0) :=  ONE&VP&VN&VP&VN&ONE&ZERO&ONE; 
  constant FSS :         std_logic_vector(31 downto 0) :=  PREAMBLE&FRAME_START;

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
  -- constants concerning the control byte of an ID_DAT and RP_DAT frames
  constant c_ID_DAT_CTRL_BYTE : std_logic_vector(7 downto 0) := "00000011";
  constant c_RP_DAT_CTRL_BYTE : std_logic_vector(7 downto 0) := "00000010";

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
  --constants concerning the nanoFIP status bits
  constant c_U_CACER_INDEX : integer := 2; 
  constant c_U_PACER_INDEX : integer := 3; 
  constant c_R_BNER_INDEX :  integer := 4; 
  constant c_R_FCSER_INDEX : integer := 5; 
  constant c_T_TXER_INDEX :  integer := 6; 
  constant c_T_WDER_INDEX :  integer := 7; 

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
  --constants concerning the MPS status bits
  constant c_REFRESHMENT_INDEX : integer :=  0; 
  constant c_SIGNIFICANCE_INDEX : integer := 2; 


  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
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
  -- construction of a table for the P3_LGTH[2:0] settings
  type t_integer_array is array (natural range <>) of integer;

  constant c_P3_LGTH_TABLE : t_integer_array(0 to 7) := 
    (0 => 2,
     1 => 8,
     2 => 16,
     3 => 32,
     4 => 64,
     5 => 124,
     others => 0);  

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 

  type t_var is (presence_var, identif_var, var_1, var_2, var_3, reset_var, var_whatever);

  type t_byte_array is array (natural range <>) of std_logic_vector(7 downto 0);

  type t_var_response is (produce, consume, reset);

  type t_var_record is record
    response :     t_var_response;
    hexvalue :     std_logic_vector(7 downto 0);
    var :          t_var;
    base_add :     unsigned(8 downto 0);
    array_length : integer;  --! -1 represents a variable length
    byte_array : t_byte_array(0 to 15);
  end record;

  type t_var_array is array (natural range <>) of t_var_record;
  
  constant c_LENGTH_BYTE_INDEX :  integer := 2;
  constant c_PDU_BYTE_INDEX :     integer := 1;


  constant c_CONSTR_BYTE_INDEX :  integer := 7;
  constant c_MODEL_BYTE_INDEX :   integer := 8;

  constant c_PRESENCE_VAR_INDEX : integer := 0;
  constant c_IDENTIF_VAR_INDEX :  integer := 1;
  constant c_VAR_3_INDEX :        integer := 2;
  constant c_VAR_1_INDEX :        integer := 3;
  constant c_VAR_2_INDEX :        integer := 4;
  constant c_RESET_VAR_INDEX :    integer := 5;

  constant c_2nd_byte_addr : std_logic_vector(6 downto 0)   := "0000010";
  constant c_1st_byte_addr : std_logic_vector(6 downto 0)   := "0000001";
  constant c_CTRL_BYTE_INDEX : std_logic_vector(6 downto 0) := "0000000";



  constant c_VARS_ARRAY : t_var_array(0 to 5) := 

    (c_PRESENCE_VAR_INDEX => (var          => presence_var,
                              hexvalue     => x"14", 
                              response     => produce,
                              base_add     => "---------",
                              array_length => 7, -- 8 bytes in total including the Control byte
                                                 -- (counting starts from 0)
                              byte_array   => (0 => c_RP_DAT_CTRL_BYTE, 1 => x"50", 2 => x"05", 
                                               3 => x"80", 4 => x"03", 5 => x"00", 6 => x"f0",
                                               7 => x"00", others => x"ff")),
 
    
     c_IDENTIF_VAR_INDEX  => (var          => identif_var,
                              hexvalue     => x"10",
                              response     => produce,
                              array_length => 10, -- 11 bytes in total including the Control byte
                                                  -- (counting starts from 0)
                              base_add     => "---------",
                              byte_array   => (0 => c_RP_DAT_CTRL_BYTE, 1 => x"52", 2 => x"08",
                                               3 => x"01", 4 => x"00", 5 => x"00", 6 => x"f0",
                                               7 => x"00", 8 => x"00", 9 => X"00", 10 => X"00",
                                               others => x"ff")),

     
     c_VAR_3_INDEX        => (var          => var_3,
                              hexvalue     => x"06", 
                              response     => produce,
                              base_add     => "100000000",
                              array_length => 1, -- only the Control and PDU type bytes are
                                                 -- predefined (counting starts from 0)  
                              byte_array   => (0 => c_RP_DAT_CTRL_BYTE, 1 => x"40",
                                               others => x"ff")),


     c_VAR_1_INDEX        => (var => var_1,
                              hexvalue     => x"05", 
                              response     => consume,
                              base_add     => "000000000",
                              array_length => 1, -- only the Control and PDU type bytes are
                                                 -- predefined (counting starts from 0)  
                              byte_array   => (0 => c_RP_DAT_CTRL_BYTE, 1 => x"40",
                                                   others => x"ff")),


     c_VAR_2_INDEX        => (var          => var_2,
                              hexvalue     => x"04", 
                              response     => consume,
                              base_add     => "010000000",
                              array_length => 1, -- only the Control and PDU type bytes are
                                                 -- predefined (counting starts from 0)   
                              byte_array   => (0 => c_RP_DAT_CTRL_BYTE, 1 => x"40",
                                               others => x"ff")),

     c_RESET_VAR_INDEX    => (var          => reset_var,
                              hexvalue     => x"e0", 
                              response     => reset,
                              base_add     => "010000000",
                              array_length => 0, -- only the Control byte is predefined
                                                 -- (counting starts from 0)
                              byte_array   => (0 => c_RP_DAT_CTRL_BYTE, others => x"ff")));



---------------------------------------------------------------------------------------------------
  component wf_rx 

  port (
    uclk_i :                in std_logic;
    nFIP_rst_i :            in std_logic;
    signif_edge_window_i :  in std_logic;
    adjac_bits_window_i :   in std_logic;
    rx_data_r_edge_i :      in std_logic;
    rx_data_f_edge_i :      in std_logic;
    rx_data_filtered_i :    in std_logic;
    sample_manch_bit_p_i :  in std_logic; 
    sample_bit_p_i  :       in std_logic;    
 
    byte_ready_p_o :        out std_logic;
    byte_o :                out std_logic_vector(7 downto 0);
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
    byte_i :            in std_logic_vector(7 downto 0);
    tx_clk_p_buff_i :   in std_logic_vector(C_CLKFCDLENTGTH -1 downto 0);
      
    request_byte_p_o :  out std_logic;
    tx_data_o :         out std_logic;
    tx_enable_o :       out std_logic
       );
  end component wf_tx;


---------------------------------------------------------------------------------------------------  
  component wf_rx_osc 
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
      tx_clk_p_buff_o :         out std_logic_vector(C_CLKFCDLENTGTH -1 downto 0)

      );
  end component wf_rx_osc;


---------------------------------------------------------------------------------------------------
  component wf_tx_rx

    port (
      uclk_i :             in std_logic; 
      rate_i :             in std_logic_vector(1 downto 0);
      nFIP_rst_i :         in std_logic;
      start_produce_p_i :  in std_logic;
      request_byte_p_o :   out std_logic;
      byte_ready_p_i :     in std_logic;
      last_byte_p_i :      in std_logic;
      d_a_i :              in std_logic;
      byte_i :             in std_logic_vector(7 downto 0);      

      tx_enable_o :        out std_logic;
      d_clk_o :            out std_logic;
      tx_data_o :          out std_logic;      
      byte_ready_p_o :     out std_logic;
      last_byte_p_o :      out std_logic;
      fss_decoded_p_o :    out std_logic;
      code_violation_p_o : out std_logic;
      crc_wrong_p_o :      out std_logic;
      crc_ok_p_o :         out std_logic;
      byte_o :             out std_logic_vector(7 downto 0)
      );
  end component wf_tx_rx;


---------------------------------------------------------------------------------------------------
  component wf_consumed_vars 
    port (
      uclk_i :              in std_logic;
      subs_i :              in  std_logic_vector (7 downto 0); 
      slone_i :             in  std_logic; 
      nFIP_rst_i :          in std_logic;
      wb_rst_i :            in std_logic;                      
      wb_clk_i :            in std_logic;
      wb_adr_i :            in  std_logic_vector (9 downto 0); 
      wb_stb_p_i :          in  std_logic; 
      byte_ready_p_i :      in std_logic;
      add_offset_i :        in std_logic_vector(6 downto 0);
      var_i :               in t_var;
      byte_i :              in std_logic_vector(7 downto 0);

      wb_data_o :           out std_logic_vector (15 downto 0);
      wb_ack_cons_p_o :     out std_logic; 
      reset_nFIP_and_FD_o : out std_logic;
      reset_RSTON_o :       out std_logic
      );

  end component wf_consumed_vars;

---------------------------------------------------------------------------------------------------
  component wf_produced_vars is
    port (
      uclk_i :          in std_logic; 
      nFIP_rst_i :      in std_logic;
      slone_i :         in std_logic; 
      nostat_i :        in std_logic; 
      m_id_dec_i :      in std_logic_vector (7 downto 0); 
      c_id_dec_i :      in std_logic_vector (7 downto 0); 
      wb_rst_i :        in std_logic;    
      wb_clk_i :        in std_logic; 
      data_i :          in std_logic_vector (15 downto 0); 
      wb_adr_i :        in std_logic_vector (9 downto 0); 
      wb_stb_p_i :      in std_logic; 
      wb_we_p_i :       in std_logic;  
      wb_cyc_i :        in std_logic;
      nFIP_status_byte_i :   in std_logic_vector(7 downto 0);
      mps_byte_i :      in std_logic_vector(7 downto 0);
      var_i :           in t_var;
      data_length_i :   in std_logic_vector(6 downto 0);
      append_status_i : in std_logic;
      add_offset_i :    in std_logic_vector(6 downto 0);

      sending_mps_o :   out std_logic; 
      byte_o :          out std_logic_vector(7 downto 0);
      wb_ack_prod_p_o : out std_logic                  
      );
  end component wf_produced_vars;


---------------------------------------------------------------------------------------------------  
  component wf_engine_control 
    generic( C_QUARTZ_PERIOD : real := 24.8);

    port (
      uclk_i :            in std_logic; 
      nFIP_rst_i :        in std_logic;
      rate_i :            in std_logic_vector(1 downto 0);
      subs_i :            in  std_logic_vector (7 downto 0); 
      p3_lgth_i :         in  std_logic_vector (2 downto 0); 
      slone_i :           in  std_logic; 
      nostat_i :          in  std_logic; 
      request_byte_p_i :  in std_logic;
      fss_decoded_p_i :   in std_logic; 
      byte_ready_p_i :    in std_logic;
      byte_i :            in std_logic_vector(7 downto 0);  
      frame_ok_p_i :      in std_logic;   

      start_produce_p_o : out std_logic;
      byte_ready_p_o :    out std_logic;
      last_byte_p_o :     out std_logic;
      var1_rdy_o:         out std_logic; 
      var2_rdy_o:         out std_logic; 
      var3_rdy_o:         out std_logic; 
      var_o :             out t_var;
      append_status_o :   out std_logic;
      consume_byte_p_o :  out std_logic;
      add_offset_o :      out std_logic_vector(6 downto 0);
      data_length_o :     out std_logic_vector(6 downto 0)
      );

  end component wf_engine_control;


---------------------------------------------------------------------------------------------------  
  component reset_logic 
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
  end component reset_logic;


---------------------------------------------------------------------------------------------------
  component dpblockram_clka_rd_clkb_wr
  generic (c_data_length : integer := 8; 		
           c_addr_length : integer := 9);   
                                          

  port (
    clk_A_i :      in std_logic; 		
    addr_A_i :     in std_logic_vector(c_addr_length - 1 downto 0);
    clk_B_i :      in std_logic;
    addr_B_i :     in std_logic_vector(c_addr_length - 1 downto 0);
    data_B_i :     in std_logic_vector(c_data_length - 1 downto 0);
    write_en_B_i : in std_logic;
 
    data_A_o :     out std_logic_vector(c_data_length -1 downto 0)
       );
  end component dpblockram_clka_rd_clkb_wr; 


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
    crc_o :              out std_logic_vector(c_GENERATOR_POLY_length - 1 downto 0)
       );
  end component wf_crc;


---------------------------------------------------------------------------------------------------
  component deglitcher 
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
  end component deglitcher;


---------------------------------------------------------------------------------------------------
  component status_gen 

    port (
      uclk_i :               in std_logic; 
      slone_i :              in std_logic; 
      nFIP_rst_i :           in std_logic;
      fd_wdgn_i :            in std_logic; 
      fd_txer_i :            in std_logic; 
      var1_access_a_i :      in std_logic; 
      var2_access_a_i :      in std_logic; 
      var3_access_a_i :      in std_logic;  
      var1_rdy_i :           in std_logic; 
      var2_rdy_i :           in std_logic; 
      var3_rdy_i :           in std_logic; 
      code_violation_p_i :   in std_logic; 
      crc_wrong_p_i :        in std_logic;
      reset_status_bytes_i : in std_logic;
      
      status_byte_o :        out std_logic_vector(7 downto 0); 
      mps_byte_o :           out std_logic_vector(7 downto 0)
      );
  end component status_gen;


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
component wf_dec_m_ids 

  port (
    uclk_i :     in std_logic; 
    nFIP_rst_i : in std_logic;
    m_id_i :     in  std_logic_vector (3 downto 0); 
    c_id_i :     in  std_logic_vector (3 downto 0); 
    s_id_o :     out std_logic_vector(1 downto 0);  
    m_id_dec_o : out  std_logic_vector (7 downto 0); 
    c_id_dec_o : out std_logic_vector (7 downto 0)
    );
end component wf_dec_m_ids;
---------------------------------------------------------------------------------------------------
end wf_package;


package body wf_package is
end wf_package;

---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------  
