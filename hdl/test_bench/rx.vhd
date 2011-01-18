-- Created by : G. Penacoba
-- Creation Date: May 2010
-- Description: Generates data to be transmitted from the fieldbus to NanoFIP.
--				Emulates Fieldrive in reception mode.
-- Modified by:
-- Modification Date:
-- Modification consisted on:

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.tb_package.all;

entity rx is
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
end rx;

architecture archi of rx is

	component rx_feeder
	generic(
		crc_l					: integer:=16
	);
	port(
		clk						: in std_logic;
		fcs_ready				: in std_logic;
		fcs_complete			: in std_logic;
		fip_frame_trigger		: in std_logic;
		msg_complete			: in std_logic;
		reset					: in std_logic;
		
		crc_start				: out std_logic;
		en_crc_end				: out std_logic;
		msg_start				: out std_logic;
		dx_en					: out std_logic;
		mux_select				: out std_logic_vector(1 downto 0);
		seq_start				: out std_logic
	);
	end component;

	component msg_sender
	port(
		clk						: in std_logic;
		fip_frame_trigger		: in std_logic;
		id_control_byte			: in std_logic_vector(7 downto 0);
		id_rp					: in std_logic;		-- '1'=>id_dat, '0'=>rp_dat
		mps_byte				: in std_logic_vector(7 downto 0);
		msg_start				: in std_logic;
		msg_new_data_req		: in std_logic;
		pdu_type_byte			: in std_logic_vector(7 downto 0);
		reset					: in std_logic;
		rp_control_byte			: in std_logic_vector(7 downto 0);
		station_adr				: in std_logic_vector(7 downto 0);
		var_adr					: in std_logic_vector(7 downto 0);
		var_adr_presence		: in std_logic_vector(7 downto 0);
		var_adr_identification	: in std_logic_vector(7 downto 0);
		var_adr_broadcast		: in std_logic_vector(7 downto 0);
		var_adr_consumed		: in std_logic_vector(7 downto 0);
		var_adr_produced		: in std_logic_vector(7 downto 0);
		var_adr_reset			: in std_logic_vector(7 downto 0);
		var_length				: in std_logic_vector(6 downto 0);
		
		msg_complete			: out std_logic;
		msg_data				: out std_logic_vector(7 downto 0);
		msg_go					: out std_logic
	);
	end component;

	component crc_gen
	generic(
		crc_l			: integer:=16								-- polinomial length in bits
	);
	port(
		clk				: in std_logic;
		gx				: in std_logic_vector(crc_l downto 0);		-- polinomial divisor
		crc_gen_start	: in std_logic;								-- launches the FCS calculation
		crc_gen_end		: in std_logic;								-- ends the FCS calculation
		mx				: in std_logic;								-- message incoming bits
		reset			: in std_logic;
		
		fcs				: out std_logic_vector(crc_l-1 downto 0);	-- FCS sequence
		fcs_ready		: out std_logic;
		fcs_valid		: out std_logic
	);
	end component;

	component serializer
	generic(
		width			: integer:=8
	);
	port(
		clk				: in std_logic;
		data_in			: in std_logic_vector(width-1 downto 0);
		go				: in std_logic;
		reset			: in std_logic;

		data_out		: out std_logic;
		done			: out std_logic
	);
	end component;

	component onetime_serializer
	generic(
		width			: integer:=8
	);
	port(
		clk				: in std_logic;
		data_in			: in std_logic_vector(width-1 downto 0);
		go				: in std_logic;
		reset			: in std_logic;

		data_out		: out std_logic;
		done			: out std_logic
	);
	end component;

	component fss_gen
	generic(
		width					: integer:=16
	);
	port(
		clk						: in std_logic;
		fss_value				: in std_logic_vector(15 downto 0);
		start_delimiter			: in std_logic;
		reset					: in std_logic;
		
		fss						: out std_logic;
		v_minus					: out std_logic;
		v_plus					: out std_logic
	);
	end component;
	
	component fes_gen
	generic(
		width					: integer:=8
	);
	port(
		clk						: in std_logic;
		fes_value				: in std_logic_vector(7 downto 0);
		start_delimiter			: in std_logic;
		reset					: in std_logic;
		
		fes						: out std_logic;
		v_minus					: out std_logic;
		v_plus					: out std_logic
	);
	end component;

	component manchester_encoder is
	port(
		clk				: in std_logic;
		data_in			: in std_logic;
		dx_en			: in std_logic;
		h_clk			: in std_logic;
		reset			: in std_logic;
		v_minus			: in std_logic;
		v_plus			: in std_logic;
		
		cd				: out std_logic;
		data_out		: out std_logic
	);
	end component;

signal fss							: std_logic;
signal fes							: std_logic;

signal msg_start					: std_logic;
signal msg_complete					: std_logic;
signal msg_new_data_req				: std_logic;
signal msg_data						: std_logic_vector(7 downto 0);
signal msg_go						: std_logic;

signal mx							: std_logic;
signal msg_dly						: std_logic_vector(crc_l downto 0);
signal mx_final						: std_logic;

signal fcs							: std_logic_vector(crc_l-1 downto 0);
signal fcs_valid					: std_logic;
signal fcs_ready					: std_logic;
signal fx							: std_logic;
signal fcs_complete					: std_logic;
signal seq_start					: std_logic;

signal en_crc_end					: std_logic;
signal crc_gen_start				: std_logic;
signal crc_gen_end					: std_logic;

signal mux_select					: std_logic_vector(1 downto 0);

signal v_minus_fss					: std_logic;
signal v_plus_fss					: std_logic;
signal v_minus_fes					: std_logic;
signal v_plus_fes					: std_logic;
signal v_minus						: std_logic;
signal v_plus						: std_logic;

signal dx_en						: std_logic;
signal dx_final						: std_logic;
signal dx_half						: std_logic;

begin

	feeder: rx_feeder
	generic map(
		crc_l					=> crc_l
	)
	port map(
		clk						=> clk,
		fcs_ready				=> fcs_ready,
		fcs_complete			=> fcs_complete,
		fip_frame_trigger		=> fip_frame_trigger,
		msg_complete			=> msg_complete,
		reset					=> reset,
		
		crc_start				=> crc_gen_start,
		en_crc_end				=> en_crc_end,
		msg_start				=> msg_start,
		dx_en					=> dx_en,
		mux_select				=> mux_select,
		seq_start				=> seq_start
	);

	msg_block: msg_sender
	port map(
		clk						=> clk,
		fip_frame_trigger		=> fip_frame_trigger,
		id_control_byte			=> id_control_byte,
		id_rp					=> id_rp,
		mps_byte				=> mps_byte,
		msg_start				=> msg_start,
		msg_new_data_req		=> msg_new_data_req,
		pdu_type_byte			=> pdu_type_byte,
		reset					=> reset,
		rp_control_byte			=> rp_control_byte,
		station_adr				=> station_adr,
		var_adr					=> var_adr,
		var_adr_presence		=> var_adr_presence,
		var_adr_identification	=> var_adr_identification,
		var_adr_broadcast		=> var_adr_broadcast,
		var_adr_consumed		=> var_adr_consumed,
		var_adr_produced		=> var_adr_produced,
		var_adr_reset			=> var_adr_reset,
		var_length				=> var_length,
		
		msg_complete			=> msg_complete,
		msg_data				=> msg_data,
		msg_go					=> msg_go
	);
	
	msg_serializer: serializer
	generic map(
		width			=> 8
	)
	port map(
		clk				=> clk,
		data_in			=> msg_data,
		go				=> msg_go,
		reset			=> reset,
		
		data_out		=> mx,
		done			=> msg_new_data_req
	);

	crc_block: crc_gen
	generic map(
		crc_l	=> crc_l
	)
	port map(
		clk				=> clk,
		gx				=> gx,
		crc_gen_start	=> crc_gen_start,
		crc_gen_end		=> crc_gen_end,
		mx				=> mx,
		reset			=> reset,
				
		fcs				=> fcs,
		fcs_ready		=> fcs_ready,
		fcs_valid		=> fcs_valid
	);

	fcs_serializer: onetime_serializer
	generic map(
		width			=> crc_l
	)
	port map(
		clk				=> clk,
		data_in			=> fcs,
		go				=> fcs_valid,
		reset			=> reset,
		
		data_out		=> fx,
		done			=> fcs_complete
	);
	
	fss_block: fss_gen
	port map(
		clk						=> clk,
		fss_value				=> fss_value,
		start_delimiter			=> seq_start,
		reset					=> reset,
		
		fss						=> fss,
		v_minus					=> v_minus_fss,
		v_plus					=> v_plus_fss
	);
	
	fes_block: fes_gen
	port map(
		clk						=> clk,
		fes_value				=> fes_value,
		start_delimiter			=> fcs_complete,
		reset					=> reset,

		fes						=> fes,
		v_minus					=> v_minus_fes,
		v_plus					=> v_plus_fes
	);
	
	encoder: manchester_encoder
	port map(
		clk				=> clk,
		data_in			=> dx_final,
		dx_en			=> dx_en,
		h_clk			=> h_clk,
		reset			=> reset,
		v_minus			=> v_minus,
		v_plus			=> v_plus,
		
		cd				=> cd,
		data_out		=> dx_half
	);

	delayer: process
	begin
		msg_dly(crc_l-1 downto 0)		<= msg_dly(crc_l downto 1);
		wait until clk ='1';
	end process;

	dx_mux: process(dx_en, mux_select, fss, mx_final, fx, fes)
	begin
			case mux_select is
			when "00" =>
				dx_final	<= fss;
		
			when "01" =>
				dx_final	<= mx_final;
			
			when "10" =>
				dx_final	<= fx;
			
			when "11" =>
				dx_final	<= fes;
			
			when others =>
				dx_final	<= '0';
			end case;
	end process;
	
	dx						<= dx_half;

	msg_dly(crc_l)			<= mx;
	mx_final				<= msg_dly(0);

	crc_gen_end				<= msg_new_data_req when en_crc_end ='1'
								else '0';

	v_minus					<= v_minus_fss or v_minus_fes;
	v_plus					<= v_plus_fss or v_plus_fes;
	
end archi;
