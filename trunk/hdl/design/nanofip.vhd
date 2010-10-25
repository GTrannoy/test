--=================================================================================================
--! @file nanofip.vhd
--=================================================================================================

--! standard library
library IEEE;

--! standard packages
use IEEE.STD_LOGIC_1164.all;  --! std_logic definitions
use IEEE.NUMERIC_STD.all;     --! conversion functions

--! specific packages
use work.WF_PACKAGE.all;      --! definitions of supplemental types, subtypes, constants

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
--! @author Pablo Alvarez Sanchez (pablo.alvarez.sanchez@cern.ch)
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
    rate_i    : in  std_logic_vector (1 downto 0); --! Bit rate
    subs_i    : in  std_logic_vector (7 downto 0); --! Subscriber number coding.
    m_id_i    : in  std_logic_vector (3 downto 0); --! Model identification settings
    c_id_i    : in  std_logic_vector (3 downto 0); --! Constructor identification settings
    p3_lgth_i : in  std_logic_vector (2 downto 0); --! Produced variable data length

    s_id_o    : out std_logic_vector (1 downto 0); --! Identification selection
 
--  FIELDRIVE connections

    fx_rxa_i  : in  std_logic; --! Reception activity detection
    fx_rxd_i  : in  std_logic; --! Receiver data
    fd_wdgn_i : in  std_logic; --! Watchdog on transmitter
    fd_txer_i : in  std_logic; --! Transmitter error

    fd_txena_o: out std_logic; --! Transmitter enable
    fd_txck_o : out std_logic; --! Line driver half bit clock
    fx_txd_o  : out std_logic; --! Transmitter data
    fd_rstn_o : out std_logic; --! Initialisation control, active low

 
--  USER INTERFACE, General signals
 
    uclk_i    : in  std_logic; --! 40 MHz clock
    slone_i   : in  std_logic; --! Stand-alone mode
    nostat_i  : in  std_logic; --! No NanoFIP status transmission
    rstin_i   : in  std_logic; --! Initialisation control, active low

    rston_o   : out std_logic; --! Reset output, active low


--  USER INTERFACE, non WISHBONE

    var1_acc_i: in  std_logic; --! Variable 1 access
    var2_acc_i: in  std_logic; --! Variable 2 access
    var3_acc_i: in  std_logic; --! Variable 3 access

    var1_rdy_o: out std_logic; --! Variable 1 ready
    var2_rdy_o: out std_logic; --! Variable 2 ready
    var3_rdy_o: out std_logic; --! Variable 3 ready


--  USER INTERFACE, WISHBONE SLAVE

    wclk_i    : in  std_logic;  --! WISHBONE clock. May be independent of UCLK.
    rst_i     : in  std_logic;  --! WISHBONE reset. Does not reset other internal logic.
    stb_i     : in  std_logic;  --! Strobe
    cyc_i     : in std_logic;
    we_i      : in  std_logic;  --! Write enable
    adr_i     : in  std_logic_vector ( 9 downto 0); --! Address
    dat_i     : in  std_logic_vector (15 downto 0); --! Data in

    dat_o     : out std_logic_vector (15 downto 0); --! Data out
    ack_o     : out std_logic --! Acknowledge

    );

  -- attribute syn_keep of fx_rxa_i : signal is true;
  -- attribute syn_preserve of fx_rxa_i : signal is true;

  -- attribute syn_insert_buffer : string;  
  -- attribute syn_insert_buffer of wbclk_i : signal is "GL25";

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
-- TMR

 attribute syn_radhardlevel : string;

 attribute syn_radhardlevel of struc: architecture is "tmr";

--=================================================================================================

  component CLKBUF
     port (PAD : in std_logic;
           Y : out std_logic);
  end component;


  signal s_data_length_from_control :  std_logic_vector (7 downto 0);
  signal s_byte_to_tx : std_logic_vector (7 downto 0);
  signal s_rst : std_logic;
  signal s_start_send_p : std_logic;
  signal s_request_byte_from_tx_p : std_logic;
  signal s_byte_to_tx_ready_p : std_logic;
  signal s_last_byte_to_tx_p : std_logic;
  signal s_byte_from_rx_ready_p : std_logic;
  signal s_byte_from_rx : std_logic_vector (7 downto 0);
  signal s_cons_byte_we_from_control : std_logic;
  signal s_var_from_control : t_var;
  signal s_add_offset_from_control : std_logic_vector (7 downto 0);
  signal s_CRC_ok_from_rx : std_logic;
  signal fss_decoded_p_from_rx : std_logic;
  signal s_stat : std_logic_vector (7 downto 0);
  signal s_ack_produced, s_ack_consumed, s_ack_o: std_logic;
  signal s_reset_status_bytes, s_sending_mps: std_logic;
  signal s_crc_bad_p : std_logic;
  signal s_var1_rdy, s_var2_rdy, s_var3_rdy : std_logic;
  signal s_mps : std_logic_vector (7 downto 0);
  signal s_m_id_dec_o, s_c_id_dec_o : std_logic_vector (7 downto 0);  
  signal s_reset_rx_unit_p : std_logic;
  signal s_ctrl_byte_received, s_pdu_byte_received, s_length_byte_received : std_logic_vector (7 downto 0);
  signal s_rst_var_byte_1, s_rst_var_byte_2 : std_logic_vector (7 downto 0);
  signal s_rsti_synch, s_slone_synch, s_nostat_synch, s_fd_wdgn_synch, s_fd_txer_synch: std_logic;
  signal s_fd_rxd_synch, s_fd_rxd_edge, s_rxd_r_edge, s_rxd_f_edge, s_wb_cyc_synch: std_logic;
  signal s_wb_we_synch, s_wb_stb_synch, s_wb_stb_r_edge: std_logic; 
  signal s_wb_dati_synch: std_logic_vector(7 downto 0);
  signal s_wb_adri_synch: std_logic_vector(9 downto 0);
  signal s_var1_access_synch, s_var2_access_synch, s_var3_access_synch: std_logic;
  signal s_slone_dati_synch: std_logic_vector(15 downto 0);
  signal s_rate_synch: std_logic_vector(1 downto 0);
  signal s_subs_synch : std_logic_vector(7 downto 0);
  signal s_m_id_synch, s_c_id_synch : std_logic_vector(3 downto 0);
  signal s_p3_lgth_synch : std_logic_vector(2 downto 0);

begin
--=================================================================================================
--                                      architecture begin
--=================================================================================================  

---------------------------------------------------------------------------------------------------
  reset_unit : wf_reset_unit 
    port map(
      uclk_i              => uclk_i,
      rsti_i              => s_rsti_synch,
      var_i               => s_var_from_control,
      subs_i              => s_subs_synch,
      rst_var_byte_1_i    => s_rst_var_byte_1,
      rst_var_byte_2_i    => s_rst_var_byte_2,
      rston_o             => rston_o,
      nFIP_rst_o          => s_rst, 
      fd_rstn_o           => fd_rstn_o  
      );
---------------------------------------------------------------------------------------------------

  engine_control : wf_engine_control 
    generic map( C_QUARTZ_PERIOD => C_QUARTZ_PERIOD)

    port map(
      uclk_i               => uclk_i,
      nFIP_u_rst_i         => s_rst, 
      tx_request_byte_p_i  => s_request_byte_from_tx_p, 
      rx_FSS_received_p_i   => fss_decoded_p_from_rx,   
      rx_byte_ready_p_i    => s_byte_from_rx_ready_p,
      rx_byte_i            => s_byte_from_rx, 
      rx_CRC_FES_ok_p_i    => s_CRC_ok_from_rx,
      tx_sending_mps_i     => s_sending_mps,
      rx_Ctrl_byte_i       => s_ctrl_byte_received,
      rx_PDU_byte_i        => s_pdu_byte_received,  
      rx_Length_byte_i     => s_length_byte_received,
      rate_i               => s_rate_synch, 
      subs_i               => s_subs_synch,
      p3_lgth_i            => s_p3_lgth_synch, 
      slone_i              => s_slone_synch, 
      nostat_i             => s_nostat_synch, 
      var1_rdy_o           => s_var1_rdy, 
      var2_rdy_o           => s_var2_rdy, 
      var3_rdy_o           => s_var3_rdy, 
      var_o                => s_var_from_control,
      tx_start_produce_p_o => s_start_send_p , 
      tx_byte_ready_p_o    => s_byte_to_tx_ready_p, 
      tx_last_byte_p_o     => s_last_byte_to_tx_p, 
      tx_rx_byte_index_o   => s_add_offset_from_control,
      tx_data_length_o     => s_data_length_from_control,
      rx_byte_ready_p_o  => s_cons_byte_we_from_control,
      reset_rx_unit_p_o    => s_reset_rx_unit_p,
      reset_status_bytes_o => s_reset_status_bytes
      );

      var1_rdy_o <= s_var1_rdy; 
      var2_rdy_o <= s_var2_rdy; 
      var3_rdy_o <= s_var3_rdy;
---------------------------------------------------------------------------------------------------



    tx_rx : wf_tx_rx 

    port map(
      uclk_i              => uclk_i,
      nFIP_u_rst_i        => s_rst,
      reset_rx_unit_p_i   => s_reset_rx_unit_p,
      start_produce_p_i   => s_start_send_p,
      request_byte_p_o    => s_request_byte_from_tx_p,
      byte_ready_p_i      => s_byte_to_tx_ready_p,
      byte_i              => s_byte_to_tx,
      last_byte_p_i       => s_last_byte_to_tx_p,
      tx_data_o           => fx_txd_o,
      tx_enable_o         => fd_txena_o,
      d_clk_o             => fd_txck_o,
      fd_rxd              => s_fd_rxd_synch,
      fd_rxd_edge_i       => s_fd_rxd_edge,
      fd_rxd_r_edge_i     => s_rxd_r_edge,
      fd_rxd_f_edge_i     => s_rxd_f_edge, 
      rate_i              => s_rate_synch,
      byte_ready_p_o      => s_byte_from_rx_ready_p,
      byte_o              => s_byte_from_rx,
      CRC_wrong_p_o       => s_crc_bad_p,
      FSS_received_p_o    => fss_decoded_p_from_rx,
      FSS_CRC_FES_viol_ok_p_o => s_CRC_ok_from_rx 
      );
---------------------------------------------------------------------------------------------------

    consumed_vars : wf_cons_bytes_from_rx 

    port map(
      uclk_i              => uclk_i,
      nFIP_u_rst_i          => s_rst, 
      slone_i             => s_slone_synch,
      byte_ready_p_i      => s_cons_byte_we_from_control,
      var_i               => s_var_from_control,
      byte_index_i        => s_add_offset_from_control,
      byte_i              => s_byte_from_rx,
      wb_clk_i            => wclk_i,   
      wb_adr_i            => s_wb_adri_synch,   
      wb_stb_r_edge_p_i   => s_wb_stb_r_edge,   
      wb_cyc_i            => s_wb_cyc_synch, 
      wb_ack_cons_p_o     => s_ack_consumed, 
      data_o              => dat_o,
      rx_Ctrl_byte_o      => s_ctrl_byte_received,
      rx_PDU_byte_o       => s_PDU_byte_received,         
      rx_Length_byte_o    => s_length_byte_received,
      rst_var_byte_1_o    => s_rst_var_byte_1, 
      rst_var_byte_2_o    => s_rst_var_byte_2
      );
---------------------------------------------------------------------------------------------------


    produced_vars : wf_prod_bytes_to_tx

    port map(
      uclk_i             => uclk_i, 
      m_id_dec_i         => s_m_id_dec_o, 
      c_id_dec_i         => s_c_id_dec_o,
      slone_i            => s_slone_synch,  
      nostat_i           => s_nostat_synch, 
      nFIP_u_rst_i       => s_rst,
      wb_clk_i           => wclk_i,   
      wb_adr_i           => s_wb_adri_synch,   
      wb_stb_r_edge_p_i  => s_wb_stb_r_edge, 
      wb_cyc_i           => s_wb_cyc_synch,  
      wb_we_p_i          => s_wb_we_synch, 
      nFIP_status_byte_i => s_stat,  
      mps_status_byte_i  => s_mps,
      var_i              => s_var_from_control,  
      byte_index_i       => s_add_offset_from_control,  
      data_length_i      => s_data_length_from_control, 
      wb_data_i          => s_wb_dati_synch,
      slone_data_i       => s_slone_dati_synch,
      var3_rdy_i         => s_var3_rdy,
      sending_mps_o      => s_sending_mps, 
      byte_o             => s_byte_to_tx,
      wb_ack_prod_p_o    => s_ack_produced  
      );
---------------------------------------------------------------------------------------------------

    status_bytes_gen : wf_status_bytes_gen 
    port map(
      uclk_i               => uclk_i,
      nFIP_u_rst_i           => s_rst,
      slone_i              => s_slone_synch,
      fd_wdgn_i            => s_fd_wdgn_synch,
      fd_txer_i            => s_fd_txer_synch,
      crc_wrong_p_i        => s_crc_bad_p,
      var_i                => s_var_from_control,
      var1_rdy_i           => s_var1_rdy,
      var2_rdy_i           => s_var2_rdy,
      var3_rdy_i           => s_var3_rdy,
      var1_acc_i           => s_var1_access_synch,
      var2_acc_i           => s_var2_access_synch,
      var3_acc_i           => s_var3_access_synch,
      reset_status_bytes_i => s_reset_status_bytes,
      nFIP_status_byte_o   => s_stat,
      mps_status_byte_o    => s_mps
      );
---------------------------------------------------------------------------------------------------

 model_constr_decoder : wf_model_constr_decoder 
  generic map (C_RELOAD_MID_CID => C_RELOAD_MID_CID)
  port map(
    uclk_i        => uclk_i,
    nFIP_u_rst_i    => s_rst,
    s_id_o        => s_id_o,
    m_id_dec_o    => s_m_id_dec_o,
    c_id_dec_o    => s_c_id_dec_o,
    m_id_i        => s_m_id_synch,
    c_id_i        => s_c_id_synch
    );


---------------------------------------------------------------------------------------------------

  synchronizer: wf_inputs_synchronizer
  port map(
    uclk_i          => uclk_i,
    wbclk_i         => wclk_i,
    nFIP_u_rst_i    => s_rst, 
    rstin_a_i       => rstin_i,
    wb_rst_a_i      => rst_i,
    slone_a_i       => slone_i,
    nostat_a_i      => nostat_i,
    fd_wdgn_a_i     => fd_wdgn_i,
    fd_txer_a_i     => fd_txer_i,
    fd_rxd_a_i      => fx_rxd_i,
    wb_cyc_a_i      => cyc_i,
    wb_we_a_i       => we_i,
    wb_stb_a_i      => stb_i,
    wb_adr_a_i      => adr_i,
    var1_access_a_i => var1_acc_i,
    var2_access_a_i => var2_acc_i,
    var3_access_a_i => var3_acc_i,
    dat_a_i         => dat_i,
    rate_a_i        => rate_i,
    subs_a_i        => subs_i,
    m_id_a_i        => m_id_i,
    c_id_a_i        => c_id_i,
    p3_lgth_a_i     => p3_lgth_i,
    u_rsti_o        => s_rsti_synch,
    slone_o         => s_slone_synch,
    nostat_o        => s_nostat_synch,
    fd_wdgn_o       => s_fd_wdgn_synch,
    fd_txer_o       => s_fd_txer_synch,
    fd_rxd_o        => s_fd_rxd_synch,
    fd_rxd_edge_o   => s_fd_rxd_edge,
    fd_rxd_r_edge_o => s_rxd_r_edge,
    fd_rxd_f_edge_o => s_rxd_f_edge, 
    wb_cyc_o        => s_wb_cyc_synch,
    wb_we_o         => s_wb_we_synch,
    wb_stb_o        => s_wb_stb_synch,
    wb_stb_r_edge_o => s_wb_stb_r_edge,
    wb_dati_o       => s_wb_dati_synch,
    wb_adri_o       => s_wb_adri_synch,
    var1_access_o   => s_var1_access_synch,
    var2_access_o   => s_var2_access_synch,
    var3_access_o   => s_var3_access_synch,
    slone_dati_o    => s_slone_dati_synch,
    rate_o          => s_rate_synch,
    subs_o          => s_subs_synch,
    m_id_o          => s_m_id_synch,
    c_id_o          => s_c_id_synch,
    p3_lgth_o       => s_p3_lgth_synch
      );
---------------------------------------------------------------------------------------------------


  ack_o   <= (s_ack_produced or s_ack_consumed); --and stb_i;  
  s_ack_o <= s_ack_produced or s_ack_consumed;

---------------------------------------------------------------------------------------------------



end architecture struc;
--============================================================================
--============================================================================
-- architecture end
--============================================================================
--============================================================================

-------------------------------------------------------------------------------
--                          E N D   O F   F I L E
-------------------------------------------------------------------------------