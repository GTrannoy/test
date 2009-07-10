--===========================================================================
--! @file consumed_ram.vhd
--! @brief RAM that stores the Consumed variables
--===========================================================================
--! Standard library
library IEEE;
--! Standard packages
use IEEE.STD_LOGIC_1164.all; --! std_logic definitions
use IEEE.NUMERIC_STD.all;    --! conversion functions


-------------------------------------------------------------------------------
--                                                                           --
--                                consumed_ram                               --
--                                                                           --
--                               CERN, BE/CO/HT                              --
--                                                                           --
-------------------------------------------------------------------------------
--
-- unit name: consumed_ram
--
--! @brief RAM that stores the Consumed variables.
--!
--! Used in the NanoFIP design.
--! Data is written to it from the WorldFIP receiver entity wf_tx_rx. 
--! Writing is controlled by the wf_engine dependent on the data type received.
--! Reading is controlled by the data_if, the Wishbone interface.
--!
--! The module implements triple redundancy to allow to mask SEU errors.
--! No 'scrubbing' of the memory (refresh with corrected data) is needed as
--! the data will be rewritten every WorldFIP cycle time anyway 
--! (typically 20-1000 ms).
--! 
--!
--! @author Erik van der Bij (Erik.van.der.Bij@cern.ch)
--
--! @date 06/07/2009
--
--! @version v0.1
--
--! @details 
--!
--! <b>Dependencies:</b>\n
--! wf_tx_rx
--! data_if
--!
--! <b>References:</b>\n
--! 
--! 
--!
--! <b>Modified by:</b>\n
--! Author: Erik van der Bij
-------------------------------------------------------------------------------
--! \n\n<b>Last changes:</b>\n
--! 06/07/2009  v0.01  EB  First version \n
--!
-------------------------------------------------------------------------------
--! @todo Define I/O signals \n
--!
-------------------------------------------------------------------------------



--============================================================================
-- Entity declaration for consumed_ram
--============================================================================
entity consumed_ram is

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

end entity consumed_ram;



-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- COMPONENT DECLARATIONS
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--! ARCHITECTURE OF CONSUMED_RAM
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
architecture rtl of consumed_ram is
begin

end architecture rtl;
-------------------------------------------------------------------------------
--                          E N D   O F   F I L E
-------------------------------------------------------------------------------
