-- Created by : G. Penacoba
-- Creation Date: Oct 2010
-- Description: Set the wdog and txerr signals according to the configuration
--				and schedule retrieved from text files.
-- Modified by:
-- Modification Date:
-- Modification consisted on:

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use std.textio.all;
use work.tb_package.all;

entity transmission_meddler is
	port(
		cfig_clk_period			: out time;
		txerr					: out std_logic;
		wdgn					: out std_logic
	);
end transmission_meddler;

architecture archi of transmission_meddler is

signal bit_rate					: integer;
signal read_config_trigger		: std_logic;

begin
	-- process reading config values from a file
	---------------------------------------------
	read_config: process
	file config_file			: text open read_mode is "data/WFIP_communication_config.txt";
	variable config_line		: line;
	variable validity_time		: time;

	variable bit_rate_config	: integer;
	begin
		readline	(config_file, config_line);
		read		(config_line, bit_rate_config);
		readline	(config_file, config_line);
		readline	(config_file, config_line);
		readline	(config_file, config_line);
		readline	(config_file, config_line);
		readline	(config_file, config_line);

		readline	(config_file, config_line);
		read		(config_line, validity_time);
		if endfile(config_file) then
			file_close(config_file);
		end if;
		
		bit_rate				<= bit_rate_config;
		read_config_trigger		<= '1';
		wait for validity_time - 1 ps;
		read_config_trigger		<= '0';
		wait for 1 ps;
	end process;

	with bit_rate select
						cfig_clk_period	<=	32 us	when 0,
											1 us	when 1,
											400 ns	when 2,
											1 us	when others;


	txerr					<= '0';
	wdgn					<= '1';


end archi;

