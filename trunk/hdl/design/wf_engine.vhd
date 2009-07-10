--===========================================================================
--! @file wf_engine.vhd
--! @brief Interprets received data and decides the handling
--===========================================================================
--! Standard library
library IEEE;
--! Standard packages
use IEEE.STD_LOGIC_1164.all; --! std_logic definitions
use IEEE.NUMERIC_STD.all;    --! conversion functions


-------------------------------------------------------------------------------
--                                                                           --
--                                 wf_engine                                 --
--                                                                           --
--                               CERN, BE/CO/HT                              --
--                                                                           --
-------------------------------------------------------------------------------
--
-- unit name: wf_engine
--
--! @brief Interprets received data and decides the handling.
--!
--! Used in the NanoFIP design. \n
--! The wf_engine unit interprets the received data (e.g.m ID_DAT, RP_DAT) 
--! and decides on the further handling of it (e.g., store in consumed_ram, 
--! or tell the tx_engine to transmit certain frames.
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
--! wf_tx_rx            \n
--! tx_engine           \n
--! reset_logic         \n
--! consumed_ram        \n
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
--! Entity declaration for wf_engine
--============================================================================
entity wf_engine is

port (
-------------------------------------------------------------------------------
--  Connections to wf_engine
-------------------------------------------------------------------------------
   du1_i     : in  std_logic; --! Strobe
   du2_o     : out std_logic; --! Acknowledge
   du3_i     : in  std_logic  --! Write enable

);

end entity wf_engine;



-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- COMPONENT DECLARATIONS
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--! ARCHITECTURE OF wf_engine
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
architecture rtl of wf_engine is
begin

end architecture rtl;
-------------------------------------------------------------------------------
--                          E N D   O F   F I L E
-------------------------------------------------------------------------------
