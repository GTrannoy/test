-- Created by : G. Penacoba
-- Creation Date: Aug 2010
-- Description: Schedules the activity of the WorldFIP bus
-- Modified by:
-- Modification Date:
-- Modification consisted on:

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity bus_arbitrer is
	port(
		id_rp				: out std_logic;
		launch_fip_cycle	: out std_logic;
		station_adr			: out std_logic_vector(7 downto 0);
		var_adr				: out std_logic_vector(7 downto 0);
		var_length			: out std_logic_vector(6 downto 0)
	);
end bus_arbitrer;

architecture archi of bus_arbitrer is

begin

	scheduler: process
	begin
		id_rp					<= '0';
		launch_fip_cycle		<= '0';
		station_adr				<= x"00";
		var_adr					<= x"00";
		var_length				<= "0000000";
		wait for 199 us;
		id_rp					<= '1';
		launch_fip_cycle		<= '1' after 1 us;		-- ID_DAT for produced
		station_adr				<= x"5A";
		var_adr					<= x"06";
		var_length				<= "0000100";
		wait for 10 us;
		id_rp					<= '0';
		launch_fip_cycle		<= '0';
		station_adr				<= x"5A";
		var_adr					<= x"00";
		var_length				<= "0000000";
		wait for 1300 us;
		id_rp					<= '1';
		launch_fip_cycle		<= '1' after 1 us;		-- ID_DAT for consumed
		station_adr				<= x"5A";
		var_adr					<= x"05";
		var_length				<= "0000100";
		wait for 10 us;
		id_rp					<= '0';
		launch_fip_cycle		<= '0';
		station_adr				<= x"5A";
		var_adr					<= x"00";
		var_length				<= "0000000";
		wait for 100 us;
		id_rp					<= '0';
		launch_fip_cycle		<= '1' after 1 us;		-- RP_DAT from consumed
		station_adr				<= x"5A";
		var_adr					<= x"05";
		var_length				<= "0000010";
		wait for 10 us;
		id_rp					<= '0';
		launch_fip_cycle		<= '0';
		station_adr				<= x"00";
		var_adr					<= x"00";
		var_length				<= "0000000";
		wait for 400 us;
		id_rp					<= '1';
		launch_fip_cycle		<= '1' after 1 us;		-- ID_DAT for produced
		station_adr				<= x"5A";
		var_adr					<= x"06";
		var_length				<= "0000100";
		wait for 10 us;
		id_rp					<= '0';
		launch_fip_cycle		<= '0';
		station_adr				<= x"5A";
		var_adr					<= x"00";
		var_length				<= "0000000";
		wait for 20000 ms;
	end process;
	
end archi;
		
