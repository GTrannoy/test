-- Created by : G. Penacoba
-- Creation Date: September 2010
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

entity user_config is
	port(
		config_validity		: out time;
		uclk_period			: out time;
		ureset_length		: out time;
		wclk_period			: out time;
		wreset_length		: out time
	);
end user_config;

architecture archi of user_config is

	signal read_config_trigger	: std_logic;
	signal report_config_trigger: std_logic;
	signal s_uclk_period		: time;
	signal s_wclk_period		: time;

begin
	-- process reading config values from a file
	---------------------------------------------
	read_config: process
	file config_file			: text open read_mode is "data/user_logic_config.txt";
	variable config_line		: line;
	variable validity_time		: time;
	
	variable uclk_period_config	: time;
	variable ureset_lgth_config	: time;
	variable wclk_period_config	: time;
	variable wreset_lgth_config	: time;
	begin
		read_config_trigger			<= '0';
		readline	(config_file, config_line);
		read		(config_line, uclk_period_config);
		readline	(config_file, config_line);
		read		(config_line, ureset_lgth_config);
		readline	(config_file, config_line);
		read		(config_line, wclk_period_config);
		readline	(config_file, config_line);
		read		(config_line, wreset_lgth_config);
		readline	(config_file, config_line);
		read		(config_line, validity_time);
		if endfile(config_file) then
			file_close(config_file);
		end if;
		config_validity			<= validity_time;
		s_uclk_period			<= uclk_period_config;
		uclk_period				<= uclk_period_config;
		ureset_length			<= ureset_lgth_config;
		s_wclk_period			<= wclk_period_config;
		wclk_period				<= wclk_period_config;
		wreset_length			<= wreset_lgth_config;
		read_config_trigger		<= '1';
		wait for validity_time;
	end process;

	-- reporting processes
	-----------------------
	report_config_trigger		<= read_config_trigger after 1 ps;

	reporting: process(report_config_trigger)
	begin
		if report_config_trigger'event and report_config_trigger ='1' then
			report LF & "User logic configuration" & LF &
						"------------------------" & LF &
			"User Clock period: " & time'image(s_uclk_period) & LF &
			"Wishbone interface Clock period: " & time'image(s_wclk_period) & LF;
		end if;
	end process;

end archi;	
