---------------------------------------------------------------------------------------------------
--! @file WF_slone_DATI_bytes_sampler.vhd
---------------------------------------------------------------------------------------------------

--! standard library
library IEEE; 

--! standard packages
use IEEE.STD_LOGIC_1164.all;  --! std_logic definitions
use IEEE.NUMERIC_STD.all;     --! conversion functions

--! specific packages
use work.WF_PACKAGE.all;      --! definitions of supplemental types, subtypes, constants

---------------------------------------------------------------------------------------------------
--                                                                                               --
--                                 WF_slone_DATI_bytes_sampler                                   --
--                                                                                               --
--                                  CERN, BE/CO/HT                                               --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
--
--! @brief     Unit responsible for the sampling of the DAT_I bus for the stand-alone operation.
--!            Following to the functional specs page 14, in stand-alone mode, nanoFIP samples the
--!            data onthe first clock cycle after the deassertion of VAR3_RDY.
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
--!                           Entity declaration for WF_slone_DATI_bytes_sampler
--=================================================================================================

entity WF_slone_DATI_bytes_sampler is

  port (
  -- INPUTS 
    -- User Interface general signals (synchronized) 
    uclk_i :          in std_logic;                      --! 40MHz clock

    -- Signal from the WF_reset_unit unit
    nFIP_urst_i :      in std_logic;                      --! internal reset

    -- User Interface Non WISHBONE
    slone_data_i :    in  std_logic_vector (15 downto 0);--! input data bus for slone mode
                                                         -- (triply buffered with uclk)  
   -- Signals from WF_engine_control
    var3_rdy_i :      in std_logic;

    byte_index_i :    in std_logic_vector (7 downto 0); --! pointer to message bytes
                                                        -- includes rp_dat.Control and rp_dat.Data

  -- OUTPUTS
    -- Signal to WF_prod_bytes_to_tx
    slone_byte_o :    out std_logic_vector (7 downto 0)

      );
end entity WF_slone_DATI_bytes_sampler;


--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of WF_slone_DATI_bytes_sampler is

  signal s_var3_rdy_d4 :    std_logic_vector (3 downto 0);
  signal s_sampled_data : std_logic_vector (15 downto 0); 

--=================================================================================================
--                                      architecture begin
--=================================================================================================  
  begin

--------------------------------------------------------------------------------------------------- 
--!@brief synchronous process Sample_Data_i: the sampling of DAT_I has to take place on the first
--! clock cycle after the deassettion of VAR3_RDY.
-- Since slone_data_i is the triply buffered version of the input bus DAT_I, the signal VAR3_RDY
-- has to be delayed too.

  Sample_Data_i: process(uclk_i) 
  begin
    if rising_edge(uclk_i) then 
      if nFIP_urst_i = '1' then
        s_var3_rdy_d4   <= (others=>'0');
        s_sampled_data <= (others=>'0');
      else 
        s_var3_rdy_d4     <= s_var3_rdy_d4(2 downto 0) & var3_rdy_i;

        if s_var3_rdy_d4(3) = '1' then        -- data latching
          s_sampled_data <= slone_data_i;

        end if;
      end if;
    end if;  
  end process;

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
  slone_byte_o <= s_sampled_data(7 downto 0) when byte_index_i = c_1st_DATA_BYTE_INDEX
             else s_sampled_data(15 downto 8); 

end architecture rtl;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------