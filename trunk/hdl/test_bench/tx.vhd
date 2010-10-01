-- Created by : G. Penacoba
-- Creation Date: July 2010
-- Description: Receives data to from the nanoFIP to be transmitted to the fieldbus.
--				Emulates Fieldrive in transmission mode.
-- Modified by:
-- Modification Date:
-- Modification consisted on:

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tx is
	generic(
		crc_l					: integer:=16
	);
	port(
		clk						: in std_logic;
		gx						: in std_logic_vector(crc_l downto 0);
		reset					: in std_logic;
		txck					: in std_logic;
		txd						: in std_logic;
		txena					: in std_logic;
		
		txerr					: out std_logic;
		wdgn					: out std_logic
	);
end tx;

architecture archi of tx is

	component manchester_decoder
	port(
		input			: in std_logic;
		
		extracted_bits	: out std_logic;
		extracted_clk	: out std_logic;
		violation		: out std_logic
	);
	end component;

	component crc_check
	generic(
		crc_l			: integer:=16								-- polinomial length in bits
	);
	port(
		clk				: in std_logic;
		crc_check_start	: in std_logic;
		crc_check_end	: in std_logic;
		gx				: in std_logic_vector(crc_l downto 0);		-- polinomial divisor
		reset			: in std_logic;
		vx				: in std_logic;								-- received message
		
		fcs_check		: out std_logic;
		fcs_ok			: out std_logic
	);
	end component;

	component frame_detector is
	port(
		bits				: in std_logic;
		clk					: in std_logic;
		reset				: in std_logic;
		violation			: in std_logic;

		eof					: out std_logic;
		sof					: out std_logic;
		vx					: out std_logic
	);
	end component;

	component frame_chopper
	port(
		clk						: in std_logic;
		eof						: in std_logic;
		reset					: in std_logic;
		sof						: in std_logic;
		vx						: in std_logic;
		
		frame_struct_check		: out std_logic;
		frame_struct_ok			: out std_logic
	);
	end component;

	signal extracted_bits		: std_logic;
	signal extracted_clk		: std_logic;
	signal fcs_check			: std_logic;
	signal fcs_ok				: std_logic;
	signal frame_struct_check	: std_logic;
	signal frame_struct_ok		: std_logic;
	signal eof					: std_logic;
	signal sof					: std_logic;
	signal violation			: std_logic;
	signal vx					: std_logic;
	
begin

	decoder: manchester_decoder
	port map(
		input				=> txd,
		
		extracted_clk		=> extracted_clk,
		extracted_bits		=> extracted_bits,
		violation			=> violation
	);
	
	detector: frame_detector
	port map(
		bits				=> extracted_bits,
		clk					=> extracted_clk,
		reset				=> reset,
		violation			=> violation,
		
		eof					=> eof,
		sof					=> sof,
		vx					=> vx
	);
	
	chopper: frame_chopper
	port map(
		clk					=> extracted_clk,
		eof					=> eof,
		reset				=> reset,
		sof					=> sof,
		vx					=> vx,
		
		frame_struct_check	=> frame_struct_check,
		frame_struct_ok		=> frame_struct_ok
	);
	
	checker: crc_check
	generic map(
		crc_l				=> crc_l
	)
	port map(
		clk					=> extracted_clk,
		crc_check_start		=> sof,
		crc_check_end		=> eof,
		gx					=> gx,
		reset				=> reset,
		vx					=> vx,
		
		fcs_check			=> fcs_check,
		fcs_ok				=> fcs_ok
	);

	txerr					<= '0';
	wdgn					<= '1';

end archi;
