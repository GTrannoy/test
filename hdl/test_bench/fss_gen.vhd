-- Created by : G. Penacoba
-- Creation Date: May 2010
-- Description: Generates the Frame Start Sequence 
--				(Preamble + Frame Start Delimiter)
-- Modified by: G. Penacoba
-- Modification Date: January 2011
-- Modification consisted on: The value used for the FSS comes from the config file

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.tb_package.all;

entity fss_gen is
	generic(
		width					: integer:=16
	);
	port(
		clk						: in std_logic;
		fss_value				: in std_logic_vector(15 downto 0);
		start_delimiter			: in std_logic;
		reset					: in std_logic;
		
		fss						: out std_logic;
		v_minus					: out std_logic;
		v_plus					: out std_logic
	);
end fss_gen;
		
architecture archi of fss_gen is

signal s_fss_value		: std_logic_vector(width downto 0);
--														 :="101010101XX10XX0U";

signal aux						: std_logic;
signal i						: integer range width downto 0;
signal sending_fss				: std_logic;

begin

	aux					<= '0' when start_delimiter ='0' else
							'1' when i = width;

	sending_fss			<= '1' when start_delimiter ='1' and aux ='0' else
							'0' when i = 0;
							
	s_fss_value			<= fss_value & "U";

	decount: process
	begin
		if reset ='1' then
			i		<= 0;
		elsif sending_fss ='1' then
			if i = 0 then
				i		<= width;
			else
				i		<= i-1;
			end if;
		end if;
		wait until clk ='1';
	end process;

	fss			<= s_fss_value(i);
	
	violation: process(i)
	begin
		case i is
		when 7 =>
			v_minus		<= '0';
			v_plus		<= '1';

		when 6 =>
			v_minus		<= '1';
			v_plus		<= '0';
		
		when 3 =>
			v_minus		<= '1';
			v_plus		<= '0';

		when 2 =>
			v_minus		<= '0';
			v_plus		<= '1';

		when others =>
			v_minus		<= '0';
			v_plus		<= '0';
		end case;
	end process;

end archi;		
