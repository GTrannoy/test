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

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use std.textio.all;

entity user_sequencer is
	port(
		cyc					: in std_logic;
		uclk_period			: in time;
		urstn_from_nf		: in std_logic;
		var1_rdy_i			: in std_logic;
		var2_rdy_i			: in std_logic;
		var3_rdy_i			: in std_logic;

		block_size			: out std_logic_vector(6 downto 0);
		launch_wb_read		: out std_logic;
		launch_wb_write 	: out std_logic;
		transfer_length		: out std_logic_vector(6 downto 0);
		transfer_offset		: out std_logic_vector(6 downto 0);
		var_id			 	: out std_logic_vector(1 downto 0);
		var1_acc_o			: out std_logic;
		var2_acc_o			: out std_logic;
		var3_acc_o			: out std_logic
	);
end user_sequencer;
	
architecture archi of user_sequencer is

signal blck_sze				: integer:=0;
signal launch_wb_rd			: std_logic:='0';
signal launch_wb_wr			: std_logic:='0';
signal transfer_lgth		: integer:=0;
signal transfer_offst		: integer:=0;
signal ucacerr				: boolean;
signal upacerr				: boolean;
signal var					: integer:=0;
signal var1_acc				: std_logic;
signal var2_acc				: std_logic;
signal var3_acc				: std_logic;
signal var3_fresh			: boolean;

begin
	
	-- process retrieving the sequence of actions performed by the user logic from a text file
	------------------------------------------------------------------------------------------
	sequence: process
	file sequence_file			: text open read_mode is "data/user_wb_sequence.txt";
	variable sequence_line		: line;
	variable stand_by_time		: time;
	variable coma				: string(1 to 1);
	
	variable block_size_tmp		: integer;
	variable rd_wr				: std_logic;
	variable trfer_lgth_tmp		: integer;
	variable trfer_ofst_tmp		: integer;
	variable var_id_tmp			: integer;
	
	begin
		wait for 0 us;
		readline	(sequence_file, sequence_line);
		readline	(sequence_file, sequence_line);
		readline	(sequence_file, sequence_line);

		loop
			launch_wb_rd		<= '0';
			launch_wb_wr		<= '0';
	
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
			wait for stand_by_time - uclk_period;

			var_id					<= std_logic_vector(to_unsigned(var_id_tmp,2));
			var						<= var_id_tmp;
			transfer_length			<= std_logic_vector(to_unsigned(trfer_lgth_tmp,7));
			transfer_lgth			<= trfer_lgth_tmp;
			transfer_offset			<= std_logic_vector(to_unsigned(trfer_ofst_tmp,7));
			transfer_offst			<= trfer_ofst_tmp;
			block_size				<= std_logic_vector(to_unsigned(block_size_tmp,7));
			blck_sze				<= block_size_tmp;
			if rd_wr ='1' then
				launch_wb_rd		<= '0';
				launch_wb_wr		<= '1';
			else
				launch_wb_rd		<= '1';
				launch_wb_wr		<= '0';
			end if;
			wait for uclk_period;
		end loop;
	end process;

	launch_wb_read		<= launch_wb_rd;
	launch_wb_write		<= launch_wb_wr;

	var1_acc_o			<= var1_acc;
	var2_acc_o			<= var2_acc;
	var3_acc_o			<= var3_acc;
	
	-- process generating the different variable access signals
	-----------------------------------------------------------
	user_access: process(var, cyc)
	begin
	case var is
	when 1 =>
		var1_acc			<= cyc;
		var2_acc			<= '0';
		var3_acc			<= '0';

	when 2 =>
		var1_acc			<= '0';
		var2_acc			<= cyc;
		var3_acc			<= '0';

	when 3 =>
		var1_acc			<= '0';
		var2_acc			<= '0';
		var3_acc			<= cyc;

	when others =>
		var1_acc			<= '0';
		var2_acc			<= '0';
		var3_acc			<= '0';
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
	
	reporting: process(launch_wb_rd, launch_wb_wr, ucacerr, upacerr)
	begin
		if launch_wb_rd ='1' then
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
		assert not(ucacerr or upacerr)
		report "               The user logic access violates the VAR_RDY condition and should generate a nanoFIP status error" & LF
		severity warning;
	end process;

end archi;
