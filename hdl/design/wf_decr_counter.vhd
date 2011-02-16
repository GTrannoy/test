--_________________________________________________________________________________________________
--                                                                                                |
--                                        |The nanoFIP|                                           |
--                                                                                                |
--                                        CERN,BE/CO-HT                                           |
--________________________________________________________________________________________________|
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--! @file WF_decr_counter.vhd                                                                     |
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
---------------------------------------------------------------------------------------------------
--
--
--! @brief     Decreasing counter with synchronous reset, load enable and decrease enable.
--
--
--! @author    Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)
--!            Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)
--
--
--! @date      10/2010
--
--
--! @version   v0.01
--
--
--! @details \n  
--
--!   \n<b>Dependencies:</b>\n
--
--
--!   \n<b>Modified by:</b>\n
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
  generic (g_counter_lgth : natural := 4);                        --! default length
  port (
  -- INPUTS 
    -- nanoFIP User Interface general signal
    uclk_i            : in std_logic;                             --! 40 MHz clock

    -- Signal from the WF_reset_unit
    nfip_rst_i        : in std_logic;                             --! nanoFIP internal reset

    -- Signals from any unit
    counter_decr_p_i  : in std_logic;                             --! decrement enable
    counter_load_i    : in std_logic;                             --! load enable
    counter_top       : in unsigned (g_counter_lgth-1 downto 0);  --! load value
     

  -- OUTPUTS
    -- Signal to any unit
    counter_o         : out unsigned (g_counter_lgth-1 downto 0); --! counter 
    counter_is_zero_o : out std_logic                             --! empty counter indication
      );
end entity WF_decr_counter;


--=================================================================================================
--!                                    architecture declaration
--=================================================================================================
architecture rtl of WF_decr_counter is

signal s_counter : unsigned (g_counter_lgth-1 downto 0);

--=================================================================================================
--                                        architecture begin
--=================================================================================================  
begin

---------------------------------------------------------------------------------------------------
  -- Synchronous process Decr_Counter

  Decr_Counter: process (uclk_i)
  begin
    if rising_edge (uclk_i) then

      if nfip_rst_i = '1' then
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
  -- Concurrent assignments for the output signals

  counter_o         <= s_counter;
  counter_is_zero_o <= '1' when s_counter = to_unsigned(0,s_counter'length) else '0';
  

end architecture rtl;
--=================================================================================================
--                                        architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------