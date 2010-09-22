-- Created by : G. Penacoba
-- Creation Date: Aug 2010
-- Description: Schedules the activity of the WorldFIP bus
-- Modified by:
-- Modification Date:
-- Modification consisted on:

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use std.textio.all;

entity bus_arbitrer is
	port(
		id_rp				: out std_logic;
		fip_frame_trigger	: out std_logic;
		station_adr			: out std_logic_vector(7 downto 0);
		var_adr				: out std_logic_vector(7 downto 0);
		var_length			: out std_logic_vector(6 downto 0)
	);
end bus_arbitrer;

architecture archi of bus_arbitrer is

begin

	scheduler: process
	file schedule_file			: text open read_mode is "data/fip_BA_schedule.txt";
	variable schedule_line		: line;
	variable stand_by_time		: time;
	variable coma				: string(1 to 1);
	
	variable id_rp_tmp			: std_logic;
	variable station_adr_tmp	: std_logic_vector(7 downto 0);
	variable var_adr_tmp		: std_logic_vector(7 downto 0);
	variable var_length_tmp		: integer;
	
	begin

		readline	(schedule_file, schedule_line);
		readline	(schedule_file, schedule_line);
		readline	(schedule_file, schedule_line);

		loop
			fip_frame_trigger		<= '0';
	
			readline	(schedule_file, schedule_line);
			read		(schedule_line, stand_by_time);
			if not(endfile(schedule_file)) then
				readline	(schedule_file, schedule_line);
				read		(schedule_line, id_rp_tmp);
				read		(schedule_line, coma);
				hread		(schedule_line, station_adr_tmp);
				read		(schedule_line, coma);
				hread		(schedule_line, var_adr_tmp);
				read		(schedule_line, coma);
				read		(schedule_line, var_length_tmp);
			else
				file_close(schedule_file);
			end if;
			wait for stand_by_time;
			
			fip_frame_trigger		<= '1' after 1 ps;
			id_rp					<= id_rp_tmp;
			station_adr				<= station_adr_tmp;
			var_adr					<= var_adr_tmp;
			var_length				<= std_logic_vector(to_unsigned(var_length_tmp,7));
			wait for 10 us;
		end loop;
	end process;
		
end archi;
		
