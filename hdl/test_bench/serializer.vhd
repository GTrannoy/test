-- Created by : G. Penacoba
-- Creation Date: March 2010
-- Description: Converts into a serial output the input word of configurable width
-- Modified by: Penacoba
-- Modification Date: 29 june 2010
-- Modification consisted on: Reset input added. 'Finished' signal not dependent
--								on 'run' signal anymore

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.tb_package.all;

entity serializer is
	generic(
		width					: byte_width:=8
	);
	port(
		clk						: in std_logic;
		data_in					: in std_logic_vector(width-1 downto 0);
		go						: in std_logic;
		nb_truncated_bits		: in byte_slice;
		reset					: in std_logic;

		data_out				: out std_logic;
		done					: out std_logic
	);
end serializer;

architecture archi of serializer is
signal byte						: std_logic_vector(width-1 downto 0);
signal finished					: std_logic;
signal report_config_trigger	: std_logic;
signal run						: std_logic;

subtype index is integer range width-1 downto 0;
signal i						: index;

signal actual_width				: byte_width;

begin

	read_bits: process
	begin
		if reset ='1' then
			i			<= actual_width-1;
		elsif run = '1' then
			if i = 0 then
				i		<= actual_width-1;
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

		if reset ='1' then
			byte	<= (others =>'0');
		elsif go ='1' then
			byte	<= data_in;
		end if;

		wait until clk ='1';
	end process;

	actual_width			<= width - nb_truncated_bits;
	data_out				<= byte(i);	
	done					<= finished;

end archi;
