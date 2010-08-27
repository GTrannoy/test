-- Created by : G. Penacoba
-- Creation Date: March 2010
-- Description: Orders the sequence of actions of the user 
-- Modified by: G. Penacoba
-- Modification Date: 23/08/2010
-- Modification consisted on: Name change 
--							+ addition of the other user interface signals

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;

entity user_sequencer is
	port(
		cyc					: in std_logic;
		urstn_i				: in std_logic;
		var1_rdy_i			: in std_logic;
		var2_rdy_i			: in std_logic;
		var3_rdy_i			: in std_logic;

		block_size			: out std_logic_vector(6 downto 0);
		launch_wb_read		: out std_logic;
		launch_wb_write 	: out std_logic;
		transfer_length		: out std_logic_vector(6 downto 0);
		transfer_offset		: out std_logic_vector(6 downto 0);
		var1_acc_o			: out std_logic;
		var2_acc_o			: out std_logic;
		var3_acc_o			: out std_logic;
		var_id			 	: out std_logic_vector(1 downto 0)
	);
end user_sequencer;
	
architecture archi of user_sequencer is

signal launch_wb_rd			: std_logic:='0';
signal launch_wb_wr			: std_logic:='0';
signal transfer_lgth		: std_logic_vector(6 downto 0):=(others=>'0');
signal transfer_offst		: std_logic_vector(6 downto 0):=(others=>'0');
signal var					: std_logic_vector(1 downto 0):=(others=>'0');

begin

	seq_for_wb: process
	begin
		block_size			<= "000" & x"0";
		launch_wb_rd		<= '0';
		launch_wb_wr		<= '0';
		transfer_lgth		<= "000" & x"0";
		transfer_offst		<= "000" & x"0";
		var					<= "00";
		wait for 100 us;

		block_size			<= "000" & x"0";
		launch_wb_rd		<= '0';
		launch_wb_wr		<= '1';
		transfer_lgth		<= "111" & x"C";
		transfer_offst		<= "000" & x"0";
		var					<= "11";
		wait for 60 ns;

		block_size			<= "000" & x"0";
		launch_wb_rd		<= '0';
		launch_wb_wr		<= '0';
		transfer_lgth		<= "000" & x"0";
		transfer_offst		<= "000" & x"0";
		var					<= "00";
		wait for 800 us;

		block_size			<= "000" & x"0";
		launch_wb_rd		<= '1';
		launch_wb_wr		<= '0';
		transfer_lgth		<= "000" & x"4";
		transfer_offst		<= "000" & x"0";
		var					<= "01";
		wait for 100 ns;

		block_size			<= "000" & x"0";
		launch_wb_rd		<= '0';
		launch_wb_wr		<= '0';
		transfer_lgth		<= "000" & x"0";
		transfer_offst		<= "000" & x"0";
		var					<= "00";
		wait for 20000 ms;
	end process;

	launch_wb_read		<= launch_wb_rd;
	launch_wb_write		<= launch_wb_wr;
	transfer_length		<= transfer_lgth;
	transfer_offset		<= transfer_offst;
	var_id				<= var;
	
	var1_acc_o			<= cyc;
--	var2_acc_o			<= cyc;
	var3_acc_o			<= cyc;

end archi;
