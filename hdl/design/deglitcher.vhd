--===========================================================================
--! @file deglitcher.vhd
--! @brief Glitch filter. 1 pulse adapted filter.
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
--! @brief Glitch filter. 1 pulse adapted filter.
--!
--! 
--!
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
--! Author:      Pablo Alvarez Sanchez
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
           rx_data_i : in  STD_LOGIC;
           clk_bit_180_p_i : in std_logic;
           rx_data_filtered_o : out  STD_LOGIC;
           carrier_p_i : in  STD_LOGIC;
           sample_manch_bit_p_o : out  STD_LOGIC;
           sample_bit_p_o : out  STD_LOGIC
         );
end deglitcher;

architecture Behavioral of deglitcher is

signal s_onesc : signed(C_ACULENGTH - 1 downto 0);
signal s_rx_data_filtered_o: STD_LOGIC;
signal s_d_d: std_logic_vector(2 downto 0);
signal s_rx_data_filtered_d : std_logic;

begin

process(uclk_i)
begin
if rising_edge(uclk_i) then
	if carrier_p_i = '1' then -- 4 clock ticks after a transition of manchestered input
		s_onesc <= to_signed(0,s_onesc'length);
	elsif  rx_data_i = '1' then
		s_onesc <= s_onesc - 1;
	else
		s_onesc <= s_onesc + 1;
	end if;
end if;
end process;


process(uclk_i)
  begin
    if rising_edge(uclk_i) then
	  if carrier_p_i = '1' then 		
	    s_rx_data_filtered_o <= s_onesc(s_onesc'left);
      end if;
      s_rx_data_filtered_d <= s_rx_data_filtered_o; 
  end if;
end process;

      sample_manch_bit_p_o <= carrier_p_i;  
      sample_bit_p_o <= clk_bit_180_p_i;

--process(carrier_p_i)
  --begin
    --if rising_edge(carrier_p_i) then
	--   s_rx_data_filtered_o <= s_onesc(s_onesc'left);
   -- elsif falling_edge(carrier_p_i) then
   --   s_rx_data_filtered_o <= s_onesc(s_onesc'left); 
   -- end if;
 -- end process;

--process(uclk_i)
  --begin
    --if rising_edge(uclk_i) then
     -- sample_manch_bit_p_o <= carrier_p_i;	
     -- sample_bit_p_o <= clk_bit_180_p_i; ---- delay on clk_bit_180_p_i, so that sample_bit is 1 clock tick before rx_data_filtered_o
    --  s_rx_data_filtered_o_1 <= s_rx_data_filtered_o_0;
    --  s_rx_data_filtered_o_0 <= s_rx_data_filtered_o; 
 -- end if;
--end process;
 rx_data_filtered_o <= s_rx_data_filtered_d;
end Behavioral;































