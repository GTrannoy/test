--_________________________________________________________________________________________________
--                                                                                                |
--                                        |The nanoFIP|                                           |
--                                                                                                |
--                                        CERN,BE/CO-HT                                           |
--________________________________________________________________________________________________|
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--! @file WF_prod_data_lgth_calc.vhd                                                              |
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
--                                   WF_prod_data_lgth_calc                                      --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
--
--! @brief     Calculation of the total amount of bytes, after the FSS and before the FCS, that
--!            have to be transferreed when a variable is produced. In detail, the calculation
--!            takes into account the: RP_DAT.Control, RP_DAT.Data.PDU_TYPE, RP_DAT.Data.Length,
--!            RP_DAT.Data.MPS_status, RP_DAT.Data.nanoFIP_status bytes as well as the user-data
--!            bytes described by the P3_LGTH.
--!
--!            ------------------------------------------------------------------------------------
--!            Reminder
--!
--!            Produced RP_DAT frame structure :
--!             ___________ ______  _______ ______ _________________ _______ _______  ___________ _______
--!            |____FSS____|_Ctrl_||__PDU__|_LGTH_|__..User-Data..__|_nstat_|__MPS__||____FCS____|__FES__|
--!
--!                                               |-----P3_LGTH-----|
--!
--
--
--! @author    Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch) \n
--!            Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)     \n
--
--
--! @date      09/12/2010
--
--
--! @version   v0.02
--
--
--! @details \n  
--
--!   \n<b>Dependencies:</b>\n
--!            WF_engine_control   \n
--
--
--!   \n<b>Modified by:</b>\n
--!            Evangelia Gousiou (Evangelia.Gousiou@cern.ch)
--
--------------------------------------------------------------------------------------------------- 
--
--------------------------------------------------------------------------------------------------- 
--
--!   \n\n<b>Last changes:</b>\n
--!     -> 12/2010 v0.02 EG  code cleaned-up+commented
--
--------------------------------------------------------------------------------------------------- 
--
--! @todo 
--!   -> 
--
--------------------------------------------------------------------------------------------------- 

---/!\----------------------------/!\----------------------------/!\-------------------------/!\---
--                               Synplify Premier D-2009.12 Warnings                             --
-- -- --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --
--                                         No Warnings                                           --
---------------------------------------------------------------------------------------------------


--=================================================================================================
--!                           Entity declaration for WF_prod_data_lgth_calc
--=================================================================================================

entity WF_prod_data_lgth_calc is

  port (
  -- INPUTS 
    -- nanoFIP WorldFIP Settings (synchronized with uclk) 
    p3_lgth_i          : in std_logic_vector (2 downto 0); --! produced var user-data length

    -- User Interface, General signals (synchronized with uclk) 
    nostat_i           : in std_logic;                     --! if negated, nFIP status is sent
    slone_i            : in std_logic;                     --! stand-alone mode

    -- Signal from the WF_engine_control unit
    var_i              : in t_var;                         --! variable type that is being treated


  -- OUTPUT
    -- Signal to the WF_engine_control and WF_production units
    prod_data_length_o : out std_logic_vector(7 downto 0)

      );
end entity WF_prod_data_lgth_calc;


--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of WF_prod_data_lgth_calc is

signal s_prod_data_length, s_p3_length_decoded : unsigned(7 downto 0);

--=================================================================================================
--                                      architecture begin
--=================================================================================================  
begin

---------------------------------------------------------------------------------------------------
--!@brief: Combinatorial process data_length_calcul: calculation of the amount of bytes, after the
--! FSS and before the FCS, that have to be transferreed when a variable is produced. In the case  
--! of the presence and the identification variables, the data length is predefined in the WF_package.
--! In the case of a var3 the inputs slone, nostat and p3_lgth[] are accounted for the calculation.
 
  data_length_calcul: process (var_i, s_p3_length_decoded, slone_i, nostat_i, p3_lgth_i)
  begin

    s_p3_length_decoded  <= c_P3_LGTH_TABLE (to_integer(unsigned(p3_lgth_i)));

    case var_i is


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -
      when var_presence => 
      -- data length information retreival from the c_VARS_ARRAY matrix (WF_package) 
        s_prod_data_length <= c_VARS_ARRAY(c_VAR_PRESENCE_INDEX).array_length;


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -
      when var_identif => 
      -- data length information retreival from the c_VARS_ARRAY matrix (WF_package) 
        s_prod_data_length <= c_VARS_ARRAY(c_VAR_IDENTIF_INDEX).array_length;


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -
      when var_3 =>  
      -- data length calculation according to the operational mode (memory or stand-alone)

      -- in slone mode                   2 bytes of user-data are produced(independantly of p3_lgth)
      -- to these there should be added: 1 byte Control
      --                                 1 byte PDU_TYPE
      --                                 1 byte Length
      --                                 1 byte MPS status
      --                      optionally 1 byte nFIP status
  
      -- in memory mode the signal      "s_p3_length_decoded" indicates the amount of user-data
      -- to these, there should be added 1 byte Control
      --                                 1 byte PDU_TYPE
      --                                 1 byte Length
      --                                 1 byte MPS status
      --                      optionally 1 byte nFIP status  

        if slone_i = '1' then

          if nostat_i = '1' then                              -- 6 bytes (counting starts from 0)
            s_prod_data_length <= to_unsigned(5, s_prod_data_length'length); 

          else                                                -- 7 bytes (counting starts from 0)
            s_prod_data_length <= to_unsigned(6, s_prod_data_length'length); 
          end if;


        else
          if nostat_i = '0' then
            s_prod_data_length <= s_p3_length_decoded + 4;      -- (counting starts from 0)

           else
            s_prod_data_length <= s_p3_length_decoded + 3;      -- (counting starts from 0)
           end if;          
          end if;

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -

      when var_1 | var_2 | var_rst =>                         -- to avoid Warnings from Synthesiser
        s_prod_data_length     <= (others => '0');

      when others => 
        s_prod_data_length     <= (others => '0');

    end case;
  end process;
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
  -- Concurrent signal assignment for the output
  prod_data_length_o           <= std_logic_vector (s_prod_data_length);


end architecture rtl;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------