-- Created by : G. Penacoba
-- Creation Date: July 2010
-- Description: Partitions the frame transmitted by nanoFIP
--				into the different components of its structure.
-- Modified by:
-- Modification Date:
-- Modification consisted on:

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity frame_chopper is
	port(
		clk						: in std_logic;
		eof						: in std_logic;
		reset					: in std_logic;
		sof						: in std_logic;
		vx						: in std_logic;
		
		frame_struct_check		: out std_logic;
		frame_struct_ok			: out std_logic
	);
end frame_chopper;

architecture archi of frame_chopper is

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

constant control_id			: unsigned(7 downto 0):=x"03";
constant control_rp			: unsigned(7 downto 0):=x"02";
constant pdu_presence		: unsigned(7 downto 0):=x"50";
constant pdu_identification	: unsigned(7 downto 0):=x"52";
constant pdu_produced		: unsigned(7 downto 0):=x"40";

type frame_data_ty			is array(0 to 130) of unsigned(7 downto 0); 
signal frame_data			: frame_data_ty:=(others=> x"00");

signal aux_latch			: std_logic;
signal byte_nb				: integer range 0 to 130:=0;
signal bytes_total			: integer range 0 to 130:=0;
signal chop_byte			: std_logic;
signal control_byte			: unsigned(7 downto 0):=x"00";
signal control_ok			: boolean:= FALSE;
signal count_done			: std_logic;
signal current_byte			: unsigned(7 downto 0):=x"00";
signal enable_chopping		: std_logic;
signal length_byte			: unsigned(7 downto 0):=x"00";
signal length_ok			: boolean:= FALSE;
signal pdu_type_byte		: unsigned(7 downto 0):=x"00";
signal reset_counter		: std_logic;
signal struct_check			: std_logic;
signal struct_ok			: boolean:= FALSE;

begin

	chopping_counter: encounter		-- counts 8 bits to separate the incomming bytes
	generic map(
		width			=> 4
	)
	port map(
		clk				=> clk,
		en				=> enable_chopping,
		reset			=> reset_counter,
		start_value		=> x"6",	-- (6 downto 0 + counter reset = 8 bits)
		
		count			=> open,
		count_done		=> count_done
	);
	
	-- process generating the signal for the latching of incomming bytes
	--------------------------------------------------------------------
	byte_chopping: process
	begin
		if enable_chopping ='1' then
			chop_byte			<= count_done;
		else
			chop_byte			<= '0';
		end if;
		wait until clk ='1';
	end process;
	
	-- process tracking the incomming byte number
	---------------------------------------------
	data_byte_counter: process
	begin
		if reset ='1' or enable_chopping ='0' then
			byte_nb				<= 0;
		elsif chop_byte ='1' then
			byte_nb				<= byte_nb + 1;
		end if;
		wait until clk ='1';
	end process;
	
	-- process latching the number of the last incomming byte as the total
	----------------------------------------------------------------------
	total_number: process
	begin
		if reset ='1' then
			bytes_total			<= 0;
		elsif eof ='1' then
			bytes_total			<= byte_nb;
		end if;
		wait until clk ='1';
	end process;
	
	-- 8-bit shift register for paralelisation of incomming data
	------------------------------------------------------------
	data_feeding: process
	begin
		current_byte			<= shift_left(current_byte,1);
		current_byte(0)			<= vx;
		wait until clk ='1';
	end process;
	
	-- process latching incomming bytes into an array of bytes
	----------------------------------------------------------
	data_recovery: process
	begin
		if reset ='1' or sof ='1' then
			frame_data			<= (others=> x"00");
		elsif chop_byte ='1' then
			frame_data(byte_nb)		<= current_byte;
		end if;
		wait until clk ='1';
	end process;
	
	-- process checking the correctness of the frame structure
	----------------------------------------------------------
	structure_check: process(frame_data, bytes_total)
	begin
		if control_byte = control_rp then
			control_ok			<= TRUE;
		else
			control_ok			<= FALSE;
		end if;
		
		if to_integer(length_byte) = (bytes_total - 4) then
			length_ok			<= TRUE;
		else
			length_ok			<= FALSE;
		end if;
		
		case pdu_type_byte is
		when x"50" =>						-- presence variable
			if (frame_data(3) = x"80" 
			and frame_data(4) = x"03"
			and frame_data(5) = x"00"
			and frame_data(6) = x"F0"
			and frame_data(7) = x"00") then
				struct_ok	<= TRUE;
			else
				struct_ok	<= FALSE;
			end if;
			
		when x"52" =>						-- identification variable
			if (frame_data(3) = x"01" 
			and frame_data(4) = x"00"
			and frame_data(5) = x"00"
			and frame_data(8) = x"00"
			and frame_data(9) = x"00"
			and frame_data(10) = x"00") then
				struct_ok	<= TRUE;
			else
				struct_ok	<= FALSE;
			end if;
			
		when x"40" =>						-- produced
			if bytes_total /= 0 then
				if (frame_data(bytes_total - 2) = x"00" 
				or frame_data(bytes_total - 2) = x"05") then
					struct_ok	<= TRUE;
				else
					struct_ok	<= FALSE;
				end if;
			end if;
			
		when others =>
			struct_ok	<= FALSE;
		end case;

	end process;
	
	-- process generating the signal indicating a valid structure check
	-------------------------------------------------------------------
	struct_check_signal: process
	begin
		if reset ='1' then
			struct_check		<= '1';
		elsif chop_byte ='1' and enable_chopping ='0' then
			struct_check		<= '1';
		else
			struct_check		<= '0';
		end if;
		wait until clk ='1';
	end process;
	
	frame_struct_check		<= struct_check;
	frame_struct_ok			<= '1' when control_ok and length_ok and struct_ok
							else '0';
	
	reset_counter		<= reset or sof or chop_byte;

	aux_latch				<= '0' when reset ='1'
							else '1' when sof ='1'
							else '0' when eof ='1';
							
	enable_chopping			<= '0' when reset ='1'
							else '1' when sof ='1'
							else '0' when (eof ='0' and aux_latch ='0');
							
	control_byte		<= frame_data(0);
	pdu_type_byte		<= frame_data(1);
	length_byte			<= frame_data(2);

	reporting: process(struct_check)
	begin
		if struct_check ='1' then
			if control_byte = control_id then
				assert FALSE
				report "            NanoFIP issued an ID_DAT frame"
				severity warning;
			elsif control_byte = control_rp then
				if pdu_type_byte = x"50" then
					if length_ok then
						if struct_ok then
							report "            NanoFIP responded with a presence variable RP_DAT frame"
							& LF & "            with a coherent length and structure according to specs";
						else
							assert FALSE
							report "            NanoFIP responded with a presence variable RP_DAT frame"
							& LF & "            but its structure is not according to specs"
							severity warning;
						end if;
					else
						assert FALSE
						report "            NanoFIP responded with a presence variable RP_DAT frame"
						& LF & "            but its length is not coherent with the length byte"
						severity warning;
					end if;
				elsif pdu_type_byte = x"52" then
					if length_ok then
						if struct_ok then
							report "            NanoFIP responded with an identification variable RP_DAT frame"
							& LF & "            with a coherent length and structure according to specs";
						else
							assert FALSE
							report "            NanoFIP responded with an identification variable RP_DAT frame"
							& LF & "            but its structure is not according to specs"
							severity warning;
						end if;
					else
						assert FALSE
						report "            NanoFIP responded with an identification variable RP_DAT frame"
						& LF & "            but its length is not coherent with the length byte"
						severity warning;
					end if;
				elsif pdu_type_byte = x"40" then
					if length_ok then
						if struct_ok then
							report "            NanoFIP responded with a produced variable RP_DAT frame"
							& LF & "            with a coherent length and structure according to specs";
						else
							assert FALSE
							report "            NanoFIP responded with a produced variable RP_DAT frame"
							& LF & "            but its structure is not according to specs"
							severity warning;
						end if;
					else
						assert FALSE
						report "            NanoFIP responded with a produced variable RP_DAT frame"
						& LF & "            but its length is not coherent with the length byte"
						severity warning;
					end if;
				else
					assert FALSE
					report "            NanoFIP responded with an RP_DAT frame"
					& LF & "            but its PDU_type byte is not according to specs"
					severity warning;
				end if;
			else
				assert FALSE
				report "            NanoFIP issued an illegal frame control byte"
				severity warning;
			end if;
		end if;
	end process;
			
						

end archi;
