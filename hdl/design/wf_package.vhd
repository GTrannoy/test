--_________________________________________________________________________________________________
--                                                                                                |
--                                        |The nanoFIP|                                           |
--                                                                                                |
--                                        CERN,BE/CO-HT                                           |
--________________________________________________________________________________________________|
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--! @file WF_package.vhd                                                                          |
---------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

---------------------------------------------------------------------------------------------------
--                                                                                               --
--                                           WF_package                                          --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
--
--! @brief     Definitions of constants, types, entities, functions
--
--
--! @author    Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)\n
--!            Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)    \n
--
--
--! @date      11/01/2011
--
--
--! @version   v0.04
--
--
--! @details \n
--
--!   \n<b>Dependencies:</b>\n
--
--
--!   \n<b>Modified by:</b>   \n
--!            Evangelia Gousiou     \n
--
---------------------------------------------------------------------------------------------------
--
--!   \n\n<b>Last changes:</b>\n
--!     ->    8/2010  v0.01  EG  byte_array of all vars cleaned_up (ex: subs_i removed) \n
--!     ->   10/2010  v0.02  EG  base_addr unsigned(8 downto 0) instead of
--!                              std_logic_vector(9 downto 0) to simplify calculations; cleaning-up
--!     ->    1/2011  v0.03  EG  turnaround times & broadcast var (91h) updated following new specs
--!                              added DualClkRam
--!     ->    2/2011  v0.04  EG  function for manch_encoder; cleaning up of constants+generics
--
---------------------------------------------------------------------------------------------------
--
--! @todo
--!   ->
--
---------------------------------------------------------------------------------------------------


--=================================================================================================
--!                              Package declaration for WF_package
--=================================================================================================

package WF_package is


---------------------------------------------------------------------------------------------------
--                                Constant regarding the user clock                              --
---------------------------------------------------------------------------------------------------

  constant c_QUARTZ_PERIOD : real := 25.0;

  constant c_DEGLITCH_THRESHOLD : natural := 4;

---------------------------------------------------------------------------------------------------
--                            Constants regarding the CRC calculation                            --
---------------------------------------------------------------------------------------------------
  constant c_CRC_POLY_LGTH  : natural                                         := 16;
  constant c_CRC_GENER_POLY : std_logic_vector (c_CRC_POLY_LGTH - 1 downto 0) := "0001110111001111";
  constant c_CRC_VERIF_POLY : std_logic_vector (c_CRC_POLY_LGTH - 1 downto 0) := "0001110001101011";


---------------------------------------------------------------------------------------------------
--                     Constants regarding the the ID_DAT and RP_DAT frame structure             --
---------------------------------------------------------------------------------------------------

  constant c_VP   : std_logic_vector (1 downto 0) := "11";
  constant c_VN   : std_logic_vector (1 downto 0) := "00";
  constant c_ONE  : std_logic_vector (1 downto 0) := "10";
  constant c_ZERO : std_logic_vector (1 downto 0) := "01";

  constant c_PRE  : std_logic_vector (15 downto 0) :=  c_ONE & c_ZERO & c_ONE & c_ZERO & c_ONE & c_ZERO & c_ONE & c_ZERO;
  constant c_FSD  : std_logic_vector (15 downto 0) :=  c_ONE & c_VP & c_VN & c_ONE & c_ZERO & c_VN & c_VP & c_ZERO;
  constant c_FES  : std_logic_vector (15 downto 0) :=  c_ONE & c_VP & c_VN & c_VP & c_VN & c_ONE & c_ZERO & c_ONE;
  constant c_FSS  : std_logic_vector (31 downto 0) :=  c_PRE & c_FSD;



---------------------------------------------------------------------------------------------------
--       Constants regarding the Control and PDU_TYPE bytes of ID_DAT and RP_DAT frames          --
---------------------------------------------------------------------------------------------------

  constant c_ID_DAT_CTRL_BYTE        : std_logic_vector (7 downto 0) := "00000011";
  constant c_RP_DAT_CTRL_BYTE        : std_logic_vector (7 downto 0) := "00000010";
  constant c_PROD_CONS_PDU_TYPE_BYTE : std_logic_vector (7 downto 0) := "01000000";



---------------------------------------------------------------------------------------------------
--                          Constants regarding the nanoFIP status bits                         --
---------------------------------------------------------------------------------------------------

  constant c_U_CACER_INDEX : integer := 2;
  constant c_U_PACER_INDEX : integer := 3;
  constant c_R_TLER_INDEX  : integer := 4;
  constant c_R_FCSER_INDEX : integer := 5;
  constant c_T_TXER_INDEX  : integer := 6;
  constant c_T_WDER_INDEX  : integer := 7;



---------------------------------------------------------------------------------------------------
--                        Constant regarding the Model & Constructor decoding                    --
---------------------------------------------------------------------------------------------------

  constant c_RELOAD_MID_CID : natural := 8;



---------------------------------------------------------------------------------------------------
--                               Constant regarding the Transmitter                              --
---------------------------------------------------------------------------------------------------

  constant c_TX_CLK_BUFF_LGTH : natural := 4; -- length of the clk buffer used for
                                              -- the transmission synchronization



---------------------------------------------------------------------------------------------------
--                            Constants regarding the MPS status bits                            --
---------------------------------------------------------------------------------------------------

  constant c_REFRESHMENT_INDEX  : integer := 0;
  constant c_SIGNIFICANCE_INDEX : integer := 2;



---------------------------------------------------------------------------------------------------
--                 Constants regarding the position of bytes in the frame structure              --
---------------------------------------------------------------------------------------------------

  constant c_CTRL_BYTE_INDEX     : std_logic_vector (7 downto 0) := "00000000"; -- 0
  constant c_PDU_BYTE_INDEX      : std_logic_vector (7 downto 0) := "00000001"; -- 1
  constant c_LGTH_BYTE_INDEX     : std_logic_vector (7 downto 0) := "00000010"; -- 2
  constant c_1st_DATA_BYTE_INDEX : std_logic_vector (7 downto 0) := "00000011"; -- 3
  constant c_2nd_DATA_BYTE_INDEX : std_logic_vector (7 downto 0) := "00000100"; -- 4

  constant c_CONSTR_BYTE_INDEX   : std_logic_vector (7 downto 0) := "00000110"; -- 6
  constant c_MODEL_BYTE_INDEX    : std_logic_vector (7 downto 0) := "00000111"; -- 7



---------------------------------------------------------------------------------------------------
--                      Constants & Types regarding the P3_LGTH[2:0] settings                    --
---------------------------------------------------------------------------------------------------

  -- Construction of a table for the P3_LGTH[2:0] settings
  type t_unsigned_array is array (natural range <>) of unsigned(7 downto 0);

  constant c_P3_LGTH_TABLE : t_unsigned_array(7 downto 0) :=
    (0      => "00000010", -- 2 bytes
     1      => "00001000", -- 8 bytes
     2      => "00010000", -- 16 bytes
     3      => "00100000", -- 32 bytes
     4      => "01000000", -- 64 bytes
     5      => "01111100", -- 124 bytes
     others => "00000010");  -- reserved



---------------------------------------------------------------------------------------------------
--                           Constants & Types regarding the bit rate                            --
---------------------------------------------------------------------------------------------------

  -- Calculation of the number of uclk ticks equivalent to the reception/ transmission period

  constant c_PERIODS_COUNTER_LGTH : natural := 11; -- in the slowest bit rate (31.25kbps), the
                                                   -- period is 32000 ns and can be measured after
                                                   -- 1280 uclk ticks. Therefore a counter of 11
                                                   -- bits is the max needed for counting
                                                   -- transmission/ reception periods.

  constant c_BIT_RATE_UCLK_TICKS_31_25Kbit: unsigned :=
                          to_unsigned((32000 / integer(C_QUARTZ_PERIOD)),c_PERIODS_COUNTER_LGTH);
  constant c_BIT_RATE_UCLK_TICKS_1_Mbit: unsigned    :=
                          to_unsigned((1000 / integer(C_QUARTZ_PERIOD)),c_PERIODS_COUNTER_LGTH);
  constant c_BIT_RATE_UCLK_TICKS_2_5_Mbit: unsigned  :=
                          to_unsigned((400 /integer(C_QUARTZ_PERIOD)),c_PERIODS_COUNTER_LGTH);

  -- Creation of a table with the c_BIT_RATE_UCLK_TICKS info per bit rate
  type t_uclk_ticks is array (Natural range <>) of unsigned (c_PERIODS_COUNTER_LGTH-1 downto 0);

  constant c_BIT_RATE_UCLK_TICKS : t_uclk_ticks (3 downto 0):=
                          (0 => (c_BIT_RATE_UCLK_TICKS_31_25Kbit),
                           1 => (c_BIT_RATE_UCLK_TICKS_1_Mbit),
                           2 => (c_BIT_RATE_UCLK_TICKS_2_5_Mbit),
                           3 => (c_BIT_RATE_UCLK_TICKS_2_5_Mbit));

  constant c_2_PERIODS_COUNTER_LGTH : natural := 12; -- length of a counter counting 2 reception/
                                                     -- transmission periods

---------------------------------------------------------------------------------------------------
--                     Constants & Types regarding the turnaround and silence times              --
---------------------------------------------------------------------------------------------------

  -- Construction of a table with the turnaround and silence times for each bit rate.
  -- The table contains the number of uclk ticks corresponding to the turnaround/ silence times.

  type t_timeouts is
  record
    turnaround : integer;
    silence    : integer;
  end record;

  constant c_31K25_INDEX   : integer := 0;
  constant c_1M_INDEX      : integer := 1;
  constant c_2M5_INDEX     : integer := 2;
  constant c_RESERVE_INDEX : integer := 3;

  type t_timeouts_table is array (natural range <>) of t_timeouts;

  constant c_TIMEOUTS_TABLE : t_timeouts_table(3 downto 0) :=

                              (c_31K25_INDEX   => (turnaround => integer (480000.0  / c_QUARTZ_PERIOD),
                                                   silence    => integer (4096000.0 / c_QUARTZ_PERIOD)),

                               c_1M_INDEX      => (turnaround => integer (14000.0   / c_QUARTZ_PERIOD),
                                                   silence    => integer (150000.0  / c_QUARTZ_PERIOD)),

                               c_2M5_INDEX     => (turnaround => integer (6000.0   / c_QUARTZ_PERIOD),
                                                   silence    => integer (96000.0 / c_QUARTZ_PERIOD)),

                               c_RESERVE_INDEX => (turnaround => integer (480000.0  /C_QUARTZ_PERIOD),
                                                   silence    => integer (4096000.0 /C_QUARTZ_PERIOD)));



---------------------------------------------------------------------------------------------------
--                    Constants & Types regarding the consumed & produced variables              --
---------------------------------------------------------------------------------------------------

  -- Construction of a table that groups main information for all the variables

  type t_var is (var_presence, var_identif, var_1, var_2, var_3, var_rst, var_whatever);

  type t_byte_array is array (natural range <>) of std_logic_vector (7 downto 0);

  type t_var_record is record
    var          : t_var;
    hexvalue     : std_logic_vector (7 downto 0);
    prod_or_cons : std_logic_vector (1 downto 0);
    broadcast    : std_logic;
    base_addr    : unsigned (8 downto 0);
    array_lgth   : unsigned (7 downto 0);
    byte_array   : t_byte_array (0 to 15);
  end record;

  type t_var_array is array (natural range <>) of t_var_record;

  constant c_VAR_PRESENCE_INDEX : integer := 0;
  constant c_VAR_IDENTIF_INDEX  : integer := 1;
  constant c_VAR_3_INDEX        : integer := 2;
  constant c_VAR_1_INDEX        : integer := 3;
  constant c_VAR_2_INDEX        : integer := 4;
  constant c_VAR_RST_INDEX      : integer := 5;


  constant c_VARS_ARRAY : t_var_array(0 to 5) :=

    (c_VAR_PRESENCE_INDEX => (var          => var_presence,
                              hexvalue     => x"14",
                              prod_or_cons => "10",
                              broadcast    => '0',
                              base_addr    => "---------",
                              array_lgth   => "00000111", -- 8 bytes in total including the Control byte
                                                          -- (counting starts from 0;-))
                              byte_array   => (0 => c_RP_DAT_CTRL_BYTE, 1 => x"50", 2 => x"05",
                                               3 => x"80", 4 => x"03" , 5 => x"00", 6 => x"f0",
                                               7 => x"00", others => x"ff")),


     c_VAR_IDENTIF_INDEX  => (var          => var_identif,
                              hexvalue     => x"10",
                              prod_or_cons => "10",
                              broadcast    => '0',
                              base_addr    => "---------",
                              array_lgth   => "00001010", -- 11 bytes in total including the Control byte
                              byte_array   => (0 => c_RP_DAT_CTRL_BYTE, 1 => x"52", 2 => x"08",
                                               3 => x"01", 4 => x"00" , 5 => x"00", 6 => x"ff",
                                               7 => x"ff", 8 => x"00" , 9 => x"00", 10 => x"00",
                                               others => x"ff")),


     c_VAR_3_INDEX        => (var          => var_3,
                              hexvalue     => x"06",
                              prod_or_cons => "10",
                              broadcast    => '0',
                              base_addr    => "100000000",
                              array_lgth   => "00000001", -- only the Control and PDU_TYPE bytes are
                                                          -- predefined
                              byte_array   => (0 => c_RP_DAT_CTRL_BYTE, 1 => c_PROD_CONS_PDU_TYPE_BYTE,
                                               others => x"ff")),


     c_VAR_1_INDEX        => (var          => var_1,
                              hexvalue     => x"05",
                              prod_or_cons => "01",
                              broadcast    => '0',
                              base_addr    => "000000000",
                              array_lgth   => "00000001", -- only the Control and PDU_TYPE bytes are
                                                          -- predefined
                              byte_array   => (0 => c_RP_DAT_CTRL_BYTE, 1 => c_PROD_CONS_PDU_TYPE_BYTE,
                                               others => x"ff")),


     c_VAR_2_INDEX        => (var          => var_2,
                              hexvalue     => x"91",
                              prod_or_cons => "01",
                              broadcast    => '1',
                              base_addr    => "010000000",
                              array_lgth   => "00000001", -- only the Control and PDU_TYPE bytes are
                                                          -- predefined
                              byte_array   => (0 => c_RP_DAT_CTRL_BYTE, 1 => c_PROD_CONS_PDU_TYPE_BYTE,
                                               others => x"ff")),

     c_VAR_RST_INDEX    =>   (var          => var_rst,
                              hexvalue     => x"e0",
                              prod_or_cons => "01",
                              broadcast    => '1',
                              base_addr    => "---------",
                              array_lgth   => "00000001", -- only the Control and PDU_TYPE bytes are
                                                          -- predefined
                              byte_array   => (0 => c_RP_DAT_CTRL_BYTE, 1 => c_PROD_CONS_PDU_TYPE_BYTE,
                                               others => x"ff")));



---------------------------------------------------------------------------------------------------
--                                      Components Declarations:                                 --
---------------------------------------------------------------------------------------------------


---------------------------------------------------------------------------------------------------
  component WF_rx_deserializer
  port (
    uclk_i                   : in std_logic;
    nfip_rst_i               : in std_logic;
    rx_rst_p_i               : in std_logic;
    signif_edge_window_i     : in std_logic;
    adjac_bits_window_i      : in std_logic;
    fd_rxd_r_edge_p_i        : in std_logic;
    fd_rxd_f_edge_p_i        : in std_logic;
    fd_rxd_i                 : in std_logic;
    sample_manch_bit_p_i     : in std_logic;
    sample_bit_p_i           : in std_logic;
  -----------------------------------------------------------------
    byte_ready_p_o           : out std_logic;
    byte_o                   : out std_logic_vector (7 downto 0);
    crc_or_manch_wrong_p_o   : out std_logic;
    fss_crc_fes_manch_ok_p_o : out std_logic;
    fss_received_p_o         : out std_logic;
    rx_osc_rst_o             : out std_logic);
  -----------------------------------------------------------------
  end component WF_rx_deserializer;




---------------------------------------------------------------------------------------------------
  component WF_tx_serializer
  port (
    uclk_i                  : in std_logic;
    nfip_rst_i              : in std_logic;
    tx_start_p_i            : in std_logic;
    byte_request_accept_p_i : in std_logic;
    last_byte_p_i           : in std_logic;
    byte_i                  : in std_logic_vector (7 downto 0);
    tx_clk_p_buff_i         : in std_logic_vector (c_TX_CLK_BUFF_LGTH -1 downto 0);
  -----------------------------------------------------------------
    byte_request_p_o        : out std_logic;
    tx_osc_rst_p_o          : out std_logic;
    tx_data_o               : out std_logic;
    tx_enable_o             : out std_logic);
  -----------------------------------------------------------------
  end component WF_tx_serializer;



---------------------------------------------------------------------------------------------------
  component WF_cons_bytes_processor
  port (
    uclk_i                : in std_logic;
    slone_i               : in std_logic;
    nfip_rst_i            : in std_logic;
    wb_clk_i              : in std_logic;
    wb_adr_i              : in std_logic_vector (8 downto 0);
    byte_ready_p_i        : in std_logic;
    byte_index_i          : in std_logic_vector (7 downto 0);
    var_i                 : in t_var;
    byte_i                : in std_logic_vector (7 downto 0);
  -----------------------------------------------------------------
    data_o                : out std_logic_vector (15 downto 0);
    cons_ctrl_byte_o      : out std_logic_vector (7 downto 0);
    cons_pdu_byte_o       : out std_logic_vector (7 downto 0);
    cons_lgth_byte_o      : out std_logic_vector (7 downto 0);
    cons_var_rst_byte_1_o : out std_logic_vector (7 downto 0);
    cons_var_rst_byte_2_o : out std_logic_vector (7 downto 0));
  -----------------------------------------------------------------
  end component WF_cons_bytes_processor;



---------------------------------------------------------------------------------------------------
  component WF_consumption is
  port (
    uclk_i                      : in std_logic;
    slone_i                     : in std_logic;
    subs_i                      : in std_logic_vector (7 downto 0);
    nfip_rst_i                  : in std_logic;
    rx_byte_i                   : in std_logic_vector (7 downto 0);
    rx_byte_ready_p_i           : in std_logic;
    rx_fss_crc_fes_manch_ok_p_i : in std_logic;
    rx_crc_or_manch_wrong_p_i   : in std_logic;
    wb_clk_i                    : in std_logic;
    wb_adr_i                    : in std_logic_vector (8 downto 0);
    var_i                       : in t_var;
    byte_index_i                : in std_logic_vector (7 downto 0);
  -----------------------------------------------------------------
    var1_rdy_o                  : out std_logic;
    var2_rdy_o                  : out std_logic;
    data_o                      : out std_logic_vector (15 downto 0);
    nfip_status_r_tler_p_o      : out std_logic;
    assert_rston_p_o            : out std_logic;
    rst_nfip_and_fd_p_o         : out std_logic);
  -----------------------------------------------------------------
  end component WF_consumption;



---------------------------------------------------------------------------------------------------
  component WF_fd_receiver is
  port (
    uclk_i                      : in std_logic;
    rate_i                      : in std_logic_vector (1 downto 0);
    fd_rxd_a_i                  : in std_logic;
    nfip_rst_i                  : in std_logic;
    rx_rst_p_i                  : in std_logic;
  -----------------------------------------------------------------
    rx_byte_o                   : out std_logic_vector (7 downto 0);
    rx_byte_ready_p_o           : out std_logic;
    rx_fss_crc_fes_manch_ok_p_o : out std_logic;
    rx_fss_received_p_o         : out std_logic;
    rx_crc_or_manch_wrong_p_o   : out std_logic );
  -----------------------------------------------------------------
  end component WF_fd_receiver;



---------------------------------------------------------------------------------------------------
  component WF_rx_osc is
  port (
    uclk_i                  : in std_logic;
    rate_i                  : in  std_logic_vector (1 downto 0);
    nfip_rst_i              : in std_logic;
    fd_rxd_edge_p_i         : in std_logic;
    rx_osc_rst_i            : in std_logic;
  -----------------------------------------------------------------
    rx_manch_clk_p_o        : out std_logic;
    rx_bit_clk_p_o          : out std_logic;
    rx_signif_edge_window_o : out std_logic;
    rx_adjac_bits_window_o  : out std_logic );
  -----------------------------------------------------------------
end component WF_rx_osc;



---------------------------------------------------------------------------------------------------
  component WF_production is
  port (
    uclk_i                  : in std_logic;
    slone_i                 : in std_logic;
    nostat_i                : in std_logic;
    nfip_rst_i              : in std_logic;
    wb_clk_i                : in std_logic;
    wb_adr_i                : in std_logic_vector (8 downto 0);
    wb_data_i               : in std_logic_vector (7 downto 0);
    wb_ack_prod_p_i         : in std_logic;
    slone_data_i            : in std_logic_vector (15 downto 0);
    var1_acc_a_i            : in std_logic;
    var2_acc_a_i            : in std_logic;
    var3_acc_a_i            : in std_logic;
    fd_txer_a_i             : in  std_logic;
    fd_wdgn_a_i             : in  std_logic;
    byte_index_i            : in std_logic_vector (7 downto 0);
    data_lgth_i             : in std_logic_vector (7 downto 0);
    byte_request_accept_p_i : in std_logic;
    var_i                   : in t_var;
    var1_rdy_i              : in std_logic;
    var2_rdy_i              : in std_logic;
    nfip_status_r_fcser_p_i : in std_logic;
    nfip_status_r_tler_p_i  : in std_logic;
    constr_id_dec_i         : in  std_logic_vector (7 downto 0);
    model_id_dec_i          : in  std_logic_vector (7 downto 0);
  -----------------------------------------------------------------
    byte_o                  : out std_logic_vector (7 downto 0);
    u_cacer_o               : out std_logic;
    r_fcser_o               : out std_logic;
    u_pacer_o               : out std_logic;
    r_tler_o                : out std_logic;
    var3_rdy_o              : out std_logic);
  -----------------------------------------------------------------
  end component WF_production;



---------------------------------------------------------------------------------------------------
  component WF_fd_transmitter is
  port (
    uclk_i                     : in std_logic;
    rate_i                     : in std_logic_vector (1 downto 0);
    nfip_rst_i                 : in std_logic;
    tx_byte_i                  : in std_logic_vector (7 downto 0);
    tx_byte_request_accept_p_i : in std_logic;
    tx_last_byte_p_i           : in std_logic;
    tx_start_p_i               : in std_logic;
  -----------------------------------------------------------------
    tx_byte_request_p_o        : out std_logic;
    tx_data_o                  : out std_logic;
    tx_enable_o                : out std_logic;
    tx_clk_o                   : out std_logic);
  -----------------------------------------------------------------
  end component WF_fd_transmitter;



---------------------------------------------------------------------------------------------------
  component WF_tx_osc is
  port (
    uclk_i          : in std_logic;
    rate_i          : in  std_logic_vector (1 downto 0);
    nfip_rst_i      : in std_logic;
    tx_osc_rst_p_i  : in std_logic;
  -----------------------------------------------------------------
    tx_clk_o        : out std_logic;
    tx_clk_p_buff_o : out std_logic_vector (c_TX_CLK_BUFF_LGTH -1 downto 0));
  -----------------------------------------------------------------
  end component WF_tx_osc;



---------------------------------------------------------------------------------------------------
  component WF_prod_bytes_retriever is
  port (
    uclk_i               : in std_logic;
    slone_i              : in std_logic;
    nostat_i             : in std_logic;
    nfip_rst_i           : in std_logic;
    model_id_dec_i       : in std_logic_vector (7 downto 0);
    constr_id_dec_i      : in std_logic_vector (7 downto 0);
    wb_clk_i             : in std_logic;
    wb_data_i            : in std_logic_vector (7 downto 0);
    wb_adr_i             : in std_logic_vector (8 downto 0);
    wb_ack_prod_p_i      : in std_logic;
    slone_data_i         : in std_logic_vector (15 downto 0);
    nFIP_status_byte_i   : in std_logic_vector (7 downto 0);
    mps_status_byte_i    : in std_logic_vector (7 downto 0);
    var_i                : in t_var;
    data_lgth_i          : in std_logic_vector (7 downto 0);
    byte_index_i         : in std_logic_vector (7 downto 0);
    byte_being_sent_p_i  : in std_logic;
    var3_rdy_i           : in std_logic;
  -----------------------------------------------------------------
    rst_status_bytes_p_o : out std_logic;
    byte_o               : out std_logic_vector (7 downto 0));
  -----------------------------------------------------------------
  end component WF_prod_bytes_retriever;



---------------------------------------------------------------------------------------------------
  component WF_engine_control
  port (
    uclk_i                      : in std_logic;
    nfip_rst_i                  : in std_logic;
    rate_i                      : in std_logic_vector (1 downto 0);
    subs_i                      : in std_logic_vector (7 downto 0);
    p3_lgth_i                   : in std_logic_vector (2 downto 0);
    slone_i                     : in std_logic;
    nostat_i                    : in std_logic;
    tx_byte_request_p_i         : in std_logic;
    rx_fss_received_p_i         : in std_logic;
    rx_crc_or_manch_wrong_p_i   : in std_logic;
    rx_byte_i                   : in std_logic_vector (7 downto 0);
    rx_byte_ready_p_i           : in std_logic;
    rx_fss_crc_fes_manch_ok_p_i : in std_logic;
  -----------------------------------------------------------------
    tx_byte_request_accept_p_o  : out std_logic;
    tx_last_byte_p_o            : out std_logic;
    tx_start_p_o                : out std_logic;
    prod_cons_byte_index_o      : out std_logic_vector (7 downto 0);
    prod_data_lgth_o            : out std_logic_vector (7 downto 0);
    rx_rst_p_o                  : out std_logic;
    var_o                       : out t_var);
  -----------------------------------------------------------------
  end component WF_engine_control;



---------------------------------------------------------------------------------------------------
  component WF_reset_unit
  port (
    uclk_i              : in std_logic;
    wb_clk_i            : in std_logic;
    rstin_a_i           : in std_logic;
    rstpon_a_i          : in std_logic;
    rate_i              : in std_logic_vector (1 downto 0);
    rst_i               : in std_logic;
    rst_nFIP_and_FD_p_i : in std_logic;
    assert_RSTON_p_i    : in std_logic;
  -----------------------------------------------------------------
    wb_rst_o            : out std_logic;
    nFIP_rst_o          : out std_logic;
    rston_o             : out std_logic;
    fd_rstn_o           : out std_logic);
  -----------------------------------------------------------------
  end component WF_reset_unit;



---------------------------------------------------------------------------------------------------
  component WF_DualClkRAM_clka_rd_clkb_wr
  generic (g_ram_data_lgth : integer;
           g_ram_addr_lgth : integer);
  port (
    clk_porta_i      : in std_logic;
    addr_porta_i     : in std_logic_vector (g_ram_addr_lgth - 1 downto 0);
    clk_portb_i      : in std_logic;
    addr_portb_i     : in std_logic_vector (g_ram_addr_lgth - 1 downto 0);
    data_portb_i     : in std_logic_vector (g_ram_data_lgth - 1 downto 0);
    write_en_portb_i : in std_logic;
  -----------------------------------------------------------------
    data_porta_o     : out std_logic_vector (g_ram_data_lgth -1 downto 0));
  -----------------------------------------------------------------
  end component WF_DualClkRAM_clka_rd_clkb_wr;



---------------------------------------------------------------------------------------------------
  component DualClkRam is
  port (
    CLKA   : in std_logic;
    ADDRA  : in std_logic_vector (8 downto 0);
    DINA   : in std_logic_vector (7 downto 0);
    RWA    : in std_logic;
    CLKB   : in std_logic;
    ADDRB  : in std_logic_vector (8 downto 0);
    DINB   : in std_logic_vector (7 downto 0);
    RWB    : in std_logic;
    RESETn : in std_logic;
  -----------------------------------------------------------------
    DOUTA  : out std_logic_vector (7 downto 0);
    DOUTB  : out std_logic_vector (7 downto 0));
  -----------------------------------------------------------------
  end component DualClkRam;



---------------------------------------------------------------------------------------------------
  component  WF_crc
  port (
    uclk_i             : in std_logic;
    nfip_rst_i         : in std_logic;
    start_crc_p_i      : in std_logic;
    data_bit_i         : in std_logic;
    data_bit_ready_p_i : in std_logic;
  -----------------------------------------------------------------
    crc_ok_p_o         : out std_logic;
    crc_o              : out std_logic_vector (c_CRC_POLY_LGTH - 1 downto 0));
  -----------------------------------------------------------------
  end component WF_crc;



---------------------------------------------------------------------------------------------------
  component WF_manch_encoder is
  generic (g_word_lgth :  natural);
  port (
    word_i       : in std_logic_vector (g_word_lgth-1 downto 0);
  -----------------------------------------------------------------
    word_manch_o : out std_logic_vector ((2*g_word_lgth)-1 downto 0));
  -----------------------------------------------------------------
  end component WF_manch_encoder;



---------------------------------------------------------------------------------------------------
  component WF_rx_manch_code_check is
  port (
    uclk_i                : in std_logic;
    nfip_rst_i            : in std_logic;
    serial_input_signal_i : in std_logic;
    sample_bit_p_i        : in std_logic;
    sample_manch_bit_p_i  : in std_logic;
  -----------------------------------------------------------------
    manch_code_viol_p_o   : out std_logic);
  -----------------------------------------------------------------
  end component WF_rx_manch_code_check;



---------------------------------------------------------------------------------------------------
  component WF_rx_deglitcher
  port (
    uclk_i                     : in std_logic;
    nfip_rst_i                 : in std_logic;
    fd_rxd_a_i                 : in std_logic;
  -----------------------------------------------------------------
    fd_rxd_filtered_o          : out std_logic;
    fd_rxd_filtered_edge_p_o   : out std_logic;
    fd_rxd_filtered_f_edge_p_o : out std_logic);
  -----------------------------------------------------------------
  end component WF_rx_deglitcher;



---------------------------------------------------------------------------------------------------
  component WF_status_bytes_gen
  port (
    uclk_i                  : in std_logic;
    slone_i                 : in std_logic;
    nfip_rst_i              : in std_logic;
    fd_wdgn_a_i             : in std_logic;
    fd_txer_a_i             : in std_logic;
    var1_acc_a_i            : in std_logic;
    var2_acc_a_i            : in std_logic;
    var3_acc_a_i            : in std_logic;
    var1_rdy_i              : in std_logic;
    var2_rdy_i              : in std_logic;
    var3_rdy_i              : in std_logic;
    nfip_status_r_tler_p_i  : in std_logic;
    nfip_status_r_fcser_p_i : in std_logic;
    rst_status_bytes_p_i    : in std_logic;
  -----------------------------------------------------------------
    u_cacer_o               : out std_logic;
    u_pacer_o               : out std_logic;
    r_tler_o                : out std_logic;
    r_fcser_o               : out std_logic;
    nFIP_status_byte_o      : out std_logic_vector (7 downto 0);
    mps_status_byte_o       : out std_logic_vector (7 downto 0));
  -----------------------------------------------------------------
  end component WF_status_bytes_gen;



---------------------------------------------------------------------------------------------------
  component WF_bits_to_txd
  port (
    uclk_i              : in std_logic;
    nfip_rst_i          : in std_logic;
    txd_bit_index_i     : in unsigned (4 downto 0);
    data_byte_manch_i   : in std_logic_vector (15 downto 0);
    crc_byte_manch_i    : in std_logic_vector (31 downto 0);
    sending_fss_i       : in std_logic;
    sending_data_i      : in std_logic;
    sending_crc_i       : in std_logic;
    sending_fes_i       : in std_logic;
    stop_transmission_i : in std_logic;
    tx_clk_p_i          : in std_logic;
  -----------------------------------------------------------------
    txd_o               : out std_logic;
    tx_enable_o         : out std_logic);
  -----------------------------------------------------------------
  end component WF_bits_to_txd;



---------------------------------------------------------------------------------------------------
  component nanofip
  port (
    rate_i       : in  std_logic_vector (1 downto 0);
    subs_i       : in  std_logic_vector (7 downto 0);
    m_id_i       : in  std_logic_vector (3 downto 0);
    c_id_i       : in  std_logic_vector (3 downto 0);
    p3_lgth_i    : in  std_logic_vector (2 downto 0);
    fd_wdgn_a_i  : in  std_logic;
    fd_txer_a_i  : in  std_logic;
    fd_rxcdn_i   : in  std_logic;
    fd_rxd_i     : in  std_logic;
    uclk_i       : in  std_logic;
    slone_i      : in  std_logic;
    nostat_i     : in  std_logic;
    rstin_i      : in  std_logic;
    rstpon_i     : in std_logic;
    var1_acc_a_i : in  std_logic;
    var2_acc_a_i : in  std_logic;
    var3_acc_a_i : in  std_logic;
    wb_clk_i     : in  std_logic;
    dat_i        : in  std_logic_vector (15 downto 0);
    adr_i        : in  std_logic_vector (9 downto 0);
    rst_i        : in  std_logic;
    stb_i        : in  std_logic;
    cyc_i        : in std_logic;
    we_i         : in  std_logic;
  -----------------------------------------------------------------
    rston_o      : out std_logic;
    s_id_o       : out std_logic_vector (1 downto 0);
    fd_rstn_o    : out std_logic;
    fd_txena_o   : out std_logic;
    fd_txck_o    : out std_logic;
    fd_txd_o     : out std_logic;
    var1_rdy_o   : out std_logic;
    var2_rdy_o   : out std_logic;
    var3_rdy_o   : out std_logic;
    u_cacer_o    : out std_logic;
    u_pacer_o    : out std_logic;
    r_tler_o     : out std_logic;
    r_fcser_o    : out std_logic;
    ack_o        : out std_logic;
    dat_o        : out std_logic_vector (15 downto 0));
  -----------------------------------------------------------------
  end component nanofip;



---------------------------------------------------------------------------------------------------
  component WF_model_constr_decoder
  port (
    uclk_i          : in std_logic;
    nfip_rst_i      : in std_logic;
    model_id_i      : in std_logic_vector (3 downto 0);
    constr_id_i     : in std_logic_vector (3 downto 0);
  -----------------------------------------------------------------
    select_id_o     : out std_logic_vector (1 downto 0);
    model_id_dec_o  : out std_logic_vector (7 downto 0);
    constr_id_dec_o : out std_logic_vector (7 downto 0));
  -----------------------------------------------------------------
  end component WF_model_constr_decoder;



---------------------------------------------------------------------------------------------------
  component WF_decr_counter is
  generic (g_counter_lgth :  natural := 5);
  port (
    uclk_i            : in std_logic;
    nfip_rst_i        : in std_logic;
    counter_top       : in unsigned (g_counter_lgth-1 downto 0);
    counter_load_i    : in std_logic;
    counter_decr_p_i  : in std_logic;
  -----------------------------------------------------------------
    counter_o         : out unsigned (g_counter_lgth-1 downto 0);
    counter_is_zero_o : out std_logic);
  -----------------------------------------------------------------
  end component WF_decr_counter;



---------------------------------------------------------------------------------------------------
  component WF_incr_counter is
  generic (g_counter_lgth :  natural := 8);
  port (
    uclk_i            : in std_logic;
    reinit_counter_i  : in std_logic;
    incr_counter_i    : in std_logic;
  -----------------------------------------------------------------
    counter_o         : out unsigned (g_counter_lgth-1 downto 0);
    counter_is_full_o : out std_logic);
  -----------------------------------------------------------------
  end component WF_incr_counter;



---------------------------------------------------------------------------------------------------
  component WF_prod_data_lgth_calc is
  port (
    slone_i            : in std_logic;
    nostat_i           : in std_logic;
    p3_lgth_i          : in std_logic_vector (2 downto 0);
    var_i              : in t_var;
  -----------------------------------------------------------------
    prod_data_lgth_o   : out std_logic_vector (7 downto 0));
  -----------------------------------------------------------------
  end component WF_prod_data_lgth_calc;



---------------------------------------------------------------------------------------------------
  component WF_cons_outcome is
  port (
    uclk_i                      : in std_logic;
    slone_i                     : in std_logic;
    nfip_rst_i                  : in std_logic;
    subs_i                      : in std_logic_vector (7 downto 0);
    rx_fss_crc_fes_manch_ok_p_i : in std_logic;
    rx_crc_or_manch_wrong_p_i   : in std_logic;
    var_i                       : in t_var;
    rx_byte_index_i             : in std_logic_vector (7 downto 0);
    cons_ctrl_byte_i            : in std_logic_vector (7 downto 0);
    cons_pdu_byte_i             : in std_logic_vector (7 downto 0);
    cons_lgth_byte_i            : in std_logic_vector (7 downto 0);
    cons_var_rst_byte_1_i       : in std_logic_vector (7 downto 0);
    cons_var_rst_byte_2_i       : in std_logic_vector (7 downto 0);
  -----------------------------------------------------------------
    var1_rdy_o                  : out std_logic;
    var2_rdy_o                  : out std_logic;
    nfip_status_r_tler_p_o      : out std_logic;
    assert_rston_p_o            : out std_logic;
    rst_nfip_and_fd_p_o         : out std_logic);
  -----------------------------------------------------------------
  end component WF_cons_outcome;



---------------------------------------------------------------------------------------------------
component WF_prod_permit is
  port (
    uclk_i     : in std_logic;
    nfip_rst_i : in std_logic;
    var_i      : in t_var;
  -----------------------------------------------------------------
    var3_rdy_o : out std_logic);
  -----------------------------------------------------------------
end component WF_prod_permit;



---------------------------------------------------------------------------------------------------
component WF_wb_controller is
  port (
    wb_clk_i        : in std_logic;
    wb_rst_i        : in std_logic;
    wb_stb_i        : in std_logic;
    wb_cyc_i        : in std_logic;
    wb_we_i         : in std_logic;
    wb_adr_id_i     : in  std_logic_vector (2 downto 0);
  -----------------------------------------------------------------
    wb_ack_prod_p_o : out std_logic;
    wb_ack_p_o      : out std_logic);
  -----------------------------------------------------------------
end component WF_wb_controller;



---------------------------------------------------------------------------------------------------
  function f_manch_encoder (word_i :std_logic_vector) return std_logic_vector;



end WF_package;


--=================================================================================================
--!                                        package body
--=================================================================================================
package body WF_package is


---------------------------------------------------------------------------------------------------
--!@brief Function for the encoding of a word to its Manchester 2 (manch.) equivalent.
--! Each bit "1" is replaced by "10" and each bit "0" by "01".
--! The manch. encoding ensures that there is one transition for each bit.
--!   o bit            :    "0"           "1"
--!   o manch. encoded :   "0 1"         "1 0"
--!   o scheme         :    _|-           -|_

  function f_manch_encoder (word_i : std_logic_vector) return std_logic_vector is

  variable word_manch_o : std_logic_vector ((2*word_i'length) -1 downto 0);

  begin
    for I in word_i'range loop
      word_manch_o (I*2)   := not word_i(I);
      word_manch_o (I*2+1) := word_i(I);
    end loop;
  -----------------------------------------------------------------
    return word_manch_o;
  -----------------------------------------------------------------
  end function;



end WF_package;
--=================================================================================================
--                                         package end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------