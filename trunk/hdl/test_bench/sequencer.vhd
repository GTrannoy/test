-- Created by : G. Penacoba
-- Creation Date: March 2010
-- Description: Orders the sequence of actions during the runing 
--				of the testbench.
-- Modified by:
-- Modification Date:
-- Modification consisted on:

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;

entity sequencer is
	port(
		block_size			: out std_logic_vector(6 downto 0);
		launch_wb_read		: out std_logic;
		launch_wb_write 	: out std_logic;
		transfer_length		: out std_logic_vector(6 downto 0);
		transfer_offset		: out std_logic_vector(6 downto 0);
		var_id			 	: out std_logic_vector(1 downto 0)
	);
end sequencer;
	
architecture archi of sequencer is
begin

	seq_for_wb: process
	begin
		block_size			<= "000" & x"0";
		launch_wb_read		<= '0';
		launch_wb_write		<= '0';
		transfer_length		<= "000" & x"0";
		transfer_offset		<= "000" & x"0";
		var_id				<= "00";
		wait for 100 us;

		block_size			<= "000" & x"0";
		launch_wb_read		<= '0';
		launch_wb_write		<= '1';
		transfer_length		<= "000" & x"8";
		transfer_offset		<= "000" & x"0";
		var_id				<= "11";
		wait for 60 ns;

		block_size			<= "000" & x"0";
		launch_wb_read		<= '0';
		launch_wb_write		<= '0';
		transfer_length		<= "000" & x"0";
		transfer_offset		<= "000" & x"0";
		var_id				<= "00";
		wait for 1 us;

		block_size			<= "000" & x"0";
		launch_wb_read		<= '1';
		launch_wb_write		<= '0';
		transfer_length		<= "000" & x"8";
		transfer_offset		<= "000" & x"0";
		var_id				<= "10";
		wait for 100 ns;

		block_size			<= "000" & x"0";
		launch_wb_read		<= '0';
		launch_wb_write		<= '0';
		transfer_length		<= "000" & x"0";
		transfer_offset		<= "000" & x"0";
		var_id				<= "00";
		wait for 20000 ms;
	end process;

end archi;
