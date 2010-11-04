---------------------------------------------------------------------------------------------------
--! @file WF_decr_counter.vhd
---------------------------------------------------------------------------------------------------

--! standard library
library IEEE; 

--! standard packages
use IEEE.STD_LOGIC_1164.all;  --! std_logic definitions
use IEEE.NUMERIC_STD.all;     --! conversion functions

---------------------------------------------------------------------------------------------------
--                                                                                               --
--                                        WF_decr_counter                                        --
--                                                                                               --
--                                        CERN, BE/CO/HT                                         --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
--
--! @brief     Synchronous decreasing counter with a load enable and decrease enable signals;
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
--!                           Entity declaration for WF_decr_counter
--=================================================================================================

entity WF_decr_counter is
  generic(counter_length : natural);
  port (
  -- INPUTS 
    -- User Interface general signals (synchronized) 
    uclk_i :           in std_logic;                             --! 40MHz clock

    -- Signal from the WF_reset_unit unit
    nFIP_urst_i :     in std_logic;                             --! internal reset

   -- Signals from any unit
   counter_top :       in unsigned (counter_length-1 downto 0);  --! load value
   counter_load_i :    in std_logic;                             --! load enable
   counter_decr_p_i :  in std_logic;                             --! decrement enable
    

  -- OUTPUTS
    -- Signal to any unit
    counter_o :         out unsigned (counter_length-1 downto 0);--! counter 
    counter_is_zero_o : out std_logic                            --! empty counter indication
      );
end entity WF_decr_counter;


--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of WF_decr_counter is

signal s_counter : unsigned(counter_length-1 downto 0);

--=================================================================================================
--                                      architecture begin
--=================================================================================================  
  begin

---------------------------------------------------------------------------------------------------
  Decr_Counter: process(uclk_i)
  begin
    if rising_edge(uclk_i) then
      if nFIP_urst_i = '1' then
        s_counter   <= (others => '0');
      else

        if counter_load_i = '1' then
          s_counter <= counter_top;

        elsif counter_decr_p_i = '1' then
          s_counter <= s_counter - 1;

        end if;
      end if;
    end if;
  end process;


 --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
  counter_o         <= s_counter;
  counter_is_zero_o <= '1' when s_counter = to_unsigned(0,s_counter'length) else '0';
  

end architecture rtl;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------