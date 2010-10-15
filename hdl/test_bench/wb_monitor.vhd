-- Created by : G. Penacoba
-- Creation Date: October 2010
-- Description: Block performing the validity check of the exchanged data from the user side.
--				Monitors only the contents of the memory through the wishbone interface signals.
-- Modified by:
-- Modification Date:
-- Modification consisted on:

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use std.textio.all;
use work.tb_package.all;

entity wb_monitor is
	port(
		ack_i					: in std_logic;
		clk_o					: in std_logic;
		dat_i					: in std_logic_vector(7 downto 0);
		rst_o					: in std_logic;

		adr_o					: in std_logic_vector(9 downto 0);
		cyc_o					: in std_logic;
		dat_o					: in std_logic_vector(7 downto 0);
		stb_o					: in std_logic;
		we_o					: in std_logic
	);
end wb_monitor;

architecture archi of wb_monitor is

signal writing_produced					: boolean;
signal valid_bus_cycle					: boolean;

signal adr								: byte_count_type;
signal var_id							: integer:=0;

signal in_consumed						: vector_type;
signal in_broadcast						: vector_type;
signal out_produced						: vector_type;

begin

	-- process reading from a text file the data sent by FIP for consumption
	------------------------------------------------------------------------
	read_incoming: process(cyc_o, var_id)
	file data_file			: text;
	variable data_line		: line;
	variable data_byte		: std_logic_vector(7 downto 0);
	variable data_vector	: vector_type;
	variable i				: integer:=0;
	
	begin
		if cyc_o ='1' then
			if var_id = 1 then
				data_vector		:= (others => x"00");
				file_open(data_file,"data/tmp_var1_mem.txt",read_mode);
				while not(endfile(data_file)) loop
					readline			(data_file, data_line);
					read				(data_line, data_byte);
					data_vector(i)		:= data_byte;
					i					:= i+1;
				end loop;
				file_close(data_file);
				i				:= 0;
				in_consumed		<= data_vector;

			elsif var_id = 2 then
				data_vector		:= (others => x"00");
				file_open(data_file,"data/tmp_var2_mem.txt",read_mode);
				while not(endfile(data_file)) loop
					readline			(data_file, data_line);
					read				(data_line, data_byte);
					data_vector(i)		:= data_byte;
					i					:= i+1;
				end loop;
				file_close(data_file);
				i				:= 0;
				in_broadcast	<= data_vector;
			end if;
		end if;
	end process;

	-- process checking the validity of the incoming consumed data as they are retrieved from nanoFIP memory
	--------------------------------------------------------------------------------------------------------
	check_consumed_and_broadcast: process
	begin
		if valid_bus_cycle then
			if var_id = 1 then
				assert in_consumed(adr) = dat_i
				report "               Value retrieved from memory in address " & integer'image(adr) & 
				" of the consumed variable does not match the one sent from FIP" & LF
				severity warning;
			elsif var_id = 2 then
				assert in_broadcast(adr) = dat_i
				report "               Value retrieved from memory in address " & integer'image(adr) & 
				" of the broadcast variable does not match the one sent from FIP" & LF
				severity warning;
			end if;
		end if;
		wait until clk_o ='1';
	end process;
			
	-- process building an image of the nanoFIP memory for the produced variable
	----------------------------------------------------------------------------
	produced_memory:process
	begin
		if writing_produced and valid_bus_cycle then
			out_produced(adr)			<= dat_o;
		end if;
		wait until clk_o ='1';
	end process;
	
	-- process transcribing to a text file the image of the nanoFIP memory for the produced variable
	------------------------------------------------------------------------------------------------
	write_outgoing: process(writing_produced)
	file data_file			: text;
	variable data_line		: line;

	begin
		if writing_produced'event and writing_produced = FALSE then
			file_open(data_file,"data/tmp_var3_mem.txt",write_mode);
			for i in 0 to max_frame_length-1 loop
				write		(data_line, out_produced(i));
				writeline	(data_file, data_line);
			end loop;
			file_close(data_file);
		end if;
	end process;
				
	var_id						<= to_integer(unsigned(adr_o(8 downto 7)))+1;
	adr							<= to_integer(unsigned(adr_o(6 downto 0)));
	
	valid_bus_cycle				<= cyc_o ='1' and stb_o ='1' and ack_i ='1';
	writing_produced			<= cyc_o ='1' and var_id = 3 and we_o ='1';

end archi;
