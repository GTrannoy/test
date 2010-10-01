-- Created by : G. Penacoba
-- Creation Date: May 2010
-- Description: Module for the readout of the configuration settings from a 
--				text file.
-- Modified by:
-- Modification Date:
-- Modification consisted on:

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use std.textio.all;


entity bus_config is
	generic(
		crc_l				: integer:=16
	);
	port(
		f_clk_period		: out time;
		gx					: out std_logic_vector(crc_l downto 0)		
	);
end;

architecture archi of bus_config is

signal s_gx					: std_logic_vector(crc_l downto 0);

signal bit_rate				: integer;
signal read_config_trigger	: std_logic;
signal report_config_trigger: std_logic;
signal gx_strg				: string(1 to crc_l+1);
signal rate_strg			: string(1 to 19);


begin

	-- process reading config values from a file
	---------------------------------------------
	read_config: process
	file config_file			: text open read_mode is "data/WFIP_communication_config.txt";
	variable config_line		: line;
	variable validity_time		: time;

	variable bit_rate_config	: integer;
	variable gx_config			: std_logic_vector(crc_l downto 0);
	begin
		read_config_trigger		<= '0';
		readline	(config_file, config_line);
		read		(config_line, bit_rate_config);
		readline	(config_file, config_line);
		read		(config_line, gx_config);
		readline	(config_file, config_line);
		read		(config_line, validity_time);
		if endfile(config_file) then
			file_close(config_file);
		end if;
		bit_rate				<= bit_rate_config;
		gx						<= gx_config;
		s_gx					<= gx_config;
		read_config_trigger		<= '1';
		wait for validity_time;
	end process;

	with bit_rate select
						f_clk_period	<=	32 us	when 0,
											1 us	when 1,
											400 ns	when 2,
											0 us	when others;

	-- Translation of values for the reporting
	------------------------------------------
	with bit_rate select
		rate_strg					<=	"31.25 kbit/s       "	when 0,
										"1 Mbit/s           "	when 1,
										"2.5 Mbit/s         "	when 2,
										"Incorrectly defined"	when others;
	
	gx_strg_generation: for i in crc_l downto 0 generate
		gx_strg(crc_l+1-i) <= '1' when s_gx(i) ='1' else '0';
	end generate;
	
	-- reporting process
	-----------------------
	report_config_trigger		<= read_config_trigger after 1 ps;

	reporting: process(report_config_trigger)
	begin
		if report_config_trigger'event and report_config_trigger ='1' then
			report LF & "WFIP bus configuration settings for test" & LF &
						"-----------------------------------------" & LF &
			"WorldFIP rate: " & rate_strg & LF &
			"CRC length: " & integer'image(crc_l) & " bits" & LF &
			"CRC generation polinomial: " & gx_strg & Lf;
		end if;
	end process;
end archi;
