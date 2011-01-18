-- Created by : G. Penacoba
-- Creation Date: March 2010
-- Description: Counter with enable signal. Count value and 'done' signal
--				available. 'done' signal asserted at count value = 0.
-- Modified by: G. Penacoba
-- Modification Date: 30/04/2010
-- Modification consisted on: using unsigned types and numeric_std package
--								instead of std_logic_vectors and std_logic_unsigned


library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity encounter is
	generic(
		width		: integer:=16
	);
	port(
		clk			: in std_logic;
		en			: in std_logic;
		reset		: in std_logic;
		start_value	: in std_logic_vector(width-1 downto 0);
	
		count		: out std_logic_vector(width-1 downto 0);
		count_done	: out std_logic
	);
	
end encounter;

architecture archi of encounter is

constant zeroes	: unsigned(width-1 downto 0):=(others=>'0');

signal one		: unsigned(width-1 downto 0);
signal value	: unsigned(width-1 downto 0):=(others=>'0');

begin
	
	decount: process (reset, clk, start_value)
	begin
		if reset = '1' then
			value		<= unsigned(start_value);
		elsif clk'event and clk= '1' then
			if en = '1' and value > zeroes then
				value	<= value - "1";
			end if;
		end if;
	end process;
	count	<= std_logic_vector(value);

	one	<= zeroes + "1";
	redundant: process (reset, clk)
	begin
		if reset = '1' then
			count_done	<= '0';
		elsif clk'event and clk ='1' then
			if en ='1' and value = one then	
				count_done	<= '1';
			elsif value = zeroes then
				count_done	<= '1';
			else
				count_done	<= '0';
			end if;
		end if;
	end process;
	
end archi;
