-- Created by : G. Penacoba
-- Creation Date: March 2010
-- Description: Orders the sequence of actions of the user 
-- Modified by: G. Penacoba
-- Modification Date: 23/08/2010
-- Modification consisted on: Name change 
--							+ addition of the other user interface signals

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use std.textio.all;

entity user_sequencer is
	port(
		cyc					: in std_logic;
		uclk_period			: in time;
		urstn_i				: in std_logic;
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

signal blck_sze				: std_logic_vector(6 downto 0):=(others=>'0');
signal launch_wb_rd			: std_logic:='0';
signal launch_wb_wr			: std_logic:='0';
signal transfer_lgth		: std_logic_vector(6 downto 0):=(others=>'0');
signal transfer_offst		: std_logic_vector(6 downto 0):=(others=>'0');
signal var					: std_logic_vector(1 downto 0):=(others=>'0');

begin

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
			var						<= std_logic_vector(to_unsigned(var_id_tmp,2));
			transfer_length			<= std_logic_vector(to_unsigned(trfer_lgth_tmp,7));
			transfer_lgth			<= std_logic_vector(to_unsigned(trfer_lgth_tmp,7));
			transfer_offset			<= std_logic_vector(to_unsigned(trfer_ofst_tmp,7));
			transfer_offst			<= std_logic_vector(to_unsigned(trfer_ofst_tmp,7));
			block_size				<= std_logic_vector(to_unsigned(block_size_tmp,7));
			blck_sze				<= std_logic_vector(to_unsigned(block_size_tmp,7));
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


--	seq_for_wb: process
--	begin
--		block_size			<= "000" & x"0";
--		launch_wb_rd		<= '0';
--		launch_wb_wr		<= '0';
--		transfer_lgth		<= "000" & x"0";
--		transfer_offst		<= "000" & x"0";
--		var					<= "00";
--		wait for 100 us;
--
--		block_size			<= "000" & x"0";
--		launch_wb_rd		<= '0';
--		launch_wb_wr		<= '1';
--		transfer_lgth		<= "111" & x"C";
--		transfer_offst		<= "000" & x"0";
--		var					<= "11";
--		wait for 60 ns;
--
--		block_size			<= "000" & x"0";
--		launch_wb_rd		<= '0';
--		launch_wb_wr		<= '0';
--		transfer_lgth		<= "000" & x"0";
--		transfer_offst		<= "000" & x"0";
--		var					<= "00";
--		wait for 1800 us;
--
--		block_size			<= "000" & x"0";
--		launch_wb_rd		<= '1';
--		launch_wb_wr		<= '0';
--		transfer_lgth		<= "000" & x"4";
--		transfer_offst		<= "000" & x"0";
--		var					<= "01";
--		wait for 100 ns;
--
--		block_size			<= "000" & x"0";
--		launch_wb_rd		<= '0';
--		launch_wb_wr		<= '0';
--		transfer_lgth		<= "000" & x"0";
--		transfer_offst		<= "000" & x"0";
--		var					<= "00";
--		wait for 20000 ms;
--	end process;

	launch_wb_read		<= launch_wb_rd;
	launch_wb_write		<= launch_wb_wr;
--	transfer_length		<= transfer_lgth;
--	transfer_offset		<= transfer_offst;
--	var_id				<= var;
	
	var1_acc_o			<= cyc;
--	var2_acc_o			<= cyc;
	var3_acc_o			<= cyc;

end archi;
