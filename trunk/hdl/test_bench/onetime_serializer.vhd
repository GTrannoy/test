-- Created by : G. Penacoba
-- Creation Date: May 2010
-- Description: Converts into a serial output the input word of configurable width withouth clk delay
-- Modified by: Penacoba
-- Modification Date: 29 June 2010
-- Modification consisted on: Reset input added. 'Finished' signal is not dependent
--								on 'run' signal anymore.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.tb_package.all;

entity onetime_serializer is
	generic(
		width			: integer:=8
	);
	port(
		clk				: in std_logic;
		data_in			: in std_logic_vector(width-1 downto 0);
		go				: in std_logic;
		reset			: in std_logic;

		data_out		: out std_logic;
		done			: out std_logic
	);
end onetime_serializer;

architecture archi of onetime_serializer is
signal byte				: std_logic_vector(width-1 downto 0);
signal finished			: std_logic;
signal run				: std_logic;

subtype index is integer range width-1 downto 0;
signal i				: index;

begin

	read_bits: process
	begin
		if reset ='1' then
			i			<= width-1;
		elsif run = '1' or go ='1' then
			if i = 0 then
				i		<= width-1;
			else
				i		<= i-1;
			end if;
		end if;

		if reset ='1' then
			finished	<= '0';
		elsif i = 1 then
			finished	<= '1';
		else
			finished	<= '0';
		end if;
		
		if reset ='1' then
			run		<= '0';
		elsif go ='1' then
			run		<= '1';
		elsif finished ='1' then
			run		<= '0';
		end if;

		wait until clk ='1';
	end process;

	data_out		<= byte(i);	
	done			<= finished;

	byte	<= data_in when go ='1';

end archi;
