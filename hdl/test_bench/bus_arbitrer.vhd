-- Created by : G. Penacoba
-- Creation Date: Aug 2010
-- Description: Schedules the activity of the WorldFIP bus
-- Modified by: G. Penacoba
-- Modification Date: September 2010
-- Modification consisted on: Retrieving schedule from a text file and reporting.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use std.textio.all;

entity bus_arbitrer is
	port(
		f_clk_period		: in time;
		
		fip_frame_trigger	: out std_logic;
		id_rp				: out std_logic;
		station_adr			: out std_logic_vector(7 downto 0);
		var_adr				: out std_logic_vector(7 downto 0);
		var_length			: out std_logic_vector(6 downto 0)
	);
end bus_arbitrer;

architecture archi of bus_arbitrer is

signal s_fip_frame_trigger		: std_logic;
signal s_id_rp					: std_logic;
signal s_station_adr			: std_logic_vector(7 downto 0);
signal s_var_adr				: std_logic_vector(7 downto 0);
signal s_var_length				: std_logic_vector(6 downto 0);

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
		wait for 0 us;
		readline	(schedule_file, schedule_line);
		readline	(schedule_file, schedule_line);
		readline	(schedule_file, schedule_line);

		loop
			fip_frame_trigger		<= '0';
			s_fip_frame_trigger		<= '0';
	
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
			wait for stand_by_time - f_clk_period;

			id_rp					<= id_rp_tmp;
			s_id_rp					<= id_rp_tmp;
			station_adr				<= station_adr_tmp;
			s_station_adr			<= station_adr_tmp;
			var_adr					<= var_adr_tmp;
			s_var_adr				<= var_adr_tmp;
			var_length				<= std_logic_vector(to_unsigned(var_length_tmp,7));
			s_var_length			<= std_logic_vector(to_unsigned(var_length_tmp,7));
			fip_frame_trigger		<= '1';
			s_fip_frame_trigger		<= '1';
			wait for f_clk_period;
		end loop;
	end process;

	reporting: process(s_fip_frame_trigger)
	begin
		if s_fip_frame_trigger ='1' then
			if s_id_rp ='1' then
				case s_var_adr is 
				when x"14" =>
					report "            ID_DAT identifier for Presence Variable sent to agent with address "
					& integer'image(to_integer(unsigned(s_station_adr))) & LF;
				when x"10" =>
					report "            ID_DAT identifier for Identification Variable sent to agent with address "
					& integer'image(to_integer(unsigned(s_station_adr))) & LF;
				when x"05" =>
					report "            ID_DAT identifier for Consumed Variable sent to agent with address "
					& integer'image(to_integer(unsigned(s_station_adr))) & LF;
				when x"04" =>
					report "            ID_DAT identifier for Consumed Broadcast Variable sent to agent with address "
					& integer'image(to_integer(unsigned(s_station_adr))) & LF;
				when x"06" =>
					report "            ID_DAT identifier for Produced Variable sent to agent with address "
					& integer'image(to_integer(unsigned(s_station_adr))) & LF;
				when x"E6" =>
					report "            ID_DAT identifier for Reset Variable sent to agent with address "
					& integer'image(to_integer(unsigned(s_station_adr))) & LF;
				when others =>
					report "            ID_DAT identifier for a not supported variable sent to agent with address " 
					& integer'image(to_integer(unsigned(s_station_adr))) & LF;
				end case;
			else
				report "            RP_DAT frame with " & integer'image(to_integer(unsigned(s_var_length))) 
						& " bytes of data + MPS sent for consumption" & LF & LF;
			end if;
		end if;
	end process;
		
end archi;
		
