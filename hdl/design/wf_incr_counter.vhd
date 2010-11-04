--________________________________________________________________________________________________|
--                                                                                                |
--                                        |The nanoFIP|                                           |
--                                                                                                |
--                                        CERN,BE/CO-HT                                           |
--________________________________________________________________________________________________|
--________________________________________________________________________________________________|

--------------------------------------------------------------------------------------------------
--! @file WF_incr_counter.vhd
---------------------------------------------------------------------------------------------------

--! standard library
library IEEE; 

--! standard packages
use IEEE.STD_LOGIC_1164.all;  --! std_logic definitions
use IEEE.NUMERIC_STD.all;     --! conversion functions

---------------------------------------------------------------------------------------------------
--                                                                                               --
--                                         WF_incr_counter                                       --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
--
--! @brief     Fully synchronous increasing counter with a reset, a reinitialise & an enable signal
--
--
--! @author    Pablo Alvarez Sanchez (pablo.alvarez.sanchez@cern.ch)
--!            Evangelia Gousiou     (evangelia.gousiou@cern.ch)
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
--!                           Entity declaration for WF_incr_counter
--=================================================================================================

entity WF_incr_counter is
  generic(counter_length : natural);
  port (
  -- INPUTS 
    -- User Interface general signals (synchronized) 
    uclk_i :           in std_logic;                           --! 40MHz clock

    -- Signal from the WF_reset_unit unit
    nFIP_urst_i :      in std_logic;                           --! internal reset

   -- Signals from any unit
   reinit_counter_i :  in std_logic;                           --! reinitializes counter to 0
   incr_counter_i:     in std_logic;                           --! increment enable

  -- OUTPUT
    -- Signal to any unit
   counter_o :         out unsigned(counter_length-1 downto 0); --! counter
   counter_is_full_o : out std_logic                            --! all counter bits at '1' 
      );
end entity WF_incr_counter;


--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of WF_incr_counter is

signal s_counter, s_counter_full : unsigned(counter_length-1 downto 0);

--=================================================================================================
--                                      architecture begin
--=================================================================================================  
  begin

  s_counter_full <= (others => '1');
--------------------------------------------------------------------------------------------------- 
  Incr_Counter: process(uclk_i)
  begin

    if rising_edge(uclk_i) then
      if nFIP_urst_i = '1' then
        s_counter <= (others => '0');

      elsif reinit_counter_i = '1' then
        s_counter <= (others => '0');

      elsif incr_counter_i = '1' then
        s_counter <= s_counter + 1;

      end if;
    end if;
  end process;

  counter_o         <= s_counter;
  counter_is_full_o <= '1' when s_counter= s_counter_full
                  else '0';

end architecture rtl;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------