-- Created by : G. Penacoba
-- Creation Date: July 2010
-- Description: Partitions the frame transmitted by nanoFIP
--				into the different components of its structure.
-- Modified by:
-- Modification Date:
-- Modification consisted on:

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use std.textio.all;
use work.tb_package.all;

entity frame_chopper is
	port(
		clk						: in std_logic;
		eof						: in std_logic;
		reset					: in std_logic;
		sof						: in std_logic;
		vx						: in std_logic;
		
		bytes_total				: out byte_count_type;
		control_byte			: out std_logic_vector(7 downto 0);
		frame_data				: out vector_type;
		frame_received			: out std_logic
	);
end frame_chopper;

architecture archi of frame_chopper is

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

signal frame				: vector_type:=(others=> x"00");

signal aux_latch			: std_logic;
signal byte_nb				: byte_count_type:=0;
signal chop_byte			: std_logic;
signal count_done			: std_logic;
signal current_byte			: unsigned(7 downto 0):=x"00";
signal enable_chopping		: std_logic;
signal reset_counter		: std_logic;

begin

	-- process generating the signal for the latching of incomming bytes
	--------------------------------------------------------------------
	byte_chopping: process
	begin
		if enable_chopping ='1' then
			chop_byte			<= count_done;
		else
			chop_byte			<= '0';
		end if;
		wait until clk ='1';
	end process;
	
	-- process tracking the incomming byte number
	---------------------------------------------
	data_byte_counter: process
	begin
		if reset ='1' or enable_chopping ='0' then
			byte_nb				<= 0;
		elsif chop_byte ='1' then
			byte_nb				<= byte_nb + 1;

			assert byte_nb 		< max_frame_length -1
			report "               **** check NOT OK **** "
			& " The frame received from NanoFIP exceeds the maximum specified length"
			severity warning;
		end if;
		wait until clk ='1';
	end process;
	
	-- process latching the number of the last incomming byte as the total
	----------------------------------------------------------------------
	total_number: process
	begin
		if reset ='1' then
			bytes_total			<= 0;
		elsif eof ='1' then
			bytes_total			<= byte_nb;
		end if;
		wait until clk ='1';
	end process;
	
	-- 8-bit shift register for paralelisation of incomming data
	------------------------------------------------------------
	data_feeding: process
	begin
		current_byte			<= shift_left(current_byte,1);
		current_byte(0)			<= vx;
		wait until clk ='1';
	end process;
	
	-- process latching incomming bytes into an array of bytes
	----------------------------------------------------------
	data_recovery: process
	begin
		if reset ='1' or sof ='1' then
			frame				<= (others=> x"00");
		elsif chop_byte ='1' then
			if byte_nb = 0 then
				control_byte			<= std_logic_vector(current_byte);
			else
				frame(byte_nb-1)		<= std_logic_vector(current_byte);
			end if;
		end if;
		wait until clk ='1';
	end process;

	-- process indicating the completion of the reception of a new valid frame
	--------------------------------------------------------------------------
	frame_received_signal: process
	begin
		if reset ='1' then
			frame_received		<= '0';
		elsif chop_byte ='1' and enable_chopping ='0' then
			frame_received		<= '1';
		else
			frame_received		<= '0';
		end if;
		wait until clk ='1';
	end process;

	chopping_counter: encounter		-- counts 8 bits to separate the incomming bytes
	generic map(
		width			=> 4
	)
	port map(
		clk				=> clk,
		en				=> enable_chopping,
		reset			=> reset_counter,
		start_value		=> x"6",	-- (6 downto 0 + counter reset = 8 bits)
		
		count			=> open,
		count_done		=> count_done
	);

	frame_data			<= frame;
	
	reset_counter			<= reset or sof or chop_byte;

	aux_latch				<= '0' when reset ='1'
							else '1' when sof ='1'
							else '0' when eof ='1';
							
	enable_chopping			<= '0' when reset ='1'
							else '1' when sof ='1'
							else '0' when (eof ='0' and aux_latch ='0');
	
end archi;
