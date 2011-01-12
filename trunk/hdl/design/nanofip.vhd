---------------------------------------------------------------------------------------------------
--! @file nanofip.vhd
---------------------------------------------------------------------------------------------------

--! standard library
library IEEE;

--! standard packages
use IEEE.STD_LOGIC_1164.all;  --! std_logic definitions
use IEEE.NUMERIC_STD.all;     --! conversion functions

--! specific packages
use work.WF_PACKAGE.all;      --! definitions of types, constants, entities

-- library synplify;
-- use synplify.attributes.all;


-- syn_translate on;
-- library synplify;
-- syn_translate off;

--------------------------------------------------------------------------------------------------- 
--                                                                           --
--                                   nanofip                                 --
--                                                                           --
--                               CERN, BE/CO/HT                              --
--                                                                           --
--------------------------------------------------------------------------------------------------- 
--
-- unit name: nanofip (nanofip / nanofip)
--
--! @mainpage NanoFIP
--! <HR>
--! @section intro_sec Introduction
--! The NanoFIP is an FPGA component implementing the WorldFIP protocol that
--! can be used in field devices able to communicate at the three standard 
--! speeds. The NanoFIP, that is developed as part of the WorldFIP insourcing
--! project, is designed to be radiation tolerant by using different single 
--! event upset mitigation techniques such as triple module redundancy. \n\n
--! The NanoFIP design is to be implemented in an Actel ProASIC3 Flash family
--! FPGA that is supposedly to not loose its configuration or have serious
--! total dose effects or latchup problems. SEE still exists but should not 
--! give any problems because of SEE mitigation techniques used in the NanoFIP 
--! design. \n
--! \n
--! The device is used in conjunction with a FielDrive driver chip and FieldTR
--! insulating transformer, both available from the company ALSTOM. 
--!
--! <HR>
--! @section more_sec More information
--! This design is based on the <em>NanoFIP functional specification v1.2</em> 
--! http://www.ohwr.org/twiki/pub/OHR/CernFIP/WP3/cernfip_fspec1_2.pdf
--!
--! Complete information about this project at 
--! http://www.ohwr.org/twiki/bin/view/OHR/CernFIP/ \n\n
--! 
--! <HR>
--! @image html nanofip_image_1s.gif "Block diagram of the NanoFIP design"
--!
--! @author Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)
--
--! @date 07/07/2009
--
--! @version v0.1
--
--! @details 
--!
--! <b>Dependencies:</b>\n
--! 
--!
--! <b>References:</b>\n
--! 
--! 
--!
--! <b>Modified by:</b>\n
--! Author: Erik van der Bij
--------------------------------------------------------------------------------------------------- 
--! \n\n<b>Last changes:</b>\n
--! 30/06/2009  v0.010  EB  First version \n
--! 06/07/2009  v0.011  EB  Dummy blocks  \n
--! 07/07/2009  v0.011  EB  Comments      \n
--!
--------------------------------------------------------------------------------------------------- 
--! @todo Create entity \n
--
--------------------------------------------------------------------------------------------------- 

--! @brief Top level design file of nanofip

--=================================================================================================
--!                           Entity declaration for nanoFIP
--=================================================================================================

entity nanofip is

  port (
-- WorldFIP settings
    rate_i     : in  std_logic_vector (1 downto 0); --! Bit rate
    subs_i     : in  std_logic_vector (7 downto 0); --! Subscriber number coding.
    m_id_i     : in  std_logic_vector (3 downto 0); --! Model identification settings
    c_id_i     : in  std_logic_vector (3 downto 0); --! Constructor identification settings
    p3_lgth_i  : in  std_logic_vector (2 downto 0); --! Produced variable data length

    s_id_o     : out std_logic_vector (1 downto 0); --! Identification selection
 
--  FIELDRIVE connections

    fd_rxcdn_i : in  std_logic; --! Reception activity detection
    fd_rxd_i   : in  std_logic; --! Receiver data
    fd_wdgn_i  : in  std_logic; --! Watchdog on transmitter
    fd_txer_i  : in  std_logic; --! Transmitter error

    fd_txena_o:  out std_logic; --! Transmitter enable
    fd_txck_o  : out std_logic; --! Line driver half bit clock
    fd_txd_o   : out std_logic; --! Transmitter data
    fd_rstn_o  : out std_logic; --! Initialisation control, active low

 
--  USER INTERFACE, General signals
 
    uclk_i     : in  std_logic; --! 40 MHz clock
    slone_i    : in  std_logic; --! Stand-alone mode
    nostat_i   : in  std_logic; --! No NanoFIP status transmission
    rstin_i    : in  std_logic; --! Initialisation control, active low

    rston_o    : out std_logic; --! Reset output, active low


--  USER INTERFACE, NON WISHBONE

    var1_acc_i : in  std_logic; --! Variable 1 access
    var2_acc_i : in  std_logic; --! Variable 2 access
    var3_acc_i : in  std_logic; --! Variable 3 access

    var1_rdy_o : out std_logic; --! Variable 1 ready
    var2_rdy_o : out std_logic; --! Variable 2 ready
    var3_rdy_o : out std_logic; --! Variable 3 ready

    u_cacer_o  : out std_logic; --! nanoFIP status byte, bit 2
    u_pacer_o  : out std_logic; --! nanoFIP status byte, bit 3
    r_tler_o   : out std_logic; --! nanoFIP status byte, bit 4
    r_fcser_o  : out std_logic; --! nanoFIP status byte, bit 5

--  USER INTERFACE, WISHBONE Slave

    wclk_i   : in  std_logic;  --! WISHBONE clock. May be independent of UCLK.
    rst_i      : in  std_logic;  --! WISHBONE reset. Does not reset other internal logic.
    stb_i      : in  std_logic;  --! Strobe
    cyc_i      : in std_logic;
    we_i       : in  std_logic;  --! Write enable
    adr_i      : in  std_logic_vector ( 9 downto 0); --! Address
    dat_i      : in  std_logic_vector (15 downto 0); --! Data in

    dat_o      : out std_logic_vector (15 downto 0); --! Data out
    ack_o      : out std_logic --! Acknowledge
    );


  -- attribute syn_insert_buffer : string;  
  -- attribute syn_insert_buffer of clk_wb_i : signal is "GL25";

end entity nanofip;
--=================================================================================================
-- end of entity declaration
--=================================================================================================


--=================================================================================================
--!                                  architecture declaration
--=================================================================================================

--! Architecture contains only connectivity
architecture struc of nanofip is

--=================================================================================================
-- Triple Module Redundancy

 attribute syn_radhardlevel          : string;
 attribute syn_radhardlevel of struc : architecture is "tmr";

--=================================================================================================

  component CLKBUF
    port (PAD : in std_logic;
          Y   : out std_logic);
  end component;


  signal s_data_length_from_control :  std_logic_vector (7 downto 0);
  signal s_rst, s_nfip_status_r_fcser_p : std_logic;
  signal s_start_prod_p, s_rst_rx_osc : std_logic;
  signal s_prod_request_byte_p, s_prod_sending_mps : std_logic;
  signal s_prod_byte_ready_p : std_logic;
  signal s_prod_last_byte_p : std_logic;
  signal s_cons_byte_ready_p : std_logic;
  signal s_cons_byte : std_logic_vector (7 downto 0);
  signal s_cons_byte_ready_from_control : std_logic;
  signal s_var_from_control : t_var;
  signal s_cons_prod_byte_index_from_control : std_logic_vector (7 downto 0);
  signal s_fss_crc_fes_viol_ok_p, s_urst_r_edge : std_logic;
  signal s_cons_fss_decoded_p, s_assert_RSTON_p : std_logic;
  signal s_prod_ack, s_wb_ack_cons, s_ack_o: std_logic;
  signal s_rst_status_bytes: std_logic;
  signal s_cons_crc_wrong_p, s_reset_nFIP_and_FD_p  : std_logic;
  signal s_var1_rdy, s_var2_rdy, s_var3_rdy : std_logic;
  signal s_model_id_dec, s_constr_id_dec : std_logic_vector (7 downto 0);  
  signal s_rst_rx_unit_p, s_nfip_status_r_tler, s_signif_edge_window, s_adjac_bits_window, s_rx_bit_clk_p, s_rx_manch_clk_p : std_logic;
  signal s_cons_ctrl_byte, s_cons_PDU_byte, s_cons_lgth_byte : std_logic_vector (7 downto 0);
  signal s_urst_synch, s_slone_synch, s_nostat_synch, s_fd_wdgn_synch, s_fd_txer_synch: std_logic;
  signal s_fd_rxd_synch, s_fd_rxd_edge_p, s_fd_rxd_r_edge_p, s_fd_rxd_f_edge_p, s_wb_cyc_synch: std_logic;
  signal s_wb_we_synch, s_wb_stb_synch, s_wb_stb_r_edge: std_logic; 
  signal s_wb_dati_synch: std_logic_vector(7 downto 0);
  signal s_wb_adri_synch: std_logic_vector(9 downto 0);
  signal s_var1_access_synch, s_var2_access_synch, s_var3_access_synch: std_logic;
  signal s_slone_dati_synch: std_logic_vector(15 downto 0);
  signal s_rate_synch: std_logic_vector(1 downto 0);
  signal s_subs_synch, s_cons_var_rst_byte_1, s_cons_var_rst_byte_2 : std_logic_vector(7 downto 0);
  signal s_m_id_synch, s_c_id_synch : std_logic_vector(3 downto 0);
  signal s_p3_lgth_synch : std_logic_vector(2 downto 0);
  signal s_tx_clk_p_buff                   : std_logic_vector (c_TX_CLK_BUFF_LGTH -1 downto 0);

--=================================================================================================
--                                      architecture begin
--=================================================================================================  
begin

---------------------------------------------------------------------------------------------------
  reset_unit : WF_reset_unit 
    port map(
      uclk_i                => uclk_i,
      urst_i                => s_urst_synch,
      rate_i                => s_rate_synch,--------------------
      urst_r_edge_i         => s_urst_r_edge,
      var_i                 => s_var_from_control,
      subs_i                => s_subs_synch,--------------------
      rst_nFIP_and_FD_p_i   => s_reset_nFIP_and_FD_p,
      assert_RSTON_p_i      => s_assert_RSTON_p,
      rston_o               => rston_o,
      nFIP_rst_o            => s_rst, 
      fd_rstn_o             => fd_rstn_o  
      );
---------------------------------------------------------------------------------------------------

  engine_control : WF_engine_control 
    generic map( c_QUARTZ_PERIOD => c_QUARTZ_PERIOD)

    port map(
      uclk_i                  => uclk_i,
      nfip_urst_i             => s_rst, 
      tx_request_byte_p_i     => s_prod_request_byte_p, 
      rx_FSS_received_p_i     => s_cons_fss_decoded_p,   
      rx_byte_ready_p_i       => s_cons_byte_ready_p,
      rx_byte_i               => s_cons_byte, 
      rx_CRC_FES_ok_p_i       => s_fss_crc_fes_viol_ok_p,
      rx_crc_wrong_p_i        => s_cons_crc_wrong_p,
      tx_sending_mps_i        => s_prod_sending_mps,
      rx_ctrl_byte_i          => s_cons_ctrl_byte,
      rx_pdu_byte_i           => s_cons_PDU_byte,  
      rx_length_byte_i        => s_cons_lgth_byte,
      rx_var_rst_byte_1_i     => s_cons_var_rst_byte_1,
      rx_var_rst_byte_2_i     => s_cons_var_rst_byte_2,
      rate_i                  => s_rate_synch,---------------- 
      subs_i                  => s_subs_synch,----------------
      p3_lgth_i               => s_p3_lgth_synch, ----------------------
      slone_i                 => s_slone_synch, 
      nostat_i                => s_nostat_synch, 
      var1_rdy_o              => s_var1_rdy, 
      var2_rdy_o              => s_var2_rdy, 
      var3_rdy_o              => s_var3_rdy, 
      var_o                   => s_var_from_control,
      tx_start_produce_p_o    => s_start_prod_p , 
      tx_byte_ready_p_o       => s_prod_byte_ready_p, 
      tx_last_byte_p_o        => s_prod_last_byte_p, 
      tx_rx_byte_index_o      => s_cons_prod_byte_index_from_control,
      tx_data_length_o        => s_data_length_from_control,
      rx_byte_ready_p_o       => s_cons_byte_ready_from_control,
      rst_rx_unit_p_o         => s_rst_rx_unit_p,
      assert_rston_p_o        => s_assert_RSTON_p,
      rst_nfip_and_fd_p_o     => s_reset_nFIP_and_FD_p,
      nfip_status_r_fcser_p_o => s_nfip_status_r_fcser_p,
      rst_status_bytes_o      => s_rst_status_bytes,
      nfip_status_r_tler_o    => s_nfip_status_r_tler
      );

      var1_rdy_o <= s_var1_rdy; 
      var2_rdy_o <= s_var2_rdy; 
      var3_rdy_o <= s_var3_rdy;
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
  Consumption: wf_consumption
  port map(
    uclk_i                  => uclk_i,
    slone_i                 => slone_i,
    nfip_urst_i             => s_rst,
    fd_rxd_i                => s_fd_rxd_synch,
    fd_rxd_r_edge_p_i       => s_fd_rxd_r_edge_p,
    fd_rxd_f_edge_p_i       => s_fd_rxd_f_edge_p,
    clk_wb_i                => wclk_i,
    wb_adr_i                => s_wb_adri_synch,
    wb_stb_r_edge_p_i       => s_wb_stb_r_edge,
    wb_cyc_i                => s_wb_cyc_synch,
    var_i                   => s_var_from_control,
    byte_ready_p_i          => s_cons_byte_ready_from_control,
    byte_index_i            => s_cons_prod_byte_index_from_control,
    rst_rx_unit_p_i         => s_rst_rx_unit_p,
    signif_edge_window_i    => s_signif_edge_window,
    adjac_bits_window_i     => s_adjac_bits_window,
    sample_bit_p_i          => s_rx_bit_clk_p,
    sample_manch_bit_p_i    => s_rx_manch_clk_p,
    ---------------------------------------------------------------
    data_o                  => dat_o,
    wb_ack_cons_p_o         => s_wb_ack_cons,
    byte_o                  => s_cons_byte,
    byte_ready_p_o          => s_cons_byte_ready_p,
    fss_received_p_o        => s_cons_fss_decoded_p, 
    crc_wrong_p_o           => s_cons_crc_wrong_p,
    fss_crc_fes_viol_ok_p_o => s_fss_crc_fes_viol_ok_p,
    cons_var_rst_byte_1_o   => s_cons_var_rst_byte_1,
    cons_var_rst_byte_2_o   => s_cons_var_rst_byte_2,
    cons_ctrl_byte_o        => s_cons_ctrl_byte, 
    cons_pdu_byte_o         => s_cons_PDU_byte,
    cons_lgth_byte_o        => s_cons_lgth_byte,
    rst_rx_osc_o            => s_rst_rx_osc
    ---------------------------------------------------------------
       );

---------------------------------------------------------------------------------------------------
  rx_tx_osc :WF_rx_tx_osc
    generic map(C_PERIODS_COUNTER_LENGTH => 11,
                c_TX_CLK_BUFF_LGTH       => 4)
    port map(
      uclk_i                  => uclk_i,
      nfip_urst_i             => s_rst, 
      rxd_edge_i              => s_fd_rxd_edge_p,      
      rst_rx_osc_i            => s_rst_rx_osc, 
      rate_i                  => s_rate_synch,  
      tx_clk_p_buff_o         => s_tx_clk_p_buff,
      tx_clk_o                => fd_txck_o,
      rx_manch_clk_p_o        => s_rx_manch_clk_p,
      rx_bit_clk_p_o          => s_rx_bit_clk_p, 
      rx_signif_edge_window_o => s_signif_edge_window,
      rx_adjac_bits_window_o  => s_adjac_bits_window
      );



---------------------------------------------------------------------------------------------------
  Production: wf_production
  port map(
    uclk_i                  => uclk_i,
    slone_i                 => slone_i,
    nostat_i                => nostat_i,
    nfip_urst_i             => s_rst,
    clk_wb_i                => wclk_i,
    wb_data_i               => s_wb_dati_synch,
    wb_adr_i                => s_wb_adri_synch,
    wb_stb_r_edge_p_i       => s_wb_stb_r_edge,
    wb_we_i                 => s_wb_we_synch,
    wb_cyc_i                => s_wb_cyc_synch,
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
    byte_ready_p_i          => s_prod_byte_ready_p,
    last_byte_p_i           => s_prod_last_byte_p,
    rst_status_bytes_i      => s_rst_status_bytes,
    nfip_status_r_tler_i    => s_nfip_status_r_tler,
    nfip_status_r_fcser_p_i => s_cons_crc_wrong_p,
    var1_rdy_i              => s_var1_rdy,
    var2_rdy_i              => s_var2_rdy,
    var3_rdy_i              => s_var3_rdy,
    tx_clk_p_buff_i         => s_tx_clk_p_buff,
    model_id_dec_i          => s_model_id_dec,
    constr_id_dec_i         => s_constr_id_dec,
    --------------------------------------------------------------------------
    request_byte_p_o        => s_prod_request_byte_p,
    sending_mps_o           => s_prod_sending_mps,
    tx_data_o               => fd_txd_o,
    tx_enable_o             => fd_txena_o,
    u_cacer_o               => u_cacer_o,
    u_pacer_o               => u_pacer_o,
    r_tler_o                => r_tler_o,
    r_fcser_o               => r_fcser_o,
    wb_ack_prod_p_o         => s_prod_ack
    --------------------------------------------------------------------------
       );

---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------

 model_constr_decoder : WF_model_constr_decoder 
  port map(
    uclk_i          => uclk_i,
    nfip_urst_i     => s_rst,
    model_id_i      => s_m_id_synch,--------------
    constr_id_i     => s_c_id_synch,

    select_id_o     => s_id_o,
    model_id_dec_o  => s_model_id_dec,
    constr_id_dec_o => s_constr_id_dec
    );


---------------------------------------------------------------------------------------------------

  synchronizer: WF_inputs_synchronizer
  port map(
    uclk_i            => uclk_i,
    clk_wb_i          => wclk_i,
    nfip_urst_i       => s_rst, 
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
    wb_adr_a_i        => adr_i,
    var1_access_a_i   => var1_acc_i,
    var2_access_a_i   => var2_acc_i,
    var3_access_a_i   => var3_acc_i,
    dat_a_i           => dat_i,
    rate_a_i          => rate_i,
    subs_a_i          => subs_i,
    m_id_a_i          => m_id_i,
    c_id_a_i          => c_id_i,
    p3_lgth_a_i       => p3_lgth_i,
    rsti_o            => s_urst_synch,
    urst_r_edge_o     => s_urst_r_edge,
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
    wb_dati_o         => s_wb_dati_synch,
    wb_adri_o         => s_wb_adri_synch,
    var1_access_o     => s_var1_access_synch,
    var2_access_o     => s_var2_access_synch,
    var3_access_o     => s_var3_access_synch,
    slone_dati_o      => s_slone_dati_synch,
    rate_o            => s_rate_synch,
    subs_o            => s_subs_synch,
    m_id_o            => s_m_id_synch,
    c_id_o            => s_c_id_synch,
    p3_lgth_o         => s_p3_lgth_synch
      );
---------------------------------------------------------------------------------------------------


  ack_o   <= (s_prod_ack or s_wb_ack_cons); --and stb_i;  
  s_ack_o <= s_prod_ack or s_wb_ack_cons;

---------------------------------------------------------------------------------------------------



end architecture struc;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------