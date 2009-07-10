--===========================================================================
--! @file produced_rom.vhd
--! @brief ROM that stores the fixed parts of Produced variables
--===========================================================================
--! Standard library
library IEEE;
--! Standard packages
use IEEE.STD_LOGIC_1164.all; --! std_logic definitions
use IEEE.NUMERIC_STD.all;    --! conversion functions


-------------------------------------------------------------------------------
--                                                                           --
--                                produced_rom                               --
--                                                                           --
--                               CERN, BE/CO/HT                              --
--                                                                           --
-------------------------------------------------------------------------------
--
-- unit name: produced_rom
--
--! @brief ROM that stores the fixed parts of Produced variables.
--!
--! Used in the NanoFIP design. \n
--! This ROM stores the fixed parts of Produced variables, including the
--! full contents of the Presence variable.\n
--! Reading is controlled by the tx_engine.
--!
--! SEE mitigation techniques used:
--! The ROM will not need any SEE mitigation techniques as the FlashROM used
--! in the Actel is supposedly not upsettable.
--! Of course it may also be implemented as logic generating the 15 or so
--! constants.
--! 
--! @attention The FlashROM of a ProASIC3 has a maximum clock frequency of
--! 15 MHz and a Tcko of up to 29 ns!
--!
--! @author Erik van der Bij (Erik.van.der.Bij@cern.ch)
--
--! @date 06/07/2009
--
--! @version v0.01
--
--! @details 
--!
--! <b>Dependencies:</b>
--! - tx_engine
--! - data_if
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
--! Entity declaration for consumed_rom
--============================================================================
entity produced_rom is

port (
-------------------------------------------------------------------------------
-- Connections to wf_tx_rx (WorldFIP received data)
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
--  Connections to wf_engine
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
--  Connections to data_if
-------------------------------------------------------------------------------


   du1_i     : in  std_logic; --! Strobe
   du2_o     : out std_logic; --! Acknowledge
   du3_i     : in  std_logic  --! Write enable

);

end entity produced_rom;



-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- COMPONENT DECLARATIONS
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--! ARCHITECTURE OF PRODUCED_ROM
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
architecture rtl of produced_rom is
begin

end architecture rtl;
-------------------------------------------------------------------------------
--                          E N D   O F   F I L E
-------------------------------------------------------------------------------
