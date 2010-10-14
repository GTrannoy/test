-- Created by : G. Penacoba
-- Creation Date: February 2010
-- Description: Module to perform wishbone cycles (read/write in single or block transfer)
-- Modified by: G. Penacoba
-- Modification Date: October 2010
-- Modification consisted on: Memory counters on read adapted to include Length and PDU type bytes.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.std_logic_textio.all;
use std.textio.all;

entity wishbone_interface is
	port(
		block_size			: in std_logic_vector(6 downto 0);
		launch_wb_read		: in std_logic;
		launch_wb_write 	: in std_logic;
		transfer_length		: in std_logic_vector(6 downto 0);
		transfer_offset		: in std_logic_vector(6 downto 0);
		var_id			 	: in std_logic_vector(1 downto 0);
		
		valid_wb_cycle		: out std_logic;

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
end wishbone_interface;
	
architecture archi of wishbone_interface is

component encounter
	generic(
		width				: integer:=16
	);
	port(
		clk					: in std_logic;
		en					: in std_logic;
		reset				: in std_logic;
		start_value			: in std_logic_vector(width-1 downto 0);
	
		count				: out std_logic_vector(width-1 downto 0);
		count_done			: out std_logic
	);
end component;

constant zero					: std_logic_vector(6 downto 0):=(others =>'0');

type wb_st_type						is (idle, single, burst, rest);
signal wb_state, nxt_wb_state		: wb_st_type:=idle;

signal add_count				: std_logic_vector(9 downto 0);
signal burst_done				: std_logic;
signal burst_size				: std_logic_vector(6 downto 0):=(others=>'0');
signal cyc						: std_logic;
signal data_for_mem				: std_logic_vector(7 downto 0);
signal mem_count				: std_logic_vector(6 downto 0);
signal mem_done					: std_logic;
signal mem_length				: std_logic_vector(6 downto 0):=(others=>'0');
signal mem_offset				: std_logic_vector(6 downto 0):=(others=>'0');
signal reset_burst				: std_logic;
signal reset_mem				: std_logic;
signal stb						: std_logic;
signal valid_bus_cycle			: std_logic;
signal var_adr					: std_logic_vector(1 downto 0):=(others=>'0');
signal we						: std_logic:='0';

begin

-- wishbone interface state machine (sequential section)
-----------------------------------------------------------------------------
	wb_fsm_seq: process
	begin
		if rst_i = '1' then
			wb_state <= idle;
		else
			wb_state <= nxt_wb_state;
		end if;
		wait until clk_i ='1';
	end process;

-- wishbone interface state machine (combinatorial section)
-----------------------------------------------------------------------------------
	wb_fsm_comb: process (wb_state, launch_wb_read, launch_wb_write, 
							burst_size, ack_i, burst_done, mem_done)
	begin
		case wb_state is
		when idle =>
			cyc				<= '0';
			reset_burst		<= '1';
			reset_mem		<= '1';
			stb				<= '0';
			
			if (launch_wb_read /='0' or launch_wb_write /='0') then
				if burst_size > zero then
					nxt_wb_state	<= burst;
				else
					nxt_wb_state	<= single;
				end if;
			else
				nxt_wb_state	<= idle;
			end if;

		when single =>
			cyc				<= '1';
			reset_burst		<= '1';
			reset_mem		<= '0';
			stb				<= '1';

			if ack_i ='0' then
					nxt_wb_state		<= single;
			elsif mem_done ='1' then
					nxt_wb_state		<= idle;
			else
					nxt_wb_state		<= rest;
			end if;

		when burst =>
			cyc				<= '1';
			reset_burst		<= '0';
			reset_mem		<= '0';
			stb				<= '1';

			if ack_i ='0' then
					nxt_wb_state		<= burst;
			elsif mem_done ='1' then
					nxt_wb_state		<= idle;
			elsif burst_done ='1' then
					nxt_wb_state		<= rest;
			else
					nxt_wb_state		<= burst;
			end if;

		when rest =>
			cyc				<= '1';
			reset_burst		<= '1';
			reset_mem		<= '0';
			stb				<= '0';

			if burst_size > zero then
					nxt_wb_state		<= burst;
			else
					nxt_wb_state		<= single;
			end if; 

		when others =>
			cyc				<= '0';
			reset_burst		<= '1';
			reset_mem		<= '1';
			stb				<= '0';

			nxt_wb_state		<= idle;
		end case;
	end process;

-- latches for identifying the type of the memory access cycle
--------------------------------------------------------------
	latch_inference: process (launch_wb_read, launch_wb_write)
	begin
		if launch_wb_read ='1' then
			if block_size = zero then
				burst_size	<= zero;
			else
				burst_size	<= block_size - ("000" & x"1");
			end if;
			if transfer_offset = zero then
				mem_length		<= transfer_length + ("000" & x"1");
				mem_offset		<= (others=>'0');
			else
				mem_length		<= transfer_length - ("000" & x"1");
				mem_offset		<= transfer_offset + ("000" & x"2");
			end if;
			var_adr			<= var_id -"01";
			we				<= '0';
		elsif launch_wb_write ='1' then
			if block_size = zero then
				burst_size	<= zero;
			else
				burst_size	<= block_size - ("000" & x"1");
			end if;
			mem_length		<= transfer_length - ("000" & x"1");
			mem_offset		<= transfer_offset + ("000" & x"2");
			var_adr			<= var_id -"01";
			we				<= '1';
		end if;
	end process;

	add_count			<= "0" & var_adr & (mem_count + mem_offset);
	valid_bus_cycle		<= stb and cyc and ack_i;

-- output signals
-----------------------
	valid_wb_cycle		<= valid_bus_cycle;
	adr_o				<= add_count;
	cyc_o				<= cyc;
	dat_o				<= data_for_mem;
	stb_o				<= stb;
	we_o				<= we;

-- process reading bytes from random data file
---------------------------------------------
	read_store: process
	file data_file: text open read_mode is "data/data_store.txt";
	variable data_line: line;
	variable data_byte: std_logic_vector(7 downto 0);
	begin
		readline (data_file, data_line);
		read (data_line, data_byte);
		data_for_mem		<= data_byte;
		wait until clk_i ='1';
	end process;

	burst_counter: encounter
	generic map(
		width				=> 7
		)
	port map(
		clk					=> clk_i,
		en					=> valid_bus_cycle,
		reset				=> reset_burst,
		start_value			=> burst_size,

		count				=> open,
		count_done			=> burst_done
	);

	mem_counter: encounter
	generic map(
		width				=> 7
		)
	port map(
		clk					=> clk_i,
		en					=> valid_bus_cycle,
		reset				=> reset_mem,
		start_value			=> mem_length,

		count				=> mem_count,
		count_done			=> mem_done
	);

end archi;
