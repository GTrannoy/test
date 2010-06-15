-- Created by : G. Penacoba
-- Creation Date: May 2010
-- Description: Converts the serial data into Manchester code
-- Modified by:
-- Modification Date:
-- Modification consisted on:

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity halfer is
	port(
		clk				: in std_logic;
		data_in			: in std_logic;
		v_minus			: in std_logic;
		v_plus			: in std_logic;
		
		data_out		: out std_logic
	);
end halfer;

architecture archi of halfer is

signal first			: std_logic;
signal second			: std_logic;

begin

	first		<= '0' when data_in ='0' else '1';
	second		<= '1' when data_in ='0' else '0';
	
	data_out	<= '1' when v_plus ='1' else
					'0' when v_minus ='1' else
					first when clk ='1' else 
					second when clk ='0';

end archi;
