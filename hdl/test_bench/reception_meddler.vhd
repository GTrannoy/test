-- Created by : G. Penacoba
-- Creation Date: March 2011
-- Description: Introduces violation and jitter errors on the received stream
--				or defines the number of bits to be sliced off the stream
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
		
		jitter						: out jitter_time;
		nb_truncated_bits			: out byte_slice;
		truncated_preamble			: out boolean;
		v_minus_err					: out std_logic;
		v_plus_err					: out std_logic
	);
end reception_meddler;

architecture archi of reception_meddler is

signal config_validity_time		: time;
signal insertion_pending		: boolean:= TRUE;
signal insert_violation			: boolean;
signal jitter_active			: boolean:=FALSE;
signal jitter_value				: time;
signal report_config_trigger	: std_logic;
signal trunc_preamble			: boolean;
signal truncated_bits			: byte_slice;
signal violation_positive		: boolean:= TRUE;

begin

-- process reading config values from a file
	---------------------------------------------
	read_config: process
	file config_file				: text open read_mode is "data/errors_config.txt";
	variable config_line			: line;
	variable validity_time			: time;
	
	variable trunc_preamble_config	: boolean;
	variable insert_viol_config		: boolean;
	variable jitter_config			: jitter_time;
	variable truncated_bits_config	: byte_slice;
	begin
		readline	(config_file, config_line);
		read		(config_line, trunc_preamble_config);
		readline	(config_file, config_line);
		read		(config_line, insert_viol_config);
		readline	(config_file, config_line);
		read		(config_line, jitter_config);
		readline	(config_file, config_line);
		read		(config_line, truncated_bits_config);

		readline	(config_file, config_line);
		readline	(config_file, config_line);
		
		readline	(config_file, config_line);
		read		(config_line, validity_time);
		if endfile(config_file) then
			file_close(config_file);
		end if;
		trunc_preamble			<= trunc_preamble_config;
		insert_violation		<= insert_viol_config;
		jitter_value			<= jitter_config;
		truncated_bits			<= truncated_bits_config;
		config_validity_time	<= validity_time;
		report_config_trigger	<= '1';
		wait for 0 ps;
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
				insertion_pending			<= FALSE;
				violation_positive			<= not(violation_positive);
			else
				v_minus_err					<= '0';
				v_plus_err					<= '0';
			end if;
		else
			v_minus_err						<= '0';
			v_plus_err						<= '0';
			insertion_pending				<= TRUE;
		end if;
		wait until clk ='1';
	end process;
	
	jitter_insertion: process
	begin
		jitter_active						<= not(jitter_active);
		wait until clk ='1';
	end process;
	
	nb_truncated_bits						<= truncated_bits;
	truncated_preamble						<= trunc_preamble;
	jitter									<= jitter_value when jitter_active else 0 ps;
	
	reporting: process(report_config_trigger)
	begin
		if report_config_trigger'event and report_config_trigger ='1' then
			if now > 0 ps then
				if trunc_preamble then
					report	"               A malfunction in the reception from the FIELDRIVE is simulated " 
					& LF &  "               by truncating the begining of the preamble" & LF
					severity warning;
				end if;
				if insert_violation then
					report	"               A reception error from the FIELDRIVE is simulated " 
					& LF &  "               by inserting a violation in the manchester code." 
					& LF &  "               This should be reflected by a flag bit in the nanoFIP status error byte" & LF
					severity warning;
				end if;
				if truncated_bits > 0 then
					report	"               A reception error from the FIELDRIVE is simulated " 
					& LF &  "               by truncating " & integer'image(truncated_bits) & " bit(s) per byte " 
					& LF &  "               of the data in the frame(s) being sent" & LF
					severity warning;
				end if;		
			end if;
		end if;
	end process;

end archi;

