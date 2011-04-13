--_________________________________________________________________________________________________
--                                                                                                |
--                                        |The nanoFIP|                                           |
--                                                                                                |
--                                        CERN,BE/CO-HT                                           |
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
-- File         WF_fd_receiver.vhd                                                                |
---------------------------------------------------------------------------------------------------

-- Standard library
library IEEE;
-- Standard packages
use IEEE.STD_LOGIC_1164.all; -- std_logic definitions
use IEEE.NUMERIC_STD.all;    -- conversion functions

-- Specific packages
use work.WF_PACKAGE.all;     -- definitions of types, constants, entities

---------------------------------------------------------------------------------------------------
--                                                                                               --
--                                         WF_fd_receiver                                        --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
--
-- Description  The unit groups the main actions that regard FIELDRIVE data reception.
--              It instantiates the units:
--
--              o WF_rx_deserializer : for the formation of bytes of data to be provided to the:
--                                     o WF_engine_control unit, for the contents of ID_DAT frames
--                                     o WF_cons_bytes_processor unit, for the contents of consumed
--                                       RP_DAT frames
--
--              o WF_rx_osc          : for the clock recovery
--
--              o WF_rx_deglitcher   : for the filtering of the input FD_RXD
--
--
--                                _________________________         _________________________
--                               |                         |       |                         |
--                               |      WF_Consumption     |       |    WF_engine_control    |
--                               |_________________________|       |_________________________|
--                                           /\                                /\
--                                ___________________________________________________________
--                               |                      WF_fd_revceiver                      |
--                               |                                                _________  |
--                               |   _______________________________________     |         | |
--                               |  |                                       |    |         | |
--                               |  |           WF_rx_deserializer          |    |  WF_rx  | |
--                               |  |                                       |  < |  _osc   | |
--                               |  |_______________________________________|    |         | |
--                               |                     /\                        |_________| |
--                               |   _______________________________________                 |
--                               |  |                                       |                |
--                               |  |            WF_rx_deglitcher           |                |
--                               |  |_______________________________________|                |
--                               |                                                           |
--                               |___________________________________________________________|
--                                                            \/
--                            ___________________________________________________________________
--                          0_____________________________FIELDBUS______________________________O
--
--
-- Authors      Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)
--              Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)
--
--
-- Date         15/02/2011
--
--
-- Version      v0.01
--
--
-- Depends on   WF_reset_unit
--              WF_engine_control
--
--
---------------------------------------------------------------------------------------------------
--
-- Last changes
--     ->
--
---------------------------------------------------------------------------------------------------



--=================================================================================================
--                              Entity declaration for WF_fd_receiver
--=================================================================================================
entity WF_fd_receiver is

  port (
  -- INPUTS
    -- nanoFIP User Interface, General signals
    uclk_i                : in std_logic;  -- 40 MHZ clock

    -- nanoFIP WorldFIP Settings
    rate_i                : in std_logic_vector (1 downto 0);  -- WorldFIP bit rate

    -- nanoFIP FIELDRIVE
    fd_rxd_a_i            : in std_logic;  -- receiver data

    -- Signal from the WF_reset_unit
    nfip_rst_i            : in std_logic;  -- nanoFIP internal reset

    -- Signal from the WF_engine_control unit
    rx_rst_i              : in std_logic;  -- reset during production or
                                           -- reset if consumption is lasting more than
                                           -- expected (ID_DAT > 8 bytes, RP_DAT > 133 bytes)


  -- OUTPUTS
    -- Signals to the WF_engine_control and WF_consumption
    rx_byte_o             : out std_logic_vector (7 downto 0); -- retrieved data byte
    rx_byte_ready_p_o     : out std_logic; -- pulse indicating a new retrieved data byte
    rx_fss_crc_fes_ok_p_o : out std_logic; -- indication of a frame (ID_DAT or RP_DAT) with
                                           -- correct FSS, FES & CRC; pulse upon FES detection
    rx_crc_wrong_p_o      : out std_logic; -- indication of a frame (ID_DAT or RP_DAT) with
                                           -- wrong CRC; pulse upon FES detection

    -- Signals to the WF_engine_control
    rx_fss_received_p_o   : out std_logic  -- pulse upon FSS detection (ID/ RP_DAT)

    );

end entity WF_fd_receiver;


--=================================================================================================
--                                    architecture declaration
--=================================================================================================
architecture struc of WF_fd_receiver is

  signal s_rx_osc_rst, s_adjac_bits_window, s_signif_edge_window : std_logic;
  signal s_sample_bit_p, s_sample_manch_bit_p                    : std_logic;
  signal s_fd_rxd_filt, s_rxd_filt_edge_p                        : std_logic;
  signal s_fd_rxd_filt_f_edge_p, s_fd_rxd_filt_r_edge_p          : std_logic;

--=================================================================================================
--                                       architecture begin
--=================================================================================================
begin


---------------------------------------------------------------------------------------------------
--                                          Deglitcher                                           --
---------------------------------------------------------------------------------------------------

  FIELDRIVE_Receiver_Deglitcher: WF_rx_deglitcher
  port map (
    uclk_i                 => uclk_i,
    nfip_rst_i             => nfip_rst_i,
    fd_rxd_a_i             => fd_rxd_a_i,
  -----------------------------------------------------------------
    fd_rxd_filt_o          => s_fd_rxd_filt,
    fd_rxd_filt_edge_p_o   => s_rxd_filt_edge_p,
    fd_rxd_filt_f_edge_p_o => s_fd_rxd_filt_f_edge_p);
  -----------------------------------------------------------------

    s_fd_rxd_filt_r_edge_p <= s_rxd_filt_edge_p and (not s_fd_rxd_filt_f_edge_p);



---------------------------------------------------------------------------------------------------
--                                          Oscillator                                           --
---------------------------------------------------------------------------------------------------

  FIELDRIVE_Receiver_Oscillator: WF_rx_osc
  port map (
    uclk_i                  => uclk_i,
    rate_i                  => rate_i,
    nfip_rst_i              => nfip_rst_i,
    fd_rxd_edge_p_i         => s_rxd_filt_edge_p,
    rx_osc_rst_i            => s_rx_osc_rst,
   ------------------------------------------------------
    rx_manch_clk_p_o        => s_sample_manch_bit_p,
    rx_bit_clk_p_o          => s_sample_bit_p,
    rx_signif_edge_window_o => s_signif_edge_window,
    rx_adjac_bits_window_o  => s_adjac_bits_window);
   -----------------------------------------------------



---------------------------------------------------------------------------------------------------
--                                         Deserializer                                          --
---------------------------------------------------------------------------------------------------

  FIELDRIVE_Receiver_Deserializer: WF_rx_deserializer
  port map (
    uclk_i               => uclk_i,
    nfip_rst_i           => nfip_rst_i,
    rx_rst_i             => rx_rst_i,
    sample_bit_p_i       => s_sample_bit_p,
    sample_manch_bit_p_i => s_sample_manch_bit_p,
    signif_edge_window_i => s_signif_edge_window,
    adjac_bits_window_i  => s_adjac_bits_window,
    fd_rxd_f_edge_p_i    => s_fd_rxd_filt_f_edge_p,
    fd_rxd_r_edge_p_i    => s_fd_rxd_filt_r_edge_p,
    fd_rxd_i             => s_fd_rxd_filt,
   ------------------------------------------------------
    byte_ready_p_o       => rx_byte_ready_p_o,
    byte_o               => rx_byte_o,
    fss_crc_fes_ok_p_o   => rx_fss_crc_fes_ok_p_o,
    rx_osc_rst_o         => s_rx_osc_rst,
    fss_received_p_o     => rx_fss_received_p_o,
    crc_wrong_p_o        => rx_crc_wrong_p_o);
   ------------------------------------------------------


end architecture struc;

--=================================================================================================
--                                        architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------