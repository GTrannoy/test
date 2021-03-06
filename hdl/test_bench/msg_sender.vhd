-- Created by : G. Penacoba
-- Creation Date: May 2010
-- Description: Reads the msg bytes from a text file for transmission
--				to NanoFIP.
-- Modified by: Penacoba
-- Modification Date: September 2010
-- Modification consisted on: Addition of PDU_type byte and Length_byte 
--								on consumed variable frame.
-- Modified by: Penacoba
-- Modification Date: December 2010
-- Modification consisted on: Addition of states in FSM for reset

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use std.textio.all;
use work.tb_package.all;

entity msg_sender is
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
end msg_sender;

architecture archi of msg_sender is

	component encounter is
	generic(
		width		: integer:=16
	);
	port(
		clk			: in std_logic;
		en			: in std_logic;
		reset		: in std_logic;
		start_value	: in std_logic_vector(width-1 downto 0);
	
		count		: out std_logic_vector(width-1 downto 0);
		count_done	: out std_logic
	);
	end component;

type mstate_ty				is (idle, ctrl_id, id_high, id_low, 
								ctrl_rp, pdu_type, length, data, 
								pdu_type_res, length_res, data_res,
								last_byte, mps);
signal mstate, nxt_mstate	: mstate_ty;

constant length_byte_res	: std_logic_vector(7 downto 0):=x"03";

signal control				: std_logic_vector(7 downto 0);
signal count				: std_logic_vector(6 downto 0);
signal count_done			: std_logic;
signal en_count				: std_logic;
signal file_data			: std_logic_vector(7 downto 0);
signal in_broadcast			: vector_type;
signal in_consumed			: vector_type;
signal ind					: byte_count_type;
signal length_byte			: std_logic_vector(7 downto 0);
signal m_data				: std_logic_vector(7 downto 0);
signal nxt_data				: std_logic;
signal res_first			: std_logic_vector(7 downto 0);
signal res_second			: std_logic_vector(7 downto 0);
signal reset_count			: std_logic;
signal running				: std_logic;
signal start_value			: std_logic_vector(6 downto 0);
signal un_length			: unsigned(6 downto 0);
signal var_id				: std_logic_vector(7 downto 0);
signal xy					: std_logic_vector(7 downto 0);


begin

-- process reading bytes from random data file
---------------------------------------------
	read_store: process
	file data_file: text open read_mode is "data/data_store.txt";
	variable data_line: line;
	variable data_byte: std_logic_vector(7 downto 0);
	begin
		readline (data_file, data_line);
		hread (data_line, data_byte);
		file_data	<= data_byte;
		wait until clk ='1';
	end process;

-- state machine for the generation of the message bytes (sequential section)
-----------------------------------------------------------------------------
	msg_send_seq: process
	begin
		if reset ='1' then
			mstate			<= idle;
		else
			mstate			<= nxt_mstate;
		end if;
		wait until clk ='1';
	end process;

-- state machine for the generation of the message bytes (combinatorial section)
-----------------------------------------------------------------------------
	msg_send_comb: process(mstate, msg_start, msg_new_data_req, count_done,
							control, var_id, xy, file_data)
	begin
		case mstate is
		when idle =>
			en_count			<= '0';
			msg_complete		<= '0';
			m_data				<= control;
			reset_count			<= '1';
			running				<= '0';
			
			if msg_start ='1' then
				if control = id_control_byte then
					nxt_mstate		<= ctrl_id;
				else
					nxt_mstate		<= ctrl_rp;
				end if;
			else
				nxt_mstate		<= idle;
			end if;
			
		when ctrl_id =>
			en_count			<= '0';
			msg_complete		<= '0';
			m_data				<= var_id;
			reset_count			<= '0';
			running				<= '1';
	
			if msg_new_data_req ='1' then
				nxt_mstate			<= id_high;
			else
				nxt_mstate			<= ctrl_id;
			end if;

		when id_high =>
			en_count			<= '0';
			msg_complete		<= '0';
			m_data				<= xy;
			reset_count			<= '0';
			running				<= '1';
	
			if msg_new_data_req ='1' then
				nxt_mstate			<= id_low;
			else
				nxt_mstate			<= id_high;
			end if;
			
		when id_low =>
			en_count			<= '0';
			msg_complete		<= '1';
			m_data				<= control;
			reset_count			<= '0';
			running				<= '0';
	
			if msg_new_data_req ='1' then
				nxt_mstate			<= idle;
			else
				nxt_mstate			<= id_low;
			end if;

		when ctrl_rp =>
			en_count			<= '0';
			msg_complete		<= '0';
			m_data				<= pdu_type_byte;
			reset_count			<= '0';
			running				<= '1';
	
			if msg_new_data_req ='1' then
				if var_id = var_adr_reset then
					nxt_mstate			<= pdu_type_res;
				else
					nxt_mstate			<= pdu_type;
				end if;
			else
				nxt_mstate			<= ctrl_rp;
			end if;

		when pdu_type_res =>
			en_count			<= '1';
			msg_complete		<= '0';
			m_data				<= length_byte_res;
			reset_count			<= '0';
			running				<= '1';
	
			if msg_new_data_req ='1' then
				nxt_mstate			<= length_res;
			else
				nxt_mstate			<= pdu_type_res;
			end if;

		when length_res =>
			en_count			<= '1';
			msg_complete		<= '0';
			m_data				<= res_first;
			reset_count			<= '0';
			running				<= '1';
	
			if msg_new_data_req ='1' then
				nxt_mstate			<= data_res;
			else
				nxt_mstate			<= length_res;
			end if;

		when data_res =>
			en_count			<= '1';
			msg_complete		<= '0';
			m_data				<= res_second;
			reset_count			<= '0';
			running				<= '1';
	
			if msg_new_data_req ='1' then
				nxt_mstate			<= last_byte;
			else
				nxt_mstate			<= data_res;
			end if;

		when pdu_type =>
			en_count			<= '1';
			msg_complete		<= '0';
			m_data				<= length_byte;
			reset_count			<= '0';
			running				<= '1';
	
			if msg_new_data_req ='1' then
				nxt_mstate			<= length;
			else
				nxt_mstate			<= pdu_type;
			end if;

		when length =>
			en_count			<= '1';
			msg_complete		<= '0';
			m_data				<= file_data;
			reset_count			<= '0';
			running				<= '1';
	
			if msg_new_data_req ='1' then
				nxt_mstate			<= data;
			else
				nxt_mstate			<= length;
			end if;

		when data =>
			en_count			<= '1';
			msg_complete		<= '0';
			m_data				<= file_data;
			reset_count			<= '0';
			running				<= '1';
	
			if count_done ='1' then
				nxt_mstate			<= last_byte;
			else
				nxt_mstate			<= data;
			end if;

		when last_byte =>
			en_count			<= '1';
			msg_complete		<= '0';
			m_data				<= mps_byte;
			reset_count			<= '0';
			running				<= '1';
	
			if msg_new_data_req ='1' then
				nxt_mstate			<= mps;
			else
				nxt_mstate			<= last_byte;
			end if;

		when mps =>
			en_count			<= '1';
			msg_complete		<= '1';
			m_data				<= control;
			reset_count			<= '0';
			running				<= '0';
	
			if msg_new_data_req ='1' then
				nxt_mstate			<= idle;
			else
				nxt_mstate			<= mps;
			end if;

		when others =>
			en_count			<= '0';
			msg_complete		<= '0';
			m_data				<= control;
			reset_count			<= '0';
			running				<= '0';
			
			nxt_mstate		<= idle;
		end case;
	end process;

-- process latching the input signals when the transmission is launched
-- for use during the whole transmission
-------------------------------------------------------------------------
	latching: process (reset, fip_frame_trigger, id_rp, var_length, 
						un_length, var_adr, station_adr)
	begin
		if reset ='1' then
			control			<= x"00";
			length_byte		<= x"00";
			res_first		<= x"00";
			res_second		<= x"00";
			start_value		<= "0000000";
			un_length		<= "0000000";
			var_id			<= x"00";
			xy				<= x"00";
		elsif fip_frame_trigger ='1' then
			if id_rp ='1' then
				control		<= id_control_byte;
			else
				control		<= rp_control_byte;
			end if;
			length_byte			<= "0" & std_logic_vector(un_length);
			res_first			<= std_logic_vector(unsigned(station_adr) + "1");
			res_second			<= std_logic_vector(unsigned(station_adr) + "10");
			start_value			<= std_logic_vector(un_length);
			un_length			<= unsigned(var_length) + "1";
			var_id				<= var_adr;
			xy					<= station_adr;
		end if;
	end process;
	
-- process building up the image of the memory 
-- corresponding to the consumed and broadcast variables
--------------------------------------------------------
	consumed_memory: process
	begin
		if control = rp_control_byte and nxt_data ='1' then
			if var_id = var_adr_consumed then
				in_consumed(ind)		<= m_data;
			elsif var_id = var_adr_broadcast then
				in_broadcast(ind)		<= m_data;
			end if;
		end if;
		wait until clk ='1';
	end process;
	
	index: process
	begin
		if running ='1' then
			if nxt_data ='1' then
				ind			<= ind + 1;
			end if;
		else
			ind				<= 0;
		end if;
		wait until clk ='1';
	end process;
	
-- process transcribing the image of the memory
-- into a file for checking by other modules
-----------------------------------------------
	write_incoming: process(running)
	file data_file			: text;
	variable data_line		: line;
	variable reset_time		: time;
	
	begin
		if running'event and running ='0' then
			if control = rp_control_byte then
				if var_id = var_adr_consumed then
					file_open(data_file,"data/tmp_var1_mem.txt",write_mode);
					for i in 0 to max_frame_length-1 loop
						write		(data_line, in_consumed(i));
						writeline	(data_file, data_line);
					end loop;
					file_close(data_file);
				elsif var_id = var_adr_broadcast then
					file_open(data_file,"data/tmp_var2_mem.txt",write_mode);
					for i in 0 to max_frame_length-1 loop
						write		(data_line, in_broadcast(i));
						writeline	(data_file, data_line);
					end loop;
					file_close(data_file);
				elsif var_id = var_adr_reset then
					reset_time	:= now;
					file_open(data_file,"data/tmp_vreset_hist.txt",write_mode);
					write		(data_line, reset_time);
					writeline	(data_file, data_line);
					hwrite		(data_line, res_first);
					writeline	(data_file, data_line);
					hwrite		(data_line, res_second);
					writeline	(data_file, data_line);
					file_close(data_file);
				end if;
			end if;
		end if;
	end process;
	
	msg_data		<= m_data;		
	msg_go			<= msg_start or nxt_data;
	nxt_data		<= msg_new_data_req when running ='1' else '0';

	length_counter: encounter
	generic map(
		width		=> 7
	)
	port map(
		clk			=> msg_new_data_req,
		en			=> en_count,
		reset		=> reset_count,
		start_value	=> start_value,
		
		count		=> count,
		count_done	=> count_done
	);

end archi;
	
