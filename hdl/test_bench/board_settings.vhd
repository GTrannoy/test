-- Created by : G. Penacoba
-- Creation Date: MAy 2010
-- Description: Module emulating the settings on the board switches
-- Modified by:
-- Modification Date:
-- Modification consisted on:

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

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

type id_record is record
	pin			: std_logic;
	vector		: unsigned(1 downto 0);
end record;
type id_type is array (3 downto 0) of id_record;

signal var_length			: unsigned(2 downto 0);
signal length_strg			: string(1 to 19);
signal station_adr			: unsigned(7 downto 0);
signal report_trigger		: std_logic:='0';
signal m_id					: id_type;
signal c_id					: id_type;
signal gnd					: id_record;
signal s_id0				: id_record;
signal s_id1				: id_record;
signal vcc					: id_record;
signal model				: unsigned(7 downto 0);
signal constructor			: unsigned(7 downto 0);
signal rate					: std_logic_vector(1 downto 0);
signal rate_strg			: string(1 to 19);
signal nostat				: std_logic;
signal stat_strg			: string(1 to 19);
signal slone				: std_logic;
signal mode_strg			: string(1 to 19);

begin
	
	-- configuration settings (this part of the file is the one to be changed on the different testbenches)
	------------------------------------------------------------------------------------------------------

	rate				<= "01";
	station_adr			<= x"5A";
	slone				<= '1';
	var_length			<= "101";
	nostat				<= '0';

	c_id(3)				<= gnd;
	c_id(2)				<= gnd;
	c_id(1)				<= gnd;
	c_id(0)				<= gnd;
	
	m_id(3)				<= gnd;
	m_id(2)				<= gnd;
	m_id(1)				<= gnd;
	m_id(0)				<= gnd;

	-- specs defintions (this part of the file should not be changed)
	----------------------------------------------------------------
	rate_o							<= rate;
	with rate select
		rate_strg					<=	"31.25 kbit/s       "	when "00",
										"1 Mbit/s           "	when "01",
										"2.5 Mbit/s         "	when "10",
										"Incorrectly defined"	when others;
		
	subs_o							<= std_logic_vector(station_adr);

	slone_o							<= slone;
	with slone select
		mode_strg					<=	"Memory mode        "	when '0',
										"Stand-alone mode   "	when '1',
										"Incorrectly defined"	when others;

	p3_lgth_o						<= std_logic_vector(var_length);
	with var_length select
		length_strg					<=	"2 bytes            "	when "000",
										"8 bytes            "	when "001",
										"16 bytes           "	when "010",
										"32 bytes           "	when "011",
										"64 bytes           "	when "100",
										"124 bytes          "	when "101",
										"Incorrectly defined"	when others;

	nostat_o						<= nostat;
	with nostat select
		stat_strg					<=	"Disabled           "	when '1',
										"Enabled            "	when '0',
										"Incorrectly defined"	when others;

	constructor(7 downto 6)			<= c_id(3).vector;
	constructor(5 downto 4)			<= c_id(2).vector;
	constructor(3 downto 2)			<= c_id(1).vector;
	constructor(1 downto 0)			<= c_id(0).vector;

	c_id_o(3)						<= c_id(3).pin;
	c_id_o(2)						<= c_id(2).pin;
	c_id_o(1)						<= c_id(1).pin;
	c_id_o(0)						<= c_id(0).pin;

	model(7 downto 6)				<= m_id(3).vector;
	model(5 downto 4)				<= m_id(2).vector;
	model(3 downto 2)				<= m_id(1).vector;
	model(1 downto 0)				<= m_id(0).vector;

	m_id_o(3)						<= m_id(3).pin;
	m_id_o(2)						<= m_id(2).pin;
	m_id_o(1)						<= m_id(1).pin;
	m_id_o(0)						<= m_id(0).pin;

	gnd.pin							<= '0';
	gnd.vector						<= "00";
	
	s_id0.pin						<= s_id_i(0);
	s_id0.vector					<= "01";

	s_id1.pin						<= s_id_i(1);
	s_id1.vector					<= "10";

	vcc.pin							<= '1';
	vcc.vector						<= "11";
	
	-- reporting processes
	-----------------------
	report_trigger		<= '1' after 1 ps;

	reporting: process(report_trigger)
	begin
		if now /= 0 ps then
			report LF & "Configuration settings for nanoFIP under test" & LF &
						"---------------------------------------------" & LF &
			"WorldFIP rate: " & rate_strg & LF &
			"Agent address: " & integer'image(to_integer(station_adr)) & LF &
			"Operation mode: " & mode_strg & Lf &
			"Produced variable length: " & length_strg & LF &
			"NanoFIP status byte tranmission: " & stat_strg & LF &
			"Constructor ID: " & integer'image(to_integer(constructor)) & LF &
			"Model ID: " & integer'image(to_integer(model)) & LF;
		end if;
	end process;
	
end archi;
