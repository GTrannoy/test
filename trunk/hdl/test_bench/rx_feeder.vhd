-- Created by : G. Penacoba
-- Creation Date: May 2010
-- Description: Schedules the order in which the data are fed serially to the NanoFIP
-- Modified by:
-- Modification Date:
-- Modification consisted on:

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity rx_feeder is
	generic(
		crc_l					: integer:=16
	);
	port(
		clk						: in std_logic;
		fcs_ready				: in std_logic;
		fcs_complete			: in std_logic;
		launch_fip_transmit		: in std_logic;
		msg_complete			: in std_logic;
		reset					: in std_logic;
		
		crc_start				: out std_logic;
		dx_en					: out std_logic;
		en_crc_end				: out std_logic;
		msg_start				: out std_logic;
		mux_select				: out std_logic_vector(1 downto 0);
		seq_start				: out std_logic
	);
end rx_feeder;

architecture archi of rx_feeder is

type fstate_ty				is (idle, start_seq, start_frame, start_frame_bk,
							 waiting, end_msg, issue_fcs, end_frame, end_frame_bk);
signal fstate, nxt_fstate	: fstate_ty;

signal fss_start			: std_logic;
signal fss_dly				: std_logic_vector(15 downto 0);
signal fss_complete			: std_logic;
signal fes_start			: std_logic;
signal fes_dly				: std_logic_vector(7 downto 0);
signal fes_complete			: std_logic;

signal msg_seq_start		: std_logic;
signal msg_start_dly		: std_logic_vector(16 downto 0);

begin

-- serial data feeder state machine (sequential section)
--------------------------------------------------------
	rx_feeder_seq: process
	begin	
		if reset ='1' then
			fstate		<= idle;
		else
			fstate		<= nxt_fstate;
		end if;
		wait until clk ='1';
	end process;
	
-- serial data feeder state machine (combinatorial section)
--------------------------------------------------------
	rx_feeder_comb: process (fstate, launch_fip_transmit, fss_complete,
							 msg_complete, fcs_ready, fcs_complete, fes_complete)
	begin
		case fstate is
		when idle =>
			dx_en					<= '0';
			en_crc_end				<= '0';
			fes_start				<= '0';
			fss_start				<= '0';
			msg_seq_start			<= '0';
			mux_select				<= "00";
			
			if launch_fip_transmit ='1' then
				nxt_fstate			<= start_seq;
			else
				nxt_fstate			<= idle;
			end if;
		
		when start_seq =>
			dx_en					<= '0';
			en_crc_end				<= '0';
			fes_start				<= '0';
			fss_start				<= '0';
			msg_seq_start			<= '1';
			mux_select				<= "00";
			
			nxt_fstate				<= start_frame;
		
		when start_frame =>
			dx_en					<= '1';
			en_crc_end				<= '0';
			fes_start				<= '0';
			fss_start				<= '1';
			msg_seq_start			<= '0';
			mux_select				<= "00";
			
			nxt_fstate				<= start_frame_bk;
		
		when start_frame_bk =>
			dx_en					<= '1';
			en_crc_end				<= '0';
			fes_start				<= '0';
			fss_start				<= '0';
			msg_seq_start			<= '0';
			mux_select				<= "00";
			
			if fss_complete ='1' then
				nxt_fstate			<= waiting;
			else
				nxt_fstate			<= start_frame_bk;
			end if;
		
		when waiting =>
			dx_en					<= '1';
			en_crc_end				<= '0';
			fes_start				<= '0';
			fss_start				<= '0';
			msg_seq_start			<= '0';
			mux_select				<= "01";
			
			if msg_complete ='1' then
				nxt_fstate			<= end_msg;
			else
				nxt_fstate			<= waiting;
			end if;
		
		when end_msg =>
			dx_en					<= '1';
			en_crc_end				<= '1';
			fes_start				<= '0';
			fss_start				<= '0';
			msg_seq_start			<= '0';
			mux_select				<= "01";
			
			if  fcs_ready ='1' then
				nxt_fstate			<= issue_fcs;
			else
				nxt_fstate			<= end_msg;
			end if;
		
		when issue_fcs =>
			dx_en					<= '1';
			en_crc_end				<= '0';
			fes_start				<= '0';
			fss_start				<= '0';
			msg_seq_start			<= '0';
			mux_select				<= "10";
			
			if  fcs_complete ='1' then
				nxt_fstate			<= end_frame;
			else
				nxt_fstate			<= issue_fcs;
			end if;

		when end_frame =>
			dx_en					<= '1';
			en_crc_end				<= '0';
			fes_start				<= '1';
			fss_start				<= '0';
			msg_seq_start			<= '0';
			mux_select				<= "11";
			
			nxt_fstate				<= end_frame_bk;
			
		when end_frame_bk =>
			dx_en					<= '1';
			en_crc_end				<= '0';
			fes_start				<= '0';
			fss_start				<= '0';
			msg_seq_start			<= '0';
			mux_select				<= "11";
			
			if  fes_complete ='1' then
				nxt_fstate			<= idle;
			else
				nxt_fstate			<= end_frame_bk;
			end if;

		when others =>
			dx_en					<= '0';
			en_crc_end				<= '0';
			fes_start				<= '0';
			fss_start				<= '0';
			msg_seq_start			<= '0';
			mux_select				<= "00";
			
			nxt_fstate				<= idle;
		end case;
	end process;

-- shift registers to delay and adjust synchronisation signals between blocks
-----------------------------------------------------------------------------
	delayer: process
	begin
		fss_dly(14 downto 0)		<= fss_dly(15 downto 1);

		msg_start_dly(15 downto 0)	<= msg_start_dly(16 downto 1);

		fes_dly(6 downto 0)			<= fes_dly(7 downto 1);

		wait until clk ='1';
	end process;

	msg_start_dly(16)		<= msg_seq_start;
	msg_start				<= msg_start_dly(crc_l);
		
	crc_start				<= msg_start_dly(crc_l-1);

	fss_dly(15)				<= fss_start;
	fss_complete			<= fss_dly(0);

	fes_dly(7)				<= fes_start;
	fes_complete			<= fes_dly(0);
	
	seq_start				<= msg_seq_start;
	
end archi;		

