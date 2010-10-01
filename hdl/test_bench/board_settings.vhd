-- Created by : G. Penacoba
-- Creation Date: MAy 2010
-- Description: Module emulating the settings on the board switches
-- Modified by: Penacoba
-- Modification Date: September 2010
-- Modification consisted on: All the config data come from a text file.
--								No compilation is needed to run a new test
--								with different board configuration, and several
--								successive configurations can be run on the same test.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use std.textio.all;

entity board_settings is
	port(
		s_id_i			: in std_logic_vector(1 downto 0);
		
		c_id_o			: out std_logic_vector(3 downto 0);
		m_id_o			: out std_logic_vector(3 downto 0);
		nostat_o		: out std_logic;
		p3_lgth_o		: out std_logic_vector(2 downto 0);
		rate_o			: out std_logic_vector(1 downto 0);
		slone_o			: out std_logic;
		subs_o			: out std_logic_vector(7 downto 0)
	);
end board_settings;

architecture archi of board_settings is

signal c_id_3					: string(1 to 3);
signal c_id_2					: string(1 to 3);
signal c_id_1					: string(1 to 3);
signal c_id_0					: string(1 to 3);
signal m_id_3					: string(1 to 3);
signal m_id_2					: string(1 to 3);
signal m_id_1					: string(1 to 3);
signal m_id_0					: string(1 to 3);
signal nostat					: std_logic;
signal plength					: std_logic_vector(2 downto 0);
signal rate						: std_logic_vector(1 downto 0);
signal slone					: std_logic;
signal station_adr				: unsigned(7 downto 0);

signal constructor				: unsigned(7 downto 0);
signal model					: unsigned(7 downto 0);
signal length_strg				: string(1 to 19);
signal mode_strg				: string(1 to 19);
signal rate_strg				: string(1 to 19);
signal nstat_strg				: string(1 to 19);

signal read_config_trigger		: std_logic:='0';
signal report_config_trigger	: std_logic:='0';

begin

	-- process reading config values from a file
	---------------------------------------------
	read_config: process
	file config_file			: text open read_mode is "data/board_settings_config.txt";
	variable config_line		: line;
	variable validity_time		: time;

	variable c_id_3_config		: string(1 to 3);
	variable c_id_2_config		: string(1 to 3);
	variable c_id_1_config		: string(1 to 3);
	variable c_id_0_config		: string(1 to 3);
	variable m_id_3_config		: string(1 to 3);
	variable m_id_2_config		: string(1 to 3);
	variable m_id_1_config		: string(1 to 3);
	variable m_id_0_config		: string(1 to 3);
	variable nostat_config		: std_logic;
	variable plength_config		: std_logic_vector(2 downto 0);
	variable rate_config		: std_logic_vector(1 downto 0);
	variable slone_config		: std_logic;
	variable station_adr_config	: std_logic_vector(7 downto 0);
	
	begin
		read_config_trigger		<= '0';
		
		readline	(config_file, config_line);
		read		(config_line, c_id_3_config);
		readline	(config_file, config_line);
		read		(config_line, c_id_2_config);
		readline	(config_file, config_line);
		read		(config_line, c_id_1_config);
		readline	(config_file, config_line);
		read		(config_line, c_id_0_config);

		readline	(config_file, config_line);
		read		(config_line, m_id_3_config);
		readline	(config_file, config_line);
		read		(config_line, m_id_2_config);
		readline	(config_file, config_line);
		read		(config_line, m_id_1_config);
		readline	(config_file, config_line);
		read		(config_line, m_id_0_config);

		readline	(config_file, config_line);
		read		(config_line, nostat_config);

		readline	(config_file, config_line);
		read		(config_line, plength_config);

		readline	(config_file, config_line);
		read		(config_line, rate_config);

		readline	(config_file, config_line);
		read		(config_line, slone_config);

		readline	(config_file, config_line);
		hread		(config_line, station_adr_config);

		readline	(config_file, config_line);
		read		(config_line, validity_time);
		if endfile(config_file) then
			file_close(config_file);
		end if;
--		wait for 1 ps;
		
		read_config_trigger		<= '1';
		c_id_3					<= c_id_3_config;
		c_id_2					<= c_id_2_config;
		c_id_1					<= c_id_1_config;
		c_id_0					<= c_id_0_config;
		m_id_3					<= m_id_3_config;
		m_id_2					<= m_id_2_config;
		m_id_1					<= m_id_1_config;
		m_id_0					<= m_id_0_config;
		nostat					<= nostat_config;
		plength					<= plength_config;
		rate					<= rate_config;
		slone					<= slone_config;
		station_adr				<= unsigned(station_adr_config);
		wait for validity_time;
	end process;
	
	-- Signals actually sent to nanoFIP
	-----------------------------------
	with c_id_3 select
					c_id_o(3)		<=	'0'			when "gnd",
										'1' 		when "vcc",
										s_id_i(1) 	when "sd1",
										s_id_i(0) 	when "sd0",
										'0'			when others;
	with c_id_2 select
					c_id_o(2)		<=	'0'			when "gnd",
										'1' 		when "vcc",
										s_id_i(1) 	when "sd1",
										s_id_i(0) 	when "sd0",
										'0'			when others;
	with c_id_1 select
					c_id_o(1)		<=	'0'			when "gnd",
										'1' 		when "vcc",
										s_id_i(1) 	when "sd1",
										s_id_i(0) 	when "sd0",
										'0'			when others;
	with c_id_0 select
					c_id_o(0)		<=	'0'			when "gnd",
										'1' 		when "vcc",
										s_id_i(1) 	when "sd1",
										s_id_i(0) 	when "sd0",
										'0'			when others;
	with m_id_3 select
					m_id_o(3)		<=	'0'			when "gnd",
										'1' 		when "vcc",
										s_id_i(1) 	when "sd1",
										s_id_i(0) 	when "sd0",
										'0'			when others;
	with m_id_2 select
					m_id_o(2)		<=	'0'			when "gnd",
										'1' 		when "vcc",
										s_id_i(1) 	when "sd1",
										s_id_i(0) 	when "sd0",
										'0'			when others;
	with m_id_1 select
					m_id_o(1)		<=	'0'			when "gnd",
										'1' 		when "vcc",
										s_id_i(1) 	when "sd1",
										s_id_i(0) 	when "sd0",
										'0'			when others;
	with m_id_0 select
					m_id_o(0)		<=	'0'			when "gnd",
										'1' 		when "vcc",
										s_id_i(1) 	when "sd1",
										s_id_i(0) 	when "sd0",
										'0'			when others;
	nostat_o						<= nostat;
	p3_lgth_o						<= plength;
	rate_o							<= rate;
	slone_o							<= slone;
	subs_o							<= std_logic_vector(station_adr);

	-- Translation of values for the reporting
	------------------------------------------
	with c_id_3 select
			constructor(7 downto 6)	<=	"00"	when "gnd",
										"11" 	when "vcc",
										"10"	when "sd1",
										"01"	when "sd0",
										"00"	when others;
	with c_id_2 select
			constructor(5 downto 4)	<=	"00"	when "gnd",
										"11" 	when "vcc",
										"10"	when "sd1",
										"01"	when "sd0",
										"00"	when others;
	with c_id_1 select
			constructor(3 downto 2)	<=	"00"	when "gnd",
										"11" 	when "vcc",
										"10"	when "sd1",
										"01"	when "sd0",
										"00"	when others;
	with c_id_0 select
			constructor(1 downto 0)	<=	"00"	when "gnd",
										"11" 	when "vcc",
										"10"	when "sd1",
										"01"	when "sd0",
										"00"	when others;
	with m_id_3 select
			model(7 downto 6)		<=	"00"	when "gnd",
										"11" 	when "vcc",
										"10"	when "sd1",
										"01"	when "sd0",
										"00"	when others;
	with m_id_2 select
			model(5 downto 4)		<=	"00"	when "gnd",
										"11" 	when "vcc",
										"10"	when "sd1",
										"01"	when "sd0",
										"00"	when others;
	with m_id_1 select
			model(3 downto 2)		<=	"00"	when "gnd",
										"11" 	when "vcc",
										"10"	when "sd1",
										"01"	when "sd0",
										"00"	when others;
	with m_id_0 select
			model(1 downto 0)		<=	"00"	when "gnd",
										"11" 	when "vcc",
										"10"	when "sd1",
										"01"	when "sd0",
										"00"	when others;
	with nostat select
		nstat_strg					<=	"Disabled           "	when '1',
										"Enabled            "	when '0',
										"Incorrectly defined"	when others;
	with plength select
		length_strg					<=	"2 bytes            "	when "000",
										"8 bytes            "	when "001",
										"16 bytes           "	when "010",
										"32 bytes           "	when "011",
										"64 bytes           "	when "100",
										"124 bytes          "	when "101",
										"Incorrectly defined"	when others;
	with rate select
		rate_strg					<=	"31.25 kbit/s       "	when "00",
										"1 Mbit/s           "	when "01",
										"2.5 Mbit/s         "	when "10",
										"Incorrectly defined"	when others;
	with slone select
		mode_strg					<=	"Memory mode        "	when '0',
										"Stand-alone mode   "	when '1',
										"Incorrectly defined"	when others;

	-- reporting processes
	-----------------------
	report_config_trigger		<= read_config_trigger after 1 ps;

	reporting: process(report_config_trigger)
	begin
		if report_config_trigger'event and report_config_trigger ='1' then
			report LF & "Board configuration settings for nanoFIP under test" & LF &
						"---------------------------------------------------" & LF &
			"WorldFIP rate: " & rate_strg & LF &
			"Agent address: " & integer'image(to_integer(station_adr)) & LF &
			"Operation mode: " & mode_strg & Lf &
			"Produced variable length: " & length_strg & LF &
			"NanoFIP status byte tranmission: " & nstat_strg & LF &
			"Constructor ID: " & integer'image(to_integer(constructor)) & LF &
			"Model ID: " & integer'image(to_integer(model)) & LF;
		end if;
	end process;
	
end archi;
