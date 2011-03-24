--_________________________________________________________________________________________________
--                                                                                                |
--                                        |The nanoFIP|                                           |
--                                                                                                |
--                                        CERN,BE/CO-HT                                           |
--________________________________________________________________________________________________|
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--! @file WF_fd_transmitter.vhd                                                                   |
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
--                                         WF_fd_transmitter                                     --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
--
--! @brief     The unit groups the main actions that regard data transmission.
--!            It instantiates the units:
--!
--!              o WF_tx_serializer : that receives bytes from the WF_Production, encodes them
--!                                   (Manchester 2), adds the FSS, FCS & FES fields and puts one
--!                                   by one bits to the FIELDRIVE output FD_TXD, following the
--!                                   synchronization signals from the WF_tx_osc unit.
--!                                   Also generates the nanoFIP output FD_TXENA.
--!
--!              o WF_tx_osc        : that generates the nanoFIP FIELDRIVE output FD_TXCK
--!                                   and the array of pulses tx_clk_p_buff (used for the
--!                                   synchronization of the WF_tx_serializer).
--!                                ___________________________________________________________
--!                               |                                                           |
--!                               |                       WF_Production                       |
--!                               |___________________________________________________________|
--!                                                            \/
--!                                ___________________________________________________________
--!                               |                     WF_fd_transmitter                     |
--!                               |                                                           |
--!                               |      ________________________________________________     |
--!                               |     |                                                |    |
--!                               |     |                  WF_tx_osc                     |    |
--!                               |     |________________________________________________|    |
--!                               |                            \/                             |
--!                               |     _________________________________________________     |
--!                               |    |                                                 |    |
--!                               |    |                 WF_tx_serializer                |    |
--!                               |    |                                                 |    |
--!                               |    |_________________________________________________|    |
--!                               |___________________________________________________________|
--!                                                            \/
--!                            ___________________________________________________________________
--!                          0_____________________________FIELDBUS______________________________O
--!
--!
--!
--
--
--! @author    Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)
--!            Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)
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
--!   \n<b>Dependencies:</b>     \n
--!            WF_reset_unit     \n
--!            WF_production     \n
--!            WF_engine_control \n
--
--
--!   \n<b>Modified by:</b>\n
--
---------------------------------------------------------------------------------------------------
--
--!   \n\n<b>Last changes:</b>\n
--!     ->
--
---------------------------------------------------------------------------------------------------
--
--! @todo
--! ->
--
---------------------------------------------------------------------------------------------------



--=================================================================================================
--!                           Entity declaration for WF_fd_transmitter
--=================================================================================================

entity WF_fd_transmitter is

  port (
  -- INPUTS
    -- nanoFIP User Interface, General signal
    uclk_i                     : in std_logic; --! 40 MHz clock

    -- nanoFIP WorldFIP Settings
    rate_i                     : in std_logic_vector (1 downto 0); --! WorldFIP bit rate

    -- Signal from the WF_reset_unit
    nfip_rst_i                 : in std_logic; --! nanoFIP internal reset

    -- Signals from the WF_production unit
    tx_byte_i                  : in std_logic_vector (7 downto 0); --! byte to be delivered

    -- Signals from the WF_engine_control
    tx_start_p_i               : in std_logic; --! indication for the start of the production
    tx_byte_request_accept_p_i : in std_logic; --! indication that a byte is ready to be delivered
    tx_last_data_byte_p_i      : in std_logic; --! indication of he last data byte
                                               --  (CRC, FES not included)



  -- OUTPUTS
    -- Signal to the WF_engine_control
    tx_completed_p_o           : out std_logic;
    tx_byte_request_p_o        : out std_logic;--! request for a new byte to be transmitted; pulse
                                               --! at the end of the transmission of a previous byte

    -- nanoFIP FIELDRIVE outputs
    tx_data_o                  : out std_logic;--! transmitter data
    tx_enable_o                : out std_logic;--! transmitter enable
    tx_clk_o                   : out std_logic --! line driver half bit clock
    );
end entity WF_fd_transmitter;


--=================================================================================================
--!                                    architecture declaration
--=================================================================================================
architecture struc of WF_fd_transmitter is

  signal s_tx_clk_p_buff : std_logic_vector (c_TX_CLK_BUFF_LGTH-1 downto 0);
  signal s_tx_osc_rst_p  : std_logic;


--=================================================================================================
--!                                       architecture begin
--=================================================================================================
begin


---------------------------------------------------------------------------------------------------
--                                           Oscillator                                          --
---------------------------------------------------------------------------------------------------

--!@brief Instantiation of the WF_tx_osc unit

  tx_oscillator: WF_tx_osc
  port map (
    uclk_i          => uclk_i,
    rate_i          => rate_i,
    nfip_rst_i      => nfip_rst_i,
    tx_osc_rst_p_i  => s_tx_osc_rst_p,
   -----------------------------------------------
    tx_clk_o        => tx_clk_o,
    tx_clk_p_buff_o => s_tx_clk_p_buff);
   -----------------------------------------------



---------------------------------------------------------------------------------------------------
--                                           Serializer                                          --
---------------------------------------------------------------------------------------------------

--!@brief Instantiation of the WF_tx_serializer unit

  tx_serializer: WF_tx_serializer
  port map (
    uclk_i                   => uclk_i,
    nfip_rst_i               => nfip_rst_i,
    tx_start_p_i             => tx_start_p_i,
    byte_request_accept_p_i  => tx_byte_request_accept_p_i,
    byte_i                   => tx_byte_i,
    last_byte_p_i            => tx_last_data_byte_p_i,
    tx_clk_p_buff_i          => s_tx_clk_p_buff,
   -----------------------------------------------
    tx_byte_request_p_o      => tx_byte_request_p_o,
    tx_completed_p_o         => tx_completed_p_o,
    tx_data_o                => tx_data_o,
    tx_osc_rst_p_o           => s_tx_osc_rst_p,
    tx_enable_o              => tx_enable_o );
   -----------------------------------------------



end architecture struc;
--=================================================================================================
--                                        architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------