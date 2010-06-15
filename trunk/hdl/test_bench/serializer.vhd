-- Created by : G. Penacoba
-- Creation Date: March 2010
-- Description: Converts into a serial output the input word of configurable width
-- Modified by:
-- Modification Date:
-- Modification consisted on:

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity serializer is
	generic(
		width			: integer:=8
	);
	port(
		clk				: in std_logic;
		data_in			: in std_logic_vector(width-1 downto 0);
		go				: in std_logic;

		data_out		: out std_logic;
		done			: out std_logic
	);
end serializer;

architecture archi of serializer is
signal byte				: std_logic_vector(width-1 downto 0);
signal finished			: std_logic;
signal run				: std_logic;

subtype index is integer range width-1 downto 0;
signal i				: index;

begin

	read_bits: process
	begin
		if run = '1' then
			if i = 0 then
				i		<= width-1;
			else
				i		<= i-1;
			end if;

			if i = 1 then
				finished	<= '1';
			else
				finished	<= '0';
			end if;
		end if;

		if go ='1' then
			run		<= '1';
		elsif finished ='1' then
			run		<= '0';
		end if;

		if go ='1' then
			byte	<= data_in;
		end if;

		wait until clk ='1';
	end process;

	data_out		<= byte(i);	
	done			<= finished;

end archi;
