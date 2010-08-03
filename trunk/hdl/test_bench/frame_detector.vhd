-- Created by : G. Penacoba
-- Creation Date: July 2010
-- Description: Detects the Start-of-frame and End-of-frame delimiters
--				from the transmitted bit stream.
-- Modified by:
-- Modification Date:
-- Modification consisted on:

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity frame_detector is
	port(
		bits				: in std_logic;
		clk					: in std_logic;
		reset				: in std_logic;
		violation			: in std_logic;

		eof					: out std_logic;
		sof					: out std_logic;
		vx					: out std_logic
	);
end frame_detector;
	
architecture archi of frame_detector is

constant fsd			: std_logic_vector(7 downto 0):=x"D2";
constant fsd_viol		: std_logic_vector(7 downto 0):=x"66";
constant fed			: std_logic_vector(7 downto 0):=x"D5";
constant fed_viol		: std_logic_vector(7 downto 0):=x"78";

signal passing_byte		: unsigned(7 downto 0):=(others=>'0');
signal sof_detected		: std_logic;
signal eof_detected		: std_logic;
signal sof_delayer		: unsigned(7 downto 0);
signal viol_snapshot		: unsigned(7 downto 0);

begin
	
	shifting: process
	begin
		if reset ='1' then
			passing_byte		<= (others=>'0');
			vx					<= '0';
			
			viol_snapshot		<= (others=>'0');
			
			sof					<= '0';
			sof_delayer			<= (others=>'0');
		else
			vx					<= passing_byte(7);
			passing_byte		<= shift_left(passing_byte,1);
			passing_byte(0)		<= bits;
			
			viol_snapshot		<= shift_left(viol_snapshot,1);
			viol_snapshot(0)	<= violation;
			
			sof					<= sof_delayer(7);
			sof_delayer			<= shift_left(sof_delayer,1);
			sof_delayer(0)		<= sof_detected;
		end if;
		wait until clk='1';
	end process;
	
	sof_detected		<= '1' when (std_logic_vector(passing_byte) = fsd 
							and std_logic_vector(viol_snapshot) = fsd_viol)
							else '0';
	eof_detected		<= '1' when (std_logic_vector(passing_byte) = fed 
							and std_logic_vector(viol_snapshot) = fed_viol)
							else '0';
	eof					<= eof_detected;
	

end archi;
	
