--_________________________________________________________________________________________________
--                                                                                                |
--                                        |The nanoFIP|                                           |
--                                                                                                |
--                                        CERN,BE/CO-HT                                           |
--________________________________________________________________________________________________|
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--! @file WF_manch_code_viol_check.vhd
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
--                                 WF_manch_code_viol_check                                      --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
--
--! @brief     The unit follows the incoming deglitched serial signal and outputs a pulse if a
--!            Manchester 2 (manch.) code violation is detected.
--!            It is assumed that a violation happens if after a half-bit-clock period (plus 2 uclk
--!            periods), the incoming signal has not had a transition.
--!            Note: the term sample_manch_bit_p refers to the moments when a manch. encoded bit
--!            should be sampled (before and after a significant edge), whereas the 
--!            sample_bit_p includes only the sampling of the 1st part, before the transition. 
--!            Example:
--!                    bit                : 0 
--!                    manch. encoded     : _|-
--!                    sample_manch_bit_p : ^ ^
--!                    sample_bit_p       : ^    (this sampling will give the 0)

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
--!     -> 12/12/2010  v0.02  EG  cleaning-up+commenting
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
    -- nanoFIP User Interface general signal 
    uclk_i                : in std_logic; --! 40MHz clock

    -- Signal from the WF_reset_unit
    nfip_urst_i           : in std_logic; --! nanoFIP internal reset

    -- Signals from the wf_rx_deserializer
    serial_input_signal_i : in std_logic; --! input signal
    sample_bit_p_i        : in std_logic; --! pulse for the sampling of a new bit
    sample_manch_bit_p_i  : in std_logic; --! pulse for the sampling of a new manch. bit
 
   
  -- OUTPUTS
    -- Signal to the wf_rx_deserializer
    manch_code_viol_p_o  : out std_logic  --! pulse indicating a code violation
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
--!@brief Synchronous process Check_Code_Violations: in order to check for code violations, the
--! input signal is delayed by half-bit-clock period (serial_input_signal_d).
--! The signal check_code_viol_p is a pulse occuring 2 uclk periods after a manch. transition is
--! expected.
--! As the following drawing roughly indicates, a violation exists if the signal and its delayed
--! version are identical on the check_code_viol_p moments.

--                                     0    V-    1
--   rxd_filtered          :         __|--|____|--|__ 
--   serial_input_signal_d :           __|--|____|--|__
--   check_code_viol       :             ^    ^    ^

  Check_code_violations: process (uclk_i)
    begin
      if rising_edge (uclk_i) then 
         if nfip_urst_i = '1' then
           s_check_code_viol_p       <= '0';
           s_sample_bit_p_d1         <= '0';
           s_sample_bit_p_d2         <= '0';
           s_serial_input_signal_d   <= '0';

         else

           if sample_manch_bit_p_i = '1' then
             s_serial_input_signal_d <= serial_input_signal_i; 
           end if;

            s_check_code_viol_p      <= s_sample_bit_p_d2; -- 2 uclk ticks delay
            s_sample_bit_p_d2        <= s_sample_bit_p_d1;
            s_sample_bit_p_d1        <= sample_bit_p_i;
         end if;
      end if;
  end process; 

 --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
  -- Concurrent signal assignment
  manch_code_viol_p_o                <= s_check_code_viol_p and 
                                        (not (serial_input_signal_i xor s_serial_input_signal_d));
  

end architecture rtl;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------