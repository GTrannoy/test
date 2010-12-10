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

entity slone_monitor is
	port(
		dat_i				: in std_logic_vector(15 downto 0);
		dat_o				: in std_logic_vector(15 downto 0);
		slone_access_read	: in std_logic;
		slone_access_write	: in std_logic;
		uclk				: in std_logic;
		ureset				: in std_logic;
		var_id				: in std_logic_vector(1 downto 0)
	);
end slone_monitor;

architecture archi of slone_monitor is

signal in_consumed		: std_logic_vector(15 downto 0);
signal in_broadcast		: std_logic_vector(15 downto 0);
signal out_produced		: vector_type;

begin

	-- process reading from a text file the data sent by FIP for consumption
	------------------------------------------------------------------------
	read_incoming: process(slone_access_read, var_id)
	file data_file			: text;
	variable data_line		: line;
	variable data_byte_hi	: std_logic_vector(7 downto 0);
	variable data_byte_lo	: std_logic_vector(7 downto 0);
	
	begin
		if slone_access_read ='1' then
			if var_id = "01" then
				file_open(data_file,"data/tmp_var1_mem.txt",read_mode);
				readline			(data_file, data_line);
				readline			(data_file, data_line);
				readline			(data_file, data_line);
				read				(data_line, data_byte_lo);
				readline			(data_file, data_line);
				read				(data_line, data_byte_hi);
				file_close(data_file);
				in_consumed			<= data_byte_hi & data_byte_lo;
			elsif var_id = "10" then
				file_open(data_file,"data/tmp_var2_mem.txt",read_mode);
				readline			(data_file, data_line);
				readline			(data_file, data_line);
				readline			(data_file, data_line);
				read				(data_line, data_byte_lo);
				readline			(data_file, data_line);
				read				(data_line, data_byte_hi);
				file_close(data_file);
				in_broadcast		<= data_byte_hi & data_byte_lo;
			end if;
		end if;
	end process;

	-- process checking the validity of the incoming consumed data as they are read from nanoFIP slone bus
	------------------------------------------------------------------------------------------------------
	check_consumed_and_broadcast: process(slone_access_read)
	begin
		if slone_access_read ='0' then
			if var_id = "01" then
				assert in_consumed = dat_i
				report "               **** check NOT OK ****  The value read from the 16-bit stand-alone bus" &
				" does not match the one sent from FIP for the consumed variable" & LF
				severity warning;
			elsif var_id = "10" then
				assert in_broadcast = dat_i
				report "               **** check NOT OK ****  The value read from the 16-bit stand-alone bus" &
				" does not match the one sent from FIP for the broadcast variable" & LF
				severity warning;
			end if;
		end if;
	end process;
	
	-- process building an image of the nanoFIP memory for the produced variable
	----------------------------------------------------------------------------
	building_produced: process
	begin
		if slone_access_write ='1' then
			out_produced(2)		<= dat_o(7 downto 0);
			out_produced(3)		<= dat_o(15 downto 8);
		end if;
		wait until uclk ='1';
	end process;
	
	-- process transcribing to a text file the image of the nanoFIP memory for the produced variable
	------------------------------------------------------------------------------------------------
	write_outgoing: process(slone_access_write)
	file data_file			: text;
	variable data_line		: line;

	begin
		if slone_access_write ='0' then
			file_open(data_file,"data/tmp_var3_mem.txt",write_mode);
			for i in 0 to max_frame_length-1 loop
				write		(data_line, out_produced(i));
				writeline	(data_file, data_line);
			end loop;
			file_close(data_file);
		end if;
	end process;
	
end archi;
