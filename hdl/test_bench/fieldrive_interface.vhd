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
		fip_frame_trigger		: in std_logic;
		gx						: in std_logic_vector(crc_l downto 0);
		id_control_byte			: in std_logic_vector(7 downto 0);
		id_rp					: in std_logic;
		h_clk					: in std_logic;
		mps_byte				: in std_logic_vector(7 downto 0);
		pdu_type_byte			: in std_logic_vector(7 downto 0);
		rp_control_byte			: in std_logic_vector(7 downto 0);
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
		
		txerr					: out std_logic;
		wdgn					: out std_logic
	);
	end component;

	component bus_arbitrer
	port(
		f_clk_period		: in time;
		
		fip_frame_trigger	: out std_logic;
		id_rp				: out std_logic;
		station_adr			: out std_logic_vector(7 downto 0);
		var_adr				: out std_logic_vector(7 downto 0);
		var_length			: out std_logic_vector(6 downto 0)
	);
	end component;

	component bus_config
	generic(
		crc_l				: integer:=16
	);
	port(
		f_clk_period		: out time;
		gx					: out std_logic_vector(crc_l downto 0);
		id_control_byte		: out std_logic_vector(7 downto 0);
		mps_byte			: out std_logic_vector(7 downto 0);
		pdu_type_byte		: out std_logic_vector(7 downto 0);
		rp_control_byte		: out std_logic_vector(7 downto 0)
	);
	end component;

constant crc_l				: integer:=16;

signal cd					: std_logic;
signal dx					: std_logic;
signal f_clk_period			: time:= 0 us;
signal f_clk				: std_logic:='1';
signal fd_reset				: std_logic;
signal fip_frame_trigger	: std_logic;
signal gx					: std_logic_vector(crc_l downto 0);
signal h_clk				: std_logic:='1';
signal id_rp				: std_logic;		-- '1' => id_dat, '0' => rp_dat
signal id_control_byte		: std_logic_vector(7 downto 0);
signal mps_byte				: std_logic_vector(7 downto 0);
signal pdu_type_byte		: std_logic_vector(7 downto 0);
signal rp_control_byte		: std_logic_vector(7 downto 0);
signal station_adr			: std_logic_vector(7 downto 0);
signal txck					: std_logic;
signal txd					: std_logic;
signal txena				: std_logic;
signal txerr				: std_logic;
signal var_adr				: std_logic_vector(7 downto 0);
signal var_length			: std_logic_vector(6 downto 0);
signal wdgn					: std_logic;

begin
	
	clock: process
	begin
		wait for 0 us;
		f_clk				<= not(f_clk);
		wait for f_clk_period/2;
	end process;

	half_clock: process
	begin
		wait for 0 us;
		h_clk				<= not(h_clk);
		wait for f_clk_period/4;
	end process;

	fd_reset				<= not(fd_rstn_i);
	txd						<= fx_txd_i;
	txck					<= fd_txck_i;
	txena					<= fd_txena_i;
	
	fd_wdgn_o				<= wdgn;
	fd_txer_o				<= txerr;
	
	fx_rxa_o				<= not(cd);
	fx_rxd_o				<= dx;

	rx_block: rx
	generic map(
		crc_l				=> crc_l
	)
	port map(
		clk					=> f_clk,
		fip_frame_trigger	=> fip_frame_trigger,
		gx					=> gx,
		id_control_byte		=> id_control_byte,
		id_rp				=> id_rp,
		h_clk				=> h_clk,
		mps_byte			=> mps_byte,
		pdu_type_byte		=> pdu_type_byte,
		rp_control_byte		=> rp_control_byte,
		reset				=> fd_reset,
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
		clk					=> f_clk,
		gx					=> gx,
		reset				=> fd_reset,
		txck				=> txck,
		txd					=> txd,
		txena				=> txena,
		
		txerr				=> txerr,
		wdgn				=> wdgn
	);
	
	fip_bus_arbitrer_emulator: bus_arbitrer
	port map(
		f_clk_period		=> f_clk_period,

		fip_frame_trigger	=> fip_frame_trigger,
		id_rp				=> id_rp,
		station_adr			=> station_adr,
		var_adr				=> var_adr,
		var_length			=> var_length
	);
	
	fip_bus_config: bus_config
	generic map(
		crc_l				=> crc_l
	)
	port map(
		f_clk_period		=> f_clk_period,
		gx					=> gx,
		id_control_byte		=> id_control_byte,
		mps_byte			=> mps_byte,
		pdu_type_byte		=> pdu_type_byte,
		rp_control_byte		=> rp_control_byte
	);
	
end archi;
