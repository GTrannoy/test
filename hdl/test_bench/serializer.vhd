-- Created by : G. Penacoba
-- Creation Date: March 2010
-- Description: Converts into a serial output the input word of configurable width
-- Modified by: Penacoba
-- Modification Date: 29 june 2010
-- Modification consisted on: Reset input added. 'Finished' signal not dependent
--								on 'run' signal anymore

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use std.textio.all;
use work.tb_package.all;

entity serializer is
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
end serializer;

architecture archi of serializer is
signal byte						: std_logic_vector(width-1 downto 0);
signal finished					: std_logic;
signal report_config_trigger	: std_logic;
signal run						: std_logic;

subtype index is integer range width-1 downto 0;
signal i						: index;

subtype width_slice is integer range 0 to width;
signal nb_truncated_bits		: width_slice;
signal actual_width				: width_slice;

begin

	read_bits: process
	begin
		if reset ='1' then
			i			<= actual_width-1;
		elsif run = '1' then
			if i = 0 then
				i		<= actual_width-1;
			else
				i		<= i-1;
			end if;
		end if;

		if reset ='1' then
			finished	<= '0';
		elsif i = 1 then
			finished	<= '1';
		else
			finished	<= '0';
		end if;

		if reset ='1' then
			run		<= '0';
		elsif go ='1' then
			run		<= '1';
		elsif finished ='1' then
			run		<= '0';
		end if;

		if reset ='1' then
			byte	<= (others =>'0');
		elsif go ='1' then
			byte	<= data_in;
		end if;

		wait until clk ='1';
	end process;

	actual_width			<= width - nb_truncated_bits;
	data_out				<= byte(i);	
	done					<= finished;

-- process reading config values from a file
	---------------------------------------------
	read_config: process
	file config_file				: text open read_mode is "data/errors_config.txt";
	variable config_line			: line;
	variable validity_time			: time;
	
	variable truncated_bits_config	: width_slice;
	begin
		readline	(config_file, config_line);
		readline	(config_file, config_line);
		
		readline	(config_file, config_line);
		read		(config_line, truncated_bits_config);

		readline	(config_file, config_line);
		readline	(config_file, config_line);

		readline	(config_file, config_line);
		read		(config_line, validity_time);
		if endfile(config_file) then
			file_close(config_file);
		end if;
		nb_truncated_bits		<= truncated_bits_config;
		report_config_trigger	<= '1';
		wait for validity_time - 1 ps;
		report_config_trigger	<= '0';
		wait for 1 ps;
	end process;

	reporting: process(report_config_trigger)
	begin
		if report_config_trigger'event and report_config_trigger ='1' then
			if now > 0 ps then
				if nb_truncated_bits > 0 then
					report	"               A reception error from the FIELDRIVE is simulated " 
					& LF &  "               by truncating " & integer'image(nb_truncated_bits) & " bit(s) per byte " 
					& LF &  "               of the data in next frame(s) being sent" & LF
					severity warning;
				end if;		
			end if;
		end if;
	end process;

end archi;
