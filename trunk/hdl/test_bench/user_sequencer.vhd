-- Created by : G. Penacoba
-- Creation Date: March 2010
-- Description: Orders the sequence of actions of the user 
-- Modified by: G. Penacoba
-- Modification Date: 23/08/2010
-- Modification consisted on: Name change 
--							+ addition of the other user interface signals
-- Modification Date: October 2010
-- Modification consisted on: Addition of access to schedule from a text file + reporting
--							+ addition of user access error and freshness status signals
-- Modification Date: 1 November 2010
-- Modification consisted on: Management of user_access signals and errors and freshness status 
--							 moved to a different file.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use std.textio.all;
use work.tb_package.all;

entity user_sequencer is
	port(
		uclk_period			: in time;
		wclk_period			: in time;

		block_size			: out std_logic_vector(6 downto 0);
		launch_slone_read	: out std_logic;
		launch_slone_write 	: out std_logic;
		launch_wb_read		: out std_logic;
		launch_wb_write 	: out std_logic;
		transfer_length		: out std_logic_vector(6 downto 0);
		transfer_offset		: out std_logic_vector(6 downto 0);
		var_id			 	: out std_logic_vector(1 downto 0)
	);
end user_sequencer;
	
architecture archi of user_sequencer is

signal blck_sze				: integer:=0;
signal launch_slone_rd		: std_logic:='0';
signal launch_slone_wr		: std_logic:='0';
signal launch_wb_rd			: std_logic:='0';
signal launch_wb_wr			: std_logic:='0';
signal transfer_lgth		: integer:=0;
signal transfer_offst		: integer:=0;
signal var					: integer:=0;

begin
	
	-- process retrieving the sequence of actions performed by the user logic from a text file
	------------------------------------------------------------------------------------------
	sequence: process
	file sequence_file			: text open read_mode is "data/user_sequence.txt";
	variable sequence_line		: line;
	file config_file			: text;
	variable config_line		: line;
	variable stand_by_time		: time;
	variable coma				: string(1 to 1);
	
	variable block_size_tmp		: integer;
	variable rd_wr				: std_logic;
	variable slone_cfig_tmp		: std_logic_vector(0 downto 0);
	variable trfer_lgth_tmp		: integer;
	variable trfer_ofst_tmp		: integer;
	variable var_id_tmp			: integer;
	
	begin
		wait for 0 us;
		readline	(sequence_file, sequence_line);
		readline	(sequence_file, sequence_line);
		readline	(sequence_file, sequence_line);
		wait for wclk_period;

		loop
			launch_slone_rd		<= '0';
			launch_slone_wr		<= '0';
			launch_wb_rd		<= '0';
			launch_wb_wr		<= '0';
			
			file_open(config_file,"data/tmp_board_config.txt",read_mode);
			readline		(config_file, config_line);
			read			(config_line, slone_cfig_tmp);
			file_close(config_file);
--			report " FIRST slone config " & integer'image(to_integer(unsigned(slone_cfig_tmp)));

			readline	(sequence_file, sequence_line);
			read		(sequence_line, stand_by_time);
			if not(endfile(sequence_file)) then
				readline	(sequence_file, sequence_line);
				read		(sequence_line, rd_wr);
				read		(sequence_line, coma);
				read		(sequence_line, var_id_tmp);
				read		(sequence_line, coma);
				read		(sequence_line, trfer_lgth_tmp);
				read		(sequence_line, coma);
				read		(sequence_line, trfer_ofst_tmp);
				read		(sequence_line, coma);
				read		(sequence_line, block_size_tmp);
			else
				file_close(sequence_file);
			end if;
			if slone_cfig_tmp ="1" then
				wait for stand_by_time - uclk_period;
			else
				wait for stand_by_time - wclk_period;
			end if;
	
			var_id					<= std_logic_vector(to_unsigned(var_id_tmp,2));
			var						<= var_id_tmp;
			transfer_length			<= std_logic_vector(to_unsigned(trfer_lgth_tmp,7));
			transfer_lgth			<= trfer_lgth_tmp;
			transfer_offset			<= std_logic_vector(to_unsigned(trfer_ofst_tmp,7));
			transfer_offst			<= trfer_ofst_tmp;
			block_size				<= std_logic_vector(to_unsigned(block_size_tmp,7));
			blck_sze				<= block_size_tmp;
			
			file_open(config_file,"data/tmp_board_config.txt",read_mode);
			readline		(config_file, config_line);
			read			(config_line, slone_cfig_tmp);
			file_close(config_file);
--			report " SECOND slone config " & integer'image(to_integer(unsigned(slone_cfig_tmp)));

			if slone_cfig_tmp ="1" then
				if rd_wr ='1' then
					launch_slone_rd		<= '0';
					launch_slone_wr		<= '1';
					launch_wb_rd		<= '0';
					launch_wb_wr		<= '0';
				else
					launch_slone_rd		<= '1';
					launch_slone_wr		<= '0';
					launch_wb_rd		<= '0';
					launch_wb_wr		<= '0';
				end if;
			else
				if rd_wr ='1' then
					launch_slone_rd		<= '0';
					launch_slone_wr		<= '0';
					launch_wb_rd		<= '0';
					launch_wb_wr		<= '1';
				else
					launch_slone_rd		<= '0';
					launch_slone_wr		<= '0';
					launch_wb_rd		<= '1';
					launch_wb_wr		<= '0';
				end if;
			end if;
			if slone_cfig_tmp ="1" then
				wait for uclk_period;
			else
				wait for wclk_period;
			end if;
		end loop;
	end process;

	launch_slone_read		<= launch_slone_rd;
	launch_slone_write		<= launch_slone_wr;
	launch_wb_read			<= launch_wb_rd;
	launch_wb_write			<= launch_wb_wr;

	
	reporting: process(launch_slone_rd, launch_slone_wr, launch_wb_rd, launch_wb_wr)
	begin
		if launch_slone_rd ='1' then
			report LF & "            User logic reads 2 bytes from the 16-bit stand-alone bus"& LF;
		
		elsif launch_slone_wr ='1' then
			report LF & "            User logic writes 2 bytes on the 16-bit stand-alone bus"& LF;
		
		elsif launch_wb_rd ='1' then
			if transfer_offst = 0 then
				report LF & "            User logic reads " & integer'image(transfer_lgth) & 
				" bytes of user data plus the length byte and the PDU type byte" & 
				" between address " & integer'image(transfer_offst+transfer_lgth+1) & " and address 0" &
				" from variable " & integer'image(var) & " in nanoFIP memory" & LF;
			else
				report LF & "            User logic reads " & integer'image(transfer_lgth) & 
				" bytes of user data" &
				" between address " & integer'image(transfer_offst+transfer_lgth+1) & 
				" and address " & integer'image(transfer_offst+2) & 
				" from variable " & integer'image(var) & " in nanoFIP memory" & LF;
			end if;
		
		elsif launch_wb_wr ='1' then
			report LF & "            User logic writes " & integer'image(transfer_lgth) & 
			" bytes on variable " & integer'image(var) &
			" in nanoFIP memory between address " & integer'image(transfer_offst+transfer_lgth+1) & 
			" and address " & integer'image(transfer_offst+2) & LF;
		end if;
	end process;

end archi;
