-- Created by : G. Penacoba
-- Creation Date: May 2010
-- Description: Emulates the Fieldrive
-- Modified by:
-- Modification Date:
-- Modification consisted on:

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.tb_package.all;

entity fieldrive_interface is
	port(
		fd_rstn_i		: in std_logic;
		fd_txck_i		: in std_logic;
		fd_txd_i		: in std_logic;
		fd_txena_i		: in std_logic;

		fd_rxcdn_o		: out std_logic;
		fd_rxd_o		: out std_logic;
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
		fes_value				: in std_logic_vector(7 downto 0);
		fip_frame_trigger		: in std_logic;
		fss_value				: in std_logic_vector(15 downto 0);
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
		var_adr_presence		: in std_logic_vector(7 downto 0);
		var_adr_identification	: in std_logic_vector(7 downto 0);
		var_adr_broadcast		: in std_logic_vector(7 downto 0);
		var_adr_consumed		: in std_logic_vector(7 downto 0);
		var_adr_produced		: in std_logic_vector(7 downto 0);
		var_adr_reset			: in std_logic_vector(7 downto 0);
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
		f_clk_period			: in time;
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
		f_clk_period			: in time;
		
		fip_frame_trigger		: out std_logic;
		id_rp					: out std_logic;
		station_adr				: out std_logic_vector(7 downto 0);
		var_adr					: out std_logic_vector(7 downto 0);
		var_length				: out std_logic_vector(6 downto 0)
	);
	end component;

	component bus_config
	generic(
		crc_l				: integer:=16
	);
	port(
		f_clk_period			: out time;
		fes_value				: out std_logic_vector(7 downto 0);
		fss_value				: out std_logic_vector(15 downto 0);
		gx						: out std_logic_vector(crc_l downto 0);
		id_control_byte			: out std_logic_vector(7 downto 0);
		min_turn_around			: out time;
		mps_byte				: out std_logic_vector(7 downto 0);
		pdu_type_byte			: out std_logic_vector(7 downto 0);
		rp_control_byte			: out std_logic_vector(7 downto 0);
		silence_time			: out time;
		var_adr_presence		: out std_logic_vector(7 downto 0);
		var_adr_identification	: out std_logic_vector(7 downto 0);
		var_adr_broadcast		: out std_logic_vector(7 downto 0);
		var_adr_consumed		: out std_logic_vector(7 downto 0);
		var_adr_produced		: out std_logic_vector(7 downto 0);
		var_adr_reset			: out std_logic_vector(7 downto 0)
	);
	end component;

	component bus_monitor
	port(
		cd						: in std_logic;
		f_clk_period			: in time;
		fd_reset				: in std_logic;
		id_rp					: in std_logic;
		min_turn_around			: in time;
		silence_time			: in time;
		txena					: in std_logic
	);
	end component;

constant crc_l				: integer:=16;


signal cd						: std_logic;
signal dx						: std_logic;
signal f_clk_period				: time:= 0 us;
signal f_clk					: std_logic:='1';
signal fd_reset					: std_logic;
signal fes_value				: std_logic_vector(7 downto 0);
signal fip_frame_trigger		: std_logic;
signal fss_value				: std_logic_vector(15 downto 0);
signal gx						: std_logic_vector(crc_l downto 0);
signal h_clk					: std_logic:='1';
signal id_rp					: std_logic;		-- '1' => id_dat, '0' => rp_dat
signal id_control_byte			: std_logic_vector(7 downto 0);
signal min_turn_around			: time;
signal mps_byte					: std_logic_vector(7 downto 0);
signal pdu_type_byte			: std_logic_vector(7 downto 0);
signal rp_control_byte			: std_logic_vector(7 downto 0);
signal silence_time				: time;
signal station_adr				: std_logic_vector(7 downto 0);
signal sof						: std_logic;
signal txck						: std_logic;
signal txd						: std_logic;
signal txena					: std_logic;
signal txerr					: std_logic;
signal var_adr					: std_logic_vector(7 downto 0);
signal var_adr_presence			: std_logic_vector(7 downto 0);
signal var_adr_identification	: std_logic_vector(7 downto 0);
signal var_adr_broadcast		: std_logic_vector(7 downto 0);
signal var_adr_consumed			: std_logic_vector(7 downto 0);
signal var_adr_produced			: std_logic_vector(7 downto 0);
signal var_adr_reset			: std_logic_vector(7 downto 0);
signal var_length				: std_logic_vector(6 downto 0);
signal wdgn						: std_logic;

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
	txd						<= fd_txd_i;
	txck					<= fd_txck_i;
	txena					<= fd_txena_i;
	
	fd_wdgn_o				<= wdgn;
	fd_txer_o				<= txerr;
	
	fd_rxcdn_o				<= not(cd);
	fd_rxd_o				<= dx or (txd and txena);

	rx_block: rx
	generic map(
		crc_l				=> crc_l
	)
	port map(
		clk						=> f_clk,
		fes_value				=> fes_value,
		fip_frame_trigger		=> fip_frame_trigger,
		fss_value				=> fss_value,
		gx						=> gx,
		id_control_byte			=> id_control_byte,
		id_rp					=> id_rp,
		h_clk					=> h_clk,
		mps_byte				=> mps_byte,
		pdu_type_byte			=> pdu_type_byte,
		rp_control_byte			=> rp_control_byte,
		reset					=> fd_reset,
		station_adr				=> station_adr,
		var_adr					=> var_adr,
		var_adr_presence		=> var_adr_presence,
		var_adr_identification	=> var_adr_identification,
		var_adr_broadcast		=> var_adr_broadcast,
		var_adr_consumed		=> var_adr_consumed,
		var_adr_produced		=> var_adr_produced,
		var_adr_reset			=> var_adr_reset,
		var_length				=> var_length,

		cd						=> cd,
		dx						=> dx
	);

	tx_block: tx
	generic map(
		crc_l				=> crc_l
	)
	port map(
		clk					=> f_clk,
		f_clk_period		=> f_clk_period,
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
		f_clk_period			=> f_clk_period,

		fip_frame_trigger		=> fip_frame_trigger,
		id_rp					=> id_rp,
		station_adr				=> station_adr,
		var_adr					=> var_adr,
		var_length				=> var_length
	);
	
	fip_bus_config: bus_config
	generic map(
		crc_l					=> crc_l
	)
	port map(
		f_clk_period			=> f_clk_period,
		gx						=> gx,
		fes_value				=> fes_value,
		fss_value				=> fss_value,
		id_control_byte			=> id_control_byte,
		min_turn_around			=> min_turn_around,
		mps_byte				=> mps_byte,
		pdu_type_byte			=> pdu_type_byte,
		rp_control_byte			=> rp_control_byte,
		silence_time			=> silence_time,
		var_adr_presence		=> var_adr_presence,
		var_adr_identification	=> var_adr_identification,
		var_adr_broadcast		=> var_adr_broadcast,
		var_adr_consumed		=> var_adr_consumed,
		var_adr_produced		=> var_adr_produced,
		var_adr_reset			=> var_adr_reset
	);
	
	fip_bus_monitor: bus_monitor
	port map(
		cd						=> cd,
		f_clk_period			=> f_clk_period,
		fd_reset				=> fd_reset,
		id_rp					=> id_rp,
		min_turn_around			=> min_turn_around,
		silence_time			=> silence_time,
		txena					=> txena
	);

end archi;
