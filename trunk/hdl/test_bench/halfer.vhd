-- Created by : G. Penacoba
-- Creation Date: May 2010
-- Description: Converts the serial data into Manchester code
-- Modified by: Penacoba
-- Modification Date: 1 July 2010 (v4)
-- Modification consisted on: Outputs synchronised to eliminate glitches in simulation with
--								a half bit clock.
--								Output is now half a clock cycle later.
--								Reset input added.
--								Carrier detect signal 'cd' is now generated in this module.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.tb_package.all;

entity halfer is
	port(
		clk				: in std_logic;
		data_in			: in std_logic;
		dx_en			: in std_logic;
		h_clk			: in std_logic;
		reset			: in std_logic;
		v_minus			: in std_logic;
		v_plus			: in std_logic;
		
		cd				: out std_logic;
		data_out		: out std_logic
	);
end halfer;

architecture archi of halfer is

signal next_transition_is_significant	: boolean;

signal carrier							: std_logic;
signal data								: std_logic;

begin

	selection: process
	begin
		if reset ='1' then
			data							<= '0';
		elsif v_plus = '1' then
			data							<= '1';
		elsif v_minus ='1' then
			data							<= '0';
		else
			if next_transition_is_significant then
				data						<= not(data);
			else
				data						<= data_in;
			end if;
		end if;
		
		if reset ='1' then
			next_transition_is_significant		<= FALSE;
		elsif dx_en ='0' then
			next_transition_is_significant		<= FALSE;
		else
			next_transition_is_significant		<= not(next_transition_is_significant);
		end if;

		carrier		<= dx_en;
		wait until h_clk ='1';
	end process;
	
	cd				<= carrier;
	data_out		<= data when carrier ='1' else '0';

end archi;
