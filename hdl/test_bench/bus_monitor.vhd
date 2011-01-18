-- Created by : G. Penacoba
-- Creation Date: Dec 2010
-- Description: Checks the timing requirements on the bus
-- Modified by: G. Penacoba
-- Modification Date: January 2011
-- Modification consisted on: Minimum turn around times and silence times now come from config file.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.tb_package.all;

entity bus_monitor is
	port(
		cd						: in std_logic;
		f_clk_period			: in time;
		id_rp					: in std_logic;
		min_turn_around			: in time;
		silence_time			: in time;
		txena					: in std_logic
	);
end bus_monitor;

architecture archi of bus_monitor is

signal ba_responded				: boolean;
signal end_turn_around			: time:=0 fs;
signal nanofip_responded		: boolean;
signal silence_time_reached		: boolean;
signal start_turn_around		: time:=0 fs;

begin

	end_of_id_dat: process(cd)
	begin
		if cd'event and cd ='0' then
			if id_rp ='1' then
				start_turn_around	<= now;
			end if;
		end if;
	end process;
	
	begining_of_rp_dat_detection: process(txena)
	begin
		if txena'event and txena ='1' then
			end_turn_around		<= now;
		end if;
	end process;

	surveillance: process
	begin
		wait for 0 fs;
		if cd ='1' and id_rp ='1' then
			ba_responded				<= FALSE;
			nanofip_responded			<= FALSE;
			silence_time_reached		<= FALSE;
		elsif cd = '1' then
			ba_responded				<= TRUE;
		elsif txena ='1' then
			nanofip_responded			<= TRUE;
		elsif now - start_turn_around > silence_time then
			silence_time_reached		<= TRUE;
		end if;	
		wait for f_clk_period;
	end process;
	
	reporting: process(ba_responded, nanofip_responded, silence_time_reached)
	begin
		if silence_time_reached and not(ba_responded or nanofip_responded) and start_turn_around > 0 fs then
			report	"               //// check NOT OK \\\\  The specified silence time of " & time'image(silence_time) 
														& " has been reached without any answer to the ID_DAT frame" & LF
			severity warning;
		elsif nanofip_responded and not(ba_responded or silence_time_reached) then
			report	"            __ check OK __  NanoFIP responds after " & time'image(end_turn_around - start_turn_around) 
																	& ". This turn-around time is within specs" & LF;
		elsif nanofip_responded and ba_responded and not(silence_time_reached) then
			report	"               //// check NOT OK \\\\  The bus arbitrer and nanoFIP have both responded to the same ID_DAT" & LF
			severity warning;
		end if;
	end process;
			
end archi;
