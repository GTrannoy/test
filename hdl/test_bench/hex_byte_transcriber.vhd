-- Created by : G. Penacoba
-- Creation Date: October 2010
-- Description: Converts an std_logic_vector into its hex string representation
-- Modified by:
-- Modification Date:
-- Modification consisted on:

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use std.textio.all;

entity hex_byte_transcriber is
	port(
		input		: in std_logic_vector(7 downto 0);
		output		: out string (1 to 2)
	);
end hex_byte_transcriber;


architecture archi of hex_byte_transcriber is
begin
	with input(7 downto 4) select
		output(1)			<=	'F'	when x"F",
								'E' when x"E",
								'D' when x"D",
								'C' when x"C",
								'B' when x"B",
								'A' when x"A",
								'9' when x"9",
								'8' when x"8",
								'7' when x"7",
								'6' when x"6",
								'5' when x"5",
								'4' when x"4",
								'3' when x"3",
								'2' when x"2",
								'1' when x"1",
								'0' when x"0",
								'X' when others;
	with input(3 downto 0) select
		output(2)			<=	'F'	when x"F",
								'E' when x"E",
								'D' when x"D",
								'C' when x"C",
								'B' when x"B",
								'A' when x"A",
								'9' when x"9",
								'8' when x"8",
								'7' when x"7",
								'6' when x"6",
								'5' when x"5",
								'4' when x"4",
								'3' when x"3",
								'2' when x"2",
								'1' when x"1",
								'0' when x"0",
								'X' when others;
						
end archi;
