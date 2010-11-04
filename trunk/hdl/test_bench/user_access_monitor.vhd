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
signal ucacerr				: boolean;
signal upacerr				: boolean;
signal var1_acc				: std_logic;
signal var2_acc				: std_logic;
signal var3_acc				: std_logic;
signal var3_fresh			: boolean;

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
	
end archi;
