--_________________________________________________________________________________________________
--                                                                                                |
--                                        |The nanoFIP|                                           |
--                                                                                                |
--                                        CERN,BE/CO-HT                                           |
--________________________________________________________________________________________________|
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--                                                                                               --
--                                  WF_DualClkRAM_clka_rd_clkb_wr                                --
--                                                                                               --
---------------------------------------------------------------------------------------------------
-- File         WF_DualClkRAM_clka_rd_clkb_wr.vhd  
--
-- Description  The unit provides the memory triplication, transparently to the outside world.
--              The component DualClkRam (512 bytes) is triplicated: each incoming byte is written
--              at the same position in the three memories, whereas each outgoing byte is the
--              outcome of a majority voter.
--              The memory is dual port; port A is used for reading only, port B for writing only.
--
--              Remark: MajorityVoter(A,B,C) = (A and B) OR (A and C) OR (B and C)
--
--
-- Authors      Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)
--              Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)
-- Date         10/12/2010
-- Version      v0.02
-- Depends on   DualClkRAM.vhd
----------------
-- Last changes
--     12/2010  v0.02  EG  code cleaned-up+commented
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
--                   Entity declaration for WF_DualClkRAM_clka_rd_clkb_wr
--=================================================================================================

entity WF_DualClkRAM_clka_rd_clkb_wr is
  generic (g_ram_data_lgth : integer;  -- length of data word
           g_ram_addr_lgth : integer); -- memory depth
  port (
  -- INPUTS
    -- Inputs concerning port A
    clk_porta_i      : in std_logic;
    addr_porta_i     : in std_logic_vector (g_ram_addr_lgth - 1 downto 0);

    -- Inputs concerning port B
    clk_portb_i      : in std_logic;
    addr_portb_i     : in std_logic_vector (g_ram_addr_lgth - 1 downto 0);
    data_portb_i     : in std_logic_vector (g_ram_data_lgth - 1 downto 0);
    write_en_portb_i : in std_logic;


  -- OUTPUT
    -- Output concerning port A
    data_porta_o     : out std_logic_vector (g_ram_data_lgth -1 downto 0)
);
end WF_DualClkRAM_clka_rd_clkb_wr;


--=================================================================================================
--                                    architecture declaration
--=================================================================================================
architecture syn of WF_DualClkRAM_clka_rd_clkb_wr is

--  type t_data_o_A_array is array (natural range <>) of std_logic_vector (7 downto 0);
--  signal s_data_o_A_array : t_data_o_A_array (0 to 2); -- keeps the DOUTA of each one of the memories
  signal s_one, s_rwB     : std_logic;
  signal s_zeros          : std_logic_vector (7 downto 0);


--=================================================================================================
--                                       architecture begin
--=================================================================================================
begin

  s_one   <= '1';
  s_zeros <= (others => '0');
  s_rwB   <= not write_en_portb_i;

---------------------------------------------------------------------------------------------------
-- memory triplication
-- The component DualClkRam is generated three times.
-- Port A is used for reading only, port B for writing only.
-- The input DINB is written in the same position in the 3 memories.
-- The output DOUTA from each memory is kept in the array s_data_o_A_array.

--  G_memory_triplication: for I in 0 to 2 generate

    UDualClkRam : DualClkRam
    port map (
      DINA   => s_zeros,
      ADDRA  => addr_porta_i,
      RWA    => s_one,
      CLKA   => clk_porta_i,

      DINB   => data_portb_i,
      ADDRB  => addr_portb_i,
      RWB    => s_rwB,
      CLKB   => clk_portb_i,

      RESETn => s_one,

      DOUTA  => data_porta_o, --s_data_o_A_array(I),
      DOUTB  => open);

--  end generate;


---------------------------------------------------------------------------------------------------
-- Combinatorial Majority_Voter

-- Majority_Voter: data_porta_o <= (s_data_o_A_array(0) and s_data_o_A_array(1)) or
--                                 (s_data_o_A_array(1) and s_data_o_A_array(2)) or
--                                 (s_data_o_A_array(2) and s_data_o_A_array(0));

end syn;
--=================================================================================================
--                                        architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------