--_________________________________________________________________________________________________
--                                                                                                |
--                                        |The nanoFIP|                                           |
--                                                                                                |
--                                        CERN,BE/CO-HT                                           |
--________________________________________________________________________________________________|
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--! @file nanofip.vhd                                                                             |
---------------------------------------------------------------------------------------------------

--! standard library
library IEEE;

--! standard packages
use IEEE.STD_LOGIC_1164.all;  --! std_logic definitions
use IEEE.NUMERIC_STD.all;     --! conversion functions

--! specific packages
use work.WF_PACKAGE.all;      --! definitions of types, constants, entities


--------------------------------------------------------------------------------------------------- 
--                                                                                               --
--                                              nanoFIP                                          --
--                                                                                               --
--------------------------------------------------------------------------------------------------- 
--
--
--! @brief    
--! The nanoFIP is an FPGA component implementing the WorldFIP protocol that can be used in field
--! devices. The nanoFIP is designed to be radiation tolerant by using different single event upset
--! mitigation techniques such as Triple Module Redundancy and several reset possibilities. The
--! nanoFIP design is to be implemented in an Actel ProASIC3 Flash family FPGA that is preserving
--! its configuration and has high tolerance to total dose radiation effects. The device is used
--! in conjunction with a FIELDRIVE chip and FIELDTR insulating transformer, both available from
--! the company ALSTOM.
--!
--! In the WorldFIP protocol, the master of the bus, Bus Arbitrer (BA) initiates all the activity
--! in the bus. The BA is broadcasting ID_DAT frames, requesting for a particular variable, to all
--! the stations connected to the same network segment. Figure 1 shows the structure of an ID_DAT
--! frame:
--!                   ___________ ______  _______ ______  ___________ _______
--!                  |____FSS____|_Ctrl_||__Var__|_Subs_||____FCS____|__FES__|
--! 
--!                           Figure 1 : ID_DAT frame structure
--!
--! nanoFIP is handling the following set of variables addressed by:
--!   o ID_DAT Var_Subs = 14_xy: for the presence variable
--!   o ID_DAT Var_Subs = 10_xy: for the identification variable
--!   o ID_DAT Var_Subs = 05_xy: for the consumed variable of any length up to 124 bytes
--!   o ID_DAT Var_Subs = 91_..: for the broadcast consumed variable of any length up to 124 bytes
--!   o ID_DAT Var_Subs = 06_xy: for the produced variable of a user-settable length (P3_LGTH)
--!   o ID_DAT Var_Subs = E0_..: for the broadcast consumed reset variable
--!
--! After a 14xy or a 10xy or a 06xy ID_DAT, if nanoFIP's address (SUBS) is xy, it will respond
--! with a "produced" RP_DAT frame, containing the variable requested. Figure 2 shows the structure
--! of a RP_DAT frame:
--!                ___________ ______  _____________________  ___________ _______
--!               |____FSS____|_Ctrl_||_____...-Data..._____||____FCS____|__FES__|
--!
--!                            Figure 2 : RP_DAT frame structure
--!
--! After a 05xy ID_DAT, if nanoFIP's address (SUBS) is xy, or after a broadcast ID_DAT 91..h or
--! E0..h, nanoFIP will "consume" the incoming RP_DAT frame.
--!
--! Regarding the interface with the user, nanoFIP provides:
--!   o variable data transfer over an integrated memory accessible with an 8-bit WISHBONE
--!     System-On-Chip interconnection
--!   o possibility of stand-alone mode with a 16 bits input bus and 16 bits output bus, without
--!     the need to transfer data to or from the memory
--!   o separate data valid outputs for each variable (consumed and produced)
--!
--! nanoFIP provides several reset possibilities:
--!  o External reset input pin, RSTIN, activated by the user logic
--!  o External reset input pin, RST_I, activated by the user, that resets only the WISHBONE logic
--!  o Addressed reset by the reset broadcast consumed variable (E0..h),
--!    validated by station address as data
--!
--! nanoFIP also provides resets to the user and to the FIELDRIVE:
--!  o Reset output available to external logic (RSTON) by the reset broadcast consumed variable
--!    (E0..h), validated by station address as data
--!  o FIELDRIVE reset output (FD_RSTN) by the reset broadcast consumed variable (E0..h),
--!    validated by station address as data
--! 
--! nanoFIP's main building blocks are (Figure 3):
--!  o WF_inputs_synchronizer : for the synchronization of all the input signals with the user
--!    or the WISHBONE clock.
--!  o WF_reset_unit          : for the treatment of the reset input signals and the generation
--!    of the reset outputs.
--!  o WF_tx_rx_osc           : for the generation of the clocks used by the transmitter and
--!    receiver for the data serialization and deserialization.
--!  o WF_consumption         : for the processing of consumed variables, from the deserialization
--!    to the bytes storage and validation.     
--!  o WF_production          : for the processing of produced variables, from the bytes
--!    retrieval to the serialization.
--!  o WF_engine_control      : for the processing of the ID_DAT frames and the coordination of the
--!    WF_consumption and WF_production units. 
--!  o WF_model_constr_dec    : for the decoding of the WorldFIP settings M_ID and C_ID and the
--!    generation of the S_ID.
--!  o WF_wb_controller       : for the handling of the "User Interface WISHBONE Slave" control
--!                             signals.
--!
--!                 _____________     __________________________     _____________                  
--!                |             |   |                          |   |             |
--!                |             |   |       WF_tx_rx_osc       |   |             |
--!                |             |   |                          |   |             |
--!                |             |   |__________________________|   |             |
--!                |             |                                  |             |
--!                | WF_inputs_  |    ___________   ____________    |
--!                | synchroniser|   |           | |            |   |             |
--!                |             |   |           | |            |   |             |
--!                |             |   |           | |            |   |             |
--!                |             |   |           | |            |   |             |
--!                |             |   |           | |            |   |             |
--!                |             |   |           | |            |   |             |
--!                |             |   |           | |            |   |  WF_engine  |
--!                |_____________|   |           | |            |   |  _control   |
--!                                  |           | |            |   |             |
--!                 _____________    |    WF_    | |     WF_    |   |             |
--!                |             |   |consumption| | production |   |             |
--!                |             |   |           | |            |   |             |
--!                |   WF_reset  |   |           | |            |   |             |
--!                |   _unit     |   |           | |            |   |             |
--!                |             |   |           | |            |   |             |
--!                |_____________|   |           | |            |   |             |
--!                                  |           | |            |   |             |
--!                 _____________    |           | |            |   |             |
--!                |             |   |           | |            |   |             |
--!                |             |   |___________| |____________|   |             |
--!                |  WF_model_  |                                  |             |
--!                | constr_dec  |    ___________________________   |             |
--!                |             |   |     WF_wb_controller      |  |             |
--!                |_____________|   |___________________________|  |_____________|
--!                                    
--!                                Figure 3: nanoFIP block diagram
--!
--! The design is based on the NanoFIP functional specification v1.3 document, available at:
--! http://www.ohwr.org/projects/cern-fip/documents \n
--! Complete information about this project at: http://www.ohwr.org/projects/cern-fip
--
--
--! @author    Erik Van der Bij      (Erik.Van.der.Bij@cern.ch)     \n
--!            Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)\n
--!            Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)    \n
--        
--
--! @date      15/01/2011
--
--
--! @version   v0.04
--
--
--! @details\n 
--
--!   \n<b>Dependencies:</b>   \n
--!            WF_inputs_synchronizer \n
--!            WF_reset_unit          \n
--!            WF_model_constr_dec    \n
--!            WF_tx_rx_osc           \n
--!            WF_consumption         \n
--!            WF_production          \n
--!            WF_engine_control      \n
--
--
--!   \n<b>Modified by:</b>\n
--!            Pablo Alvarez Sanchez \n
--!            Evangelia Gousiou     \n
--
---------------------------------------------------------------------------------------------------
--
--!   \n\n<b>Last changes:</b>\n
--!     ->  30/06/2009  v0.010  EB  First version \n
--!     ->  06/07/2009  v0.011  EB  Dummy blocks  \n
--!     ->  07/07/2009  v0.011  EB  Comments      \n
--!     ->  15/09/2009  v0.v2   PA  
--!     ->  09/12/2010  v0.v3   EG  Logic removed (new unit inputs_synchronizer added)
--!     ->  7/01/2011   v0.04   EG  major restructuring; only 7 units on top level 
--!     ->  20/01/2011  v0.05   EG  new unit WF_wb_controller(removes the or gate from top level)
--
--------------------------------------------------------------------------------------------------- 
--
--! @todo 
--
--------------------------------------------------------------------------------------------------- 

---/!\----------------------------/!\----------------------------/!\-------------------------/!\---
--                                    Synplify Premier Warnings                                  --
-- -- --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --
--  "W MT420 Found inferred clock nanofip|wclk_i"; "W MT420 Found inferred clock nanofip|uclk_i" --
-- The wclk and uclk are the nanoFIP's input clocks.                                             --
---------------------------------------------------------------------------------------------------


--=================================================================================================
--!                           Entity declaration for nanoFIP
--=================================================================================================

entity nanofip is

  port (

--INPUTS

  -- WorldFIP settings

  c_id_i     : in  std_logic_vector (3 downto 0); --! Constructor identification settings
  m_id_i     : in  std_logic_vector (3 downto 0); --! Model identification settings
  p3_lgth_i  : in  std_logic_vector (2 downto 0); --! Produced variable data length
  rate_i     : in  std_logic_vector (1 downto 0); --! Bit rate
  subs_i     : in  std_logic_vector (7 downto 0); --! Subscriber number coding (station address)


  --  FIELDRIVE 

  fd_rxcdn_i : in  std_logic;                     --! Reception activity detection, active low
  fd_rxd_i   : in  std_logic;                     --! Receiver data
  fd_txer_i  : in  std_logic;                     --! Transmitter error
  fd_wdgn_i  : in  std_logic;                     --! Watchdog on transmitter

 
  --  User Interface, General signals
 
  nostat_i   : in  std_logic;                     --! No NanoFIP status with produced data

  rstin_i    : in  std_logic;                     --! Initialisation control, active low
                                                  --! Resets nanoFIP & the FIELDRIVE

  rstpon_i   : in std_logic;                      --! Power On Reset, active low

  slone_i    : in  std_logic;                     --! Stand-alone mode
  uclk_i     : in  std_logic;                     --! 40 MHz clock


  --  User Interface, NON-WISHBONE

  var1_acc_i : in  std_logic;                    --! Signals that the user logic is accessing var 1
  var2_acc_i : in  std_logic;                    --! Signals that the user logic is accessing var 2
  var3_acc_i : in  std_logic;                    --! Signals that the user logic is accessing var 3


  --  User Interface, WISHBONE Slave
  wclk_i     : in  std_logic;                    --! WISHBONE clock; may be independent of uclk
  adr_i      : in  std_logic_vector(9 downto 0); --! WISHBONE address
  cyc_i      : in std_logic;                     --! WISHBONE cycle 

  dat_i      : in  std_logic_vector(15 downto 0);--! dat_i(7 downto 0) : WISHBONE data in, memory mode
                                                 --! dat_i(15 downto 0): data in, stand-alone mode

  rst_i      : in  std_logic;                    --! WISHBONE reset
                                                 --! Does not reset other internal logic

  stb_i      : in  std_logic;                    --! WISHBONE strobe
  we_i       : in  std_logic;                    --! WISHBONE write enable


-- OUTUTS

  -- WorldFIP settings

  s_id_o     : out std_logic_vector(1 downto 0); --! Identification selection
 

  --  FIELDRIVE

  fd_rstn_o  : out std_logic;                    --! Initialisation control, active low
  fd_txck_o  : out std_logic;                    --! Line driver half bit clock
  fd_txd_o   : out std_logic;                    --! Transmitter data
  fd_txena_o:  out std_logic;                    --! Transmitter enable


  --  User Interface, General signals
 
  rston_o    : out std_logic;                    --! Reset output, active low


  --  User Interface, NON-WISHBONE

  r_fcser_o  : out std_logic;                    --! nanoFIP status byte, bit 5
  r_tler_o   : out std_logic;                    --! nanoFIP status byte, bit 4
  u_cacer_o  : out std_logic;                    --! nanoFIP status byte, bit 2
  u_pacer_o  : out std_logic;                    --! nanoFIP status byte, bit 3

  var1_rdy_o : out std_logic;                    --! Signals new data received & can safely be read
  var2_rdy_o : out std_logic;                    --! Signals new data received & can safely be read
  var3_rdy_o : out std_logic;                    --! Signals that the var 3 can safely be written


  --  User Interface, WISHBONE Slave

  dat_o      : out std_logic_vector(15 downto 0);--! dat_o(7 downto 0) : WISHBONE data out, memory mode
                                                 --! dat_o(15 downto 0): data out, stand-alone mode

  ack_o      : out std_logic                     --! WISHBONE acknowledge

    );

end entity nanofip;


--=================================================================================================
--!                                   architecture declaration
--=================================================================================================

architecture struc of nanofip is

---------------------------------------------------------------------------------------------------
--                                    Triple Module Redundancy                                   --
---------------------------------------------------------------------------------------------------
 attribute syn_radhardlevel          : string;                                                   --
 attribute syn_radhardlevel of struc : architecture is "tmr";                                    --
---------------------------------------------------------------------------------------------------


  component CLKBUF
    port (PAD : in std_logic;
          Y   : out std_logic);
  end component;


  signal s_rst, s_rx_byte_ready, s_start_prod_p, s_rst_rx_osc, s_prod_request_byte_p   : std_logic;
  signal s_prod_last_byte_p                                                            : std_logic;
  signal s_rstin_synch, s_slone_synch, s_nostat_synch, s_fd_wdgn_synch, s_fd_txer_synch: std_logic;
  signal s_fss_crc_fes_manch_ok_p, s_cons_fss_decoded_p                                : std_logic;
  signal s_crc_wrong_p, s_reset_nFIP_and_FD_p, s_rx_manch_clk_p, s_rx_bit_clk_p        : std_logic;
  signal s_var1_access_synch, s_var2_access_synch, s_var3_access_synch, s_wb_stb_synch : std_logic;
  signal s_var1_rdy, s_var2_rdy, s_var3_rdy, s_assert_RSTON_p, s_wb_ack_prod           : std_logic;
  signal s_rst_rx_unit_p, s_nfip_status_r_tler, s_signif_edge_window , s_wb_we_synch   : std_logic;
  signal s_fd_rxd_synch, s_fd_rxd_edge_p, s_fd_rxd_r_edge_p, s_fd_rxd_f_edge_p         : std_logic;
  signal s_wb_stb_r_edge, s_adjac_bits_window, s_wb_cyc_synch, s_prod_byte_ready_p     : std_logic;
  signal s_var_from_control                                                            : t_var;
  signal s_data_length_from_control, s_subs_synch                  : std_logic_vector (7 downto 0);
  signal s_rx_byte, s_model_id_dec, s_constr_id_dec                : std_logic_vector (7 downto 0);
  signal s_cons_prod_byte_index_from_control                       : std_logic_vector (7 downto 0);
  signal s_slone_dati_synch                                        : std_logic_vector(15 downto 0);
  signal s_m_id_synch, s_c_id_synch                                : std_logic_vector (3 downto 0);
  signal s_p3_lgth_synch                                           : std_logic_vector (2 downto 0);
  signal s_rate_synch                                              : std_logic_vector (1 downto 0);
  signal s_tx_clk_p_buff                       : std_logic_vector (c_TX_CLK_BUFF_LGTH -1 downto 0);


--=================================================================================================
--                                       architecture begin                                        
--=================================================================================================  
begin


---------------------------------------------------------------------------------------------------
--                                     WF_inputs_synchronizer                                    --
---------------------------------------------------------------------------------------------------
  synchronizer: WF_inputs_synchronizer
  port map(
    uclk_i            => uclk_i,
    wb_clk_i          => wclk_i,
    nfip_rst_i        => s_rst, 
    rstin_a_i         => rstin_i,
    wb_rst_a_i        => rst_i,
    slone_a_i         => slone_i,
    nostat_a_i        => nostat_i,
    fd_wdgn_a_i       => fd_wdgn_i,
    fd_txer_a_i       => fd_txer_i,
    fd_rxd_a_i        => fd_rxd_i,
    fd_rxcdn_a_i      => fd_rxcdn_i, 
    wb_cyc_a_i        => cyc_i,
    wb_we_a_i         => we_i,
    wb_stb_a_i        => stb_i,
    var1_access_a_i   => var1_acc_i,
    var2_access_a_i   => var2_acc_i,
    var3_access_a_i   => var3_acc_i,
    dat_a_i           => dat_i,
    rate_a_i          => rate_i,
    subs_a_i          => subs_i,
    m_id_a_i          => m_id_i,
    c_id_a_i          => c_id_i,
    p3_lgth_a_i       => p3_lgth_i,
    ---------------------------------------------------------
    rstin_o           => s_rstin_synch,
    slone_o           => s_slone_synch,
    nostat_o          => s_nostat_synch,
    fd_wdgn_o         => s_fd_wdgn_synch,
    fd_txer_o         => s_fd_txer_synch,
    fd_rxd_o          => s_fd_rxd_synch,
    fd_rxd_edge_p_o   => s_fd_rxd_edge_p,
    fd_rxd_r_edge_p_o => s_fd_rxd_r_edge_p,
    fd_rxd_f_edge_p_o => s_fd_rxd_f_edge_p, 
    wb_cyc_o          => s_wb_cyc_synch,
    wb_we_o           => s_wb_we_synch,
    wb_stb_o          => s_wb_stb_synch,
    wb_stb_r_edge_o   => s_wb_stb_r_edge,
    var1_access_o     => s_var1_access_synch,
    var2_access_o     => s_var2_access_synch,
    var3_access_o     => s_var3_access_synch,
    slone_dati_o      => s_slone_dati_synch,
    rate_o            => s_rate_synch,
    subs_o            => s_subs_synch,
    m_id_o            => s_m_id_synch,
    c_id_o            => s_c_id_synch,
    p3_lgth_o         => s_p3_lgth_synch
    ---------------------------------------------------------
      );



---------------------------------------------------------------------------------------------------
--                                         WF_reset_unit                                         --
---------------------------------------------------------------------------------------------------
  reset_unit : WF_reset_unit 
    port map(
      uclk_i                => uclk_i,
      rstin_i               => s_rstin_synch,
      rstpon_i              => rstpon_i,
      rate_i                => s_rate_synch,
      var_i                 => s_var_from_control,
      rst_nFIP_and_FD_p_i   => s_reset_nFIP_and_FD_p,
      assert_RSTON_p_i      => s_assert_RSTON_p,
    ---------------------------------------------------------
      rston_o               => rston_o,
      nFIP_rst_o            => s_rst, 
      fd_rstn_o             => fd_rstn_o  
    ---------------------------------------------------------
      );



---------------------------------------------------------------------------------------------------
--                                          WF_rx_tx_osc                                         --
---------------------------------------------------------------------------------------------------
  rx_tx_osc :WF_rx_tx_osc
    generic map(C_PERIODS_COUNTER_LENGTH => 11,
                c_TX_CLK_BUFF_LGTH       => 4)
    port map(
      uclk_i                  => uclk_i,
      nfip_rst_i              => s_rst, 
      rxd_edge_i              => s_fd_rxd_edge_p,      
      rst_rx_osc_i            => s_rst_rx_osc, 
      rate_i                  => s_rate_synch,  
    ---------------------------------------------------------
      tx_clk_p_buff_o         => s_tx_clk_p_buff,
      tx_clk_o                => fd_txck_o,
      rx_manch_clk_p_o        => s_rx_manch_clk_p,
      rx_bit_clk_p_o          => s_rx_bit_clk_p, 
      rx_signif_edge_window_o => s_signif_edge_window,
      rx_adjac_bits_window_o  => s_adjac_bits_window
    ---------------------------------------------------------
      );



---------------------------------------------------------------------------------------------------
--                                         WF_consumption                                        --
---------------------------------------------------------------------------------------------------
  Consumption: WF_consumption
  port map(
    uclk_i                  => uclk_i,
    slone_i                 => slone_i,
    nfip_rst_i              => s_rst,
    subs_i                  => s_subs_synch,
    fd_rxd_i                => s_fd_rxd_synch,
    fd_rxd_r_edge_p_i       => s_fd_rxd_r_edge_p,
    fd_rxd_f_edge_p_i       => s_fd_rxd_f_edge_p,
    wb_clk_i                => wclk_i,
    wb_adr_i                => adr_i (8 downto 0),
    var_i                   => s_var_from_control,
    byte_index_i            => s_cons_prod_byte_index_from_control,
    rst_rx_unit_p_i         => s_rst_rx_unit_p,
    signif_edge_window_i    => s_signif_edge_window,
    adjac_bits_window_i     => s_adjac_bits_window,
    sample_bit_p_i          => s_rx_bit_clk_p,
    sample_manch_bit_p_i    => s_rx_manch_clk_p,
    ---------------------------------------------------------
    var1_rdy_o              => s_var1_rdy,
    var2_rdy_o              => s_var2_rdy,
    data_o                  => dat_o,
    byte_o                  => s_rx_byte,
    byte_ready_p_o          => s_rx_byte_ready,
    fss_received_p_o        => s_cons_fss_decoded_p, 
    crc_wrong_p_o           => s_crc_wrong_p,
    fss_crc_fes_manch_ok_p_o => s_fss_crc_fes_manch_ok_p,
    nfip_status_r_tler_o    => s_nfip_status_r_tler,
    assert_rston_p_o        => s_assert_RSTON_p,
    rst_nfip_and_fd_p_o     => s_reset_nFIP_and_FD_p,
    rst_rx_osc_o            => s_rst_rx_osc
    ---------------------------------------------------------
       );



---------------------------------------------------------------------------------------------------
--                                         WF_production                                         --
---------------------------------------------------------------------------------------------------
  Production: WF_production
  port map(
    uclk_i                  => uclk_i,
    slone_i                 => slone_i,
    nostat_i                => nostat_i,
    nfip_rst_i              => s_rst,
    wb_clk_i                => wclk_i,
    wb_data_i               => dat_i(7 downto 0),
    wb_adr_i                => adr_i(8 downto 0),
    wb_ack_prod_p_i         => s_wb_ack_prod,  
    slone_data_i            => s_slone_dati_synch,
    var1_acc_i              => s_var1_access_synch,
    var2_acc_i              => s_var2_access_synch,
    var3_acc_i              => s_var3_access_synch,
    fd_txer_i               => s_fd_txer_synch,
    fd_wdgn_i               => s_fd_wdgn_synch,
    var_i                   => s_var_from_control,
    data_length_i           => s_data_length_from_control,
    byte_index_i            => s_cons_prod_byte_index_from_control,
    start_prod_p_i          => s_start_prod_p,
    byte_request_accept_p_i => s_prod_byte_ready_p,
    last_byte_p_i           => s_prod_last_byte_p,
    nfip_status_r_tler_i    => s_nfip_status_r_tler,
    nfip_status_r_fcser_p_i => s_crc_wrong_p,
    var1_rdy_i              => s_var1_rdy,
    var2_rdy_i              => s_var2_rdy,
    tx_clk_p_buff_i         => s_tx_clk_p_buff,
    model_id_dec_i          => s_model_id_dec,
    constr_id_dec_i         => s_constr_id_dec,
    ---------------------------------------------------------
    byte_request_p_o        => s_prod_request_byte_p,
    tx_data_o               => fd_txd_o,
    tx_enable_o             => fd_txena_o,
    u_cacer_o               => u_cacer_o,
    u_pacer_o               => u_pacer_o,
    r_tler_o                => r_tler_o,
    r_fcser_o               => r_fcser_o,
    var3_rdy_o              => s_var3_rdy
    ---------------------------------------------------------
       );



---------------------------------------------------------------------------------------------------
--                                       WF_engine_control                                       --
---------------------------------------------------------------------------------------------------

  engine_control : WF_engine_control 
    generic map( c_QUARTZ_PERIOD => c_QUARTZ_PERIOD)

    port map(
      uclk_i                      => uclk_i,
      nfip_rst_i                   => s_rst, 
      tx_byte_request_p_i          => s_prod_request_byte_p, 
      rx_fss_received_p_i          => s_cons_fss_decoded_p,   
      rx_byte_i                    => s_rx_byte, 
      rx_byte_ready_p_i            => s_rx_byte_ready,
      rx_fss_crc_fes_manch_ok_p_i  => s_fss_crc_fes_manch_ok_p,
      rx_crc_wrong_p_i             => s_crc_wrong_p,
      rate_i                       => s_rate_synch,
      subs_i                       => s_subs_synch,
      p3_lgth_i                    => s_p3_lgth_synch, 
      slone_i                      => s_slone_synch, 
      nostat_i                     => s_nostat_synch, 
    ---------------------------------------------------------
      var_o                       => s_var_from_control,
      tx_start_prod_p_o           => s_start_prod_p , 
      tx_byte_request_accept_p_o  => s_prod_byte_ready_p, 
      tx_last_byte_p_o            => s_prod_last_byte_p, 
      prod_cons_byte_index_o      => s_cons_prod_byte_index_from_control,
      prod_data_length_o          => s_data_length_from_control,
      rst_rx_unit_p_o             => s_rst_rx_unit_p
    ---------------------------------------------------------
      );

      var1_rdy_o <= s_var1_rdy; 
      var2_rdy_o <= s_var2_rdy; 
      var3_rdy_o <= s_var3_rdy;



---------------------------------------------------------------------------------------------------
--                                    WF_model_constr_decoder                                    --
---------------------------------------------------------------------------------------------------
 model_constr_decoder : WF_model_constr_decoder 
  port map(
    uclk_i          => uclk_i,
    nfip_rst_i      => s_rst,
    model_id_i      => s_m_id_synch,
    constr_id_i     => s_c_id_synch,
    ---------------------------------------------------------
    select_id_o     => s_id_o,
    model_id_dec_o  => s_model_id_dec,
    constr_id_dec_o => s_constr_id_dec
    ---------------------------------------------------------
    );



---------------------------------------------------------------------------------------------------
--                                      WF_wb_controller                                      --
---------------------------------------------------------------------------------------------------
  WISHBONE_ack_generator: WF_wb_controller
  port map (
    wb_clk_i          => wclk_i,
    wb_rst_i          => rst_i,
    wb_cyc_i          => s_wb_cyc_synch,      
    wb_stb_r_edge_p_i => s_wb_stb_r_edge,
    wb_we_i           => s_wb_we_synch,
    wb_adr_id_i       => adr_i (9 downto 7),   
    ---------------------------------------------------------------
    wb_ack_prod_p_o   => s_wb_ack_prod,
    wb_ack_p_o        => ack_o
    ---------------------------------------------------------------  
      );


---------------------------------------------------------------------------------------------------



end architecture struc;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------