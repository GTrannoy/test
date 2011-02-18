-- Created by : G. Penacoba
-- Creation Date: Dec 2010
-- Description: Checks the timing requirements on the bus
-- Modified by: G. Penacoba
-- Modification Date: January 2011
-- Modification consisted on: Minimum turn around times and silence times now come from config file. 
--							Block also checks resets of Fieldrive.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use std.textio.all;
use work.tb_package.all;

entity bus_monitor is
	port(
		cd						: in std_logic;
		f_clk_period			: in time;
		fd_reset				: in std_logic;
		id_rp					: in std_logic;
		min_turn_around			: in time;
		silence_time			: in time;
		txena					: in std_logic
	);
end bus_monitor;

architecture archi of bus_monitor is

signal ba_responded						: boolean;
signal end_turn_around					: time:=0 fs;
signal fd_reset_asserted				: boolean;
signal fd_reset_assertion				: time:=0 fs;
signal nanofip_responded				: boolean;
signal silence_time_reached				: boolean;
signal start_turn_around				: time:=0 fs;
signal station_adr						: std_logic_vector(7 downto 0);
signal preset_hist_opened_ok			: boolean;
signal preset_time						: time;
signal previous_preset_time				: time;
signal previous_ureset_time				: time;
signal previous_vreset_time				: time;
signal rst_latency_reached				: boolean;
signal ureset_hist_opened_ok			: boolean;
signal ureset_time						: time;
signal vreset_first_byte				: std_logic_vector(7 downto 0);
signal vreset_hist_opened_ok			: boolean;
signal vreset_time						: time;

begin
	--process starting to count the effective turn-around time
	-- just after the end of the reception of he ID_DAT
	-----------------------------------------------------------
	end_of_id_dat: process(cd)
	begin
		if cd'event and cd ='0' then
			if id_rp ='1' then
				start_turn_around	<= now;
			end if;
		end if;
	end process;
	
	--process ending the effective turn-around time from 
	-- the moment the tx_ena signal is asserted
	-----------------------------------------------------------
	begining_of_rp_dat_detection: process(txena)
	begin
		if txena'event and txena ='1' then
			end_turn_around		<= now;
		end if;
	end process;

	--process describing the possible bus reactions
	-----------------------------------------------
	bus_activity_surveillance: process
	begin
		wait for 0 fs;
		if cd ='1' and id_rp ='1' then
			ba_responded				<= FALSE;
			nanofip_responded			<= FALSE;
			silence_time_reached		<= FALSE;
		elsif cd = '1' then
			ba_responded				<= TRUE;
		elsif txena ='1' then
			nanofip_responded			<= TRUE;
		elsif now - start_turn_around > silence_time then
			silence_time_reached		<= TRUE;
		end if;	
		wait for f_clk_period;
	end process;
	
	bus_activity_reporting: process(ba_responded, nanofip_responded, silence_time_reached)
	begin
		if silence_time_reached and not(ba_responded or nanofip_responded) and start_turn_around > 0 fs then
			report	"               #### check NOT OK ####  The specified silence time of " & time'image(silence_time) 
														& " has been reached without any answer to the ID_DAT frame" & LF
			severity warning;
		elsif nanofip_responded and not(ba_responded or silence_time_reached) then
			report	"            __ check OK __  NanoFIP responds after " & time'image(end_turn_around - start_turn_around) 
																	& ". This turn-around time is within specs" & LF;
		elsif nanofip_responded and ba_responded and not(silence_time_reached) then
			report	"               #### check NOT OK ####  The bus arbitrer and nanoFIP have both responded to the same ID_DAT" & LF
			severity warning;
		end if;
	end process;
	
	-- process extracting the history information for the different resets
	-- from temporary text files
	----------------------------------------------------------------------	
	check_for_reset_history: process--(fd_reset)
	file phist_file					: text;
	variable phist_line				: line;
	variable pfile_status			: FILE_OPEN_STATUS;
	file uhist_file					: text;
	variable uhist_line				: line;
	variable ufile_status			: FILE_OPEN_STATUS;
	file vhist_file					: text;
	variable vhist_line				: line;
	variable vfile_status			: FILE_OPEN_STATUS;
	file config_file				: text;
	variable config_line			: line;
	variable prst_time				: time;
	variable urst_time				: time;
	variable vrst_time				: time;
	variable first_byte				: std_logic_vector(7 downto 0);
	variable station_adr_tmp		: std_logic_vector(7 downto 0);
	begin
		--if fd_reset ='1' then
		wait for 0 fs;
		wait for 0 fs;
		wait for 0 fs;
			file_open(pfile_status, phist_file,"data/tmp_preset_hist.txt",read_mode);
			if pfile_status = open_ok then
				readline					(phist_file, phist_line);
				read						(phist_line, prst_time);
				file_close(phist_file);
				preset_hist_opened_ok		<= TRUE;
				preset_time					<= prst_time;
			else
				preset_hist_opened_ok		<= FALSE;
			end if;

			file_open(ufile_status, uhist_file,"data/tmp_ureset_hist.txt",read_mode);
			if ufile_status = open_ok then
				readline					(uhist_file, uhist_line);
				read						(uhist_line, urst_time);
				file_close(uhist_file);
				ureset_hist_opened_ok		<= TRUE;
				ureset_time					<= urst_time;
			else
				ureset_hist_opened_ok		<= FALSE;
			end if;

			file_open(vfile_status, vhist_file,"data/tmp_vreset_hist.txt",read_mode);
			if vfile_status = open_ok then
				readline					(vhist_file, vhist_line);
				read						(vhist_line, vrst_time);
				readline					(vhist_file, vhist_line);
				hread						(vhist_line, first_byte);
				file_close(vhist_file);

				vreset_hist_opened_ok		<= TRUE;
				vreset_time					<= vrst_time;
				vreset_first_byte			<= first_byte;
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
--		end if;
		wait for f_clk_period;
	end process;
	
	process (fd_reset)
	begin
		if fd_reset'event and fd_reset ='1' then
--			wait for 0 ps;
			fd_reset_assertion			<= now;
		end if;
	end process;
	
	resets_surveillance: process
	begin
		wait for 0 ps;
		wait for 0 ps;
		wait for 0 ps;
		previous_preset_time	<= preset_time;
		previous_ureset_time	<= ureset_time;
		previous_vreset_time	<= vreset_time;
		
		if previous_preset_time /= preset_time
		or previous_ureset_time /= ureset_time
		or previous_vreset_time /= vreset_time then
			fd_reset_asserted		<= FALSE;
			rst_latency_reached		<= FALSE;
		
		elsif fd_reset = '1' then
			fd_reset_asserted		<= TRUE;
			
		elsif (preset_hist_opened_ok and ((now - preset_time) > reset_max_latency))
		and (ureset_hist_opened_ok and ((now - ureset_time) > reset_max_latency))
		and (vreset_hist_opened_ok and ((now - vreset_time) > reset_max_latency) and (vreset_first_byte = station_adr)) then

			rst_latency_reached		<= TRUE;
		end if;

		wait for f_clk_period;
	end process;

	reset_reporting: process(fd_reset_asserted, rst_latency_reached, fd_reset_assertion)
	begin
		if rst_latency_reached and not fd_reset_asserted then
			report "               #### Check NOT OK #### " & time'image(reset_max_latency) & " have passed and" 
			& LF & "                                      nanoFIP has still not asserted the Fieldrive reset (FD_RSTN)" & LF
			severity warning;
		elsif fd_reset_asserted then
			if not (preset_hist_opened_ok 
			or ureset_hist_opened_ok 
			or (vreset_hist_opened_ok and (vreset_first_byte = station_adr))) then
				report "               #### Check NOT OK #### NanoFIP has asserted the Fieldrive reset (FD_RSTN)"
				& LF & "                                      although no action or event prompted it" & LF
				severity warning;
			else
				if preset_time < fd_reset_assertion and fd_reset_assertion < preset_time + reset_max_latency then
					report "            __ Check OK __ After " & time'image(fd_reset_assertion - preset_time) & " NanoFIP asserts" 
					& LF & "                           the Fieldrive reset (FD_RSTN) in response to the power-on reset signal" & LF;

				elsif ureset_time < fd_reset_assertion and fd_reset_assertion < ureset_time + reset_max_latency then
					report "            __ Check OK __ After " & time'image(fd_reset_assertion - ureset_time) & " NanoFIP asserts" 
					& LF & "                           the Fieldrive reset (FD_RSTN) in response to the reset signal generated by the user logic" & LF;

				elsif vreset_time < fd_reset_assertion and fd_reset_assertion < vreset_time + reset_max_latency then
					if vreset_first_byte = station_adr then
						report "            __ Check OK __ After " & time'image(fd_reset_assertion - vreset_time) & " NanoFIP asserts" 
						& LF & "                           the Fieldrive reset (FD_RSTN) in response to the presence of nanoFIP station address"
						& LF & "                           in the first byte of the reset variable sent by the Bus Arbitrer" & LF;
					else
						report "               #### Check NOT OK #### NanoFIP has asserted the Fieldrive reset (FD_RSTN) in response to the Reset variable "
						& LF & "                                      although the station address was not present in the first byte" & LF
						severity warning;
					end if;

				elsif (fd_reset_assertion > (preset_time + reset_max_latency)) 
				and (fd_reset_assertion > (ureset_time + reset_max_latency))
				and (fd_reset_assertion > (vreset_time + reset_max_latency)) and (vreset_first_byte = station_adr) then
					report "               #### Check NOT OK #### NanoFIP has asserted now the Fieldrive reset (FD_RSTN). This is too late"
					& LF & "                                      with respect to the generating event to consider it a proper reaction" & LF
					severity warning;
				end if;
			end if;
		end if;
	end process;

	reset_reporting2: process(fd_reset)
	variable fd_rst_deassertion			: time;
	begin
		if fd_reset'event and fd_reset ='1' and fd_reset_asserted then
				report "               #### Check NOT OK #### NanoFIP has asserted the Fieldrive reset (FD_RSTN) again"
				& LF & "                                      although no action or event prompted it" & LF
				severity warning;
		end if;
			
		if fd_reset'event and fd_reset ='0' and now /= 0 fs then
			fd_rst_deassertion	:= now;
			report "            NanoFIP has kept the Fieldrive reset asserted for " & time'image(fd_rst_deassertion - fd_reset_assertion) & LF;
		end if;
	end process;
	
end archi;
