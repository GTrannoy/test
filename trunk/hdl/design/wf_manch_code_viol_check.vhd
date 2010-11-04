--________________________________________________________________________________________________|
--                                                                                                |
--                                        |The nanoFIP|                                           |
--                                                                                                |
--                                        CERN,BE/CO-HT                                           |
--________________________________________________________________________________________________|
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--! @file WF_decr_counter.vhd
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
--                                 WF_manch_code_viol_check                                      --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
--
--! @brief     The unit follows an incoming serial signal and outputs a pulse 
--!            if a manchester 2 code violation is detected.
--!            It is assumed that a violation happens if after half reception period 
--!            plus 2 uclck periods, the incoming signal has not had a transition.
--
--
--! @author    Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)
--!            Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)
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
--!                           Entity declaration for WF_manch_code_viol_check
--=================================================================================================

entity WF_manch_code_viol_check is
  port (
  -- INPUTS 
    -- User Interface general signals (synchronized) 
    uclk_i :               in std_logic; --! 40MHz clock

    -- Signal from the WF_reset_unit unit
    nFIP_urst_i :          in std_logic; --! internal reset

   -- Signals from WF_rx
   serial_input_signal_i : in std_logic; --! input signal
   sample_bit_p_i :        in std_logic; --! pulse for the sampling of a new bit
   sample_manch_bit_p_i :  in std_logic; --! pulse for the sampling of a new manch. bit
    

  -- OUTPUTS
    -- Signal to WF_rx
    manch_code_viol_p_o : out std_logic  --! pulse indicating a code violation
      );
end entity WF_manch_code_viol_check;


--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of WF_manch_code_viol_check is

signal s_sample_bit_p_d1,s_sample_bit_p_d2,s_check_code_viol_p,s_serial_input_signal_d : std_logic;

--=================================================================================================
--                                      architecture begin
--=================================================================================================  
  begin

---------------------------------------------------------------------------------------------------


---------------------------------------------------------------------------------------------------
--!@brief Synchronous process Check_Code_Violations:in order to check the existance code violations
--! the input signal is delayed by half reception period.
--! The signal check_code_viol_p is a pulse with period the reception period. The pulse occurs
--! 2 uclk periods after a manch. transition is expected.
--! As the following drawing roughly indicates, a violation exists if the signal and its delayed
--! version are identical on the s_check_code_viol_p moments.

--                                 0    V-    1
--   rxd_filtered_o:         __|--|____|--|__ 
--   s_serial_input_signal_d:       __|--|____|--|__
--   s_check_code_viol_p:             ^    ^     ^

  Check_code_violations: process(uclk_i)
    begin
      if rising_edge (uclk_i) then 
         if nFIP_urst_i = '1' then
           s_check_code_viol_p   <='0';
           s_sample_bit_p_d1     <='0';
           s_sample_bit_p_d2     <='0';
           s_serial_input_signal_d  <='0';

         else

           if sample_manch_bit_p_i = '1' then
             s_serial_input_signal_d <= serial_input_signal_i; 
           end if;

            s_check_code_viol_p   <= s_sample_bit_p_d2; -- small delay
            s_sample_bit_p_d2     <= s_sample_bit_p_d1;
            s_sample_bit_p_d1     <= sample_bit_p_i;
         end if;
      end if;
  end process; 

 --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
  manch_code_viol_p_o <= s_check_code_viol_p and 
                        (not (serial_input_signal_i xor s_serial_input_signal_d));
  

end architecture rtl;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------