--_________________________________________________________________________________________________
--                                                                                                |
--                                        |The nanoFIP|                                           |
--                                                                                                |
--                                        CERN,BE/CO-HT                                           |
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--                                                                                               --
--                                        WF_decr_counter                                        --
--                                                                                               --
---------------------------------------------------------------------------------------------------
-- File         WF_decr_counter.vhd 
-- Description  Decreasing counter with synchronous reset, load enable and decrease enable
-- Authors      Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)
--              Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)
-- Date         10/2010
-- Version      v0.01
-- Depends on   WF_reset_unit
----------------
-- Last changes
--     10/2010  EG  v0.01  first version
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
--                               GNU LESSER GENERAL PUBLIC LICENSE                                |
--                              ------------------------------------                              |
-- This source file is free software; you can redistribute it and/or modify it under the terms of |
-- the GNU Lesser General Public License as published by the Free Software Foundation; either     |
-- version 2.1 of the License, or (at your option) any later version.                             |
-- This source is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;       |
-- without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.      |
-- See the GNU Lesser General Public License for more details.                                    |
-- You should have received a copy of the GNU Lesser General Public License along with this       |
-- source; if not, download it from http://www.gnu.org/licenses/lgpl-2.1.html                     |
---------------------------------------------------------------------------------------------------



--=================================================================================================
--                                      Libraries & Packages
--=================================================================================================

-- Standard library
library IEEE;
use IEEE.STD_LOGIC_1164.all; -- std_logic definitions
use IEEE.NUMERIC_STD.all;    -- conversion functions
-- Specific library
library work;
use work.WF_PACKAGE.all;     -- definitions of types, constants, entities


--=================================================================================================
--                           Entity declaration for WF_decr_counter
--=================================================================================================

entity WF_decr_counter is
  generic (g_counter_lgth : natural := 4);                        -- default length
  port (
  -- INPUTS
    -- nanoFIP User Interface general signal
    uclk_i            : in std_logic;                             -- 40 MHz clock

    -- Signal from the WF_reset_unit
    nfip_rst_i        : in std_logic;                             -- nanoFIP internal reset

    -- Signals from any unit
    counter_decr_p_i  : in std_logic;                             -- decrement enable
    counter_load_i    : in std_logic;                             -- load enable
    counter_top       : in unsigned (g_counter_lgth-1 downto 0);  -- load value


  -- OUTPUTS
    -- Signal to any unit
    counter_o         : out unsigned (g_counter_lgth-1 downto 0); -- counter
    counter_is_zero_o : out std_logic                             -- empty counter indication
      );
end entity WF_decr_counter;


--=================================================================================================
--                                    architecture declaration
--=================================================================================================
architecture rtl of WF_decr_counter is

  signal s_counter_is_zero : std_logic;
  signal s_counter         : unsigned (g_counter_lgth-1 downto 0);

--=================================================================================================
--                                       architecture begin
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

        counter_is_zero_o <= s_counter_is_zero; -- for slack reasons, especially for the
                                                -- 21 bits "session_timeout" counters
      end if;
    end if;
  end process;


 --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  -- Concurrent assignments 

  counter_o         <= s_counter;
  s_counter_is_zero <= '1' when s_counter = to_unsigned(0,s_counter'length) else '0';


end architecture rtl;
--=================================================================================================
--                                        architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------