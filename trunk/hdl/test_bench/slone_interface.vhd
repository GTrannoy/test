-- Created by : G. Penacoba
-- Creation Date: November 2010
-- Description: Generates the produced variable data
--				and the variable access signals to indicate activity in stand-alone
-- Modified by:
-- Modification Date:
-- Modification consisted on:

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use std.textio.all;
use work.tb_package.all;

entity slone_interface is
	port(
		launch_slone_read	: in std_logic;
		launch_slone_write	: in std_logic;
		uclk				: in std_logic;
		ureset				: in std_logic;

		dat_o				: out std_logic_vector(15 downto 0);
		slone_access_read	: out std_logic;
		slone_access_write	: out std_logic
	);
end slone_interface;

architecture archi of slone_interface is

signal action					: std_logic;
signal data_for_slone_hi		: std_logic_vector(7 downto 0);
signal data_for_slone_lo		: std_logic_vector(7 downto 0);
signal slone_rd					: std_logic;
signal slone_wr					: std_logic;

begin

	-- process to dectect a rising edge on the inputs
	-------------------------------------------------
	input_registers: process
	begin
		slone_rd		<= launch_slone_read;
		slone_wr		<= launch_slone_write;
		if ureset ='1' then
			action			<= '0';
		elsif (slone_rd ='0' and launch_slone_read ='1') 
			or (slone_wr ='0' and launch_slone_write ='1') then
			action			<= '1';
		else
			action			<= '0';
		end if;		
	wait until uclk ='1';
	end process;
	
	-- processes to fix the output data
	-----------------------------------
	output_register: process
	begin
		if ureset ='1' then
			dat_o					<= (others=>'0');
		elsif action ='1' and slone_wr ='1' then
			dat_o(15 downto 8)		<= data_for_slone_hi;
			dat_o(7 downto 0)		<= data_for_slone_lo;
		end if;
		wait until uclk ='1';
	end process;

	access_register: process
	begin
		if ureset ='1' then
			slone_access_read		<= '0';
		elsif launch_slone_read ='1' or (action ='1' and slone_rd ='1') then
			slone_access_read		<= '1';
		else
			slone_access_read		<= '0';
		end if;
		if ureset ='1' then
			slone_access_write		<= '0';
		elsif launch_slone_write ='1' or (action ='1' and slone_wr ='1') then
			slone_access_write		<= '1';
		else
			slone_access_write		<= '0';
		end if;
		wait until uclk ='1';
	end process;

	-- process reading bytes from random data file
	---------------------------------------------
	read_store: process
	file data_file: text open read_mode is "data/data_store.txt";
	variable data_line: line;
	variable data_byte_hi: std_logic_vector(7 downto 0);
	variable data_byte_lo: std_logic_vector(7 downto 0);
	begin
		readline (data_file, data_line);
		read (data_line, data_byte_hi);
		readline (data_file, data_line);
		read (data_line, data_byte_lo);
		data_for_slone_hi		<= data_byte_hi;
		data_for_slone_lo		<= data_byte_lo;
		wait until uclk ='1';
	end process;
	
end archi;
