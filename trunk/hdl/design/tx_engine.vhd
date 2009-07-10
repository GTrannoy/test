--===========================================================================
--! @file tx_engine.vhd
--! @brief Sends RP_DAT frames
--===========================================================================
--! Standard library
library IEEE;
--! Standard packages
use IEEE.STD_LOGIC_1164.all; --! std_logic definitions
use IEEE.NUMERIC_STD.all;    --! conversion functions


-------------------------------------------------------------------------------
--                                                                           --
--                                 tx_engine                                 --
--                                                                           --
--                               CERN, BE/CO/HT                              --
--                                                                           --
-------------------------------------------------------------------------------
--
-- unit name: tx_engine
--
--! @brief Sends RP_DAT frames.
--!
--! Used in the NanoFIP design. \n
--! The tx_engine unit sends RP_DAT frames under command of the wf_engine.
--! The wf_engine tells what RP_DAT should be given (presence, 
--! identification, var3).\n
--! The data comes from various sources (produced_ram, produced_rom, 
--! status_gen, settings) and is combined before being presented to the 
--! wf_tx_rx.
--!
--!
--! @author Erik van der Bij (Erik.van.der.Bij@cern.ch)
--
--! @date 07/07/2009
--
--! @version v0.01
--
--! @details 
--!
--! <b>Dependencies:</b>\n
--! wf_engine           \n
--! wf_tx_rx            \n
--! reset_logic         \n
--! produced_ram        \n
--! produced_rom        \n
--! status_gen          \n
--! settings            \n
--!
--! <b>References:</b>\n
--! 
--! 
--!
--! <b>Modified by:</b>\n
--! Author: Erik van der Bij
-------------------------------------------------------------------------------
--! \n\n<b>Last changes:</b>\n
--! 07/07/2009  v0.01  EB  First version \n
--!
-------------------------------------------------------------------------------
--! @todo Define I/O signals \n
--!
-------------------------------------------------------------------------------



--============================================================================
--! Entity declaration for tx_engine
--============================================================================
entity tx_engine is

port (
-------------------------------------------------------------------------------
--  Connections to tx_engine
-------------------------------------------------------------------------------
   du1_i     : in  std_logic; --! Strobe
   du2_o     : out std_logic; --! Acknowledge
   du3_i     : in  std_logic  --! Write enable

);

end entity tx_engine;



-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- COMPONENT DECLARATIONS
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--! ARCHITECTURE OF tx_engine
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
architecture rtl of tx_engine is
begin

end architecture rtl;
-------------------------------------------------------------------------------
--                          E N D   O F   F I L E
-------------------------------------------------------------------------------
