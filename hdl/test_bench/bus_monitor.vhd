-- Created by : G. Penacoba
-- Creation Date: Dec 2010
-- Description: Checks the timing requirements on the bus
-- Modified by:
-- Modification Date:
-- Modification consisted on:

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.tb_package.all;

entity bus_monitor is
	port(
		cd				: in std_logic;
		f_clk_period	: in time;
		id_rp			: in std_logic;
		sof				: in std_logic;
		txena			: in std_logic
	);
end bus_monitor;

architecture archi of bus_monitor is

constant min_turn_around_3125k	: time:= 460 us;
constant silence_time_3125k		: time:= 4160 us;
constant min_turn_around_1M		: time:= 10 us;
constant silence_time_1M		: time:= 150 us;
constant min_turn_around_25M	: time:= 5 us;
constant silence_time_25M		: time:= 100 us;

signal ba_responded				: boolean;
signal end_turn_around			: time:=0 fs;
signal min_turn_around			: time;
signal nanofip_responded		: boolean;
signal silence_time				: time;
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
	
	sof_detection: process(sof)
	begin
		if sof'event and sof ='1' then
			if txena ='1' then
				end_turn_around		<= now;
			end if;
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
		elsif sof ='1' and txena ='1' then
			nanofip_responded			<= TRUE;
		elsif now - start_turn_around > silence_time then
			silence_time_reached		<= TRUE;
		end if;	
		wait for f_clk_period;
	end process;
	
	reporting: process(ba_responded, nanofip_responded, silence_time_reached)
	begin
		if silence_time_reached and not(ba_responded or nanofip_responded) and start_turn_around > 0 fs then
			report	"               **** check NOT OK ****  The specified silence time of " & time'image(silence_time) 
														& " has been reached without any answer to the ID_DAT frame" & LF
			severity warning;
		elsif nanofip_responded and not(ba_responded or silence_time_reached) then
			report	"            (( check OK ))  nanoFIP responds after " & time'image(end_turn_around - start_turn_around) 
																	& ". This turn-around time is within specs" & LF;
		elsif nanofip_responded and ba_responded and not(silence_time_reached) then
			report	"               **** check NOT OK ****  The bus arbitrer and nanoFIP have both responded to the same ID_DAT" & LF
			severity warning;
		end if;
	end process;
			
	specs: process(f_clk_period)
	begin
		if f_clk_period = 32 us then
			min_turn_around		<= min_turn_around_3125k;
			silence_time		<= silence_time_3125k;
		elsif f_clk_period = 1 us then
			min_turn_around		<= min_turn_around_1M;
			silence_time		<= silence_time_1M;
		elsif f_clk_period = 400 ns then
			min_turn_around		<= min_turn_around_25M;
			silence_time		<= silence_time_25M;
		else
			min_turn_around		<= min_turn_around_1M;
			silence_time		<= silence_time_1M;
		end if;
	end process;

end archi;
	
--	reporting1: process(start_turn_around)
--	begin
--		report  "At " & time'image(start_turn_around) & " CD signal falls to 0 : start couting turn-around";
--	end process;
--	
--	reporting2: process(end_turn_around)
--	begin
--		report  "At " & time'image(end_turn_around) & " finish couting. Turn-around = " & time'image(end_turn_around-start_turn_around);
--	end process;
--
--	txena_detection: process(txena)
--	begin
--		if txena'event and txena ='1' then
--			if txena ='1' then
--				txena_asserted		<= now;
--			end if;
--		end if;
--	end process;
	
--	reporting: process(turn_around)
--	begin
--		if start_turn_around < txena_asserted and txena_asserted < end_turn_around then
--			if min_turn_around < turn_around and turn_around < silence_time then
--				report	"             (( check OK ))  After " & time'image(txena_asserted - start_turn_around)
--				& 					" nanoFIP has asserted the TX_ENA signal marking the start of the transmission"
--				& LF &	"                               The effective turn around time is " & time'image(turn_around) &" which is within specs" & LF;
--			else
--				report	"               **** check NOT OK ****  After " & time'image(txena_asserted - start_turn_around)
--				& 					" nanoFIP has asserted the TX_ENA signal marking the start of the transmission"
--				& LF &	"                                       The effective turn around time is " & time'image(turn_around) & " which is out of specs" & LF
--				severity warning;
--			end if;
--		else
--			report	"               **** check NOT OK ****  The signal TX_ENA is not being asserted correctly by nanoFIP" & LF
--			severity warning;
--		end if;
--			
--	end process;
--	
--	turn_around		<= end_turn_around - start_turn_around;
--						when end_turn_around > start_turn_around;
