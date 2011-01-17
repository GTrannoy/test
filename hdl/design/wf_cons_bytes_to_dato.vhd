--_________________________________________________________________________________________________
--                                                                                                |
--                                        |The nanoFIP|                                           |
--                                                                                                |
--                                        CERN,BE/CO-HT                                           |
--________________________________________________________________________________________________|
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--! @file WF_cons_bytes_to_dato.vhd                                                               |
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
--                                      WF_cons_bytes_to_dato                                    --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
--
--! @brief     In stand-alone mode, after the reception of a consumed or consumed broadcast
--!            variable, the unit is responsible for transering the two data-bytes of the variable
--!            to the 2-bytes long bus DAT_O.
--!            The bytes are put in the bus one by one as they arrive, as the signal 
--!            transfer_byte_p_i indicates.
--!
--!            Note: The validity of these transfered bytes is indicated by the "nanoFIP
--!            User Interface, NON_WISHBONE" signals VAR1_RDY/ VAR2_RDY which arrive after
--!            the reception of the FCS and FES bytes.  
--
--
--! @author    Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch) \n
--!            Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)     \n
--
--
--! @date      10/01/2011
--
--
--! @version   v0.02
--
--
--! @details \n  
--
--!   \n<b>Dependencies:</b>    \n
--!     WF_reset_unit           \n
--!     WF_cons_bytes_processor \n
--
--
--!   \n<b>Modified by:</b>\n
--!     Evangelia Gousiou (Evangelia.Gousiou@cern.ch)
--
--------------------------------------------------------------------------------------------------- 
--
--!   \n\n<b>Last changes:</b>\n
--!     -> 11/2010   v0.01  EG  unit created
--!     -> 10/1/2011 v0.02  EG  unit renamed from WF_slone_cons_bytes_to_dato to
--!                             WF_cons_bytes_to_dato; cleaning-up + commenting
--
--------------------------------------------------------------------------------------------------- 
--
--! @todo 
--!   -> 
--
--------------------------------------------------------------------------------------------------- 

---/!\----------------------------/!\----------------------------/!\-------------------------/!\---
--                               Sunplify Premier D-2009.12 Warnings                             --
-- -- --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --
--                                         No Warnings!                                          --
---------------------------------------------------------------------------------------------------


--=================================================================================================
--!                           Entity declaration for WF_cons_bytes_to_dato
--=================================================================================================

entity WF_cons_bytes_to_dato is

  port (
  -- INPUTS 
    -- nanoFIP User Interface, General signals (synchronized with uclk) 
    uclk_i            : in std_logic;                     --! 40MHz clock

    -- Signal from the WF_reset_unit unit
    nfip_urst_i       : in std_logic;                     --! nanoFIP internal reset

    -- Signals from the WF_cons_bytes_processor
    byte_i            : in std_logic_vector (7 downto 0); --! de-serialised byte

    transfer_byte_p_i : in std_logic_vector (1 downto 0); --! 01: byte_i transfered to DAT_O(7:0)
                                                          --! 10: byte_i transfered to DAT_O(15:8)


  -- OUTPUTS
    -- Signal to the WF_prod_bytes_retriever
    slone_data_o      : out std_logic_vector (15 downto 0) --! output bus DAT_O
      );
end entity WF_cons_bytes_to_dato;


--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of WF_cons_bytes_to_dato is


--=================================================================================================
--                                      architecture begin
--=================================================================================================  
begin

---------------------------------------------------------------------------------------------------
--!@brief synchronous process Data_Transfer_To_Dat_o: In stand-alone mode, accrording to the signal
--! transfer_byte_p_i, the first or second byte of the user interface bus DAT_O takes the
--! incoming byte byte_i.
Data_Transfer_To_Dat_o: process (uclk_i) 
  begin
    if rising_edge (uclk_i) then
      if nfip_urst_i = '1' then
        slone_data_o  <= (others => '0');         -- bus initialization
 
      else

        if transfer_byte_p_i(0) = '1' then        -- the 1st byte is transfered in the lsb of the bus 

          slone_data_o(7 downto 0)   <= byte_i;   -- it stays there until a new cons. var arrives

        end if;                                   


        if transfer_byte_p_i(1) = '1' then        -- the 2nd byte is transfered in the msb of the bus

          slone_data_o(15 downto 8)  <= byte_i;   -- it stays there until a new cons. var arrives

        end if;


      end if;
    end if;
  end process;


end architecture rtl;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------