-- Created by : G. Penacoba
-- Creation Date: September 2010
-- Description: Module for the readout of the configuration settings from a 
--				text file.
-- Modified by: G. Penacoba
-- Modification Date: October 2010
-- Modification consisted on: Added ID_DAT, RP_DAT control bytes and PDU_type and MPS bytes configurable from the text file

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use std.textio.all;
use work.tb_package.all;

entity bus_config is
	generic(
		crc_l				: integer:=16
	);
	port(
		f_clk_period		: out time;
		gx					: out std_logic_vector(crc_l downto 0);
		id_control_byte		: out std_logic_vector(7 downto 0);
		mps_byte			: out std_logic_vector(7 downto 0);
		pdu_type_byte		: out std_logic_vector(7 downto 0);
		rp_control_byte		: out std_logic_vector(7 downto 0)
	);
end;

architecture archi of bus_config is

signal s_gx					: std_logic_vector(crc_l downto 0);
							-- polynome according to EN-61158-4-7: "10001110111001111";
signal s_id_control			: std_logic_vector(7 downto 0);
signal s_pdu_type			: std_logic_vector(7 downto 0);
signal s_rp_control			: std_logic_vector(7 downto 0);
signal s_mps				: std_logic_vector(7 downto 0);
signal id_control_strg		: string(1 to 2);
signal pdu_type_strg		: string(1 to 2);
signal rp_control_strg		: string(1 to 2);
signal mps_strg				: string(1 to 2);
signal bit_rate				: integer;
signal gx_strg				: string(1 to crc_l+1);
signal rate_strg			: string(1 to 19);
signal read_config_trigger	: std_logic;
signal report_config_trigger: std_logic;

begin

	-- process reading config values from a file
	---------------------------------------------
	read_config: process
	file config_file			: text open read_mode is "data/WFIP_communication_config.txt";
	variable config_line		: line;
	variable validity_time		: time;

	variable bit_rate_config	: integer;
	variable gx_config			: std_logic_vector(crc_l downto 0);
	variable id_control_config	: std_logic_vector(7 downto 0);
	variable mps_config			: std_logic_vector(7 downto 0);
	variable pdu_type_config	: std_logic_vector(7 downto 0);
	variable rp_control_config	: std_logic_vector(7 downto 0);
	begin
		readline	(config_file, config_line);
		read		(config_line, bit_rate_config);
		readline	(config_file, config_line);
		read		(config_line, gx_config);
		readline	(config_file, config_line);
		hread		(config_line, id_control_config);
		readline	(config_file, config_line);
		hread		(config_line, mps_config);
		readline	(config_file, config_line);
		hread		(config_line, pdu_type_config);
		readline	(config_file, config_line);
		hread		(config_line, rp_control_config);

		readline	(config_file, config_line);
		read		(config_line, validity_time);
		if endfile(config_file) then
			file_close(config_file);
		end if;
		
		bit_rate				<= bit_rate_config;
		gx						<= gx_config;
		s_gx					<= gx_config;
		id_control_byte			<= id_control_config;
		s_id_control			<= id_control_config;
		mps_byte				<= mps_config;
		s_mps					<= mps_config;
		pdu_type_byte			<= pdu_type_config;
		s_pdu_type				<= pdu_type_config;
		rp_control_byte			<= rp_control_config;
		s_rp_control			<= rp_control_config;
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
	
	id_control_generation: hex_byte_transcriber
	port map(
		input			=> s_id_control,
		output			=> id_control_strg
	);
	mps_generation: hex_byte_transcriber
	port map(
		input			=> s_mps,
		output			=> mps_strg
	);
	pdu_type_generation: hex_byte_transcriber
	port map(
		input			=> s_pdu_type,
		output			=> pdu_type_strg
	);
	rp_control_generation: hex_byte_transcriber
	port map(
		input			=> s_rp_control,
		output			=> rp_control_strg
	);
	
	-- reporting process
	-----------------------
	report_config_trigger		<= read_config_trigger;-- after 1 ps;

	reporting: process(report_config_trigger)
	begin
		if report_config_trigger'event and report_config_trigger ='1' then
			report LF & "WFIP bus configuration settings for test" & LF &
						"-----------------------------------------" & LF &
			"WorldFIP rate: " & rate_strg & LF &
			"CRC length: " & integer'image(crc_l) & " bits" & LF &
			"CRC generation polinomial: " & gx_strg & Lf &
			"Control bytes for ID_DAT frame and RP_DAT frame: " & id_control_strg & "h & " & rp_control_strg & "h respectively" & LF &
			"PDU_type byte for consumed variables: " & pdu_type_strg & "h" & LF &
			"MPS byte for fresh data on consumed variables: " & mps_strg & "h" & LF;
		end if;
	end process;
	
end archi;
