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

--library synplify;
--use synplify.attributes.all;


--syn_translate on
--library synplify;
--syn_translate off

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
    s_id_o    : out std_logic_vector (1 downto 0); --! Identification selection
    m_id_i    : in  std_logic_vector (3 downto 0); --! Model identification settings
    c_id_i    : in  std_logic_vector (3 downto 0); --! Constructor identification settings
    p3_lgth_i : in  std_logic_vector (2 downto 0); --! Produced variable data length

 
--  FIELDRIVE connections

    fd_rstn_o : out std_logic; --! Initialisation control, active low
    fd_wdgn_i : in  std_logic; --! Watchdog on transmitter
    fd_txer_i : in  std_logic; --! Transmitter error
    fd_txena_o: out std_logic; --! Transmitter enable
    fd_txck_o : out std_logic; --! Line driver half bit clock
    fx_txd_o  : out std_logic; --! Transmitter data
    fx_rxa_i  : in  std_logic; --! Reception activity detection
    fx_rxd_i  : in  std_logic; --! Receiver data

 
--  USER INTERFACE, General signals
 
    uclk_i    : in  std_logic; --! 40 MHz clock
    slone_i   : in  std_logic; --! Stand-alone mode
    nostat_i  : in  std_logic; --! No NanoFIP status transmission

    rstin_i   : in  std_logic; --! Initialisation control, active low

    rston_o   : out std_logic; --! Reset output, active low



--  USER INTERFACE, non WISHBONE

    var1_rdy_o: out std_logic; --! Variable 1 ready

    var1_acc_i: in  std_logic; --! Variable 1 access
    var2_rdy_o: out std_logic; --! Variable 2 ready
    var2_acc_i: in  std_logic; --! Variable 2 access
    var3_rdy_o: out std_logic; --! Variable 3 ready
    var3_acc_i: in  std_logic; --! Variable 3 access

--  USER INTERFACE, WISHBONE SLAVE

    wclk_i    : in  std_logic; --! Wishbone clock. May be independent of UCLK.
    dat_i     : in  std_logic_vector (15 downto 0); --! Data in

    dat_o     : out std_logic_vector (15 downto 0); --! Data out
    adr_i     : in  std_logic_vector ( 9 downto 0); --! Address
    rst_i     : in  std_logic; --! Wishbone reset. Does not reset other internal logic.
    stb_i     : in  std_logic; --! Strobe
    ack_o     : out std_logic; --! Acknowledge
    cyc_i     : in std_logic;
    we_i      : in  std_logic  --! Write enable

    );

 -- attribute syn_keep of fx_rxa_i : signal is true;
 -- attribute syn_preserve of fx_rxa_i : signal is true;

--    attribute syn_insert_buffer : string;
--attribute syn_insert_buffer of wclk_i : signal is "GL25";

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


  signal s_data_length_from_control :  std_logic_vector(7 downto 0);
  signal s_byte_to_tx : std_logic_vector(7 downto 0);
  signal s_rst : std_logic;
  signal s_start_send_p : std_logic;
  signal s_request_byte_from_tx_p : std_logic;
  signal s_byte_to_tx_ready_p : std_logic;
  signal s_last_byte_to_tx_p, s_last_byte_from_rx_p : std_logic;
  signal s_byte_from_rx_ready_p : std_logic;
  signal s_byte_from_rx : std_logic_vector(7 downto 0);
  signal s_cons_byte_we_from_control : std_logic;
  signal s_var_from_control : t_var;
  signal s_add_offset_from_control : std_logic_vector(7 downto 0);
  signal s_crc_ok_from_rx : std_logic;
  signal fss_decoded_p_from_rx : std_logic;
  signal s_stat : std_logic_vector(7 downto 0);
  signal s_ack_produced, s_ack_consumed, s_ack_o: std_logic;
  signal s_reset_status_bytes, s_sending_mps: std_logic;
  signal s_code_violation_p : std_logic;
  signal s_crc_bad_p : std_logic;
  signal s_var1_rdy : std_logic;
  signal s_var2_rdy : std_logic;
  signal s_var3_rdy : std_logic;
  signal s_mps : std_logic_vector(7 downto 0);
  signal s_wb_data_d1, s_wb_data_d2, s_data_o : std_logic_vector(15 downto 0);
  signal s_m_id_dec_o, s_c_id_dec_o : std_logic_vector(7 downto 0);  
  --signal s_stb_d, s_we_d, s_cyc_d : std_logic;
  signal s_reset_nFIP_and_FD, s_reset_rston : std_logic;
  signal s_adr_d1, s_adr_d2 : std_logic_vector (9 downto 0);
  signal s_stb_r_edge, s_stb_d1, s_stb_d2, s_stb_d3 : std_logic;
  signal s_we_d1, s_we_d2, s_cyc_d1, s_cyc_d2 : std_logic;

begin
--=================================================================================================
--                                      architecture begin
--=================================================================================================  

---------------------------------------------------------------------------------------------------
  ureset_logic : reset_logic 
    port map(
      uclk_i              => uclk_i,
      rstin_i             => rstin_i,
      reset_nFIP_and_FD_i => s_reset_nFIP_and_FD,
      reset_RSTON_i       => s_reset_rston,
      rston_o             => rston_o,
      nFIP_rst_o          => s_rst, 
      fd_rstn_o           => fd_rstn_o  
      );
---------------------------------------------------------------------------------------------------

  uwf_engine_control : wf_engine_control 
    generic map( C_QUARTZ_PERIOD => 25.0)

    port map(
      uclk_i            => uclk_i,
      nFIP_rst_i        => s_rst, 
      start_produce_p_o => s_start_send_p , 
      request_byte_p_i  => s_request_byte_from_tx_p, 
      byte_ready_p_o    => s_byte_to_tx_ready_p, 
      last_byte_p_o     => s_last_byte_to_tx_p, 
      fss_decoded_p_i   => fss_decoded_p_from_rx,   
      byte_ready_p_i    => s_byte_from_rx_ready_p,
      byte_i            => s_byte_from_rx, 
      frame_ok_p_i      => s_crc_ok_from_rx,   
      rate_i            => rate_i, 
      subs_i            => subs_i,
      p3_lgth_i         => p3_lgth_i, 
      slone_i           => slone_i, 
      nostat_i          => nostat_i, 
      var1_rdy_o        => s_var1_rdy, 
      var2_rdy_o        => s_var2_rdy, 
      var3_rdy_o        => s_var3_rdy, 
      var_o             => s_var_from_control,
      add_offset_o      => s_add_offset_from_control,
      data_length_o     => s_data_length_from_control,
      consume_byte_p_o  => s_cons_byte_we_from_control
      );
---------------------------------------------------------------------------------------------------

  uwf_tx_rx : wf_tx_rx 

    port map(
      uclk_i              => uclk_i,
      nFIP_rst_i          => s_rst,
      start_produce_p_i   => s_start_send_p,
      request_byte_p_o    => s_request_byte_from_tx_p,
      byte_ready_p_i      => s_byte_to_tx_ready_p,
      byte_i              => s_byte_to_tx,
      last_byte_p_i       => s_last_byte_to_tx_p,
      tx_data_o           => fx_txd_o,
      tx_enable_o         => fd_txena_o,
      d_clk_o             => fd_txck_o,
      d_a_i               => fx_rxd_i,
      rate_i              => rate_i,
      byte_ready_p_o      => s_byte_from_rx_ready_p,
      byte_o              => s_byte_from_rx,
      fss_decoded_p_o     => fss_decoded_p_from_rx,
      last_byte_p_o       => s_last_byte_from_rx_p,
      code_violation_p_o  => s_code_violation_p,
      crc_wrong_p_o       => s_crc_bad_p,
      crc_ok_p_o          => s_crc_ok_from_rx 
      );
---------------------------------------------------------------------------------------------------

  uwf_consumed_vars : wf_consumed_vars 

    port map(
      uclk_i              => uclk_i,
      nFIP_rst_i          => s_rst, 
      slone_i             => slone_i,
      subs_i              => subs_i,
      byte_ready_p_i      => s_cons_byte_we_from_control,
      var_i               => s_var_from_control,
      index_offset_i      => s_add_offset_from_control,
      byte_i              => s_byte_from_rx,
      wb_rst_i            => rst_i,
      wb_clk_i            => wclk_i,   
      wb_adr_i            => s_adr_d2,   
      wb_stb_r_edge_p_i   => s_stb_r_edge,   
      wb_cyc_i            => s_cyc_d2, 
      wb_ack_cons_p_o     => s_ack_consumed, 
      data_o              => dat_o,
      reset_nFIP_and_FD_o => s_reset_nFIP_and_FD, 
      reset_RSTON_o       => s_reset_rston
      );
---------------------------------------------------------------------------------------------------

  uwf_produced_vars : wf_produced_vars

    port map(
      uclk_i             => uclk_i, 
      m_id_dec_i         => s_m_id_dec_o, 
      c_id_dec_i         => s_c_id_dec_o,
      slone_i            => slone_i,  
      nostat_i           => nostat_i, 
      sending_mps_o      => s_sending_mps, 
      nFIP_status_byte_i => s_stat,  
      mps_byte_i         => s_mps,
      var_i              => s_var_from_control,  
      index_offset_i     => s_add_offset_from_control,  
      data_length_i      => s_data_length_from_control,  
      byte_o             => s_byte_to_tx,
      wb_rst_i           => rst_i, 
      data_i             => s_wb_data_d2,   
      wb_clk_i           => wclk_i,   
      wb_adr_i           => s_adr_d2,   
      wb_stb_r_edge_p_i  => s_stb_r_edge, 
      wb_cyc_i           => s_cyc_d2,  
      wb_ack_prod_p_o    => s_ack_produced,   
      wb_we_p_i          => s_we_d2
      );
---------------------------------------------------------------------------------------------------

  ustatus_gen : status_gen 
    port map(
      uclk_i               => uclk_i,
      nFIP_rst_i           => s_rst,
      slone_i              => slone_i,
      fd_wdgn_i            => fd_wdgn_i,
      fd_txer_i            => fd_txer_i,
      code_violation_p_i   => s_code_violation_p,
      crc_wrong_p_i        => s_crc_bad_p,
      var_i                => s_var_from_control,
      var1_rdy_i           => s_var1_rdy,
      var2_rdy_i           => s_var2_rdy,
      var3_rdy_i           => s_var3_rdy,
      var1_access_a_i      => var1_acc_i,
      var2_access_a_i      => var2_acc_i,
      var3_access_a_i      => var3_acc_i,
      reset_status_bytes_i => s_reset_status_bytes,
      status_byte_o        => s_stat,
      mps_byte_o           => s_mps
      );
---------------------------------------------------------------------------------------------------

 Uwf_dec_m_ids : wf_dec_m_ids 
  port map(
    uclk_i        => uclk_i,
    nFIP_rst_i    => s_rst,
    s_id_o        => s_id_o,
    m_id_dec_o    => s_m_id_dec_o,
    c_id_dec_o    => s_c_id_dec_o,
    m_id_i        => m_id_i,
    c_id_i        => c_id_i
    );


---------------------------------------------------------------------------------------------------

WISHBONE_input_signals_buffering: process(wclk_i)
begin
 if rising_edge(wclk_i) then
   if rst_i = '1' then -- reset not buffered to comply with WISHBONE rule 3.15
     s_wb_data_d1 <= (others => '0');
     s_wb_data_d2 <= (others => '0');
     s_adr_d1     <= (others => '0');
     s_adr_d2     <= (others => '0');
     s_stb_d1     <= '0';
     s_stb_d2     <= '0';
     s_stb_d3     <= '0';
     s_cyc_d1     <= '0';
     s_cyc_d2     <= '0';
     s_we_d1      <= '0';
     s_we_d2      <= '0';

    else
      s_wb_data_d2 <= s_wb_data_d1; 
      s_wb_data_d1 <= dat_i;

      s_adr_d2 <= s_adr_d1;
      s_adr_d1 <= adr_i;

      s_stb_d1 <= stb_i;
      s_stb_d2 <= s_stb_d1; 
      s_stb_d3 <= s_stb_d2;   

      s_cyc_d1 <= cyc_i;
      s_cyc_d2 <= s_cyc_d1;    

      s_we_d1 <= we_i;
      s_we_d2 <= s_we_d1;    

    end if;
   end if;
end process;

---------------------------------------------------------------------------------------------------
  s_stb_r_edge <= (not s_stb_d3) and s_stb_d2; 

  ack_o <= (s_ack_produced or s_ack_consumed); --and stb_i;  
  s_ack_o <= s_ack_produced or s_ack_consumed;
  s_reset_status_bytes <= s_sending_mps and s_byte_to_tx_ready_p;  -- at the end of the transmission

---------------------------------------------------------------------------------------------------
      var1_rdy_o <= s_var1_rdy;  --! Variable 1 ready
      var2_rdy_o <= s_var2_rdy; --! Variable 2 ready
      var3_rdy_o <= s_var3_rdy; --! Variable 3 ready

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