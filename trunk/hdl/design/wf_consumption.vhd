--_________________________________________________________________________________________________
--                                                                                                |
--                                        |The nanoFIP|                                           |
--                                                                                                |
--                                        CERN,BE/CO-HT                                           |
--________________________________________________________________________________________________|
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--! @file WF_consumption.vhd                                                                      |
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
--                                          WF_consumption                                       --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
--
--! @brief     The unit gathers the main actions that regard data consumption.
--!            It instantiates the units:
--!
--!              o WF_rx_deglitcher        : for the filtering of the "nanoFIP FIELDRIVE"
--!                                          input fd_rxd
--!              o WF_rx_deserializer      : for the creation of bytes of data
--!              o WF_cons_bytes_processor : for the manipulation of the data as they arrive (mainly
--!                                          registering them to the RAM or putting them to DAT_O)
--!              o WF_cons_frame_validator : for the validation of the consumed frame, at the end of
--!                                          of its arrival (in terms of FSS, Ctrl, PDU_TYPE, Lgth,
--!                                          CRC bytes & manch. encoding)
--!              o WF_cons_outcome         : for the generation of the "nanoFIP User Interface, NON-
--!                                          WISHBONE" outputs VAR1_RDY and VAR2_RDY (for var_1, var_2)
--!                                          or of the internal signals for the nanoFIP and FIELDRIVE
--!                                          resets (for a var_rst)  
--!
--!                                __       _________________________________
--!                               |        |                                 | 
--!                               |        |         WF_cons_outcome         | 
--!                               |        |_________________________________|
--!                           Level 2                       ^
--!                               |         _________________________________
--!                               |        |                                 | 
--!                               |        |     WF_cons_frame_validator     | 
--!                               |__      |_________________________________|
--!                                                         ^
--!                                __       _________________________________
--!                               |        |                                 | 
--!                           Level 1      |      WF_cons_bytes_processor    |
--!                               |        |                                 | 
--!                               |__      |_________________________________|
--!                                                         ^
--!                                __       _________________________________
--!                               |        |                                 | 
--!                               |        |        WF_rx_deserializer       |
--!                               |        |                                 | 
--!                               |        |_________________________________|
--!                            Level 0                      ^
--!                               |         _________________________________
--!                               |        |                                 | 
--!                               |        |         WF_rx_deglitcher        |
--!                               |__      |_________________________________|
--! 
--!                          _______________________________________________________________
--!                         0__________________________FIELDBUS____________________________O    
--1
--!
--!            Note: In the entity declaration of this unit, below each input signal, we mark
--!            which of the instantiated units needs it.              
--
--
--! @author    Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch) \n
--!            Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)     \n
--
--
--! @date      11/01/2011
--
--
--! @version   v0.01
--
--
--! @details \n  
--
--!   \n<b>Dependencies:</b>    \n
--!     WF_prod_bytes_retriever \n
--!     WF_status_bytes_gen     \n
--!     WF_tx_serializer        \n
--!     WF_engine_control       \n
--
--
--!   \n<b>Modified by:</b>\n
--!     Evangelia Gousiou (Evangelia.Gousiou@cern.ch)
--
--
--!   \n\n<b>Last changes:</b>\n
--!     -> 
--
--
---------------------------------------------------------------------------------------------------
--
--! @todo 
--! ->  
--
--------------------------------------------------------------------------------------------------- 

---/!\----------------------------/!\----------------------------/!\-------------------------/!\---
--                               Synplify Premier D-2009.12 Warnings                             --
-- -- --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --
--                                         No Warnings!                                          --
---------------------------------------------------------------------------------------------------


--=================================================================================================
--!                           Entity declaration for WF_consumption
--=================================================================================================
entity WF_consumption is

  port (
  -- INPUTS 
	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- nanoFIP User Interface, General signals (synchronized with uclk) 

      uclk_i                   : in std_logic;
      -- used by: all the units

      slone_i                  : in std_logic;
      -- used by: WF_cons_bytes_processor for selecting the data storage (RAM or DATO bus)
      -- used by: WF_cons_outcome for the VAR2_RDY signal (stand-alone mode does not treat var_2)


	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- nanoFIP WorldFIP Settings (synchronized with uclk)

       subs_i                  : in std_logic_vector (7 downto 0); 
      -- used by: WF_cons_outcome for checking if the 2 bytes of a var_rst match the station's addr


	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- Signal from the WF_reset_unit unit

      nfip_rst_i               : in std_logic;
      -- used by: all the units


	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- Signals from the nanoFIP FIELDRIVE (WF_inputs_synchronizer)

      fd_rxd_i                 : in std_logic;
     -- used by: WF_deglitcher

      fd_rxd_r_edge_p_i        : in std_logic;
      fd_rxd_f_edge_p_i        : in std_logic; 
     -- used by: WF_deserializer


	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- nanoFIP User Interface, WISHBONE Slave (synchronized with wb_clk)

      wb_clk_i                 : in std_logic;                    
      wb_adr_i                 : in std_logic_vector(9 downto 0);
      wb_cyc_i                 : in std_logic;
      wb_stb_r_edge_p_i        : in std_logic;
      -- used by: WF_cons_bytes_processor for the managment of the Consumption RAM


	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- Signals from the WF_engine_control unit

      var_i                    : in t_var;
      -- used by: WF_cons_bytes_processor, WF_cons_frame_validator and WF_cons_outcome

      byte_index_i             : in std_logic_vector (7 downto 0); 
      -- used by: WF_cons_bytes_processor for the reception coordination 
      -- used by: WF_cons_frame_validator for the validation of the Length byte 

      rst_rx_unit_p_i          : in std_logic;
      -- used by: WF_rx_deserializer


	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- Signals from the WF_rx_tx_osc

      adjac_bits_window_i      : in std_logic;
      signif_edge_window_i     : in std_logic;
      -- used by: WF_rx_deserializer for the timing of the reception

      sample_bit_p_i           : in std_logic;
      sample_manch_bit_p_i     : in std_logic;
      -- used by: WF_rx_deglitcher and WF_rx_deserializer for the timing of the reception


    -----------------------------------------------------------------------------------------------
  -- OUTPUTS 

    -- nanoFIP User Interface, NON-WISHBONE outputs
      var1_rdy_o               : out std_logic;
      var2_rdy_o               : out std_logic;

    -- nanoFIP User Interface, WISHBONE Slave outputs 
      data_o                   : out std_logic_vector (15 downto 0);
      wb_ack_cons_p_o          : out std_logic;                     

    -- Signals to the WF_engine_control
      byte_o                   : out std_logic_vector (7 downto 0);
      byte_ready_p_o           : out std_logic;
      fss_received_p_o         : out std_logic;
      fss_crc_fes_manch_ok_p_o : out std_logic;

    -- Signals to the WF_engine_control and the WF_produce
      crc_wrong_p_o            : out std_logic;

    -- Signals to the WF_produce
      nfip_status_r_tler_o     : out std_logic;

    -- Signals to the WF_reset_unit
      assert_rston_p_o         : out std_logic;
      rst_nfip_and_fd_p_o      : out std_logic;

    -- Signal to the WF_tx_rx_osc
      rst_rx_osc_o             : out std_logic
    );

end entity WF_consumption;



--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture struc of WF_consumption is

  signal s_rxd_filtered, s_rxd_filtered_f_edge_p, s_cons_frame_ok_p, s_crc_wrong_p     : std_logic;
  signal s_sample_bit_p, s_sample_manch_bit_p, s_fss_crc_fes_manch_ok_p, s_byte_ready_p : std_logic;
  signal s_cons_ctrl_byte, s_cons_pdu_byte, s_cons_lgth_byte       : std_logic_vector (7 downto 0); 
  signal s_cons_var_rst_byte_1, s_cons_var_rst_byte_2              : std_logic_vector (7 downto 0); 
  signal s_byte_from_rx                                            : std_logic_vector (7 downto 0); 

--=================================================================================================
--                                      architecture begin
--================================================================================================= 

begin

---------------------------------------------------------------------------------------------------
--                               Consumption Level 0: Deglitcher                                 --
---------------------------------------------------------------------------------------------------
--! @brief Instantiation of the WF_rx_deglitcher unit that applies a glitch filter to the "nanoFIP
--! FIELDRIVE" input signal fd_rxd.

  Consumption_Level_0_Deglitcher : WF_rx_deglitcher 
  generic map (c_DEGLITCH_LGTH => 10)
  port map(
    uclk_i                  => uclk_i,
    nfip_rst_i              => nfip_rst_i,
    rxd_i                   => fd_rxd_i,
    sample_bit_p_i          => sample_bit_p_i,
    sample_manch_bit_p_i    => sample_manch_bit_p_i,
    -------------------------------------------------
    rxd_filtered_o          => s_rxd_filtered,
    rxd_filtered_f_edge_p_o => s_rxd_filtered_f_edge_p,
    sample_manch_bit_p_o    => s_sample_manch_bit_p,
    sample_bit_p_o          => s_sample_bit_p
    -------------------------------------------------
    );

---------------------------------------------------------------------------------------------------
--                             Consumption Level 0 : Deserializer                                --
--------------------------------------------------------------------------------------------------- 
--! @brief Instantiation of the WF_rx_deserializer unit that deserializes the deglitched fd_rxd
--! and constructs bytes of data.

  Consumption_Level_0_Deserializer: WF_rx_deserializer 
  port map (
    uclk_i                   => uclk_i,
    nfip_rst_i               => nfip_rst_i,
    rst_rx_unit_p_i          => rst_rx_unit_p_i,
    sample_bit_p_i           => s_sample_bit_p,
    signif_edge_window_i     => signif_edge_window_i,
    adjac_bits_window_i      => adjac_bits_window_i,
    rxd_f_edge_p_i           => fd_rxd_f_edge_p_i,
    rxd_r_edge_p_i           => fd_rxd_r_edge_p_i,
    rxd_filtered_i           => s_rxd_filtered,
    rxd_filtered_f_edge_p_i  => s_rxd_filtered_f_edge_p,
    sample_manch_bit_p_i     => s_sample_manch_bit_p,
    -------------------------------------------------
    byte_ready_p_o           => s_byte_ready_p,
    byte_o                   => s_byte_from_rx,
    fss_crc_fes_manch_ok_p_o => s_fss_crc_fes_manch_ok_p,
    rst_rx_osc_o             => rst_rx_osc_o,
    fss_received_p_o         => fss_received_p_o,
    crc_wrong_p_o            => s_crc_wrong_p
    -------------------------------------------------
    );

---------------------------------------------------------------------------------------------------
--                            Consumption Level 1 : Bytes Processing                             --
--------------------------------------------------------------------------------------------------- 
--! @brief Instantiation of the WF_cons_bytes_processor unit that is "consuming" data bytes
--! arriving from the WF_rx_deserializer, by registering them to the Consumed memories or by
--! transferring them to the "nanoFIP User Interface, NON_WISHBONE" output bus DAT_O.

  Consumption_Level_1_bytes_processor : WF_cons_bytes_processor 
  port map(
    uclk_i                => uclk_i,
    nfip_rst_i            => nfip_rst_i, 
    slone_i               => slone_i,
    byte_ready_p_i        => s_byte_ready_p,
    var_i                 => var_i,
    byte_index_i          => byte_index_i,
    byte_i                => s_byte_from_rx,
    wb_clk_i              => wb_clk_i,   
    wb_adr_i              => wb_adr_i,   
    wb_stb_r_edge_p_i     => wb_stb_r_edge_p_i,   
    wb_cyc_i              => wb_cyc_i, 
    -------------------------------------------------
    wb_ack_cons_p_o       => wb_ack_cons_p_o, 
    data_o                => data_o,
    cons_ctrl_byte_o      => s_cons_ctrl_byte,
    cons_pdu_byte_o       => s_cons_pdu_byte,         
    cons_lgth_byte_o      => s_cons_lgth_byte,
    cons_var_rst_byte_1_o => s_cons_var_rst_byte_1, 
    cons_var_rst_byte_2_o => s_cons_var_rst_byte_2
    -------------------------------------------------
    ); 

---------------------------------------------------------------------------------------------------
--                              Consumption Level 2 : Validation                                 --
--------------------------------------------------------------------------------------------------- 
--! @brief Instantiation of the WF_cons_frame_validator unit, responsible for the validation of a
--! received RP_DAT frame with respect to the correctness of the Control, PDU_TYPE and Length
--! bytes of the Manchester encoding.

  Consumption_Level_2_Frame_Validator: WF_cons_frame_validator
  port map(
    cons_ctrl_byte_i            => s_cons_ctrl_byte, 
    cons_pdu_byte_i             => s_cons_pdu_byte,    
    cons_lgth_byte_i            => s_cons_lgth_byte,
    rx_fss_crc_fes_manch_ok_p_i => s_fss_crc_fes_manch_ok_p,
    var_i                       => var_i,
    rx_byte_index_i             => byte_index_i,
    -------------------------------------------------------
    nfip_status_r_tler_o        => nfip_status_r_tler_o, 
    cons_frame_ok_p_o           => s_cons_frame_ok_p
    -------------------------------------------------------
      ); 


---------------------------------------------------------------------------------------------------
--                               Consumption Level 2 : Outcome                                   --
--------------------------------------------------------------------------------------------------- 
--! @brief Instantiation of the WF_cons_outcome unit that is generating :
--! the "nanoFIP User Interface, NON_WISHBONE" output signals VAR1_RDY & VAR2_RDY (for a var_1/2)
--! or the nanoFIP internal signals rst_nFIP_and_FD_p and assert_RSTON_p          (for a var_rst).

  Consumption_Level_2_Outcome : WF_cons_outcome
  port map (
    uclk_i                => uclk_i,
    slone_i               => slone_i,
    subs_i                => subs_i,
    nfip_rst_i            => nfip_rst_i, 
    cons_frame_ok_p_i     => s_cons_frame_ok_p,
    var_i                 => var_i,
    cons_var_rst_byte_1_i => s_cons_var_rst_byte_1,
    cons_var_rst_byte_2_i => s_cons_var_rst_byte_2,
    -------------------------------------------------------
    var1_rdy_o            => var1_rdy_o,
    var2_rdy_o            => var2_rdy_o,
    assert_rston_p_o      => assert_rston_p_o,
    rst_nfip_and_fd_p_o   => rst_nfip_and_fd_p_o
    -------------------------------------------------------
      ); 



---------------------------------------------------------------------------------------------------
--                                             Outputs                                           --
--------------------------------------------------------------------------------------------------- 
  byte_o                   <= s_byte_from_rx;
  byte_ready_p_o           <= s_byte_ready_p;
  fss_crc_fes_manch_ok_p_o <= s_fss_crc_fes_manch_ok_p;
  crc_wrong_p_o            <= s_crc_wrong_p;
  
end architecture struc;

--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------
