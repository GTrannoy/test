--_________________________________________________________________________________________________
--                                                                                                |
--                                        |The nanoFIP|                                           |
--                                                                                                |
--                                        CERN,BE/CO-HT                                           |
--________________________________________________________________________________________________|
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--! @file WF_prod_permit.vhd                                                                      |
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
--                                        WF_prod_permit                                         --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
--
--! @brief     Generation of the "nanoFIP User Interface, NON_WISHBONE" output signal VAR3_RDY,
--!            according to the variable (var_i) that is being treated.   
--
--
--! @author    Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch) \n
--!            Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)     \n
--
--
--! @date      14/1/2011
--
--
--! @version   v0.01
--
--
--! @details \n  
--
--!   \n<b>Dependencies:</b>\n
--!            WF_engine_control \n
--!            WF_reset_unit     \n
--
--
--!   \n<b>Modified by:</b>\n
--!            Evangelia Gousiou (Evangelia.Gousiou@cern.ch)
--
--------------------------------------------------------------------------------------------------- 
--
--!   \n\n<b>Last changes:</b>\n
--!     -> 1/2011  v0.01  EG  First version \n
--
--------------------------------------------------------------------------------------------------- 
--
--! @todo 
--
--------------------------------------------------------------------------------------------------- 



--=================================================================================================
--!                           Entity declaration for WF_prod_permit
--=================================================================================================

entity WF_prod_permit is

  port (
  -- INPUTS 
    -- nanoFIP User Interface, General signals
    uclk_i                : in std_logic;      --! 40 MHz clock

    -- Signal from the WF_reset_unit
    nfip_rst_i            : in std_logic;      --! nanoFIP internal reset

    -- Signals from the WF_engine_control
    var_i                 : in t_var;          --! variable type that is being treated


  -- OUTPUT
    -- nanoFIP User Interface, NON-WISHBONE outputs
    var3_rdy_o            : out std_logic      --! signals the user that data can safely be written
      );
end entity WF_prod_permit;


--=================================================================================================
--!                                    architecture declaration
--=================================================================================================
architecture rtl of WF_prod_permit is


--=================================================================================================
--                                        architecture begin
--=================================================================================================  
begin

---------------------------------------------------------------------------------------------------
--!@brief Synchronous process VAR3_RDY_Generation: 

--! VAR3_RDY (for produced vars): signals that the user can safely write to the produced variable
--! memory or access the DAT_I bus. It is deasserted right after the end of the reception of a
--! correct var_3 ID_DAT frame and stays de-asserted until the end of the transmission of the
--! corresponding RP_DAT from nanoFIP.

--! Note: A correct ID_DAT frame along with the variable it contained is signaled by the var_i.
--! For produced variables, the signal var_i gets its value (var3, var_presence, var_identif)
--! after the reception of a correct ID_DAT frame (with correct FSS, Control, PDU_TYPE, Length, CRC
--! and FES bytes and with a correct manch. encoding) and retains it until the end of the
--! transmission of the corresponding RP_DAT (in detail, until the end of the transmission of the
--! RP_DAT.data field;var_i becomes var_whatever during the RP_DAT.FCS and RP_DAT.FES transmission).

  VAR_RDY_Generation: process (uclk_i) 
  begin
    if rising_edge (uclk_i) then
      if nfip_rst_i = '1' then
        var3_rdy_o   <= '0';

      else
      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --
        case var_i is

         when var_3 =>                     -- nanoFIP is producing 
                                              ---------------------
          var3_rdy_o <= '0';               -- while producing, VAR3_RDY is 0
     

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --
        when others =>

          var3_rdy_o <= '1';               
      
        end case;	 	 
      end if;
    end if;
  end process;


end architecture rtl;
--=================================================================================================
--                                        architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------