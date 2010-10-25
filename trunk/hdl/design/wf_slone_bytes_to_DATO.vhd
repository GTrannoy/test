--=================================================================================================
--! @file wf_slone_bytes_to_DATO.vhd
--=================================================================================================

--! standard library
library IEEE; 

--! standard packages
use IEEE.STD_LOGIC_1164.all;  --! std_logic definitions
use IEEE.NUMERIC_STD.all;     --! conversion functions

--! specific packages
use work.WF_PACKAGE.all;      --! definitions of supplemental types, subtypes, constants

---------------------------------------------------------------------------------------------------
--                                                                                               --
--                                 wf_slone_bytes_to_DATO                                        --
--                                                                                               --
--                                  CERN, BE/CO/HT                                               --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
--
--! @brief     In stand-alone mode, the unit is responsible for transering the two desirialized
--!            bytes from the filedbus to the 2bytes long bus DAT_O. The bytes are put in the bus 
--!            one by one as they arrive.
--!            Note: After the reception of a correct FCS and the FES the signal VAR1_RDY/ VAR2_RDY
--!            is asserted and that signals the user that the data in DAT_O are valid and stable.  
--
--
--! @author    Pablo Alvarez Sanchez (pablo.alvarez.sanchez@cern.ch)
--!            Evangelia Gousiou (evangelia.gousiou@cern.ch)
--
--
--! @date      06/2010
--
--
--! @version   v0.02
--
--
--! @details \n  
--
--!   \n<b>Dependencies:</b>\n
--
--
--!   \n<b>Modified by:</b>\n
--!     Evangelia Gousiou (Evangelia.Gousiou@cern.ch)
--
--------------------------------------------------------------------------------------------------- 
--
--!   \n\n<b>Last changes:</b>\n
--
--------------------------------------------------------------------------------------------------- 
--
--! @todo 
--!   -> 
--
--------------------------------------------------------------------------------------------------- 


--=================================================================================================
--!                           Entity declaration for wf_slone_bytes_to_DATO
--=================================================================================================

entity wf_slone_bytes_to_DATO is

  port (
  -- INPUTS 
    -- User Interface general signals 
    uclk_i :           in std_logic;                     --! 40MHz clock

    -- Signal from the wf_reset_unit unit
    nFIP_u_rst_i :       in std_logic;                     --! internal reset

   -- Signals from wf_cons_bytes_from_rx
    transfer_byte_p_i: in std_logic_vector (1 downto 0); --! 01: byte_i transfered to DAT_o(7:0)
                                                         --! 10: byte_i transfered to DAT_o(15:8)

    -- Signals for the receiver wf_rx
	byte_i :           in std_logic_vector (7 downto 0); --! byte received from the rx unit




  -- OUTPUTS
    -- Signal to wf_prod_bytes_to_tx
    slone_data_o :    out std_logic_vector (15 downto 0) --! output bus DAT_O
      );
end entity wf_slone_bytes_to_DATO;


--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of wf_slone_bytes_to_DATO is


--=================================================================================================
--                                      architecture begin
--=================================================================================================  
  begin

---------------------------------------------------------------------------------------------------
--!@brief synchronous process Data_Transfer_To_Dat_o: In stand-alone mode, accrording to the signal
--! transfer_byte_p_i, the first or second byte of the user interface bus DAT_o takes the
--! incoming byte byte_i.


Data_Transfer_To_Dat_o: process (uclk_i) 
begin
  if rising_edge(uclk_i) then
    if nFIP_u_rst_i = '1' then
      slone_data_o  <= (others => '0');           -- bus initialization
 
    else

      if transfer_byte_p_i(0) = '1' then  -- the 1st byte is transfered in the lsb of the bus 

          slone_data_o(7 downto 0)   <= byte_i; -- the data stays there until a new byte arrives

      end if;                                   


      if transfer_byte_p_i(1) = '1' then  -- the 2nd byte is transfered in the msb of the bus

          slone_data_o(15 downto 8)  <= byte_i; -- the data stays there until a new byte arrives

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