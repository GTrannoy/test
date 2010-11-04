-- Created by : G. Penacoba
-- Creation Date: May 2010
-- Description: Generates the Frame End Delimiter (or Frame End Sequence)
-- Modified by:
-- Modification Date:
-- Modification consisted on:

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.tb_package.all;

entity fes_gen is
	generic(
		width					: integer:=8
	);
	port(
		clk						: in std_logic;
		start_delimiter			: in std_logic;
		reset					: in std_logic;
		
		fes						: out std_logic;
		v_minus					: out std_logic;
		v_plus					: out std_logic
	);
end fes_gen;
		
architecture archi of fes_gen is

constant fes_value		: std_logic_vector(width downto 0) :="1XXXX101U";

signal aux				: std_logic;
signal i				: integer range width downto 0;
signal sending_fes		: std_logic;

begin
	
	aux					<= '0' when start_delimiter ='0' else
							'1' when i =width;

	sending_fes			<= '1' when start_delimiter ='1' and aux ='0' else
							'0' when i = 0;

	decount: process
	begin
		if reset ='1' then
			i		<= 0;
		elsif sending_fes ='1' then
			if i = 0 then
				i		<= width;
			else
				i		<= i-1;
			end if;
		end if;
		wait until clk ='1';
	end process;

	fes			<= fes_value(i);
	
	violation: process(i)
	begin
		case i is
		when 7 =>
			v_minus		<= '0';
			v_plus		<= '1';

		when 6 =>
			v_minus		<= '1';
			v_plus		<= '0';
		
		when 5 =>
			v_minus		<= '0';
			v_plus		<= '1';

		when 4 =>
			v_minus		<= '1';
			v_plus		<= '0';

		when others =>
			v_minus		<= '0';
			v_plus		<= '0';
		end case;
	end process;
end archi;		
