--===========================================================================
--! @file nanofip.vhd
--===========================================================================
--! Standard library
library IEEE;
--! Standard packages
use IEEE.STD_LOGIC_1164.all; --! std_logic definitions
use IEEE.NUMERIC_STD.all;    --! conversion functions


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
--! @brief Top level design file of nanofip.
--!
--! The NanoFIP is an FPGA component implementing the WorldFIP protocol that
--! can be used in field devices able to communicate at the three standard 
--! speeds. The NanoFIP, that is developed as part of the WorldFIP insourcing
--! project, is designed to be radiation tolerant by using different single 
--! event upset mitigation techniques such as triple module redundancy. 
--! The device is used in conjunction with a FielDrive driver chip and FieldTR
--! insulating transformer, both available from the company ALSTOM. 
--!
--! Design based on NanoFIP functional specification v1.2 
--! http://www.ohwr.org/twiki/pub/OHR/CernFIP/WP3/cernfip_fspec1_2.pdf
--!
--! More information at http://www.ohwr.org/twiki/bin/view/OHR/CernFIP/ \n
--! 
--
--! @author Erik van der Bij (Erik.van.der.Bij@cern.ch)
--
--! @date 30/06/2009
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
--! 30/06/2009  v0.01  EB  First version \n
--!
-------------------------------------------------------------------------------
--! @todo Create entity \n
--
-------------------------------------------------------------------------------



--============================================================================
--! Entity declaration for long entity name of my_entity
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
   adr_i     : in  std_logic_vector ( 9 downto 0); --! Address
   rst_i     : in  std_logic; --! Wishbone reset. Does not reset other internal logic.
   stb_i     : in  std_logic; --! Strobe
   ack_o     : out std_logic; --! Acknowledge
   we_i      : in  std_logic --! Write enable

);

end entity nanofip;


--! Architecture contains only connectivity
architecture struc of nanofip is
begin
end a1;

-------------------------------------------------------------------------------
--                          E N D   O F   F I L E
-------------------------------------------------------------------------------
