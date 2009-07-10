--===========================================================================
--! @file data_if.vhd
--! @brief Data Interface to the User. Wishbone and stand-alone
--===========================================================================
--! Standard library
library IEEE;
--! Standard packages
use IEEE.STD_LOGIC_1164.all; --! std_logic definitions
use IEEE.NUMERIC_STD.all;    --! conversion functions


-------------------------------------------------------------------------------
--                                                                           --
--                                   data_if                                 --
--                                                                           --
--                               CERN, BE/CO/HT                              --
--                                                                           --
-------------------------------------------------------------------------------
--
-- unit name: data_if
--
--! @brief Data Interface to the User. Wishbone and stand-alone.
--!
--! Used in the NanoFIP design. \n
--! The data_if implements the data interface to the user. The main function
--! is interfacing the consumed_ram and produced_ram to the Wishbone interface
--! that is presented to the user.  Also in stand-alone this unit provides
--! the data interface to the user.
--!
--!
--! @author Erik van der Bij (Erik.van.der.Bij@cern.ch)
--
--! @date 06/07/2009
--
--! @version v0.01
--
--! @details 
--!
--! <b>Dependencies:</b>\n
--! consumed_ram        \n
--! produced_ram        \n
--! status_gen          \n
--! reset_logic         \n
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
--! Entity declaration for data_if
--============================================================================
entity data_if is

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

end entity data_if;



-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- COMPONENT DECLARATIONS
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--! ARCHITECTURE OF data_if
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
architecture rtl of data_if is
begin

end architecture rtl;
-------------------------------------------------------------------------------
--                          E N D   O F   F I L E
-------------------------------------------------------------------------------
