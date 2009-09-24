--===========================================================================
--! @file deglitcher.vhd
--! @brief Deserialises the WorldFIP data
--===========================================================================
--! Standard library
library IEEE;
--! Standard packages
use IEEE.STD_LOGIC_1164.all; --! std_logic definitions
use IEEE.NUMERIC_STD.all;    --! conversion functions


-------------------------------------------------------------------------------
--                                                                           --
--                                 deglitcher                                 --
--                                                                           --
--                               CERN, BE/CO/HT                              --
--                                                                           --
-------------------------------------------------------------------------------
--
-- unit name: deglitcher
--
--! @brief 1 microsecond pulse adapted filter
--!
--! Used in the NanoFIP design. \n
--! This unit serializes the data.
--!
--!
--! @author	    Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)
--!
--! @date 10/08/2009
--
--! @version v0.01
--
--! @details 
--!
--! <b>Dependencies:</b>\n
--! wf_engine           \n
--! tx_engine           \n
--! clk_gen             \n
--! reset_logic         \n
--! consumed_ram        \n
--!
--!
--! <b>References:</b>\n
--! 
--! 
--!
--! <b>Modified by:</b>\n
--! Author: Erik van der Bij
--!         Pablo Alvarez Sanchez
-------------------------------------------------------------------------------
--! \n\n<b>Last changes:</b>\n
--! 07/08/2009  v0.02  PAAS Entity Ports added, start of architecture content
--!
-------------------------------------------------------------------------------
--! @todo Define I/O signals \n
--!
-------------------------------------------------------------------------------



--============================================================================
--! Entity declaration for deglitcher
--============================================================================

entity deglitcher is
    Generic (C_ACULENGTH : integer := 10);
    Port ( uclk_i : in  STD_LOGIC;
           d_i : in  STD_LOGIC;
           d_o : out  STD_LOGIC;
           carrier_p_i : in  STD_LOGIC;
           d_ready_p_o : out  STD_LOGIC);
end deglitcher;

architecture Behavioral of deglitcher is

signal s_onesc : signed(C_ACULENGTH - 1 downto 0);
begin

process(uclk_i)
begin
if rising_edge(uclk_i) then
	if carrier_p_i = '1' then
		s_onesc <= to_signed(0,s_onesc'length);
	elsif  d_i = '1' then
		s_onesc <= s_onesc - 1;
	else
		s_onesc <= s_onesc + 1;
	end if;
end if;
end process;

process(uclk_i)
begin if rising_edge(uclk_i) then
	if carrier_p_i = '1' then 		
	   d_o <= s_onesc(s_onesc'left);
	end if;
	d_ready_p_o <= carrier_p_i;
	end if;
end process;

end Behavioral;

