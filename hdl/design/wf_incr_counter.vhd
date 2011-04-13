--_________________________________________________________________________________________________
--                                                                                                |
--                                        |The nanoFIP|                                           |
--                                                                                                |
--                                        CERN,BE/CO-HT                                           |
--________________________________________________________________________________________________|
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
-- File         WF_incr_counter.vhd                                                               |
---------------------------------------------------------------------------------------------------

-- Standard library
library IEEE;
-- Standard packages
use IEEE.STD_LOGIC_1164.all; -- std_logic definitions
use IEEE.NUMERIC_STD.all;    -- conversion functions

---------------------------------------------------------------------------------------------------
--                                                                                               --
--                                        WF_incr_counter                                        --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
--
-- Description  Increasing counter with synchronous reset, reinitialise and increase enable.
--
--
-- Authors      Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)
--              Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)
--
--
-- Date         10/2010
--
--
-- Version      v0.01
--
--
-- Depends on
--
--
---------------------------------------------------------------------------------------------------
--
-- Last changes
--     -> 01/2011  EG  v0.011  counter_full became a constant
--
---------------------------------------------------------------------------------------------------



--=================================================================================================
--                           Entity declaration for WF_incr_counter
--=================================================================================================

entity WF_incr_counter is
  generic (g_counter_lgth : natural := 4);                       -- default length
  port (
  -- INPUTS
    -- nanoFIP User Interface general signal
    uclk_i           : in std_logic;                             -- 40 MHz clock

   -- Signals from any unit
   incr_counter_i    : in std_logic;                             -- increment enable
   reinit_counter_i  : in std_logic;                             -- reinitializes counter to 0


  -- OUTPUT
    -- Signal to any unit
   counter_o         : out unsigned (g_counter_lgth-1 downto 0); -- counter
   counter_is_full_o : out std_logic                             -- counter full indication
      );                                                         -- (all bits to '1')

end entity WF_incr_counter;


--=================================================================================================
--                                    architecture declaration
--=================================================================================================
architecture rtl of WF_incr_counter is

constant c_COUNTER_FULL : unsigned (g_counter_lgth-1 downto 0) := (others => '1');
signal   s_counter      : unsigned (g_counter_lgth-1 downto 0);

--=================================================================================================
--                                       architecture begin
--=================================================================================================
begin


---------------------------------------------------------------------------------------------------
  -- Synchronous process Incr_Counter

  Incr_Counter: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if reinit_counter_i = '1' then
        s_counter    <= (others => '0');

      elsif incr_counter_i = '1' then
        s_counter    <= s_counter + 1;

      end if;
    end if;
  end process;


 --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  -- Concurrent assignments for output signals

  counter_o         <= s_counter;
  counter_is_full_o <= '1' when s_counter = c_COUNTER_FULL else '0';


end architecture rtl;
--=================================================================================================
--                                        architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------