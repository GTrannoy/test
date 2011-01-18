-- Created by : G. Penacoba
-- Creation Date: January 2011
-- Description: Converts an std_logic_vector into its bin string representation
-- Modified by:
-- Modification Date:
-- Modification consisted on:

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use std.textio.all;
use work.tb_package.all;

entity bin_byte_transcriber is
	port(
		input		: in std_logic_vector(7 downto 0);
		output		: out string (1 to 8)
	);
end bin_byte_transcriber;


architecture archi of bin_byte_transcriber is
begin
	with input(7) select
		output(1)			<=	'1'	when '1',
								'0' when '0',
								'X' when 'X',
								'U' when 'U',
								'-' when others;

	with input(6) select
		output(2)			<=	'1'	when '1',
								'0' when '0',
								'X' when 'X',
								'U' when 'U',
								'-' when others;
	with input(5) select
		output(3)			<=	'1'	when '1',
								'0' when '0',
								'X' when 'X',
								'U' when 'U',
								'-' when others;
	with input(4) select
		output(4)			<=	'1'	when '1',
								'0' when '0',
								'X' when 'X',
								'U' when 'U',
								'-' when others;
	with input(3) select
		output(5)			<=	'1'	when '1',
								'0' when '0',
								'X' when 'X',
								'U' when 'U',
								'-' when others;
	with input(2) select
		output(6)			<=	'1'	when '1',
								'0' when '0',
								'X' when 'X',
								'U' when 'U',
								'-' when others;
	with input(1) select
		output(7)			<=	'1'	when '1',
								'0' when '0',
								'X' when 'X',
								'U' when 'U',
								'-' when others;
	with input(0) select
		output(8)			<=	'1'	when '1',
								'0' when '0',
								'X' when 'X',
								'U' when 'U',
								'-' when others;
						
end archi;
