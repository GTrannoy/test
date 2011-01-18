--_________________________________________________________________________________________________
--                                                                                                |
--                                        |The nanoFIP|                                           |
--                                                                                                |
--                                        CERN,BE/CO-HT                                           |
--________________________________________________________________________________________________|
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--! @file WF_prod_bytes_from_dati.vhd
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
--                                    WF_prod_bytes_from_dati                                    --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
--
--! @brief     Unit responsible for the sampling of the DAT_I bus in stand-alone operation.
--!            Following to the functional specs page 15, in stand-alone mode, the nanoFIP
--!            samples the data on the first clock cycle after the deassertion of VAR3_RDY.
--
--
--! @author    Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch) \n
--!            Evangelia Gousiou (Evangelia.Gousiou@cern.ch)         \n
--
--
--! @date      04/01/2011
--
--
--! @version   v0.02
--
--
--! @details \n  
--
--!   \n<b>Dependencies:</b>\n
--!      WF_reset_unit     \n
--!      WF_engine_control \n
--
--
--!   \n<b>Modified by:</b>\n
--!     Evangelia Gousiou (Evangelia.Gousiou@cern.ch)
--
--------------------------------------------------------------------------------------------------- 
--
--!   \n\n<b>Last changes:</b>\n
--!     -> 11/2010  v0.01  EG  unit created
--!     -> 4/1/2011 v0.02  EG  unit renamed from WF_slone_prod_dati_bytes_sampler to
--!                            WF_prod_bytes_from_dati; cleaning-up + commenting
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
--!                           Entity declaration for WF_prod_bytes_from_dati
--=================================================================================================

entity WF_prod_bytes_from_dati is

  port (
  -- INPUTS 
    -- nanoFIP User Interface, General signals
    uclk_i       : in std_logic;                       --! 40MHz clock

    -- Signal from the WF_reset_unit
    nfip_rst_i   : in std_logic;                       --! nanoFIP internal reset

    -- nanoFIP User Interface, NON-WISHBONE
    slone_data_i : in  std_logic_vector (15 downto 0); --! input data bus for stand-alone mode
                                                       -- (synchronised with uclk)  
   -- Signals from the WF_engine_control unit
    byte_index_i : in std_logic_vector (7 downto 0);   --! pointer to message bytes

   -- Signals from the WF_prod_permit unit
    var3_rdy_i   : in std_logic;                       --! nanoFIP output VAR3_RDY

  -- OUTPUTS
    -- Signal to the WF_prod_bytes_retriever
    slone_byte_o : out std_logic_vector (7 downto 0)   --! sampled byte to be sent
      );
end entity WF_prod_bytes_from_dati;


--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of WF_prod_bytes_from_dati is

  signal s_var3_rdy_d4  : std_logic_vector (3 downto 0);
  signal s_sampled_data : std_logic_vector (15 downto 0); 

--=================================================================================================
--                                      architecture begin
--=================================================================================================  
begin

--------------------------------------------------------------------------------------------------- 
--!@brief Synchronous process Sample_DAT_I_bus: the sampling of the DAT_I bus in stand-alone mode
--! has to take place on the first clock cycle after the de-assertion of VAR3_RDY.
--! Note: Since slone_data_i is the triply buffered version of the bus DAT_I (for synchronisation),
--! the signal VAR3_RDY has to be (internally) delayed for 3 uclk cycles too, before the sampling;
--! the 4th delay is added in order to achieve the sampling 1 uclk AFTER the de-assertion.

Sample_DAT_I_bus: process (uclk_i) 
  begin
    if rising_edge (uclk_i) then 
      if nfip_rst_i = '1' then
        s_var3_rdy_d4    <= (others=>'0');
        s_sampled_data   <= (others=>'0');
 
     else 
        s_var3_rdy_d4    <= s_var3_rdy_d4(2 downto 0) & var3_rdy_i;

        if s_var3_rdy_d4(3) = '1' then   -- data latching
          s_sampled_data <= slone_data_i; 
        end if;

      end if;                                 
    end if;  
  end process;

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
  slone_byte_o           <= s_sampled_data(7 downto 0) when byte_index_i = c_1st_DATA_BYTE_INDEX
                       else s_sampled_data(15 downto 8); 

end architecture rtl;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------