--=================================================================================================
--! @file wf_incr_counter.vhd
--=================================================================================================

--! standard library
library IEEE; 

--! standard packages
use IEEE.STD_LOGIC_1164.all;  --! std_logic definitions
use IEEE.NUMERIC_STD.all;     --! conversion functions

---------------------------------------------------------------------------------------------------
--                                                                                               --
--                                         wf_incr_counter                                       --
--                                                                                               --
--                                         CERN, BE/CO/HT                                        --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
--
--! @brief     Synchronous increasing counter with a reset and an increase enable signal;
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
--!                           Entity declaration for wf_incr_counter
--=================================================================================================

entity wf_incr_counter is
  generic(counter_length : natural);
  port (
  -- INPUTS 
    -- User Interface general signals 
    uclk_i :         in std_logic;                           --! 40MHz clock

    -- Signal from the wf_reset_unit unit
    nFIP_u_rst_i :     in std_logic;                           --! internal reset

   -- Signals from any unit
   reset_counter_i : in std_logic;                           --! resets counter to 0
   incr_counter_i:   in std_logic;                           --! increment enable

  -- OUTPUT
    -- Signal to any unit
   counter_o :       out unsigned(counter_length-1 downto 0) --! counter
      );
end entity wf_incr_counter;


--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of wf_incr_counter is

signal s_counter : unsigned(counter_length-1 downto 0);

--=================================================================================================
--                                      architecture begin
--=================================================================================================  
  begin

--------------------------------------------------------------------------------------------------- 
  Incr_Counter: process(uclk_i)
  begin

    if rising_edge(uclk_i) then
      if nFIP_u_rst_i = '1' then
        s_counter <= (others => '0');

      elsif reset_counter_i = '1' then
        s_counter <= (others => '0');

      elsif incr_counter_i = '1' then
        s_counter <= s_counter + 1;

      end if;
    end if;
  end process;

  counter_o <= s_counter;

end architecture rtl;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------