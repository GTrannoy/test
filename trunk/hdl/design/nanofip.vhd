
--===========================================================================
--! @file nanofip.vhd
--! @brief Top level design file of nanofip
--===========================================================================
--! Standard library
library IEEE;
--! Standard packages
use IEEE.STD_LOGIC_1164.all; --! std_logic definitions
use IEEE.NUMERIC_STD.all;    --! conversion functions

use work.wf_package.all;

library synplify;

-------------------------------------------------------------------------------
--                                                                           --
--                                   nanofip                                 --
--                                                                           --
--                               CERN, BE/CO/HT                              --
--                                                                           --
-------------------------------------------------------------------------------
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
--! @author Erik van der Bij (Erik.van.der.Bij@cern.ch)
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
-------------------------------------------------------------------------------
--! \n\n<b>Last changes:</b>\n
--! 30/06/2009  v0.010  EB  First version \n
--! 06/07/2009  v0.011  EB  Dummy blocks  \n
--! 07/07/2009  v0.011  EB  Comments      \n
--!
-------------------------------------------------------------------------------
--! @todo Create entity \n
--
-------------------------------------------------------------------------------

--! @brief Top level design file of nanofip
--============================================================================
--============================================================================
--! Entity declaration for nanofip
--============================================================================
--============================================================================

entity nanofip is

  port (
-------------------------------------------------------------------------------
-- WorldFIP settings
-------------------------------------------------------------------------------
    --! Bit rate         \n
    --! 00: 31.25 kbit/s \n
    --! 01: 1 Mbit/s     \n
    --! 10: 2.5 Mbit/s   \n
    --! 11: reserved, do not use
    rate_i    : in  std_logic_vector (1 downto 0); --! Bit rate

    --! Subscriber number coding. Station address.
    subs_i    : in  std_logic_vector (7 downto 0); --! Subscriber number coding.

    --! Identification selection (see M_ID, C_ID)
    s_id_o    : out std_logic_vector (1 downto 0); --! Identification selection

    --! Identification variable settings. 
    --! Connect the ID inputs either to Gnd, Vcc, S_ID[0] or S_ID[1] to 
    --! obtain different values for the Model data (i=0,1,2,3).\n
    --! M_ID[i] connected to: Gnd S_ID0 SID1 Vcc               \n
    --! Model [2*i]            0    1    0    1                \n
    --! Model [2*i+1]          0    0    1    1
    m_id_i    : in  std_logic_vector (3 downto 0); --! Model identification settings

    --! Constructor identification settings.
    --! Connect the ID inputs either to Gnd, Vcc, S_ID[0] or S_ID[1] to 
    --! obtain different values for the Model data (i=0,1,2,3).\n
    --! C_ID[i] connected to: Gnd S_ID0 SID1 Vcc               \n
    --! Constructor[2*i]       0    1    0    1                \n
    --! Constructor[2*i+1]     0    0    1    1
    c_id_i    : in  std_logic_vector (3 downto 0); --! Constructor identification settings

    --! Produced variable data length \n
    --! 000: 2 Bytes                  \n
    --! 001: 8 Bytes                  \n
    --! 010: 16 Bytes                 \n
    --! 011: 32 Bytes                 \n
    --! 100: 64 Bytes                 \n
    --! 101: 124 Bytes                \n
    --! 110: reserved, do not use     \n
    --! 111: reserved, do not use     \n
    --! Actual size: +1 NanoFIP Status byte +1 MPS Status byte (last transmitted) 
    --! Note: when SLONE=Vcc, p3_lgth_i should be set to 000.
    p3_lgth_i : in  std_logic_vector (2 downto 0); --! Produced variable data length


-------------------------------------------------------------------------------
--  FIELDRIVE connections
-------------------------------------------------------------------------------
    fd_rstn_o : out std_logic; --! Initialisation control, active low
    fd_wdgn_i : in  std_logic; --! Watchdog on transmitter
    fd_txer_i : in  std_logic; --! Transmitter error
    fd_txena_o: out std_logic; --! Transmitter enable
    fd_txck_o : out std_logic; --! Line driver half bit clock
    fx_txd_o  : out std_logic; --! Transmitter data
    fx_rxa_i  : in  std_logic; --! Reception activity detection
    fx_rxd_i  : in  std_logic; --! Receiver data


-------------------------------------------------------------------------------
--  USER INTERFACE, General signals
-------------------------------------------------------------------------------
    uclk_i    : in  std_logic; --! 40 MHz clock

    --! Stand-alone mode
    --! If connected to Vcc, disables sending of NanoFIP status together with 
    --! the produced data.
    slone_i   : in  std_logic; --! Stand-alone mode

    --! No NanoFIP status transmission
    --! If connected to Vcc, disables sending of NanoFIP status together with 
    --! the produced data.
    nostat_i  : in  std_logic; --! No NanoFIP status transmission

    rstin_i   : in  std_logic; --! Initialisation control, active low

    --! Reset output, active low. Active when the reset variable is received 
    --! and the second byte contains the station address.
    rston_o   : out std_logic; --! Reset output, active low


-------------------------------------------------------------------------------
--  USER INTERFACE, non WISHBONE
-------------------------------------------------------------------------------

    --! Signals new data is received and can safely be read (Consumed 
    --! variable 05xyh). In stand-alone mode one may sample the data on the 
    --! first clock edge VAR1_RDY is high.
    var1_rdy_o: out std_logic; --! Variable 1 ready

    --! Signals that the user logic is accessing variable 1. Only used to 
    --! generate a status that verifies that VAR1_RDY was high when 
    --! accessing. May be grounded.
    var1_acc_i: in  std_logic; --! Variable 1 access

    --! Signals new data is received and can safely be read (Consumed 
    --! broadcast variable 04xyh). In stand-alone mode one may sample the 
    --! data on the first clock edge VAR1_RDY is high.
    var2_rdy_o: out std_logic; --! Variable 2 ready

    --! Signals that the user logic is accessing variable 2. Only used to 
    --! generate a status that verifies that VAR2_RDY was high when 
    --! accessing. May be grounded.
    var2_acc_i: in  std_logic; --! Variable 2 access

    --! Signals that the variable can safely be written (Produced variable 
    --! 06xyh). In stand-alone mode, data is sampled on the first clock after
    --! VAR_RDY is deasserted.
    var3_rdy_o: out std_logic; --! Variable 3 ready

    --! Signals that the user logic is accessing variable 3. Only used to 
    --! generate a status that verifies that VAR3_RDY was high when 
    --! accessing. May be grounded.
    var3_acc_i: in  std_logic; --! Variable 3 access

 --   dummy_o : out std_logic;
-------------------------------------------------------------------------------
--  USER INTERFACE, WISHBONE SLAVE
-------------------------------------------------------------------------------
    wclk_i    : in  std_logic; --! Wishbone clock. May be independent of UCLK.

    --! Data in. Wishbone access only on bits 7-0. Bits 15-8 only used
    --! in stand-alone mode.
    dat_i     : in  std_logic_vector (15 downto 0); --! Data in

    --! Data out. Wishbone access only on bits 7-0. Bits 15-8 only used
    --! in stand-alone mode.
    dat_o     : out std_logic_vector (15 downto 0); --! Data out
    --  dat_i     : in  std_logic_vector(15 downto 0);
    adr_i     : in  std_logic_vector ( 9 downto 0); --! Address
    rst_i     : in  std_logic; --! Wishbone reset. Does not reset other internal logic.
    stb_i     : in  std_logic; --! Strobe
    ack_o     : out std_logic; --! Acknowledge
    we_i      : in  std_logic  --! Write enable

    );

--    attribute syn_insert_buffer : string;
--attribute syn_insert_buffer of wclk_i : signal is "GL25";

end entity nanofip;
--============================================================================
-- end of entity declaration
--============================================================================



--============================================================================
--============================================================================
--! architecture declaration for nanofip
--============================================================================
--============================================================================

--! Architecture contains only connectivity
architecture struc of nanofip is
attribute syn_radhardlevel : string;
attribute syn_radhardlevel of struc: architecture is "tmr";
  component CLKBUF
     port (PAD : in std_logic;
           Y : out std_logic);
           end component;


  signal s_append_status_from_control : std_logic;
  signal s_data_length_from_control :  std_logic_vector(6 downto 0);
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
  signal s_add_offset_from_control : std_logic_vector(6 downto 0);
  signal addr_from_wb : std_logic_vector(9 downto 0);
  signal s_crc_ok_from_rx : std_logic;
  signal fss_decoded_p_from_rx : std_logic;
  --signal frame_ok_from_rx : std_logic;
  signal s_stat : std_logic_vector(7 downto 0);
  signal  s_ack_produced, s_ack_consumed, s_ack_o: std_logic;
  signal s_stat_sent_p, s_sending_stat: std_logic;
  signal s_mps_sent_p, s_sending_mps: std_logic;
  signal s_code_violation_p : std_logic;
  signal s_crc_bad_p : std_logic;
  -- signal s_crc_ok_from_rx : std_logic;
  signal s_var1_rdy : std_logic;
  signal s_var2_rdy : std_logic;
  signal s_var3_rdy : std_logic;
--  signal s_var1_access_wb_clk  : std_logic;
--  signal s_var2_access_wb_clk  : std_logic;
--  signal s_var3_access_wb_clk : std_logic;
--  signal s_reset_var1_access : std_logic;
--  signal s_reset_var2_access : std_logic;
--  signal s_reset_var3_access : std_logic;
--signal s_stat : std_logic_vector(7 downto 0);
  signal s_mps : std_logic_vector(7 downto 0);
  signal s_wb_d : std_logic_vector(15 downto 0);
  signal s_long_dummy_reg : std_logic_vector(1000 downto 0);
--  signal s_wclk : std_logic;
begin


  ureset_logic : reset_logic 
    port map(
      uclk_i => uclk_i,
      rstin_i => rstin_i,
      rston_o => rston_o,

      var_i => s_var_from_control, 
      rst_o => s_rst  
      );


  uwf_tx_rx : wf_tx_rx 

    port map(
      uclk_i => uclk_i,
      rst_i => s_rst,

      start_send_p_i  => s_start_send_p,
      request_byte_p_o  => s_request_byte_from_tx_p,
      byte_ready_p_i  => s_byte_to_tx_ready_p,
      byte_i  => s_byte_to_tx,
      last_byte_p_i  => s_last_byte_to_tx_p,

--   clk_fixed_carrier_p_o : out std_logic;
      d_o  => fx_txd_o,
      d_e_o => fd_txena_o,
      d_clk_o => fd_txck_o,

      d_a_i  => fx_rxd_i,
      
      rate_i  => rate_i,
      
      byte_ready_p_o  => s_byte_from_rx_ready_p,
      byte_o  => s_byte_from_rx,
      fss_decoded_p_o => fss_decoded_p_from_rx,   -- The frame decoder has detected the start of a frame

      last_byte_p_o  => s_last_byte_from_rx_p,
      code_violation_p_o  => s_code_violation_p,
      crc_bad_p_o  => s_crc_bad_p,

      crc_ok_p_o  => s_crc_ok_from_rx 

      );

  uwf_engine_control : wf_engine_control 
    generic map( C_QUARTZ_PERIOD => 25.0)

    port map(
      uclk_i    => uclk_i, --! User Clock
      rst_i     => s_rst, 
      -- Transmiter interface
      start_send_p_o => s_start_send_p , 
      request_byte_p_i => s_request_byte_from_tx_p, 
      byte_ready_p_o => s_byte_to_tx_ready_p, 
-- 	byte_o : out std_logic_vector(7 downto 0);
      last_byte_p_o => s_last_byte_to_tx_p, 
      

      -- Receiver interface
      fss_decoded_p_i => fss_decoded_p_from_rx,   -- The frame decoder has detected the start of a frame
      byte_ready_p_i => s_byte_from_rx_ready_p,   -- The frame docoder ouputs a new byte on byte_i
      byte_i => s_byte_from_rx,  -- Decoded byte
      frame_ok_p_i => s_crc_ok_from_rx,   
      
      -- Worldfip bit rate
      rate_i  => rate_i, 
      
      subs_i    => subs_i,  --! Subscriber number coding.
      p3_lgth_i => p3_lgth_i, --! Produced variable data length

      slone_i   => slone_i,  --! Stand-alone mode
      nostat_i   => nostat_i, --! No NanoFIP status transmission

-------------------------------------------------------------------------------
--  USER INTERFACE, non WISHBONE
-------------------------------------------------------------------------------
      var1_rdy_o => s_var1_rdy,  --! Variable 1 ready

      var2_rdy_o => s_var2_rdy, --! Variable 2 ready


      --! Signals that the variable can safely be written (Produced variable 
      --! 06xyh). In stand-alone mode, data is sampled on the first clock after
      --! VAR_RDY is deasserted.
      var3_rdy_o => s_var3_rdy, --! Variable 3 ready

--   prod_byte_i : in std_logic_vector(7 downto 0);
      var_o  => s_var_from_control,
      append_status_o  => s_append_status_from_control,
      add_offset_o => s_add_offset_from_control,
      data_length_o => s_data_length_from_control,
      cons_byte_we_p_o => s_cons_byte_we_from_control
      );

      var1_rdy_o <= s_var1_rdy;  --! Variable 1 ready
      var2_rdy_o <= s_var2_rdy; --! Variable 2 ready
      var3_rdy_o <= s_var3_rdy; --! Variable 3 ready

  uwf_consumed_vars : wf_consumed_vars 

    port map(
      uclk_i => uclk_i, --! User Clock
      rst_i  => s_rst, 
      slone_i   => slone_i, --! Stand-alone mode
      byte_ready_p_i  => s_cons_byte_we_from_control,
      var_i  => s_var_from_control,
      add_offset_i  => s_add_offset_from_control,
      byte_i  => s_byte_from_rx,

 --     var1_access_wb_clk_o => s_var1_access_wb_clk,
 --     var2_access_wb_clk_o => s_var2_access_wb_clk,

 --     reset_var1_access_i => s_reset_var1_access,
 --     reset_var2_access_i => s_reset_var2_access,

      wb_clk_i => wclk_i,   
      wb_dat_o => dat_o,   
      wb_adr_i => adr_i,   
      wb_stb_p_i => stb_i,   
      wb_ack_p_o => s_ack_consumed,   
      wb_we_p_i => we_i

      );


  uwf_produced_vars : wf_produced_vars

    port map(
      uclk_i  => uclk_i,  --! User Clock
      rst_i => s_rst,  
      m_id_i  => m_id_i,   --! Model identification settings
      c_id_i => c_id_i,   --! Constructor identification settings
      slone_i  => slone_i,  --! Stand-alone mode
      nostat_i => nostat_i,  --! No NanoFIP status transmission
      subs_i => subs_i, 
      sending_stat_o => s_sending_stat, --! The status register is being adressed
      sending_mps_o => s_sending_mps, --! The status register is being adressed

      stat_i => s_stat,  -- NanoFIP status
      mps_i => s_mps,
      
  --    var3_access_wb_clk_o => s_var3_access_wb_clk,
  --    reset_var3_access_i => s_reset_var3_access,
      
      var_i => s_var_from_control,  
      append_status_i => s_append_status_from_control,  
      add_offset_i => s_add_offset_from_control,  
      data_length_i => s_data_length_from_control,  
      byte_o => s_byte_to_tx,
-------------------------------------------------------------------------------
--!  USER INTERFACE. Data and address lines synchronized with uclk_i
-------------------------------------------------------------------------------
      wb_dat_i => s_wb_d,   
      wb_clk_i => wclk_i,   
      wb_adr_i => adr_i,   
      wb_stb_p_i => stb_i,   
      wb_ack_p_o => s_ack_produced,   
      wb_we_p_i => we_i   
      );


  ack_o <= s_ack_produced or s_ack_consumed; 

  ustatus_gen : status_gen 
    port map(
      uclk_i => uclk_i,
      rst_i => s_rst,

      fd_wdgn_i => fd_wdgn_i,
      fd_txer_i => fd_txer_i,


      code_violation_p_i => s_code_violation_p,
      crc_bad_p_i => s_crc_bad_p,

      var1_rdy_i => s_var1_rdy,
      var2_rdy_i => s_var2_rdy,
      var3_rdy_i => s_var3_rdy,

      var1_access_a_i => var1_acc_i,
      var2_access_a_i => var2_acc_i,
      var3_access_a_i => var3_acc_i,

 --     reset_var1_access_o => s_reset_var1_access,
 --     reset_var2_access_o => s_reset_var2_access,
 --     reset_var3_access_o => s_reset_var3_access,

      stat_sent_p_i => s_stat_sent_p,
      mps_sent_p_i => s_mps_sent_p,
      
      stat_o => s_stat,
      mps_o => s_mps
      );

  s_ack_o <= s_ack_produced or s_ack_consumed;
  s_stat_sent_p <= s_sending_stat and s_byte_to_tx_ready_p; --! The status register is being adressed
  s_mps_sent_p <= s_sending_stat and s_byte_to_tx_ready_p; --! The status register is being adressed


  fd_rstn_o <= '1';
  s_id_o <= "0" & fx_rxa_i; -- I connect fx_rxa_i to s_id_o just to test the pinout
  
  



--UCLKBUF : CLKBUF 
--            port map(
--            PAD => wclk_i, 
--            Y => s_wclk);

process(wclk_i)
begin
 if rising_edge(wclk_i) then
      if s_rst = '1' then
         s_wb_d <= (others => '0');
         s_long_dummy_reg <= (others => '0');
      else
         s_wb_d <= dat_i;
         s_long_dummy_reg  <= s_long_dummy_reg(s_long_dummy_reg'left - 1 downto 0) & fx_rxa_i;
      end if;
   end if;
end process;

--dummy_o <= s_long_dummy_reg(s_long_dummy_reg'left);

end architecture struc;
--============================================================================
--============================================================================
-- architecture end
--============================================================================
--============================================================================

-------------------------------------------------------------------------------
--                          E N D   O F   F I L E
-------------------------------------------------------------------------------