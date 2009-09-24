
--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   14:47:37 08/13/2009
-- Design Name:   wf_rx_osc
-- Module Name:   C:/ohr/CernFIP/trunk/software/ISE/CernFIP/wf_rx_osc_tb.vhd
-- Project Name:  CernFIP
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: wf_rx_osc
--
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- Notes: 
-- This testbench has been automatically generated using types std_logic and
-- std_logic_vector for the ports of the unit under test.  Xilinx recommends 
-- that these types always be used for the top-level I/O of a design in order 
-- to guarantee that the testbench will bind correctly to the post-implementation 
-- simulation model.
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.all;
USE ieee.numeric_std.ALL;

ENTITY wf_rx_osc_tb_vhd IS
END wf_rx_osc_tb_vhd;

ARCHITECTURE behavior OF wf_rx_osc_tb_vhd IS 

	-- Component Declaration for the Unit Under Test (UUT)
	COMPONENT wf_rx_osc
	PORT(
		uclk_i : IN std_logic;
		rst_i : IN std_logic;
		d_re_i : IN std_logic;
		load_phase_i : IN std_logic;
		rate_i : IN std_logic_vector(1 downto 0);
		  clk_carrier_p_o : out std_logic;
        clk_carrier_180_p_o : out std_logic;    
		      
		clk_bit_p_o : OUT std_logic;
		clk_bit_90_p_o : OUT std_logic;
		clk_bit_180_p_o : OUT std_logic;
		clk_bit_270_p_o : OUT std_logic;
		edge_window_o : OUT std_logic;
		phase_o : OUT std_logic_vector(19 downto 0)
		);
	END COMPONENT;

	--Inputs
	SIGNAL uclk_i :  std_logic := '0';
	SIGNAL rst_i :  std_logic := '0';
	SIGNAL d_re_i :  std_logic := '0';
	SIGNAL load_phase_i :  std_logic := '0';
	SIGNAL rate_i :  std_logic_vector(1 downto 0) := (others=>'0');

	--Outputs
	SIGNAL clk_bit_p_o :  std_logic;
	SIGNAL clk_bit_90_p_o :  std_logic;
	SIGNAL clk_bit_180_p_o :  std_logic;
	SIGNAL clk_bit_270_p_o :  std_logic;
	SIGNAL edge_window_o :  std_logic;
	signal clk_carrier_p_o : std_logic;
	signal clk_carrier_180_p_o : std_logic;
	
	SIGNAL phase_o :  std_logic_vector(19 downto 0);
   signal s_bit_period : time;
BEGIN


process
begin
uclk_i <= '0';
wait for 13 ns;
uclk_i <= '1';
wait for 12 ns;
end process;

rst_i <= '0', '1' after 110 ns, '0' after 130 ns;

s_bit_period <= 2 us;
rate_i <= "01";

process
begin
wait for 1 ns;
while true loop
d_re_i <= '0';
wait for s_bit_period - 30 ns;
wait until falling_edge(uclk_i);
d_re_i <= '1';
wait until falling_edge(uclk_i);
end loop;
end process;




load_phase_i  <= '0', '1' after 210 ns, '0' after 100030 ns;

	-- Instantiate the Unit Under Test (UUT)
	uut: wf_rx_osc PORT MAP(
		uclk_i => uclk_i,
		rst_i => rst_i,
		d_re_i => d_re_i,
		load_phase_i => load_phase_i,
		rate_i => rate_i,

      clk_carrier_p_o => clk_carrier_p_o,
	   clk_carrier_180_p_o => clk_carrier_180_p_o,

		clk_bit_p_o => clk_bit_p_o,
		clk_bit_90_p_o => clk_bit_90_p_o,
		clk_bit_180_p_o => clk_bit_180_p_o,
		clk_bit_270_p_o => clk_bit_270_p_o,
		edge_window_o => edge_window_o,
		phase_o => phase_o
	);

--	tb : PROCESS
--	BEGIN
--
--		-- Wait 100 ns for global reset to finish
--		wait for 100 ns;
--
--		-- Place stimulus here
--
--		wait; -- will wait forever
--	END PROCESS;

END;
