-- Created by : G. Penacoba
-- Creation Date: September 2010
-- Description: Module for the readout of the configuration settings from a 
--				text file.
-- Modified by: G. Penacoba
-- Modification Date: January 2011.
-- Modification consisted on: Times of resets are registered in tmp files for use by other units.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use std.textio.all;
use work.tb_package.all;

entity user_config is
	port(
		config_validity		: out time;
		uclk_period			: out time;
		ureset_length		: out time;
		wclk_period			: out time;
		wreset_length		: out time;
		preset_length		: out time
	);
end user_config;

architecture archi of user_config is

	signal read_config_trigger	: std_logic;
	signal report_config_trigger: std_logic;
	signal s_uclk_period		: time;
	signal s_ureset_length		: time;
	signal s_wclk_period		: time;
	signal s_wreset_length		: time;
	signal s_preset_length		: time;

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
	variable preset_lgth_config	: time;
	begin
		readline	(config_file, config_line);
		read		(config_line, uclk_period_config);
		readline	(config_file, config_line);
		read		(config_line, wclk_period_config);
		readline	(config_file, config_line);
		read		(config_line, preset_lgth_config);
		readline	(config_file, config_line);
		read		(config_line, ureset_lgth_config);
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
		s_wclk_period			<= wclk_period_config;
		wclk_period				<= wclk_period_config;
		s_preset_length			<= preset_lgth_config;
		preset_length			<= preset_lgth_config;
		s_ureset_length			<= ureset_lgth_config;
		ureset_length			<= ureset_lgth_config;
		s_wreset_length			<= wreset_lgth_config;
		wreset_length			<= wreset_lgth_config;
		read_config_trigger		<= '1';
		wait for validity_time - 1 ps;
		read_config_trigger			<= '0';
		wait for 1 ps;
	end process;

	-- reporting processes
	-----------------------
	report_config_trigger		<= read_config_trigger;

	history: process(report_config_trigger)
	file phist_file				: text;
	file uhist_file				: text;
	variable phist_line			: line;
	variable uhist_line			: line;
	variable prst_time			: time;
	variable urst_time			: time;
	begin
		if report_config_trigger'event and report_config_trigger ='1' then
			if s_preset_length > 0 fs then
				prst_time			:= now;
				file_open(phist_file, "data/tmp_preset_hist.txt", write_mode);
				write		(phist_line, prst_time);
				writeline	(phist_file, phist_line);
				file_close(phist_file);
			end if;
			if s_ureset_length > 0 fs then
				urst_time			:= now;
				file_open(uhist_file, "data/tmp_ureset_hist.txt", write_mode);
				write		(uhist_line, urst_time);
				writeline	(uhist_file, uhist_line);
				file_close(uhist_file);
			end if;
		end if;
	end process;

	reporting: process(report_config_trigger)
	begin
		if report_config_trigger'event and report_config_trigger ='1' then
			if now = 0 ps then
				report LF & "User logic configuration settings" & LF &
							"---------------------------------" & LF &
							"User Clock period              : " & time'image(s_uclk_period) & LF &
							"Wishbone interface Clock period: " & time'image(s_wclk_period) & LF & LF;
			end if;
			if s_preset_length > 0 fs then
				report	"               The power-on reset (RSTPON) is asserted for " & time'image(s_preset_length) 
				& LF &  "               As a consequence, nanoFIP should reset its internal registers,"
				& LF &  "               assert the Fieldrive reset (FD_RSTN)"
				& LF &  "               and reset the VAR_RDY user interface signals" & LF
				severity warning;
			end if;
			if s_ureset_length > 0 fs then
				report	"               The user reset (RSTIN) is asserted for " & time'image(s_ureset_length) 
				& LF &  "               As a consequence, nanoFIP should reset its internal registers,"
				& LF &  "               assert the Fieldrive reset (FD_RSTN)"
				& LF &  "               and reset the VAR_RDY user interface signals" & LF
				severity warning;
			end if;
			if s_wreset_length > 0 fs then
				report	"               The wishbone reset (RST_I) is asserted for " & time'image(s_wreset_length) & LF
				severity warning;
			end if;
		end if;
	end process;
			
			

end archi;	
