
--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   17:42:52 08/14/2009
-- Design Name:   wf_rx
-- Module Name:   C:/ohr/CernFIP/trunk/hdl/design/wf_rx_tb.vhd
-- Project Name:  CernFIP
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: wf_rx
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

ENTITY wf_rx_tb_vhd IS
END wf_rx_tb_vhd;

ARCHITECTURE behavior OF wf_rx_tb_vhd IS 

	-- Component Declaration for the Unit Under Test (UUT)
	COMPONENT wf_rx
	PORT(
		uclk_i : IN std_logic;
		rst_i : IN std_logic;
		d_a_i : IN std_logic;
		rate_i : IN std_logic_vector(1 downto 0);
		start_send_p_i : IN std_logic;
		byte_ready_p_i : IN std_logic;
		byte_i : IN std_logic_vector(7 downto 0);
		last_byte_i : IN std_logic;          
		request_byte_p_o : OUT std_logic;
		send_ended_p_o : OUT std_logic;
		bit_strobe_p_o : OUT std_logic;
		data_o : OUT std_logic_vector(7 downto 0);
		data_e_o : OUT std_logic
		);
	END COMPONENT;

	--Inputs
	SIGNAL uclk_i :  std_logic := '0';
	SIGNAL rst_i :  std_logic := '0';
	SIGNAL d_a_i :  std_logic := '0';
	SIGNAL start_send_p_i :  std_logic := '0';
	SIGNAL byte_ready_p_i :  std_logic := '0';
	SIGNAL last_byte_i :  std_logic := '0';
	SIGNAL rate_i :  std_logic_vector(1 downto 0) := (others=>'0');
	SIGNAL byte_i :  std_logic_vector(7 downto 0) := (others=>'0');

	--Outputs
	SIGNAL request_byte_p_o :  std_logic;
	SIGNAL send_ended_p_o :  std_logic;
	SIGNAL bit_strobe_p_o :  std_logic;
	SIGNAL data_o :  std_logic_vector(7 downto 0);
	SIGNAL data_e_o :  std_logic;

BEGIN

	-- Instantiate the Unit Under Test (UUT)
	uut: wf_rx PORT MAP(
		uclk_i => uclk_i,
		rst_i => rst_i,
		d_a_i => d_a_i,
		rate_i => rate_i,
		start_send_p_i => start_send_p_i,
		request_byte_p_o => request_byte_p_o,
		byte_ready_p_i => byte_ready_p_i,
		byte_i => byte_i,
		last_byte_i => last_byte_i,
		send_ended_p_o => send_ended_p_o,
		bit_strobe_p_o => bit_strobe_p_o,
		data_o => data_o,
		data_e_o => data_e_o
	);

	tb : PROCESS
	BEGIN

		-- Wait 100 ns for global reset to finish
		wait for 100 ns;

		-- Place stimulus here

		wait; -- will wait forever
	END PROCESS;

END;
