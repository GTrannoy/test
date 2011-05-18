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
use work.tb_package.all;

entity bus_arbitrer is
	port(
		f_clk_period			: in time;
		var_adr_presence		: in std_logic_vector(7 downto 0);
		var_adr_identification	: in std_logic_vector(7 downto 0);
		var_adr_broadcast		: in std_logic_vector(7 downto 0);
		var_adr_consumed		: in std_logic_vector(7 downto 0);
		var_adr_produced		: in std_logic_vector(7 downto 0);
		var_adr_reset			: in std_logic_vector(7 downto 0);
		
		fip_frame_trigger		: out std_logic;
		id_rp					: out std_logic;
		station_adr				: out std_logic_vector(7 downto 0);
		var_adr					: out std_logic_vector(7 downto 0);
		var_length				: out std_logic_vector(6 downto 0)
	);
end bus_arbitrer;

architecture archi of bus_arbitrer is

signal s_fip_frame_trigger		: std_logic;
signal s_id_rp					: std_logic;
signal s_station_adr			: std_logic_vector(7 downto 0);
signal s_var_adr				: std_logic_vector(7 downto 0):=(others =>'0');
signal s_var_length				: std_logic_vector(6 downto 0):=(others =>'0');

begin

	-- process reading the schedule of frame exchange from a text file
	------------------------------------------------------------------
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
		wait for 0 us;
		wait for 0 us;
		readline	(schedule_file, schedule_line);
		readline	(schedule_file, schedule_line);
		readline	(schedule_file, schedule_line);
		wait for f_clk_period;

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
				if s_var_adr = var_adr_presence then
					report "            FIP BA sends an ID_DAT identifier for Presence Variable to the agent with address "
					& integer'image(to_integer(unsigned(s_station_adr))) & LF;

				elsif s_var_adr = var_adr_identification then
					report "            FIP BA sends an ID_DAT identifier for Identification Variable to the agent with address "
					& integer'image(to_integer(unsigned(s_station_adr))) & LF;

				elsif s_var_adr = var_adr_broadcast then
					report "            FIP BA sends an ID_DAT identifier for Consumed Broadcast Variable to the agent with address "
					& integer'image(to_integer(unsigned(s_station_adr))) & LF;

				elsif s_var_adr = var_adr_consumed then
					report "            FIP BA sends an ID_DAT identifier for Consumed Variable to the agent with address "
					& integer'image(to_integer(unsigned(s_station_adr))) & LF;

				elsif s_var_adr = var_adr_produced then
					report "            FIP BA sends an ID_DAT identifier for Produced Variable to the agent with address "
					& integer'image(to_integer(unsigned(s_station_adr))) & LF;

				elsif s_var_adr = var_adr_reset then
					report "            FIP BA sends an ID_DAT identifier for Reset Variable to the agent with address "
					& integer'image(to_integer(unsigned(s_station_adr))) & LF;

				else
					report "               ++ FIP BA sends an ID_DAT identifier for an unknown variable to the agent with address " 
					& integer'image(to_integer(unsigned(s_station_adr)))
					& LF & "               ++ nanoFIP should discard this frame and ignore the subsequent RP_DAT if any."
					& LF & "               ++ As a result, the reading of the Consumed or Broadcast variable memory by the user logic"
					& LF & "               ++ should not match the values sent from FIP by the BA and the checking should report ## NOT OK ##."
					& LF & "               ++ In case no RP_DAT is issued by the BA, the checking of the response time should report ## NOT OK ##." & LF
					severity warning;
				end if;
			else
				if s_var_adr = x"E0" then
					report "            FIP BA sends an RP_DAT frame for consumption with "
										& integer'image(to_integer(unsigned(s_station_adr)+x"01")) & " on the first byte and "
										& integer'image(to_integer(unsigned(s_station_adr)+x"02")) & " on the second byte"
										& " + the MPS byte" & LF & LF;
				
				else
					if unsigned(s_var_length) < 125 then
						report "            FIP BA sends an RP_DAT frame for consumption with "
											& integer'image(to_integer(unsigned(s_var_length))) & " bytes of data"
											& " + the MPS byte" & LF & LF;
					else
						report "               FIP BA sends an RP_DAT frame for consumption with "
											   & integer'image(to_integer(unsigned(s_var_length))) & " bytes of data."
											   & " the MPS byte"
						& LF & "               ++ This variable length is above nanoFIP specs."
						& LF & "               ++ nanoFIP should discard the frame, and report it in the corresponding flag of the status byte of the next Produced variable."
						& LF & "               ++ The VAR_RDY signal should be inactive. However, the reading of the Consumed or Broadcast variable memory by the user logic"
						& LF & "               ++ will match the 124 first values sent from FIP by the BA and the checking will report _ OK _." & LF & LF
						severity warning;
					end if;
				end if;
			end if;
		end if;
	end process;
	
end archi;
		
