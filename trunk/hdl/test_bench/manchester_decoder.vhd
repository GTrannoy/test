-- Created by : G. Penacoba
-- Creation Date: June 2010
-- Description: Extracts the clock and the data from the serial line.
--				Originally the data streamn is Manchester encoded.
-- Modified by:
-- Modification Date:
-- Modification consisted on:

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity manchester_decoder is
	port(
		input			: in std_logic;
		
		extracted_bits	: out std_logic;
		extracted_clk	: out std_logic;
		violation		: out std_logic
	);
end manchester_decoder;

architecture archi of manchester_decoder is

constant secure_lock	: unsigned(3 downto 0) := x"B";
constant release_lock	: unsigned(3 downto 0) := x"8";

signal spec_clk_period	: time := 1000 ns;

signal max_jitt			: time := 60 ns;

signal qrt_period_pos	: time := 0 ns;
signal qrt_period_neg	: time := 0 ns;

signal offset1			: time := 0 ns;
signal offset2			: time := 0 ns;

signal b_clk_period		: time := 980 ns;

signal last_transition	: time := 0 ns;
signal input_period		: time := 0 ns;

signal clk1_edge		: time := 0 ns;
signal clk2_edge		: time := 0 ns;
signal clk3_edge		: time := 0 ns;
signal clk4_edge		: time := 0 ns;
signal b_clk_edge		: time := 0 ns;

signal zero_event		: time := 0 ns;
signal one_event		: time := 0 ns;

signal shift			: time := 100 ns;

signal b_clk			: std_logic;
signal clk1, clk2		: std_logic;
signal clk3, clk4		: std_logic;
signal internal_bits	: std_logic;
signal sel, locked		: std_logic;
signal viol_limit		: std_logic;

signal period_error		: boolean := FALSE;
signal locking			: boolean := FALSE;
signal lock_error		: boolean := FALSE;

signal count_period_err	: unsigned(1 downto 0):="00";
signal count_for_clk3	: unsigned(3 downto 0):=x"0";
signal count_for_clk4	: unsigned(3 downto 0):=x"0";

begin

-- processes for clock period adjustment with the received bit stream
----------------------------------------------------------------------

	b_clk_period		<= input_period 
							when (input_period < (spec_clk_period + max_jitt)
							and input_period > (spec_clk_period - max_jitt))
						else
							2 * input_period
							when (input_period < (spec_clk_period + max_jitt) / 2
							and input_period > (spec_clk_period - max_jitt) / 2);

	extracted_clk			<= b_clk;
	
	transition_monitor: process(input)
	begin
		if rising_edge(input) or falling_edge(input) then
			last_transition		<= now;
		end if;
	end process;
	
	period_monitor: process(input)
	begin
		if rising_edge(input) or falling_edge(input) then
			input_period		<= now - last_transition;
		end if;
	end process;
	
	clocks: process
	begin
		clk1		<= '1';
		clk2		<= '0';
		wait for b_clk_period / 2;
		clk1		<= '0';
		clk2		<= '1';
		wait for b_clk_period / 2;
	end process;
	
	period_error_condition: process(input_period)
	begin
		if ((input_period > (spec_clk_period + max_jitt) or input_period < (spec_clk_period - max_jitt))
		and (input_period > (spec_clk_period + max_jitt) / 2 or input_period < (spec_clk_period - max_jitt) / 2)) then

			if count_period_err = 3 then
				period_error		<= TRUE;
			else
				count_period_err	<= count_period_err + "1";
			end if;
		else
			period_error			<= FALSE;
			count_period_err		<= "00";
		end if;
	end process;

	assert not(period_error)
	report "Period of nanoFIP bit stream is out of specification"
	severity warning;


-- processes for phase adjustment with the received bit stream
--------------------------------------------------------------
	
	clock1_monitor: process(clk1)
	begin
		if rising_edge(clk1) then
			clk1_edge		<= now;
		end if;
	end process;

	clock2_monitor: process(clk2)
	begin
		if rising_edge(clk2) then
			clk2_edge		<= now;
		end if;
	end process;
	
	phase_shift_monitor: process(offset1, offset2)
	begin
		if offset1 < qrt_period_pos and offset1 > qrt_period_neg then
			shift					<= offset1;
		elsif offset2 < qrt_period_pos and offset2 > qrt_period_neg then
			shift					<= offset2;
		end if;
	end process;
	
	offset1			<= last_transition - clk1_edge;
	offset2			<= last_transition - clk2_edge;

	qrt_period_pos	<= b_clk_period / 4;
	qrt_period_neg	<= 0 ns - b_clk_period / 4;

	clk3			<= clk1 after b_clk_period / 2 + shift;
	clk4			<= clk2 after b_clk_period / 2 + shift;
	
-- processes for clock extraction from the received bit stream
--------------------------------------------------------------
	
	clock3_monitor: process(clk3)
	begin
		if rising_edge(clk3) then
			clk3_edge		<= now;
		end if;
	end process;

	clock4_monitor: process(clk4)
	begin
		if rising_edge(clk4) then
			clk4_edge		<= now;
		end if;
	end process;
	
	time0_monitor: process(input)
	begin
		if rising_edge(input) then
			zero_event	<= now;
		end if;
	end process;
	
	time1_monitor: process(input)
	begin
		if falling_edge (input) then
			one_event	<= now;
		end if;
	end process;
	
	significant_transitions_monitor: process(clk3, clk4)
	begin
		if ((zero_event > (clk3_edge + max_jitt) or zero_event < (clk3_edge - max_jitt))
		and (one_event > (clk3_edge + max_jitt) or one_event < (clk3_edge - max_jitt))
		and (zero_event > (clk4_edge + max_jitt) or zero_event < (clk4_edge - max_jitt)) 
		and (one_event > (clk4_edge + max_jitt) or one_event < (clk4_edge - max_jitt))) then
			locked					<= '0';
			count_for_clk3			<= x"0";
			count_for_clk4			<= x"0";
		elsif ((zero_event > (clk3_edge + max_jitt) or zero_event < (clk3_edge - max_jitt))
			and (one_event > (clk3_edge + max_jitt) or one_event < (clk3_edge - max_jitt))) then
			count_for_clk3			<= x"0";
			if count_for_clk4 < 15 then
				count_for_clk4			<= count_for_clk4 + "1";
			end if;
			if count_for_clk4 > secure_lock then
				sel					<= '1';
				locked				<= '1';
			elsif (count_for_clk4 > release_lock and sel ='0') then
				locked				<= '0';
			end if;
		elsif ((zero_event > (clk4_edge + max_jitt) or zero_event < (clk4_edge - max_jitt))
			and (one_event > (clk4_edge + max_jitt) or one_event < (clk4_edge - max_jitt))) then
			count_for_clk4			<= x"0";
			if count_for_clk3 < 15 then
				count_for_clk3			<= count_for_clk3 + "1";
			end if;
			if count_for_clk3 > secure_lock then
				sel					<= '0';
				locked				<= '1';
			elsif (count_for_clk3 > release_lock and sel ='1') then
				locked				<= '0';
			end if;
		end if;
	end process;
	-- This process locks the bus clock. It selects one of the two synchronised clocks by excluding
	-- the other one. If one rising edge occurs for one of the clocks without transition on the input
	-- signal, this clock stops being candidate for locking. After 7 consecutive rising edges
	-- of one of the clocks simultaneous with transitions of the input signal, the bus clock
	-- is locked onto that clock. After 5 consecutive rising edges of the locked clock not 
	-- simultaneous with a transition of the input signal, the bus clock is considered unlocked.
	-- When the input signal is inactive, the bus clock is not locked.
	
	
	clock_selection_process: process(clk3, clk4, sel)
	begin
		case sel is
		when '0' =>
			b_clk	<= clk3;
		when '1' =>
			b_clk	<= clk4;
		when others =>
			b_clk	<= 'X';
		end case;
	end process;
	
	clock_lock_error_condition: process(locked, count_for_clk3, count_for_clk4)
	begin
		if (count_for_clk3 = x"0" and count_for_clk4 = x"0") then
			locking				<= TRUE;
		elsif locked ='1' then
			locking				<= FALSE;
		end if;
		if (locked ='0' and not(locking) and (count_for_clk3 /= x"0" or count_for_clk4 /= x"0")) then
			lock_error			<= TRUE;
		else
			lock_error			<= FALSE;
		end if;
	end process;

	assert not(lock_error)
	report "Clock locked on nanoFIP bit stream is lost. Check excess jitter or violation"
	severity warning;

-- processes for the data extraction from the received bit stream
-----------------------------------------------------------------

	serial_data: process
	begin
		internal_bits	<= input;
		wait until b_clk ='1';
	end process;
	
	extracted_bits		<= internal_bits;
	
-- processes for the detection of the violations
------------------------------------------------

	viol_limit			<= b_clk after max_jitt;

	b_clock_monitor: process(b_clk)
	begin
		if rising_edge(b_clk) then
			b_clk_edge		<= now;
		end if;
	end process;

	violation_monitor: process
	begin
		if ((zero_event > (clk3_edge + max_jitt) or zero_event < (clk3_edge - max_jitt))
		and (one_event > (clk3_edge + max_jitt) or one_event < (clk3_edge - max_jitt))
		and (zero_event > (clk4_edge + max_jitt) or zero_event < (clk4_edge - max_jitt)) 
		and (one_event > (clk4_edge + max_jitt) or one_event < (clk4_edge - max_jitt))) then
			violation		<= '0';
		elsif ((zero_event > (b_clk_edge + max_jitt) or zero_event < (b_clk_edge - max_jitt))
		and (one_event > (b_clk_edge + max_jitt) or one_event < (b_clk_edge - max_jitt))) then
			violation		<= '1';
		else
			violation		<= '0';
		end if;
		wait until viol_limit ='1';
	end process;

end archi;

