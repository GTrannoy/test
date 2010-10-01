-- Created by : G. Penacoba
-- Creation Date: May 2010
-- Description: Emulates the Fieldrive
-- Modified by:
-- Modification Date:
-- Modification consisted on:

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use std.textio.all;

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
		gx					: out std_logic_vector(crc_l downto 0)		
	);
	end component;

constant crc_l				: integer:=16;

signal gx					: std_logic_vector(crc_l downto 0);--:="10001110111001111";
--signal bit_rate				: integer;
signal f_clk_period			: time:= 0 us;

signal f_clk				: std_logic:='1';
signal h_clk				: std_logic:='1';
signal fd_reset				: std_logic;

signal cd					: std_logic;
signal dx					: std_logic;
signal id_rp				: std_logic;		-- '1' => id_dat, '0' => rp_dat
signal fip_frame_trigger	: std_logic;
signal station_adr			: std_logic_vector(7 downto 0);--:=x"00";
signal txck					: std_logic;
signal txd					: std_logic;
signal txena				: std_logic;
signal txerr				: std_logic;
signal var_adr				: std_logic_vector(7 downto 0);--:=x"00";
signal var_length			: std_logic_vector(6 downto 0);--:="0000000";
signal wdgn					: std_logic;

--signal gx_strg					: string(1 to crc_l+1);
--signal rate_strg				: string(1 to 19);
--signal read_config_trigger		: std_logic:='0';
--signal report_config_trigger	: std_logic:='0';

begin
	
--	-- process reading config values from a file
--	---------------------------------------------
--	read_config: process
--	file config_file			: text open read_mode is "data/WFIP_communication_config.txt";
--	variable config_line		: line;
--	variable validity_time		: time;
--
--	variable bit_rate_config	: integer;
--	variable gx_config			: std_logic_vector(crc_l downto 0);
--	begin
--		read_config_trigger		<= '0';
--		readline	(config_file, config_line);
--		read		(config_line, bit_rate_config);
--		readline	(config_file, config_line);
--		read		(config_line, gx_config);
--		readline	(config_file, config_line);
--		read		(config_line, validity_time);
--		if endfile(config_file) then
--			file_close(config_file);
--		end if;
--		bit_rate				<= bit_rate_config;
--		gx						<= gx_config;
--		read_config_trigger		<= '1';
--		wait for validity_time;
--	end process;
--
--	with bit_rate select
--						f_clk_period	<=	32 us	when 0,
--											1 us	when 1,
--											400 ns	when 2,
--											0 us	when others;
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

	rx_block: rx
	generic map(
		crc_l				=> crc_l
	)
	port map(
		clk					=> f_clk,
		gx					=> gx,
		id_rp				=> id_rp,
		fip_frame_trigger	=> fip_frame_trigger,
		h_clk				=> h_clk,
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
		gx					=> gx
	);
	
	fd_reset				<= not(fd_rstn_i);
	txd						<= fx_txd_i;
	txck					<= fd_txck_i;
	txena					<= fd_txena_i;
	
	fd_wdgn_o				<= wdgn;
	fd_txer_o				<= txerr;
	
	fx_rxa_o				<= not(cd);
	fx_rxd_o				<= dx;

--	-- Translation of values for the reporting
--	------------------------------------------
--	with bit_rate select
--		rate_strg					<=	"31.25 kbit/s       "	when 0,
--										"1 Mbit/s           "	when 1,
--										"2.5 Mbit/s         "	when 2,
--										"Incorrectly defined"	when others;
--	
--	gx_strg_generation: for i in crc_l downto 0 generate
--		gx_strg(crc_l+1-i) <= '1' when gx(i) ='1' else '0';
--	end generate;
--	
--	-- reporting process
--	-----------------------
--	report_config_trigger		<= read_config_trigger after 1 ps;
--
--	reporting: process(report_config_trigger)
--	begin
--		if report_config_trigger'event and report_config_trigger ='1' then
--			report LF & "WFIP bus configuration settings for test" & LF &
--						"-----------------------------------------" & LF &
--			"WorldFIP rate: " & rate_strg & LF &
--			"CRC length: " & integer'image(crc_l) & " bits" & LF &
--			"CRC generation polinomial: " & gx_strg & Lf;
--		end if;
--	end process;
	
end archi;
