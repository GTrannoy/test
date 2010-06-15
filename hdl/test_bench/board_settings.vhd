-- Created by : G. Penacoba
-- Creation Date: MAy 2010
-- Description: Module emulating all the user logic activity
-- Modified by:
-- Modification Date:
-- Modification consisted on:

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity board_settings is
	port(
		s_id_i			: in std_logic_vector(1 downto 0);
		
		c_id_o			: out std_logic_vector(3 downto 0);
		m_id_o			: out std_logic_vector(3 downto 0);
		nostat_o		: out std_logic;
		p3_lgth_o		: out std_logic_vector(2 downto 0);
		rate_o			: out std_logic_vector(1 downto 0);
		slone_o			: out std_logic;
		subs_o			: out std_logic_vector(7 downto 0)
	);
end board_settings;

architecture archi of board_settings is

begin

	c_id_o(0)			<= '0';
	c_id_o(1)			<= '0';
	c_id_o(2)			<= '0';
	c_id_o(3)			<= '0';

	m_id_o(0)			<= '0';
	m_id_o(1)			<= '0';
	m_id_o(2)			<= '0';
	m_id_o(3)			<= '0';
	
	nostat_o			<= '1';
	
	p3_lgth_o			<= "000";
	
	rate_o				<= "01";
	
	slone_o				<= '0';
	
	subs_o				<= "00000001";
	
end archi;
