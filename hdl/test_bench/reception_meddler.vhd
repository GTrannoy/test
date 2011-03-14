-- Created by : G. Penacoba
-- Creation Date: March 2011
-- Description: Introduces violation and jitter errors on the received stream
--				according to the configuration and schedule retrieved from text files.
-- Modified by:
-- Modification Date:
-- Modification consisted on:

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use std.textio.all;
use work.tb_package.all;

entity reception_meddler is
	port(
		clk							: in std_logic;
		
		jitter						: out time;
		v_minus_err					: out std_logic;
		v_plus_err					: out std_logic
	);
end reception_meddler;

architecture archi of reception_meddler is

signal config_validity_time		: time;
signal insertion_pending		: boolean:= TRUE;
signal insert_violation			: boolean;
signal jitter_active			: boolean;
signal jitter_value				: time;
signal report_config_trigger	: std_logic;
signal violation_positive		: boolean:= TRUE;

begin

-- process reading config values from a file
	---------------------------------------------
	read_config: process
	file config_file				: text open read_mode is "data/errors_config.txt";
	variable config_line			: line;
	variable validity_time			: time;
	
	variable insert_viol_config		: boolean;
	variable jitter_config			: time;
	begin
		readline	(config_file, config_line);
		read		(config_line, insert_viol_config);
		readline	(config_file, config_line);
		read		(config_line, jitter_config);

		readline	(config_file, config_line);
		readline	(config_file, config_line);
		readline	(config_file, config_line);
		
		readline	(config_file, config_line);
		read		(config_line, validity_time);
		if endfile(config_file) then
			file_close(config_file);
		end if;
		insert_violation		<= insert_viol_config;
		jitter_value			<= jitter_config;
		config_validity_time	<= validity_time;
		report_config_trigger	<= '1';
		wait for validity_time - 1 ps;
		report_config_trigger	<= '0';
		wait for 1 ps;
	end process;


	violation_insertion: process
	begin
		if insert_violation then	
			if insertion_pending then	
				if violation_positive then
					v_minus_err				<= '0';
					v_plus_err				<= '1';
				else
					v_minus_err				<= '1';
					v_plus_err				<= '0';
				end if;
				insertion_pending		<= FALSE;
				violation_positive		<= not(violation_positive);
			else
				v_minus_err					<= '0';
				v_plus_err					<= '0';
			end if;
		else
			v_minus_err					<= '0';
			v_plus_err					<= '0';
			insertion_pending			<= TRUE;
		end if;
		wait until clk ='1';
	end process;
	

	reporting: process(report_config_trigger)
	begin
		if report_config_trigger'event and report_config_trigger ='1' then
			if insert_violation then
				report	"               A reception error from the FIELDRIVE is simulated " 
				& LF &  "               by inserting a violation in the manchester code." 
				& LF &  "               This should be reflected by a flag bit in the nanoFIP status error byte" & LF
				severity warning;
			end if;
		end if;
	end process;

end archi;

