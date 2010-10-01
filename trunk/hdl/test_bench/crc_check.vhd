-- Created by : G. Penacoba
-- Creation Date: April 2010
-- Description: Checks the FCS of a received message by comparing with the canonical remainder.
-- serial input, serial output, with polinomial length configurable
-- Modified by:
-- Modification Date:
-- Modification consisted on:

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use std.textio.all;

entity crc_check is
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
end crc_check;

architecture archi of crc_check is

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

type sstate_ty				is (waiting, sof, calc, eof, checking);
signal sstate, nxt_sstate	: sstate_ty;

subtype	index				is integer range crc_l downto 0;
signal i,j					: index;

subtype rx_type 			is unsigned(crc_l-1 downto 0);
type rxs_type 				is array (0 to crc_l) of rx_type;
signal lxx					: unsigned(2*crc_l-1 downto 0):=(others=>'1');

signal calc_on				: std_logic;
signal calc_off				: std_logic;
signal en_xor				: std_logic;

signal stuff_sof			: std_logic;
signal stuff_eof			: std_logic;
signal stuff_sof_done		: std_logic;
signal stuff_eof_done		: std_logic;
signal sx_in				: std_logic;
signal u_dx					: rx_type;	--divisor
signal u_rx					: rx_type;	--intermediate remainder
signal u_rx_ok				: rx_type;
signal u_sx					: rx_type;	--shift register

signal valid_check			: std_logic:='0';
signal fcs_check_ok			: std_logic:='0';

begin

	u_dx						<= unsigned(gx(crc_l-1 downto 0));
	lxx(crc_l-1 downto 0)		<= (others=>'0');		-- stuffing for the rx_ok calculation

	-- process generating the canonical remainder in case of zero errors
	-- in transmission. It will be used for verification of
	-- the calculated FCS of every received message.
	-- fully combinational
	---------------------------------------------------------------------
	zero_error_remainder: process (i,j,u_dx,lxx)
	variable rxs		: rxs_type;
	begin
		rxs(0)			:= lxx(2*crc_l-1 downto crc_l);		-- stuffing of initial remainder
		
		for j in 1 to crc_l loop							-- calculation of the crc_l succesive remainders
			if rxs(j-1)(crc_l-1) ='1' then
				for i in crc_l-1 downto 1 loop				-- calculation of each bit of the remainder
					rxs(j)(i)		:= rxs(j-1)(i-1) xor u_dx(i);
				end loop;
				rxs(j)(0)			:= u_dx(0);				-- lsb gets the following stuffing bit
			else
				for i in crc_l-1 downto 1 loop
					rxs(j)(i)		:= rxs(j-1)(i-1);
				end loop;
				rxs(j)(0)			:= '0';
			end if;
		end loop;
	u_rx_ok		<= rxs(crc_l);
	end process;
	
	-- process for the calculation of the remainder:
	-- fully combinational
	------------------------------------------------
	division: process(calc_on,u_sx,u_dx,en_xor)
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
	-- and zeroes added at the end of the message.
	-- fully combinational
	------------------------------------------------
	stuffing: process(stuff_sof, stuff_eof, vx)
	begin
		if stuff_sof='1' then
			sx_in		<= vx xor '1';
		elsif stuff_eof='1' then
			sx_in		<= '0';
		else
			sx_in		<= vx;
		end if;
	end process;

	-- FSM machines for the generation of the
	-- stuff_sof and stuff_eof signals
	--------------------------------------
	stuffing_signals_seq: process
	begin
		if reset ='1' then
			sstate	<= waiting;
		else
			sstate	<= nxt_sstate;
		end if;
		wait until clk ='1';
	end process;

	stuffing_signals_comb: process(crc_check_start, stuff_sof_done, 
							crc_check_end, stuff_eof_done, sstate)
	begin
		case sstate is
		when waiting =>
			if crc_check_start ='1' then
				nxt_sstate	<= sof;
			else
				nxt_sstate	<= waiting;
			end if;
		
		when sof =>
			if stuff_sof_done ='1' then
				nxt_sstate	<= calc;
			else
				nxt_sstate	<= sof;
			end if;

		when calc =>
			if crc_check_end ='1' then
				nxt_sstate	<= eof;
			else
				nxt_sstate	<= calc;
			end if;

		when eof =>
			if stuff_eof_done ='1' then
				nxt_sstate	<= checking;
			else
				nxt_sstate	<= eof;
			end if;
		
		when checking =>
			nxt_sstate	<= waiting;
		
		when others =>
			nxt_sstate	<= waiting;
		end case;
	end process;

	stuff_sof	<= '1' when (crc_check_start ='1' and sstate = waiting) or sstate = sof
						else '0';
	
	stuff_eof	<= '1' when sstate = eof
						else '0';
	
	calc_on		<= '1' when crc_check_start ='1'
						else '0' when sstate = waiting or sstate = checking;

	calc_off	<= not(calc_on);
	
	valid_check			<= '1' when sstate = checking else '0';

	fcs_check_ok		<= '1'	when sstate = checking and u_rx = u_rx_ok
						else '0' when sstate = checking and u_rx /= u_rx_ok
						else '0' when calc_on ='1';
	

	fcs_check			<= valid_check;
	fcs_ok				<= fcs_check_ok;

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
	
	reporting: process(valid_check)
	begin
		if valid_check ='0' and now/= 0 fs then
			if fcs_check_ok ='1' then
				report "            Frame Check Sequence (CRC) received from nanoFIP is correct" & LF & LF;
			else
				assert FALSE
				report "            Frame Check Sequence (CRC) received from nanoFIP is NOT correct" & LF & LF
				severity warning;
			end if;
		end if;
	end process;

end archi;
