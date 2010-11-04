---------------------------------------------------------------------------------------------------
--! @file WF_prod_data_lgth_calc.vhd
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
--                                 WF_prod_data_lgth_calc                                        --
--                                                                                               --
--                                  CERN, BE/CO/HT                                               --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
--
--! @brief     Calculation of the total amount of data bytes that have to be transferreed when a
--!            variable is produced (including the rp_dat.Control, rp_dat.Data.mps and
--!            rp_dat.Data.nanoFIPstatus bytes)
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
--!                           Entity declaration for WF_prod_data_lgth_calc
--=================================================================================================

entity WF_prod_data_lgth_calc is

  port (
  -- INPUTS 
    -- User Interface general signals (synchronized) 
    slone_i :          in std_logic;                    
    nostat_i :         in std_logic;  
    p3_lgth_i :        in std_logic_vector (2 downto 0);

   -- Signals from WF_engine_control
    var_i:             in t_var;

  -- OUTPUT
    -- Signal to WF_engine_control
    tx_data_length_o : out std_logic_vector(7 downto 0)
      );
end entity WF_prod_data_lgth_calc;


--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of WF_prod_data_lgth_calc is

signal s_tx_data_length, s_p3_length_decoded : unsigned(7 downto 0);
--=================================================================================================
--                                      architecture begin
--=================================================================================================  
  begin
---------------------------------------------------------------------------------------------------
--!@brief:Combinatorial process data_length_calcul: calculation of the total amount of data
--! bytes that have to be transferreed when a variable is produced, including the rp_dat.Control as
--! well as the rp_dat.Data.mps and rp_dat.Data.nanoFIPstatus bytes. In the case of the presence 
--! and the identification variables, the data length is predefined in the WF_package.
--! In the case of a var_3 the inputs slone, nostat and p3_lgth[] are accounted for the calculation. 

  data_length_calcul: process ( var_i, s_p3_length_decoded, slone_i, nostat_i, p3_lgth_i )
  begin


    s_p3_length_decoded <= c_P3_LGTH_TABLE (to_integer(unsigned(p3_lgth_i)));

    case var_i is


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -
      when var_presence => 
      -- data length information retreival from the c_VARS_ARRAY matrix (WF_package) 
        s_tx_data_length <= c_VARS_ARRAY(c_VAR_PRESENCE_INDEX).array_length;


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -
      when var_identif => 
      -- data length information retreival from the c_VARS_ARRAY matrix (WF_package) 
        s_tx_data_length <= c_VARS_ARRAY(c_VAR_IDENTIF_INDEX).array_length;


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -
      when var_3 =>  
      -- data length calculation according to the operational mode (memory or stand-alone)

      -- in slone mode                   2 bytes of user-data are produced
      -- to these there should be added: 1 byte rp_dat.Control
      --                                 1 byte PDU
      --                                 1 byte Length
      --                                 1 byte MPS 
      --                      optionally 1 byte nFIP status
  
      -- in memory mode the signal      "s_p3_length_decoded" indicates the amount of user-data
      -- to these, there should be added 1 byte rp_dat.Control
      --                                 1 byte PDU
      --                                 1 byte Length
      --                                 1 byte MPS 
      --                      optionally 1 byte nFIP status  

        if slone_i = '1' then

          if nostat_i = '1' then                              -- 6 bytes (counting starts from 0)
            s_tx_data_length <= to_unsigned(5, s_tx_data_length'length); 

          else                                                -- 7 bytes (counting starts from 0)
            s_tx_data_length <= to_unsigned(6, s_tx_data_length'length); 
          end if;


        else
          if nostat_i = '0' then
            s_tx_data_length <= s_p3_length_decoded + 4; -- (bytes counting starts from 0)

           else
            s_tx_data_length <= s_p3_length_decoded + 3; -- (bytes counting starts from 0)
           end if;          
          end if;

      when var_1 => 
        s_tx_data_length <= (others => '0');

      when var_2 =>
        s_tx_data_length <= (others => '0');

      when var_rst =>  
        s_tx_data_length <= (others => '0');

      when others => 
        s_tx_data_length <= (others => '0');

    end case;
  end process;
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 

  tx_data_length_o <= std_logic_vector (s_tx_data_length);


end architecture rtl;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------