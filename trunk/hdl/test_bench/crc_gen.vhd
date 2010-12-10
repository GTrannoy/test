-- Created by : G. Penacoba
-- Creation Date: March 2010
-- Description: Calculates Frame Check Sequence (FCS) of any length message
--              serial input, serial output, with polinomial length configurable
-- Modified by:
-- Modification Date:
-- Modification consisted on:

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.tb_package.all;

entity crc_gen is
	generic(
		crc_l			: integer:=16								-- polinomial length in bits
	);
	port(
		clk				: in std_logic;
		crc_gen_start	: in std_logic;								-- launches the FCS calculation
		crc_gen_end		: in std_logic;								-- ends the FCS calculation
		gx				: in std_logic_vector(crc_l downto 0);		-- polinomial divisor
		mx				: in std_logic;								-- message incoming bits
		reset			: in std_logic;
		
		fcs				: out std_logic_vector(crc_l-1 downto 0);	-- FCS sequence
		fcs_ready		: out std_logic;
		fcs_valid		: out std_logic
	);
end crc_gen;

architecture archi of crc_gen is

	component encounter is
	generic(
		width		: integer:=16
	);
	port(
		clk			: in std_logic;
		en			: in std_logic;
		reset		: in std_logic;
		start_value	: in std_logic_vector(width-1 downto 0);
	
		count		: out std_logic_vector(width-1 downto 0);
		count_done	: out std_logic
	);
	end component;

type sstate_ty				is (idle, sof, calc, eof, issuing);
signal sstate, nxt_sstate	: sstate_ty;

signal calc_on				: std_logic:='0';
signal calc_off				: std_logic;
signal en_xor				: std_logic;

signal stuff_sof			: std_logic;
signal stuff_eof			: std_logic;
signal stuff_sof_done		: std_logic;
signal stuff_eof_done		: std_logic;
signal sx_in				: std_logic;
signal u_dx			: unsigned(crc_l-1 downto 0);	--divisor
signal u_rx			: unsigned(crc_l-1 downto 0);	--intermediate remainder
signal u_sx			: unsigned(crc_l-1 downto 0);	--shift register

begin

	u_dx		<= unsigned(gx(crc_l-1 downto 0));

	-- process for the calculation of the remainder:
	-- fully combinational
	-------------------------------------------------------------
	division: process(u_sx,u_dx,en_xor)
	begin
		if en_xor='1' then
			u_rx		<= u_sx xor u_dx;
		else
			u_rx		<= u_sx;
		end if;
	end process;

	-- process for the shifting of the numerator 
	-- and enabling the xor operation:
	-- sequencial: 1 result bit per clock cycle
	-------------------------------------------
	shifting: process
	begin
		if reset ='1' then
			en_xor		<= '0';
			u_sx		<= (others=>'0');
		elsif calc_on ='1' then
			en_xor		<= u_rx(crc_l-1);
			u_sx		<= shift_left(u_rx,1);
			u_sx(0)		<= sx_in;
		else
			en_xor		<= '0';
			u_sx		<= (others=>'0');
		end if;
		wait until clk ='1';
	end process;

	-- process for controlling the stuffing of "ones":
	-- xored with the MSB bits of the meassage
	-- and added at the end of the message.
	-- fully combinational
	------------------------------------------------
	stuffing: process(stuff_sof, stuff_eof, mx)
	begin
		if stuff_sof='1' then
			sx_in		<= mx xor '1';
		elsif stuff_eof='1' then
			sx_in		<= '1';
		else
			sx_in		<= mx;
		end if;
	end process;

	-- FSM machines for the generation of the
	-- stuff_sof and stuff_eof signals
	--------------------------------------
	stuffing_signals_seq: process
	begin
		if reset ='1' then
			sstate	<= idle;
		else
			sstate	<= nxt_sstate;
		end if;
		wait until clk ='1';
	end process;

	stuffing_signals_comb: process(crc_gen_start, stuff_sof_done, crc_gen_end, stuff_eof_done, sstate)
	begin
		case sstate is
		when idle =>
			if crc_gen_start ='1' then
				nxt_sstate	<= sof;
			else
				nxt_sstate	<= idle;
			end if;
		
		when sof =>
			if stuff_sof_done ='1' then
				nxt_sstate	<= calc;
			else
				nxt_sstate	<= sof;
			end if;

		when calc =>
			if crc_gen_end ='1' then
				nxt_sstate	<= eof;
			else
				nxt_sstate	<= calc;
			end if;

		when eof =>
			if stuff_eof_done ='1' then
				nxt_sstate	<= issuing;
			else
				nxt_sstate	<= eof;
			end if;
		when issuing =>
			nxt_sstate	<= idle;
		
		when others =>
			nxt_sstate	<= idle;
		end case;
	end process;
	
	stuff_sof	<= '1' when (crc_gen_start ='1' and sstate = idle) or sstate = sof
						else '0';
	
	stuff_eof	<= '1' when sstate = eof
						else '0';
	
	calc_on		<= '1' when crc_gen_start ='1'
						else '0' when sstate = idle or sstate = issuing;

	calc_off	<= not(calc_on);
	
	fcs_ready	<= stuff_eof_done;
	
	fcs_valid	<= '1' when sstate = issuing
						else '0';

	fcs			<= std_logic_vector(u_rx) when sstate = issuing;
	
	
	stuff_sof_count: encounter
	generic map(width => crc_l)
	port map(
		clk			=> clk,
		en			=> stuff_sof,
		reset		=> calc_off,
		start_value	=> std_logic_vector(to_unsigned(crc_l-1,crc_l)),
	
		count		=> open,
		count_done	=> stuff_sof_done
	);

	stuff_eof_count: encounter
	generic map(width => crc_l)
	port map(
		clk			=> clk,
		en			=> stuff_eof,
		reset		=> calc_off,
		start_value	=> std_logic_vector(to_unsigned(crc_l-1,crc_l)),
	
		count		=> open,
		count_done	=> stuff_eof_done
	);
	
end archi;
