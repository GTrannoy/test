-- Created by : G. Penacoba
-- Creation Date: September 2010
-- Description: Module for the readout of the configuration settings from a 
--				text file.
-- Modified by: G. Penacoba
-- Modification Date: October 2010
-- Modification consisted on: Added ID_DAT, RP_DAT control bytes and PDU_type and MPS bytes configurable from the text file
-- Modified by: G. Penacoba
-- Modification Date: January 2011
-- Modification consisted on: Added FSS and FES values, variable addresses and turn around times configurable from the text file

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use std.textio.all;
use work.tb_package.all;

entity bus_config is
	generic(
		crc_l					: integer:=16
	);
	port(
		f_clk_period			: out time;
		fes_value				: out std_logic_vector(7 downto 0);
		fss_value				: out std_logic_vector(15 downto 0);
		gx						: out std_logic_vector(crc_l downto 0);
		id_control_byte			: out std_logic_vector(7 downto 0);
		min_turn_around			: out time;
		mps_byte				: out std_logic_vector(7 downto 0);
		pdu_type_byte			: out std_logic_vector(7 downto 0);
		rp_control_byte			: out std_logic_vector(7 downto 0);
		silence_time			: out time;
		var_adr_presence		: out std_logic_vector(7 downto 0);
		var_adr_identification	: out std_logic_vector(7 downto 0);
		var_adr_broadcast		: out std_logic_vector(7 downto 0);
		var_adr_consumed		: out std_logic_vector(7 downto 0);
		var_adr_produced		: out std_logic_vector(7 downto 0);
		var_adr_reset			: out std_logic_vector(7 downto 0)
	);
end;

architecture archi of bus_config is

constant min_turn_around_3125k	: time:= 460 us;
constant min_turn_around_1M		: time:= 10 us;
constant min_turn_around_25M	: time:= 5 us;
constant silence_time_3125k		: time:= 4096 us;
constant silence_time_1M		: time:= 150 us;
constant silence_time_25M		: time:= 96 us;

signal bit_rate					: integer;
signal min_turnaround			: time;
signal silencetime				: time;
signal s_gx						: std_logic_vector(crc_l downto 0);
								-- polynome according to EN-61158-4-7: "10001110111001111";
signal s_fss_value				: std_logic_vector(15 downto 0);
signal s_fes_value				: std_logic_vector(7 downto 0);
signal s_id_control				: std_logic_vector(7 downto 0);
signal s_rp_control				: std_logic_vector(7 downto 0);
signal s_pdu_type				: std_logic_vector(7 downto 0);
signal s_mps					: std_logic_vector(7 downto 0);
signal s_presence				: std_logic_vector(7 downto 0);
signal s_identification			: std_logic_vector(7 downto 0);
signal s_broadcast				: std_logic_vector(7 downto 0);
signal s_consumed				: std_logic_vector(7 downto 0);
signal s_produced				: std_logic_vector(7 downto 0);
signal s_reset					: std_logic_vector(7 downto 0);
signal rate_strg				: string(1 to 19);
signal gx_strg					: string(1 to crc_l+1);
signal fss_value_strg			: string(1 to 16);
signal fes_value_strg			: string(1 to 8);
signal id_control_strg			: string(1 to 2);
signal rp_control_strg			: string(1 to 2);
signal pdu_type_strg			: string(1 to 2);
signal mps_strg					: string(1 to 2);
signal presence_strg			: string(1 to 2);
signal identification_strg		: string(1 to 2);
signal broadcast_strg			: string(1 to 2);
signal consumed_strg			: string(1 to 2);
signal produced_strg			: string(1 to 2);
signal reset_strg				: string(1 to 2);
signal read_config_trigger		: std_logic;
signal report_config_trigger	: std_logic;

begin

	-- process reading config values from a file
	---------------------------------------------
	read_config: process
	file config_file				: text open read_mode is "data/WFIP_communication_config.txt";
	variable config_line			: line;
	variable validity_time			: time;

	variable bit_rate_config		: integer;
	variable gx_config				: std_logic_vector(crc_l downto 0);
	variable fss_value_config		: std_logic_vector(15 downto 0);
	variable fes_value_config		: std_logic_vector(7 downto 0);
	variable id_control_config		: std_logic_vector(7 downto 0);
	variable rp_control_config		: std_logic_vector(7 downto 0);
	variable presence_config		: std_logic_vector(7 downto 0);
	variable identification_config	: std_logic_vector(7 downto 0);
	variable broadcast_config		: std_logic_vector(7 downto 0);
	variable consumed_config		: std_logic_vector(7 downto 0);
	variable produced_config		: std_logic_vector(7 downto 0);
	variable reset_config			: std_logic_vector(7 downto 0);
	variable mps_config				: std_logic_vector(7 downto 0);
	variable pdu_type_config		: std_logic_vector(7 downto 0);
	begin
		readline	(config_file, config_line);
		read		(config_line, bit_rate_config);
		readline	(config_file, config_line);
		read		(config_line, gx_config);
		readline	(config_file, config_line);
		read		(config_line, fss_value_config);
		readline	(config_file, config_line);
		read		(config_line, fes_value_config);
		readline	(config_file, config_line);
		hread		(config_line, id_control_config);
		readline	(config_file, config_line);
		hread		(config_line, rp_control_config);
		readline	(config_file, config_line);
		hread		(config_line, presence_config);
		readline	(config_file, config_line);
		hread		(config_line, identification_config);
		readline	(config_file, config_line);
		hread		(config_line, broadcast_config);
		readline	(config_file, config_line);
		hread		(config_line, consumed_config);
		readline	(config_file, config_line);
		hread		(config_line, produced_config);
		readline	(config_file, config_line);
		hread		(config_line, reset_config);
		readline	(config_file, config_line);
		hread		(config_line, pdu_type_config);
		readline	(config_file, config_line);
		hread		(config_line, mps_config);
		readline	(config_file, config_line);
		read		(config_line, validity_time);
		if endfile(config_file) then
			file_close(config_file);
		end if;
		
		bit_rate				<= bit_rate_config;
		gx						<= gx_config;
		s_gx					<= gx_config;
		fss_value				<= fss_value_config;
		s_fss_value				<= fss_value_config;
		fes_value				<= fes_value_config;
		s_fes_value				<= fes_value_config;
		id_control_byte			<= id_control_config;
		s_id_control			<= id_control_config;
		rp_control_byte			<= rp_control_config;
		s_rp_control			<= rp_control_config;
		var_adr_presence		<= presence_config;
		s_presence				<= presence_config;
		var_adr_identification	<= identification_config;
		s_identification		<= identification_config;
		var_adr_broadcast		<= broadcast_config;
		s_broadcast				<= broadcast_config;
		var_adr_consumed		<= consumed_config;
		s_consumed				<= consumed_config;
		var_adr_produced		<= produced_config;
		s_produced				<= produced_config;
		var_adr_reset			<= reset_config;
		s_reset					<= reset_config;
		pdu_type_byte			<= pdu_type_config;
		s_pdu_type				<= pdu_type_config;
		mps_byte				<= mps_config;
		s_mps					<= mps_config;
		read_config_trigger		<= '1';
		wait for validity_time - 1 ps;
		read_config_trigger		<= '0';
		wait for 1 ps;
	end process;

	with bit_rate select
						f_clk_period	<=	32 us	when 0,
											1 us	when 1,
											400 ns	when 2,
											1 us	when others;

	-- Translation of values for the reporting
	------------------------------------------
	with bit_rate select
		rate_strg					<=	"31.25 kbit/s       "	when 0,
										"1 Mbit/s           "	when 1,
										"2.5 Mbit/s         "	when 2,
										"Incorrectly defined"	when others;
	
	gx_strg_generation: for i in crc_l downto 0 generate
		gx_strg(crc_l+1-i) <= '1' when s_gx(i) ='1' else '0';
	end generate;
	
	specs: process(bit_rate)
	begin
		if bit_rate = 0 then
			min_turnaround		<= min_turn_around_3125k;
			silencetime			<= silence_time_3125k;
		elsif bit_rate = 1 then
			min_turnaround		<= min_turn_around_1M;
			silencetime			<= silence_time_1M;
		elsif bit_rate = 2 then
			min_turnaround		<= min_turn_around_25M;
			silencetime			<= silence_time_25M;
		else
			min_turnaround		<= min_turn_around_1M;
			silencetime			<= silence_time_1M;
		end if;
	end process;

	min_turn_around				<= min_turnaround;
	silence_time				<= silencetime;
	
	fss_value_generation1: bin_byte_transcriber
	port map(
		input			=> s_fss_value(15 downto 8),
		output			=> fss_value_strg(1 to 8)
	);
	fss_value_generation2: bin_byte_transcriber
	port map(
		input			=> s_fss_value(7 downto 0),
		output			=> fss_value_strg(9 to 16)
	);
	fes_value_generation: bin_byte_transcriber
	port map(
		input			=> s_fes_value,
		output			=> fes_value_strg
	);
	id_control_generation: hex_byte_transcriber
	port map(
		input			=> s_id_control,
		output			=> id_control_strg
	);
	rp_control_generation: hex_byte_transcriber
	port map(
		input			=> s_rp_control,
		output			=> rp_control_strg
	);
	presence_generation: hex_byte_transcriber
	port map(
		input			=> s_presence,
		output			=> presence_strg
	);
	identification_generation: hex_byte_transcriber
	port map(
		input			=> s_identification,
		output			=> identification_strg
	);
	broadcast_generation: hex_byte_transcriber
	port map(
		input			=> s_broadcast,
		output			=> broadcast_strg
	);
	consumed_generation: hex_byte_transcriber
	port map(
		input			=> s_consumed,
		output			=> consumed_strg
	);
	produced_generation: hex_byte_transcriber
	port map(
		input			=> s_produced,
		output			=> produced_strg
	);
	reset_generation: hex_byte_transcriber
	port map(
		input			=> s_reset,
		output			=> reset_strg
	);
	pdu_type_generation: hex_byte_transcriber
	port map(
		input			=> s_pdu_type,
		output			=> pdu_type_strg
	);
	mps_generation: hex_byte_transcriber
	port map(
		input			=> s_mps,
		output			=> mps_strg
	);
	
	-- reporting process
	-----------------------
	report_config_trigger		<= read_config_trigger;-- after 1 ps;

	reporting: process(report_config_trigger)
	begin
		if report_config_trigger'event and report_config_trigger ='1' then
			report LF & 
			"WFIP bus configuration settings for test" & LF &
			"-----------------------------------------" & LF &
			"WorldFIP rate                                  : " & rate_strg & LF &
			"Silence time                                   : " & time'image(silencetime) & LF &
			"Minimum turn around time                       : " & time'image(min_turnaround) & LF &
			"CRC length                                     : " & integer'image(crc_l) & " bits" & LF &
			"CRC generation polinomial                      : " & gx_strg & Lf &
			"Values for FSS and FES                         : " & fss_value_strg & " & " & fes_value_strg & " respectively" & LF &
			"Control bytes for ID_DAT frame and RP_DAT frame: " & id_control_strg & "h & " & rp_control_strg & "h respectively" & LF &
			"Address for Presence Variable                  : " & presence_strg & "h" & LF &
			"Address for Idenfication Variable              : " & identification_strg & "h" & LF &
			"Address for Broadcast Variable                 : " & broadcast_strg & "h" & LF &
			"Address for Consumed Variable                  : " & consumed_strg & "h" & LF &
			"Address for Produced Variable                  : " & produced_strg & "h" & LF &
			"Address for Reset Variable                     : " & reset_strg & "h" & LF &
			"PDU_type byte for consumed variables           : " & pdu_type_strg & "h" & LF &
			"MPS byte for fresh data on consumed variables  : " & mps_strg & "h" & LF;
		end if;
	end process;
	
end archi;
