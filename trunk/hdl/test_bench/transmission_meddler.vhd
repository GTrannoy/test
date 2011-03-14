-- Created by : G. Penacoba
-- Creation Date: Oct 2010
-- Description: Set the wdog and txerr signals according to the configuration
--				and schedule retrieved from text files.
-- Modified by:
-- Modification Date:
-- Modification consisted on:

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use std.textio.all;
use work.tb_package.all;

entity transmission_meddler is
	port(
		txerr					: out std_logic;
		wdgn					: out std_logic
	);
end transmission_meddler;

architecture archi of transmission_meddler is

signal report_config_trigger	: std_logic;
signal txerr_length				: time;
signal wdgn_length				: time;
signal config_validity_time		: time;

begin

-- full functionality yet to be implemented
-------------------------------------------
--	txerr					<= '0';
--	wdgn					<= '1';
	
-- process reading config values from a file
	---------------------------------------------
	read_config: process
	file config_file				: text open read_mode is "data/errors_config.txt";
	variable config_line			: line;
	variable validity_time			: time;
	
	variable txerr_length_config	: time;
	variable wdgn_length_config		: time;
	begin
		readline	(config_file, config_line);
		readline	(config_file, config_line);
		readline	(config_file, config_line);

		readline	(config_file, config_line);
		read		(config_line, txerr_length_config);
		readline	(config_file, config_line);
		read		(config_line, wdgn_length_config);

		readline	(config_file, config_line);
		read		(config_line, validity_time);
		if endfile(config_file) then
			file_close(config_file);
		end if;
		txerr_length			<= txerr_length_config;
		wdgn_length				<= wdgn_length_config;
		config_validity_time	<= validity_time;
		report_config_trigger	<= '1';
		wait for validity_time - 1 ps;
		report_config_trigger	<= '0';
		wait for 1 ps;
	end process;

	transmission_error: process
	begin
		wait for 0 us;			-- wait needed for the config text file to be read
		if txerr_length > 0 ps then
			txerr			<= '1';
			wait for txerr_length;
		else
			txerr			<= '0';
			wait for txerr_length;
		end if;
		txerr			<= '0';
		wait for config_validity_time - txerr_length;
	end process;

	watchdog_error: process
	begin
		wait for 0 us;			-- wait needed for the config text file to be read
		if wdgn_length > 0 ps then
			wdgn			<= '0';
			wait for wdgn_length;
		else
			wdgn			<= '1';
			wait for wdgn_length;
		end if;
		wdgn			<= '1';
		wait for config_validity_time - wdgn_length;
	end process;

	reporting: process(report_config_trigger)
	begin
		if report_config_trigger'event and report_config_trigger ='1' then
			if txerr_length > 0 fs then
				report	"               A transmission error from the FIELDRIVE is simulated: " 
				& LF &  "               the TXERR signal is activated for " & time'image(txerr_length)
				& LF &  "               This should be reflected by a flag bit in the nanoFIP status error byte" & LF
				severity warning;
			end if;
			if wdgn_length > 0 fs then
				report	"               A watchdog error from the FIELDRIVE is simulated: " 
				& LF &  "               the WDGN signal is activated (low) for " & time'image(wdgn_length)
				& LF &  "               This should be reflected by a flag bit in the nanoFIP status error byte" & LF
				severity warning;
			end if;
		end if;
	end process;

end archi;

