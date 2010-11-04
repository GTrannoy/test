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

package WF_package is

  constant C_QUARTZ_PERIOD : real := 25.0;

  constant C_TXCLKBUFFLENTGTH :  natural := 4;

  constant C_RELOAD_MID_CID : natural := 8;

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --
  -- constants regarding the CRC calcutator

  constant c_GENERATOR_POLY_length :  natural:= 16;

  -- shift register xor mask
  constant c_GENERATOR_POLY: std_logic_vector (c_GENERATOR_POLY_length- 1 downto 0) :=
                                                                                "0001110111001111"; 
  -- CRC check mask
  constant c_VERIFICATION_MASK:std_logic_vector (c_GENERATOR_POLY_length-1 downto 0) :=
                                                                                "0001110001101011";
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
     others => "00000010" -- reserved 
     );  


  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- -- 
  -- calculations of the number of uclk ticks equivalent to the reception/ transmission period
  constant C_PERIODS_COUNTER_LENGTH : natural := 11; -- in the slowest bit rate (31.25kbps), the 
                                                     -- period is 32000ns and can be measured after
                                                     -- 1280 uclk ticks. Therefore a counter of 11
                                                     -- bits is the max needed for counting 
                                                     -- transmission/reception periods.

  constant c_BIT_RATE_UCLK_TICKS_31_25Kbit:unsigned:= 
                                  to_unsigned((32000/ integer(C_QUARTZ_PERIOD)),C_PERIODS_COUNTER_LENGTH);
  constant c_BIT_RATE_UCLK_TICKS_1_Mbit:unsigned:=
                                    to_unsigned((1000/ integer(C_QUARTZ_PERIOD)),C_PERIODS_COUNTER_LENGTH);
  constant c_BIT_RATE_UCLK_TICKS_2_5_Mbit:unsigned:=
                                     to_unsigned((400 /integer(C_QUARTZ_PERIOD)),C_PERIODS_COUNTER_LENGTH);

  -- formation of a table with the c_BIT_RATE_UCLK_TICKS info per bit rate
  type t_uclk_ticks is array (Natural range <>) of unsigned (C_PERIODS_COUNTER_LENGTH-1 downto 0);
  constant c_BIT_RATE_UCLK_TICKS : t_uclk_ticks(3 downto 0):=
                                                      (0 => (c_BIT_RATE_UCLK_TICKS_31_25Kbit),
                                                       1 => (c_BIT_RATE_UCLK_TICKS_1_Mbit),
                                                       2 => (c_BIT_RATE_UCLK_TICKS_2_5_Mbit),
                                                       3 => (c_BIT_RATE_UCLK_TICKS_2_5_Mbit));

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
                                                   silence  => integer(5160000.0/C_QUARTZ_PERIOD)),

                               c_1M_INDEX =>      (response => integer(45000.0/C_QUARTZ_PERIOD),
                                                   silence  => integer(150000.0/C_QUARTZ_PERIOD)),
                                              
                               c_2M5_INDEX =>     (response => integer(16000.0/C_QUARTZ_PERIOD),
                                                   silence  => integer(100000.0/C_QUARTZ_PERIOD)),

                               c_RESERVE_INDEX => (response => integer(640000.0/C_QUARTZ_PERIOD),
                                                   silence  => integer(5160000.0/C_QUARTZ_PERIOD))
                                );


  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  -- construction of a table with that gathers all the main information for all the variables
 
  type t_var is (var_presence, var_identif, var_1, var_2, var_3, var_rst, var_whatever);

  type t_byte_array is array (natural range <>) of std_logic_vector (7 downto 0);

  type t_var_response is (produce, consume, reset);

  type t_var_record is record
    response :     t_var_response;
    hexvalue :     std_logic_vector (7 downto 0);
    var :          t_var;
    base_addr :    unsigned (8 downto 0);
    last_addr :    unsigned (8 downto 0);
    array_length : unsigned (7 downto 0);
    byte_array :   t_byte_array (0 to 15);
  end record;

  type t_var_array is array (natural range <>) of t_var_record;
  
  constant c_VAR_PRESENCE_INDEX : integer := 0;
  constant c_VAR_IDENTIF_INDEX :  integer := 1;
  constant c_VAR_3_INDEX :        integer := 2;
  constant c_VAR_1_INDEX :        integer := 3;
  constant c_VAR_2_INDEX :        integer := 4;
  constant c_VAR_RST_INDEX :    integer := 5;


  constant c_VARS_ARRAY : t_var_array(0 to 5) := 

    (c_VAR_PRESENCE_INDEX => (var          => var_presence,
                              hexvalue     => x"14", 
                              response     => produce,
                              base_addr    => "---------",
                              last_addr    => "---------",
                              array_length => "00000111", -- 8 bytes in total including the Control byte
                                                          -- (counting starts from 0)
                              byte_array   => (0 => c_RP_DAT_CTRL_BYTE, 1 => x"50", 2 => x"05", 
                                               3 => x"80", 4 => x"03", 5 => x"00", 6 => x"f0",
                                               7 => x"00", others => x"ff")),
 
    
     c_VAR_IDENTIF_INDEX  => (var          => var_identif,
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

     c_VAR_RST_INDEX    => (var          => var_rst,
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

component WF_inputs_synchronizer is

  port (
    uclk_i :          in std_logic; 
    wbclk_i :         in std_logic;
    nFIP_urst_i :    in std_logic;
    rstin_a_i :       in std_logic;
    wb_rst_a_i :      in std_logic;
    slone_a_i :       in std_logic;
    nostat_a_i :      in std_logic;
    fd_wdgn_a_i :     in std_logic;
    fd_txer_a_i :     in std_logic; 
    fd_rxd_a_i :      in std_logic;   
    wb_cyc_a_i :      in std_logic;
    wb_we_a_i :       in std_logic;
    wb_stb_a_i :      in std_logic; 
    wb_adr_a_i :      in std_logic_vector(9 downto 0);
    var1_access_a_i : in std_logic;
    var2_access_a_i : in std_logic;
    var3_access_a_i : in std_logic;
    dat_a_i :         in std_logic_vector(15 downto 0);
    rate_a_i :        in std_logic_vector(1 downto 0);
    subs_a_i :        in std_logic_vector(7 downto 0);
    m_id_a_i :        in std_logic_vector(3 downto 0);
    c_id_a_i :        in std_logic_vector(3 downto 0);
    p3_lgth_a_i :     in std_logic_vector(2 downto 0);

    rsti_o :          out std_logic;
    urst_r_edge_o :   out std_logic;
    slone_o :         out std_logic;
    nostat_o :        out std_logic;
    fd_wdgn_o :       out std_logic;
    fd_txer_o :       out std_logic; 
    fd_rxd_o :        out std_logic;   
    fd_rxd_edge_o :   out std_logic; 
    fd_rxd_r_edge_o : out std_logic; 
    fd_rxd_f_edge_o : out std_logic;
    wb_cyc_o :        out std_logic;
    wb_we_o :         out std_logic;
    wb_stb_o :        out std_logic; 
    wb_stb_r_edge_o : out std_logic;
    wb_dati_o :       out std_logic_vector(7 downto 0);
    wb_adri_o :       out std_logic_vector(9 downto 0);
    var1_access_o :   out std_logic;
    var2_access_o :   out std_logic;
    var3_access_o :   out std_logic;
    slone_dati_o :    out std_logic_vector(15 downto 0);
    rate_o :          out std_logic_vector(1 downto 0);
    subs_o :          out std_logic_vector(7 downto 0);
    m_id_o :          out std_logic_vector(3 downto 0);
    c_id_o :          out std_logic_vector(3 downto 0);
    p3_lgth_o :       out std_logic_vector(2 downto 0)
      );
end component WF_inputs_synchronizer;


---------------------------------------------------------------------------------------------------
component WF_rx 

  port (
    uclk_i :                  in std_logic;
    nFIP_urst_i :              in std_logic;
    rst_rx_unit_p_i :       in std_logic;
    signif_edge_window_i :    in std_logic;
    adjac_bits_window_i :     in std_logic;
    rxd_r_edge_i :            in std_logic;
    rxd_f_edge_i :            in std_logic;
    rxd_filtered_o :          in std_logic;
    rxd_filtered_f_edge_p_i:  in std_logic;
    sample_manch_bit_p_i :    in std_logic; 
    sample_bit_p_i  :         in std_logic;    
 
    byte_ready_p_o :          out std_logic;
    byte_o :                  out std_logic_vector (7 downto 0);
    CRC_wrong_p_o :           out std_logic;
    FSS_CRC_FES_viol_ok_p_o : out std_logic;
    FSS_received_p_o :        out std_logic;
    rst_rx_osc_o : out std_logic	
       );
  end component WF_rx;


---------------------------------------------------------------------------------------------------
  component WF_tx 

  generic (C_TXCLKBUFFLENTGTH : natural);
  port (
    uclk_i :            in std_logic;
    nFIP_urst_i :      in std_logic;
    start_produce_p_i : in std_logic;
    byte_ready_p_i :    in std_logic; 
    last_byte_p_i :     in std_logic;
    byte_i :            in std_logic_vector (7 downto 0);
    tx_clk_p_buff_i :   in std_logic_vector (C_TXCLKBUFFLENTGTH -1 downto 0);
      
    request_byte_p_o :  out std_logic;
    tx_data_o :         out std_logic;
    tx_enable_o :       out std_logic
       );
  end component WF_tx;


---------------------------------------------------------------------------------------------------  
  component WF_rx_tx_osc 
    generic (C_PERIODS_COUNTER_LENGTH : natural;
             C_QUARTZ_PERIOD :          real;
             C_TXCLKBUFFLENTGTH :       natural);

    port (
      uclk_i :                  in std_logic; 
      rate_i :                  in std_logic_vector (1 downto 0);
      nFIP_urst_i :              in std_logic;
      rxd_edge_i :                in std_logic;
      rxd_f_edge_i :        in std_logic;
      rst_rx_osc_i :   in std_logic;	
 
      rx_manch_clk_p_o :        out std_logic;
      rx_bit_clk_p_o  :         out std_logic;
      rx_signif_edge_window_o : out std_logic;
      rx_adjac_bits_window_o :  out std_logic;
      tx_clk_o :                out std_logic;
      tx_clk_p_buff_o :         out std_logic_vector (C_TXCLKBUFFLENTGTH -1 downto 0)

      );
  end component WF_rx_tx_osc;


---------------------------------------------------------------------------------------------------
  component WF_tx_rx

    port (
      uclk_i :                  in std_logic; 
      rate_i :                  in std_logic_vector (1 downto 0);
      nFIP_urst_i :              in std_logic;
      rst_rx_unit_p_i :       in std_logic; 
      start_produce_p_i :       in std_logic;
      byte_ready_p_i :          in std_logic;
      last_byte_p_i :           in std_logic;
      fd_rxd :                  in std_logic;
      fd_rxd_edge_i :           in std_logic;
      fd_rxd_r_edge_i :         in std_logic;
      fd_rxd_f_edge_i :         in std_logic; 
      byte_i :                  in std_logic_vector (7 downto 0);      

      request_byte_p_o :        out std_logic;
      tx_enable_o :             out std_logic;
      d_clk_o :                 out std_logic;
      tx_data_o :               out std_logic;      
      byte_ready_p_o :          out std_logic;
      CRC_wrong_p_o :           out std_logic;
      FSS_received_p_o :        out std_logic;
      FSS_CRC_FES_viol_ok_p_o : out std_logic;
      byte_o :                  out std_logic_vector (7 downto 0)
      );
  end component WF_tx_rx;


---------------------------------------------------------------------------------------------------
  component WF_cons_bytes_from_rx 
    port (
      uclk_i :              in std_logic;
      slone_i :             in std_logic; 
      nFIP_urst_i :          in std_logic;
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
      rx_Ctrl_byte_o :      out std_logic_vector (7 downto 0);
      rx_PDU_byte_o :       out std_logic_vector (7 downto 0);           
      rx_Length_byte_o :    out std_logic_vector (7 downto 0);
      rx_var_rst_byte_1_o : out std_logic_vector (7 downto 0);
      rx_var_rst_byte_2_o : out std_logic_vector (7 downto 0)
      );

  end component WF_cons_bytes_from_rx;

---------------------------------------------------------------------------------------------------
  component WF_slone_bytes_to_DATO is

    port (
      uclk_i :              in std_logic;                   
      nFIP_urst_i :          in std_logic;                    
      transfer_byte_p_i:    in std_logic_vector (1 downto 0);
	  byte_i :              in std_logic_vector (7 downto 0); 

      slone_data_o :        out std_logic_vector(15 downto 0)
      );
end component WF_slone_bytes_to_DATO;


---------------------------------------------------------------------------------------------------
  component WF_prod_bytes_to_tx is
    port (
      uclk_i :             in std_logic; 
      slone_i :            in std_logic; 
      nostat_i :           in std_logic; 
      nFIP_urst_i :         in std_logic;
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
  end component WF_prod_bytes_to_tx;


---------------------------------------------------------------------------------------------------
component WF_slone_DATI_bytes_sampler is

  port (
    uclk_i :          in std_logic;
    nFIP_urst_i :    in std_logic; 
    slone_data_i :    in  std_logic_vector (15 downto 0);
    var3_rdy_i :      in std_logic;
    byte_index_i :    in std_logic_vector (7 downto 0);
    slone_byte_o :    out std_logic_vector (7 downto 0)
    );
end component WF_slone_DATI_bytes_sampler;


---------------------------------------------------------------------------------------------------  
  component WF_engine_control 
    generic( C_QUARTZ_PERIOD : real);

    port (
      uclk_i :                in std_logic; 
      nFIP_urst_i :           in std_logic;
      rate_i :                in std_logic_vector (1 downto 0);
      subs_i :                in std_logic_vector (7 downto 0); 
      p3_lgth_i :             in std_logic_vector (2 downto 0); 
      slone_i :               in std_logic; 
      nostat_i :              in std_logic; 
      tx_request_byte_p_i :   in std_logic;
      rx_FSS_received_p_i :   in std_logic; 
      rx_byte_ready_p_i :     in std_logic;
      rx_byte_i :             in std_logic_vector (7 downto 0);  
      rx_CRC_FES_ok_p_i :     in std_logic;  
      rx_var_rst_byte_1_i :   in std_logic_vector (7 downto 0);
      rx_var_rst_byte_2_i :   in std_logic_vector (7 downto 0); 
      tx_sending_mps_i :      in std_logic;
      rx_Ctrl_byte_i :        in std_logic_vector (7 downto 0);
      rx_PDU_byte_i :         in std_logic_vector (7 downto 0);           
      rx_Length_byte_i :      in std_logic_vector (7 downto 0);

      var1_rdy_o:             out std_logic; 
      var2_rdy_o:             out std_logic; 
      var3_rdy_o:             out std_logic; 
      tx_byte_ready_p_o :     out std_logic;
      tx_last_byte_p_o :      out std_logic;
      tx_start_produce_p_o :  out std_logic;
      tx_rx_byte_index_o :    out std_logic_vector (7 downto 0);
      tx_data_length_o :      out std_logic_vector (7 downto 0);
      rx_byte_ready_p_o :     out std_logic;
      rst_status_bytes_o :  out std_logic;
      rst_rx_unit_p_o :     out std_logic;
      var_o :                 out t_var;
      assert_RSTON_p_o :       out std_logic;
      rst_nFIP_and_FD_p_o : out std_logic
      );

  end component WF_engine_control;


---------------------------------------------------------------------------------------------------  
  component WF_reset_unit 
    port (
      uclk_i :                in std_logic; 
      urst_i :                in  std_logic; 
      rate_i :                in std_logic_vector (1 downto 0);
      urst_r_edge_i :         in std_logic;
      var_i :                 in t_var;    
      subs_i :                in  std_logic_vector (7 downto 0);
      rst_nFIP_and_FD_p_i : in std_logic;
      assert_RSTON_p_i :       in std_logic;
 
      rston_o :               out std_logic;
      nFIP_rst_o :            out std_logic; 
      fd_rstn_o :             out std_logic 
      );
  end component WF_reset_unit;


---------------------------------------------------------------------------------------------------
  component WF_DualClkRAM_clka_rd_clkb_wr
  generic (C_RAM_DATA_LGTH : integer; 		
           C_RAM_ADDR_LGTH : integer);   
                                          

  port (
    clk_A_i :      in std_logic; 		
    addr_A_i :     in std_logic_vector (C_RAM_ADDR_LGTH - 1 downto 0);
    clk_B_i :      in std_logic;
    addr_B_i :     in std_logic_vector (C_RAM_ADDR_LGTH - 1 downto 0);
    data_B_i :     in std_logic_vector (C_RAM_DATA_LGTH - 1 downto 0);
    write_en_B_i : in std_logic;
 
    data_A_o :     out std_logic_vector (C_RAM_DATA_LGTH -1 downto 0)
       );
  end component WF_DualClkRAM_clka_rd_clkb_wr; 


---------------------------------------------------------------------------------------------------
  component  WF_crc 
  generic (c_GENERATOR_POLY_length :  natural := 16);
  port (
    uclk_i :             in std_logic;
    nFIP_urst_i :         in std_logic;
    start_CRC_p_i :      in std_logic;
    data_bit_i :         in std_logic;
    data_bit_ready_p_i : in std_logic;

    CRC_ok_p :           out std_logic;
    CRC_o :              out std_logic_vector (c_GENERATOR_POLY_length - 1 downto 0)
       );
  end component WF_crc;

---------------------------------------------------------------------------------------------------
component WF_manch_encoder is
generic(word_length :  natural);
  port (
    word_i :       in std_logic_vector(word_length-1 downto 0);          
    word_manch_o : out std_logic_vector((2*word_length)-1 downto 0)
      );
end component WF_manch_encoder;

---------------------------------------------------------------------------------------------------
component WF_manch_code_viol_check is
  port (
    uclk_i :              in std_logic;
    nFIP_urst_i :          in std_logic;   
    serial_input_signal_i :   in std_logic;
    sample_bit_p_i :       in std_logic;
    sample_manch_bit_p_i : in std_logic;
 
    manch_code_viol_p_o : out std_logic
      );
end component WF_manch_code_viol_check;



---------------------------------------------------------------------------------------------------
  component WF_rx_deglitcher 
  generic (C_ACULENGTH : integer := 10);
  port (
    uclk_i :                    in std_logic;
    nFIP_urst_i :                in std_logic; 
    rxd_i :                 in std_logic;
    sample_manch_bit_p_i :      in std_logic;
    sample_bit_p_i :            in std_logic;

    sample_manch_bit_p_o :      out std_logic;
    rxd_filtered_o :        out std_logic;
    rxd_filtered_f_edge_p_o : out std_logic;
    sample_bit_p_o :            out std_logic
       ); 
  end component WF_rx_deglitcher;


---------------------------------------------------------------------------------------------------
  component WF_status_bytes_gen 

    port (
      uclk_i :               in std_logic; 
      slone_i :              in std_logic; 
      nFIP_urst_i :           in std_logic;
      fd_wdgn_i :            in std_logic; 
      fd_txer_i :            in std_logic; 
      var1_acc_i :           in std_logic; 
      var2_acc_i :           in std_logic; 
      var3_acc_i :           in std_logic; 
      var_i :                in t_var;  
      var1_rdy_i :           in std_logic; 
      var2_rdy_i :           in std_logic; 
      var3_rdy_i :           in std_logic; 
      crc_wrong_p_i :        in std_logic;
      rst_status_bytes_i : in std_logic;
      
      nFIP_status_byte_o :   out std_logic_vector (7 downto 0); 
      mps_status_byte_o :    out std_logic_vector (7 downto 0)
      );
  end component WF_status_bytes_gen;

---------------------------------------------------------------------------------------------------

  component WF_bits_to_txd
  generic (C_TXCLKBUFFLENTGTH : natural := 4);
  port (
    uclk_i :              in std_logic; 
    nFIP_urst_i :          in std_logic; 
    txd_bit_index_i :     in unsigned(4 downto 0);
    data_byte_manch_i :   in std_logic_vector (15 downto 0);
    crc_byte_manch_i :    in std_logic_vector (31 downto 0);
    sending_FSS_i :       in std_logic;
    sending_data_i :      in std_logic;
    sending_crc_i :       in std_logic;
    sending_QUEUE_i :     in std_logic;
    stop_transmission_i : in std_logic;
    tx_clk_p_buff_i :     in std_logic_vector (C_TXCLKBUFFLENTGTH -1 downto 0);

    txd_o :               out std_logic;
    tx_enable_o :         out std_logic
      );
end component WF_bits_to_txd;


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
    wbclk_i    : in  std_logic; 
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
component WF_model_constr_decoder 
  generic (C_RELOAD_MID_CID : natural); 
  port (
    uclk_i :     in std_logic; 
    nFIP_urst_i : in std_logic;
    m_id_i :     in std_logic_vector (3 downto 0); 
    c_id_i :     in std_logic_vector (3 downto 0); 

    s_id_o :     out std_logic_vector (1 downto 0);  
    m_id_dec_o : out std_logic_vector (7 downto 0); 
    c_id_dec_o : out std_logic_vector (7 downto 0)
    );
end component WF_model_constr_decoder;
---------------------------------------------------------------------------------------------------

component WF_decr_counter is
  generic(counter_length :  natural := 5);
  port (
    uclk_i :           in std_logic;
    nFIP_urst_i :       in std_logic;
    counter_top :       in unsigned (counter_length-1 downto 0);
    counter_load_i :    in std_logic;
    counter_decr_p_i :  in std_logic;

    counter_o :         out unsigned (counter_length-1 downto 0);
    counter_is_zero_o : out std_logic
      );
end component WF_decr_counter;

---------------------------------------------------------------------------------------------------
component WF_incr_counter is
  generic(counter_length :  natural := 8);
  port (
    uclk_i :           in std_logic; 
    nFIP_urst_i :      in std_logic; 
   reinit_counter_i :  in std_logic;
   incr_counter_i:     in std_logic;

   counter_o :         out unsigned(counter_length-1 downto 0);
   counter_is_full_o : out std_logic
      );
end component WF_incr_counter;



---------------------------------------------------------------------------------------------------

component WF_prod_data_lgth_calc is
  port (
    slone_i :          in std_logic;                    
    nostat_i :         in std_logic;  
    p3_lgth_i :        in std_logic_vector (2 downto 0);
    var_i:             in t_var;

    tx_data_length_o : out std_logic_vector(7 downto 0)
      );
end component WF_prod_data_lgth_calc;

---------------------------------------------------------------------------------------------------
component WF_cons_frame_validator is

  port (
    rx_Ctrl_byte_i :         in std_logic_vector (7 downto 0);
    rx_PDU_byte_i :          in std_logic_vector (7 downto 0);           
    rx_Length_byte_i :       in std_logic_vector (7 downto 0);  
    rx_FSS_CRC_FES_viol_ok_p_i : in std_logic;
    var_i:                   in t_var;
    rx_byte_index_i :        in unsigned(7 downto 0);

    cons_frame_ok_p_o :      out std_logic
      );
end component WF_cons_frame_validator;


---------------------------------------------------------------------------------------------------
component WF_VAR_RDY_generator is

  port (
    uclk_i :                in std_logic; 
    slone_i :               in std_logic;
    subs_i :                in std_logic_vector (7 downto 0);
    nFIP_urst_i :           in std_logic;  
    cons_frame_ok_p_i :     in std_logic;
    var_i :                 in t_var;
    rx_var_rst_byte_1_i :      in std_logic_vector (7 downto 0);
    rx_var_rst_byte_2_i :      in std_logic_vector (7 downto 0);

    var1_rdy_o :            out std_logic;
    var2_rdy_o :            out std_logic;
    var3_rdy_o :            out std_logic;
    assert_RSTON_p_o :       out std_logic;
    rst_nFIP_and_FD_p_o : out std_logic
      );
end component WF_VAR_RDY_generator;


end WF_package;
package body WF_package is
end WF_package;
--=================================================================================================
--                                         package end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------
