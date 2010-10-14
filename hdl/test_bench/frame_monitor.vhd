-- Created by : G. Penacoba
-- Creation Date: Oct 2010
-- Description: Checks the correctnes of the structure and data
--				of the FIP frames sent by nanoFIP.
-- Modified by:
-- Modification Date:
-- Modification consisted on:

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use std.textio.all;
use work.tb_package.all;

entity frame_monitor is
	port(
		bytes_total			: in byte_count_type;
		clk					: in std_logic;
		control_byte		: in std_logic_vector(7 downto 0);
		frame_data			: in vector_type;
		frame_received		: in std_logic
	);
end frame_monitor;

architecture archi of frame_monitor is

constant control_id			: std_logic_vector(7 downto 0):=x"03";
constant control_rp			: std_logic_vector(7 downto 0):=x"02";
constant mps_fresh			: std_logic_vector(7 downto 0):=x"05";
constant mps_not_fresh		: std_logic_vector(7 downto 0):=x"00";
constant pdu_presence		: std_logic_vector(7 downto 0):=x"50";
constant pdu_identification	: std_logic_vector(7 downto 0):=x"52";
constant pdu_produced		: std_logic_vector(7 downto 0):=x"40";

signal compare_data			: std_logic;
signal contents_ok			: boolean:= FALSE;
signal control_ok			: boolean:= FALSE;
signal constructor			: std_logic_vector(7 downto 0);
signal data_contents_ok		: boolean:= FALSE;
signal frame_ok				: boolean:= FALSE;
signal last_data			: byte_count_type;
signal model				: std_logic_vector(7 downto 0);
signal mps_byte				: std_logic_vector(7 downto 0);
signal nfip_status			: std_logic_vector(7 downto 0);
signal nostat				: std_logic;
signal length_byte			: std_logic_vector(7 downto 0);
signal length_coherent		: boolean:= FALSE;
signal length_specs_ok		: boolean:= FALSE;
signal out_produced			: vector_type;
signal pdu_type_byte		: std_logic_vector(7 downto 0);
signal report_trigger		: std_logic;
signal ucacerr				: boolean;
signal upacerr				: boolean;
signal var_string			: string(1 to 27);
signal varlength_specs		: byte_count_type;
signal var3_fresh			: boolean;

begin

	-- process checking the correctness of the frame structure
	----------------------------------------------------------
	frame_check: process(bytes_total, control_byte, frame_data, 
						frame_received, data_contents_ok, varlength_specs)
	begin
		if frame_received ='1' then
			if control_byte = control_rp then
				control_ok			<= TRUE;
			else
				control_ok			<= FALSE;
			end if;

			if to_integer(unsigned(length_byte)) = (bytes_total - 4) then
				length_coherent			<= TRUE;
			else
				length_coherent			<= FALSE;
			end if;
		
			case pdu_type_byte is
			when pdu_presence =>
				if (frame_data(2) = x"80" 
				and frame_data(3) = x"03"
				and frame_data(4) = x"00"
				and frame_data(5) = x"F0"
				and frame_data(6) = x"00") then
					contents_ok		<= TRUE;
				else
					contents_ok		<= FALSE;
				end if;
				if bytes_total = 9 then
					length_specs_ok	<= TRUE;
				else
					length_specs_ok	<= FALSE;
				end if;
			
			when pdu_identification =>
				if (frame_data(2) = x"01" 
				and frame_data(3) = x"00"
				and frame_data(4) = x"00"
				and frame_data(5) = constructor
				and frame_data(6) = model  
				and frame_data(7) = x"00"
				and frame_data(8) = x"00"
				and frame_data(9) = x"00") then
					contents_ok		<= TRUE;
				else
					contents_ok		<= FALSE;
				end if;
				if bytes_total = 12 then
					length_specs_ok	<= TRUE;
				else
					length_specs_ok	<= FALSE;
				end if;
			
			when pdu_produced =>
				if (mps_byte = mps_fresh or mps_byte = mps_not_fresh)
				and data_contents_ok then
					contents_ok		<= TRUE;
				else
					contents_ok		<= FALSE;
				end if;
				if bytes_total = varlength_specs then
					length_specs_ok	<= TRUE;
				else
					length_specs_ok	<= FALSE;
				end if;
			
			when others =>
				contents_ok		<= FALSE;
				length_specs_ok	<= FALSE;
			end case;
		end if;
	end process;
	
	-- process reading current board config values from a temp file
	---------------------------------------------------------------
	board_temp_config: process(frame_received)
	file config_file			: text;
	variable config_line		: line;

	variable constructor_config	: std_logic_vector(7 downto 0);
	variable model_config		: std_logic_vector(7 downto 0);
	variable nostat_config		: std_logic;
	variable varlength_config	: byte_count_type;
	
	begin
		if frame_received = '1' then
			file_open(config_file,"data/tmp_board_config.txt",read_mode);
		
			readline	(config_file, config_line);
			read		(config_line, varlength_config);

			readline	(config_file, config_line);
			read		(config_line, nostat_config);

			readline	(config_file, config_line);
			hread		(config_line, constructor_config);

			readline	(config_file, config_line);
			hread		(config_line, model_config);

			file_close(config_file);
		
			if nostat_config = '0' then
				varlength_specs			<= varlength_config + 6;
			else
				varlength_specs			<= varlength_config + 5;
			end if;
			nostat					<= nostat_config;
			constructor				<= constructor_config;
			model					<= model_config;
		end if;
	end process;
	
	-- process reading the current error status and variable freshness from a temp file
	------------------------------------------------------------------------------------
	read_temp_err_and_fresh: process(frame_received)
	file data_file			: text;
	variable data_line		: line;
	
	variable ucacerr_temp	: boolean;
	variable upacerr_temp	: boolean;
	variable var3fresh_temp	: boolean;
	begin
		if frame_received ='1' then
			file_open(data_file,"data/tmp_err_and_fresh.txt",read_mode);
			readline		(data_file, data_line);
			read			(data_line, ucacerr_temp);
			readline		(data_file, data_line);
			read			(data_line, upacerr_temp);
			readline		(data_file, data_line);
			read			(data_line, var3fresh_temp);
			file_close(data_file);

			ucacerr			<= ucacerr_temp;
			upacerr			<= upacerr_temp;
			var3_fresh		<= var3fresh_temp;
		end if;
	end process;

	-- process retrieving the transcription of the data present in the nanoFIP memory for production
	------------------------------------------------------------------------------------------------
	read_outgoing_produced: process(frame_received)
	file data_file			: text;
	variable data_line		: line;

	variable data_byte		: std_logic_vector(7 downto 0);
	variable data_vector	: vector_type;
	
	begin
		if frame_received ='1' and pdu_type_byte = pdu_produced then
			file_open(data_file,"data/tmp_var3_mem.txt",read_mode);
			for i in 0 to max_frame_length-1 loop
				readline			(data_file, data_line);
				hread				(data_line, data_byte);
				data_vector(i)		:= data_byte;
			end loop;
			file_close(data_file);
			out_produced		<= data_vector;
			compare_data		<= '1';
		else
			compare_data		<= '0';
		end if;
	end process;

	-- process checking the validity of the produced data
	------------------------------------------------------
	checking_produced: process(compare_data)
	variable mismatches			: byte_count_type;
	begin
		if compare_data ='1' then
			for i in 2 to last_data loop
				if out_produced(i) /= frame_data(i) then
					mismatches		:= mismatches + 1;
				end if;
			end loop;
			if mismatches = 0 then
				data_contents_ok		<= TRUE;
			else
				data_contents_ok		<= FALSE;
			end if;
		else
			mismatches				:= 0;
		end if;
	end process;
	
	trigger_report: process
	begin
		report_trigger	<= frame_received;
		wait until clk = '1';
	end process;

	reporting: process(report_trigger)
	begin
		if report_trigger ='1' then
			if frame_ok then
				report "            NanoFIP response is an RP_DAT frame of " & var_string
				& LF & "            the length is according to specs and coherent wiht the Length byte"
				& LF & "            and the frame contents match the variable expected values";
				if pdu_type_byte = pdu_produced then
					if mps_byte = mps_fresh and not(var3_fresh) then
						report "               Note however that the data are flagged incorrectly as fresh"
						severity warning;
					elsif mps_byte = mps_not_fresh and var3_fresh then
						report "               Note however that the data are flagged incorrectly as not fresh"
						severity warning;
					elsif mps_byte = mps_not_fresh and not(var3_fresh) then
						report "               Note however that the data are flagged correctly as not fresh"
						severity warning;
					end if;
					if nostat ='0' then
						assert nfip_status(2) ='0'
						report "               The nanoFIP status byte indicates a user consumed variable access error"
						severity warning;
						assert nfip_status(3) ='0'
						report "               The nanoFIP status byte indicates a user produced variable access error"
						severity warning;
						assert nfip_status(4) ='0'
						report "               The nanoFIP status byte indicates a PDU_type or Length byte error on reception"
						severity warning;
						assert nfip_status(5) ='0'
						report "               The nanoFIP status byte indicates a CRC error on reception"
						severity warning;
						assert nfip_status(6) ='0'
						report "               The nanoFIP status byte reports a Fieldrive transmit error"
						severity warning;
						assert nfip_status(7) ='0'
						report "               The nanoFIP status byte reports a Fieldrive watchdog error"
						severity warning;
					end if;
				end if;
			elsif not(control_ok) then
				if control_byte = control_id then
					report "               NanoFIP has issued an ID_DAT frame"
					severity warning;
				else
					report "               NanoFIP has issued a frame with an illegal Control byte"
					severity warning;
				end if;
			elsif not(pdu_type_byte = pdu_presence 
					or pdu_type_byte = pdu_identification 
					or pdu_type_byte = pdu_produced) then
				report "               NanoFIP response is an RP_DAT frame"
				& LF & "               but the PDU type byte corresponds to " & var_string
				severity warning;
			elsif not(length_specs_ok) then
				report "               NanoFIP response is an RP_DAT frame of " & var_string
				& LF & "               but the length is not in accordance with the specs"
				severity warning;
			elsif not(length_coherent) then
				report "               NanoFIP response is an RP_DAT frame of " & var_string
				& LF & "               but the Length byte is not coherent with the actual length"
				severity warning;
			elsif not(contents_ok) then
				report "               NanoFIP response is an RP_DAT frame of " & var_string
				& LF & "               but the frame contents don't match the variable expected values"
				severity warning;
				if pdu_type_byte = pdu_produced then
					for i in 2 to last_data loop
						assert out_produced(i) = frame_data(i)
						report "               Data value expected in memory at address " & integer'image(i) 
						& LF & "               does not match the one sent by nanoFIP " 
						& LF & "               in the corresponding position of the produced variable"
						severity warning;
					end loop;
					assert mps_byte=mps_fresh or mps_byte=mps_not_fresh
					report "               The mps_byte has an invalid value"
					severity warning;
					if nostat ='0' then
						assert nfip_status(2) ='0'
						report "               The nanoFIP status byte indicates a user consumed variable access error"
						severity warning;
						assert nfip_status(3) ='0'
						report "               The nanoFIP status byte indicates a user produced variable access error"
						severity warning;
						assert nfip_status(4) ='0'
						report "               The nanoFIP status byte indicates a PDU_type or Length byte error on reception"
						severity warning;
						assert nfip_status(5) ='0'
						report "               The nanoFIP status byte indicates a CRC error on reception"
						severity warning;
						assert nfip_status(6) ='0'
						report "               The nanoFIP status byte reports a Fieldrive transmit error"
						severity warning;
						assert nfip_status(7) ='0'
						report "               The nanoFIP status byte reports a Fieldrive watchdog error"
						severity warning;
					end if;
				end if;
			end if;
		end if;
	end process;

	with pdu_type_byte select
		var_string		<= 	"a Presence Variable,       "	when pdu_presence,
							"an Identification Variable,"	when pdu_identification,
							"a Produced Variable,       "	when pdu_produced,
							"no known variable.         "	when others;

	frame_ok			<= control_ok and length_specs_ok and length_coherent and contents_ok;

	pdu_type_byte		<= frame_data(0);
	length_byte			<= frame_data(1);
	mps_byte			<= frame_data(bytes_total-3) when frame_received ='1';
	last_data			<= bytes_total - 4 when nostat ='1' and frame_received = '1'
						else bytes_total - 5 when nostat = '0' and frame_received = '1';
	nfip_status			<= frame_data(bytes_total-4) when nostat ='0' and frame_received ='1';

end archi;
