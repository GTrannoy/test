-- Created by : G. Penacoba
-- Creation Date: May 2010
-- Description: Emulates the Fieldrive
-- Modified by:
-- Modification Date:
-- Modification consisted on:

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity fieldrive_interface is
	port(
		fd_rstn_i		: in std_logic;
		fd_txck_i		: in std_logic;
		fx_txd_i		: in std_logic;
		fd_txena_i		: in std_logic;

		fx_rxa_o		: out std_logic;
		fx_rxd_o		: out std_logic;
		fd_txer_o		: out std_logic;
		fd_wdgn_o		: out std_logic
	);
end fieldrive_interface;

architecture archi of fieldrive_interface is

	component rx
	generic(
		crc_l					: integer:=16
	);
	port(
		clk						: in std_logic;
		gx						: in std_logic_vector(crc_l downto 0);
		id_rp					: in std_logic;
		fip_frame_trigger		: in std_logic;
		h_clk					: in std_logic;
		reset					: in std_logic;
		station_adr				: in std_logic_vector(7 downto 0);
		var_adr					: in std_logic_vector(7 downto 0);
		var_length				: in std_logic_vector(6 downto 0);
		
		cd						: out std_logic;
		dx						: out std_logic
	);
	end component;
	
	component tx
	generic(
		crc_l					: integer:=16
	);
	port(
		clk						: in std_logic;
		gx						: in std_logic_vector(crc_l downto 0);
		reset					: in std_logic;
		txck					: in std_logic;
		txd						: in std_logic;
		txena					: in std_logic;
		
		txerr					: out std_logic
	);
	end component;

	component bus_arbitrer
	port(
		id_rp				: out std_logic;
		fip_frame_trigger	: out std_logic;
		station_adr			: out std_logic_vector(7 downto 0);
		var_adr				: out std_logic_vector(7 downto 0);
		var_length			: out std_logic_vector(6 downto 0)
	);
	end component;

constant crc_l				: integer:=16;
constant gx					: std_logic_vector(crc_l downto 0):="10001110111001111";

signal clk					: std_logic:='1';
signal h_clk				: std_logic:='1';
signal reset				: std_logic;

signal cd					: std_logic;
signal dx					: std_logic;
signal id_rp				: std_logic;		-- '1' => id_dat, '0' => rp_dat
signal fip_frame_trigger	: std_logic;
signal station_adr			: std_logic_vector(7 downto 0):=x"00";
signal txck					: std_logic;
signal txd					: std_logic;
signal txena				: std_logic;
signal txerr				: std_logic;
signal var_adr				: std_logic_vector(7 downto 0):=x"00";
signal var_length			: std_logic_vector(6 downto 0):="0000000";

begin

	clock: process
	begin
		clk						<= not(clk);
		wait for 500 ns;
	end process;

	half_clock: process
	begin
		h_clk					<= not(h_clk);
		wait for 250 ns;
	end process;

	rst: process
	begin
		reset					<= '1';
		wait for 20 us;
		reset					<= '0';
		wait for 1000 ms;
	end process;

	rx_block: rx
	generic map(
		crc_l				=> crc_l
	)
	port map(
		clk					=> clk,
		gx					=> gx,
		id_rp				=> id_rp,
		fip_frame_trigger	=> fip_frame_trigger,
		h_clk				=> h_clk,
		reset				=> reset,
		station_adr			=> station_adr,
		var_adr				=> var_adr,
		var_length			=> var_length,

		cd					=> cd,
		dx					=> dx
	);

	tx_block: tx
	generic map(
		crc_l				=> crc_l
	)
	port map(
		clk					=> clk,
		gx					=> gx,
		reset				=> reset,
		txck				=> txck,
		txd					=> txd,
		txena				=> txena,
		
		txerr				=> txerr
	);
	
	fip_arbitrer: bus_arbitrer
	port map(
		id_rp				=> id_rp,
		fip_frame_trigger	=> fip_frame_trigger,
		station_adr			=> station_adr,
		var_adr				=> var_adr,
		var_length			=> var_length
	);
	
	txd						<= fx_txd_i;
	txck					<= fd_txck_i;
	txena					<= fd_txena_i;
	
	fd_wdgn_o			<= '1';
	fd_txer_o			<= txerr;
	
	fx_rxa_o			<= not(cd);
	fx_rxd_o			<= dx;
	
end archi;
