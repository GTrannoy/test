-- Created by : G. Penacoba
-- Creation Date: MAy 2010
-- Description: Module emulating all the user logic activity
-- Modified by:
-- Modification Date:
-- Modification consisted on:

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity user_interface is
	port(
		urstn_i				: in std_logic;
		var1_rdy_i			: in std_logic;
		var2_rdy_i			: in std_logic;
		var3_rdy_i			: in std_logic;

		uclk_o				: out std_logic;
		urstn_o				: out std_logic;
		var1_acc_o			: out std_logic;
		var2_acc_o			: out std_logic;
		var3_acc_o			: out std_logic;

		ack_i				: in std_logic;
		dat_i				: in std_logic_vector(7 downto 0);

		adr_o				: out std_logic_vector(9 downto 0);
		cyc_o				: out std_logic;
		dat_o				: out std_logic_vector(7 downto 0);
		rst_o				: out std_logic;
		stb_o				: out std_logic;
		wclk_o				: out std_logic;
		we_o				: out std_logic
	);
end user_interface;

architecture archi of user_interface is

	component wishbone_interface
	port(
		block_size			: in std_logic_vector(6 downto 0);
		launch_wb_read		: in std_logic;
		launch_wb_write 	: in std_logic;
		transfer_length		: in std_logic_vector(6 downto 0);
		transfer_offset		: in std_logic_vector(6 downto 0);
		var_id			 	: in std_logic_vector(1 downto 0);

		ack_i				: in std_logic;
		clk_i				: in std_logic;
		dat_i				: in std_logic_vector(7 downto 0);
		rst_i				: in std_logic;

		adr_o				: out std_logic_vector(9 downto 0);
		cyc_o				: out std_logic;
		dat_o				: out std_logic_vector(7 downto 0);
		stb_o				: out std_logic;
		we_o				: out std_logic
	);
	end component;

	component sequencer
	port(
		block_size			: out std_logic_vector(6 downto 0);
		launch_wb_read		: out std_logic;
		launch_wb_write 	: out std_logic;
		transfer_length		: out std_logic_vector(6 downto 0);
		transfer_offset		: out std_logic_vector(6 downto 0);
		var_id			 	: out std_logic_vector(1 downto 0)
	);
	end component;
	
	signal block_size			: std_logic_vector(6 downto 0):="000" & x"0";
	signal clk					: std_logic:='0';
	signal launch_wb_read		: std_logic:='0';
	signal launch_wb_write 		: std_logic:='0';
	signal reset				: std_logic:='0';
	signal transfer_length		: std_logic_vector(6 downto 0):="000" & x"0";
	signal transfer_offset		: std_logic_vector(6 downto 0):="000" & x"0";
	signal var_id		 		: std_logic_vector(1 downto 0):="00";

	signal rst_i				: std_logic;

begin

	clock: process
	begin
		clk						<= not(clk);
		wait for 12500 ps;
	end process;
	
	reseting: process
	begin
--		reset				<= '0';
--		wait for 2 us;
		reset				<= '1';
		wait for 2600 ns;
		reset				<= '0';
		wait for 1000 ms;
	end process;

	uclk_o				<= clk;
	urstn_o				<= not(reset);

--	seq: sequencer
--	port map(
--		block_size				=> block_size,
--		launch_wb_read			=> launch_wb_read,
--		launch_wb_write 		=> launch_wb_write,
--		transfer_length			=> transfer_length,
--		transfer_offset			=> transfer_offset,
--		var_id					=> var_id
--	);
--
--	wb_interface:  wishbone_interface
--	port map(
--		block_size				=> block_size,
--		launch_wb_read			=> launch_wb_read,
--		launch_wb_write 		=> launch_wb_write,
--		transfer_length			=> transfer_length,
--		transfer_offset			=> transfer_offset,
--		var_id					=> var_id,
--
--		ack_i					=> ack_i,
--		clk_i					=> clk,
--		dat_i					=> dat_i,
--		rst_i					=> rst_i,
--
--		adr_o					=> adr_o,
--		cyc_o					=> cyc_o,
--		dat_o					=> dat_o,
--		stb_o					=> stb_o,
--		we_o					=> we_o
--	);

end archi;
