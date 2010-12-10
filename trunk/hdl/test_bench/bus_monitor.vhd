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

signal end_turn_around			: time:=0 fs;
signal min_turn_around			: time;
signal silence_time				: time;
signal start_turn_around		: time:=0 fs;
signal turn_around				: time;
signal txena_asserted			: time;

begin

	end_of_id_dat: process(cd)
	begin
		if cd'event and cd ='0' then
			if id_rp ='1' then
				start_turn_around	<= now;
--				report time'image(start_turn_around);
			end if;
		end if;
	end process;
	
	sof_detection: process(sof)
	begin
		if sof'event and sof ='1' then
			if txena ='1' then
				end_turn_around		<= now;
--				report time'image(end_turn_around);
			end if;
		end if;
	end process;

	txena_detection: process(txena)
	begin
		if txena'event and txena ='1' then
			if txena ='1' then
				txena_asserted		<= now;
			end if;
		end if;
	end process;
	
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
						
	process(f_clk_period)
	begin
		if f_clk_period = 32 us then
			min_turn_around		<= 640 us;
			silence_time		<= 4160 us;
		elsif f_clk_period = 1 us then
			min_turn_around		<= 10 us;
			silence_time		<= 150 us;
		elsif f_clk_period = 400 ns then
			min_turn_around		<= 16 us;
			silence_time		<= 100 us;
		else
			min_turn_around		<= 10 us;
			silence_time		<= 150 us;
		end if;
	end process;
	
end archi;
