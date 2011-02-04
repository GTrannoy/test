-- Created by : G. Penacoba
-- Creation Date: November 2010
-- Description: Tracks the user access errors of the user interface for
--				checking when nanoFIP reports.
-- Modified by:
-- Modification Date:
-- Modification consisted on:

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use std.textio.all;
use work.tb_package.all;

entity user_access_monitor is
	port(
		cyc					: in std_logic;
		urstn_from_nf		: in std_logic;
		slone_access_read	: in std_logic;
		slone_access_write	: in std_logic;
		var1_rdy_i			: in std_logic;
		var2_rdy_i			: in std_logic;
		var3_rdy_i			: in std_logic;
		var_id			 	: in std_logic_vector(1 downto 0);

		var1_acc_o			: out std_logic;
		var2_acc_o			: out std_logic;
		var3_acc_o			: out std_logic
	);
end user_access_monitor;

architecture archi of user_access_monitor is
constant reset_max_latency				: time := 100 us;
signal station_adr						: std_logic_vector(7 downto 0);
signal ucacerr							: boolean;
signal upacerr							: boolean;
signal urst_from_nf_assertion			: time:=0 fs;
signal var1_acc							: std_logic;
signal var2_acc							: std_logic;
signal var3_acc							: std_logic;
signal var3_fresh						: boolean;
signal vreset_second_byte				: std_logic_vector(7 downto 0);
signal vreset_hist_opened_ok			: boolean;
signal vreset_time						: time;

begin

	var1_acc_o			<= var1_acc;
	var2_acc_o			<= var2_acc;
	var3_acc_o			<= var3_acc;
	
	-- process generating the different variable access signals
	-----------------------------------------------------------
	user_access: process(var_id, cyc, slone_access_read, slone_access_write)
	begin
	case var_id is
	when "01" =>
		var1_acc			<= cyc or slone_access_read;
		var2_acc			<= '0';
		var3_acc			<= slone_access_write;

	when "10" =>
		var1_acc			<= '0';
		var2_acc			<= cyc or slone_access_read;
		var3_acc			<= slone_access_write;

	when "11" =>
		var1_acc			<= slone_access_read;
		var2_acc			<= slone_access_read;
		var3_acc			<= cyc or slone_access_write;

	when others =>
		var1_acc			<= slone_access_read;
		var2_acc			<= slone_access_read;
		var3_acc			<= slone_access_write;
	end case;
	end process;
	
	-- 2 proccesses generating the current status of the user access errors	
	-----------------------------------------------------------------------
	user_c_access_error: process(var1_rdy_i, var2_rdy_i, var3_rdy_i,
								 var1_acc, var2_acc)
	begin
		if (var1_acc ='1' and var1_rdy_i ='0')
		or (var2_acc ='1' and var2_rdy_i ='0') then
			ucacerr					<= TRUE;
		elsif var3_rdy_i'event and var3_rdy_i ='1' then
			ucacerr					<= FALSE after 1 ps;
		end if;
	end process;

	user_p_access_error: process(var3_rdy_i, var3_acc)
	begin
		if (var3_acc ='1' and var3_rdy_i ='0') then
			upacerr					<= TRUE;
		elsif var3_rdy_i'event and var3_rdy_i ='1' then
			upacerr					<= FALSE after 1 ps;
		end if;
	end process;

	-- process tracking the current freshness of the data in the memory for the produced variable
	---------------------------------------------------------------------------------------------
	var3_freshness:process(var3_rdy_i, var3_acc)
	begin
		if var3_acc ='1' then
			var3_fresh				<= TRUE;
		elsif var3_rdy_i'event and var3_rdy_i ='1' then
			var3_fresh				<= FALSE after 1 ps;
		end if;
	end process;
		
	-- process transcribing the current status of the user access errors 
	-- and the produced variable freshness to a text file
	-------------------------------------------------------------------
	write_produced_status:process(var3_rdy_i)
	file data_file			: text;
	variable data_line		: line;
	
	begin
		if var3_rdy_i'event and var3_rdy_i ='1' then
			file_open(data_file,"data/tmp_err_and_fresh.txt",write_mode);
			write		(data_line, ucacerr);
			writeline	(data_file, data_line);
			write		(data_line, upacerr);
			writeline	(data_file, data_line);
			write		(data_line, var3_fresh);
			writeline	(data_file, data_line);
			file_close(data_file);
		end if;
	end process;

	-- process for the user_acc register to be expected on the Produced Frames
	------------------------------------------------------------------------------------
	reporting: process(ucacerr, upacerr)
	begin
		assert not(ucacerr or upacerr)
		report "               The user logic access violates the VAR_RDY condition "
				& "and should generate a nanoFIP status error" & LF
		severity warning;
	end process;

	-- process extracting the history information for the reset
	-- from temporary text files
	-----------------------------------------------------------
	check_for_reset_history: process(urstn_from_nf)
	file vhist_file					: text;
	variable vhist_line				: line;
	variable vfile_status			: FILE_OPEN_STATUS;
	file config_file				: text;
	variable config_line			: line;
	variable vrst_time				: time;
	variable second_byte			: std_logic_vector(7 downto 0);
	variable station_adr_tmp		: std_logic_vector(7 downto 0);
	begin
		if urstn_from_nf ='0' then
			file_open(vfile_status, vhist_file,"data/tmp_vreset_hist.txt",read_mode);
			if vfile_status = open_ok then
				readline					(vhist_file, vhist_line);
				read						(vhist_line, vrst_time);
				readline					(vhist_file, vhist_line);
				readline					(vhist_file, vhist_line);
				hread						(vhist_line, second_byte);
				file_close(vhist_file);

				vreset_hist_opened_ok		<= TRUE;
				vreset_time					<= vrst_time;
				vreset_second_byte			<= second_byte;
			else
				vreset_hist_opened_ok		<= FALSE;
			end if;

			file_open(config_file,"data/tmp_board_config.txt",read_mode);
			readline				(config_file, config_line);
			readline				(config_file, config_line);
			readline				(config_file, config_line);
			readline				(config_file, config_line);
			readline				(config_file, config_line);
			readline				(config_file, config_line);
			hread					(config_line, station_adr_tmp);
			file_close(config_file);
			
			station_adr				<= station_adr_tmp;
		end if;
	end process;
	
	reset_reporting: process
	variable urstfromnf_assertion		: time;
	variable rst_allowed_source_time	: time;
	begin
		if urstn_from_nf'event and urstn_from_nf ='0' then
			wait for 0 ps;
			urstfromnf_assertion			:= now;
			rst_allowed_source_time			:= urstfromnf_assertion - reset_max_latency;
			urst_from_nf_assertion			<= urstfromnf_assertion;

			if vreset_hist_opened_ok 
			and rst_allowed_source_time <= vreset_time and vreset_time <= urstfromnf_assertion 
			and vreset_second_byte = station_adr then
				report "            __ Check OK __ After " & time'image(urstfromnf_assertion - vreset_time)
				& LF & "                           NanoFIP asserts the User Reset (RSTON)"
				& LF & "                           in response to the presence of nanoFIP station address"
				& LF & "                           in the second byte of the reset variable sent by the Bus Arbitrer" & LF;

			else
				report "               #### Check NOT OK #### NanoFIP has asserted the User Reset (RSTON)"
				& LF & "                                      although no action or event prompted it" & LF
				severity warning;
			end if;
		end if;
		wait on urstn_from_nf;
	end process;

	reset_reporting2: process(urstn_from_nf)
	variable urstfromnf_deassertion			: time;
	begin
		if urstn_from_nf'event and urstn_from_nf ='1' and now /= 0 fs then
			urstfromnf_deassertion	:= now;
			report "            NanoFIP has kept the User Reset asserted for " 
			& time'image(urstfromnf_deassertion - urst_from_nf_assertion) & LF;
		end if;
	end process;
			

end archi;
