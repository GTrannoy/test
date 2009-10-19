
--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   16:20:04 09/21/2009
-- Design Name:   nanofip
-- Module Name:   C:/ohr/CernFIP/trunk/hdl/test_bench/nanofip_tb.vhd
-- Project Name:  CernFIP
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: nanofip
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

ENTITY nanofip_tb_vhd IS
END nanofip_tb_vhd;

ARCHITECTURE behavior OF nanofip_tb_vhd IS 

  -- Component Declaration for the Unit Under Test (UUT)
  COMPONENT nanofip
    PORT(
      rate_i : IN std_logic_vector(1 downto 0);
      subs_i : IN std_logic_vector(7 downto 0);
      m_id_i : IN std_logic_vector(3 downto 0);
      c_id_i : IN std_logic_vector(3 downto 0);
      p3_lgth_i : IN std_logic_vector(2 downto 0);
      fd_wdgn_i : IN std_logic;
      fd_txer_i : IN std_logic;
      fx_rxa_i : IN std_logic;
      fx_rxd_i : IN std_logic;
      uclk_i : IN std_logic;
      slone_i : IN std_logic;
      nostat_i : IN std_logic;
      rstin_i : IN std_logic;
      var1_acc_i : IN std_logic;
      var2_acc_i : IN std_logic;
      var3_acc_i : IN std_logic;
      wclk_i : IN std_logic;
      dat_i : IN std_logic_vector(15 downto 0);
      adr_i : IN std_logic_vector(9 downto 0);
      rst_i : IN std_logic;
      stb_i : IN std_logic;
      we_i : IN std_logic;          
      s_id_o : OUT std_logic_vector(1 downto 0);
      fd_rstn_o : OUT std_logic;
      fd_txena_o : OUT std_logic;
      fd_txck_o : OUT std_logic;
      fx_txd_o : OUT std_logic;
      rston_o : OUT std_logic;
      var1_rdy_o : OUT std_logic;
      var2_rdy_o : OUT std_logic;
      var3_rdy_o : OUT std_logic;
      dat_o : OUT std_logic_vector(15 downto 0);
      ack_o : OUT std_logic
      );
  END COMPONENT;

  --Inputs
  SIGNAL fd_wdgn_i :  std_logic := '0';
  SIGNAL fd_txer_i :  std_logic := '0';
  SIGNAL fx_rxa_i :  std_logic := '0';
  SIGNAL fx_rxd_i :  std_logic := '0';
  SIGNAL uclk_i :  std_logic := '0';
  SIGNAL slone_i :  std_logic := '0';
  SIGNAL nostat_i :  std_logic := '0';
  SIGNAL rstin_i :  std_logic := '0';
  SIGNAL var1_acc_i :  std_logic := '0';
  SIGNAL var2_acc_i :  std_logic := '0';
  SIGNAL var3_acc_i :  std_logic := '0';
  SIGNAL wclk_i :  std_logic := '0';
  SIGNAL rst_i :  std_logic := '0';
  SIGNAL stb_i :  std_logic := '0';
  SIGNAL we_i :  std_logic := '0';
  SIGNAL rate_i :  std_logic_vector(1 downto 0) := (others=>'0');
  SIGNAL subs_i :  std_logic_vector(7 downto 0) := (others=>'0');
  SIGNAL m_id_i :  std_logic_vector(3 downto 0) := (others=>'0');
  SIGNAL c_id_i :  std_logic_vector(3 downto 0) := (others=>'0');
  SIGNAL p3_lgth_i :  std_logic_vector(2 downto 0) := (others=>'0');
  SIGNAL dat_i :  std_logic_vector(15 downto 0) := (others=>'0');
  SIGNAL adr_i :  std_logic_vector(9 downto 0) := (others=>'0');

  --Outputs
  SIGNAL s_id_o :  std_logic_vector(1 downto 0);
  SIGNAL fd_rstn_o :  std_logic;
  SIGNAL fd_txena_o :  std_logic;
  SIGNAL fd_txck_o :  std_logic;
  SIGNAL fx_txd_o :  std_logic;
  SIGNAL rston_o :  std_logic;
  SIGNAL var1_rdy_o :  std_logic;
  SIGNAL var2_rdy_o :  std_logic;
  SIGNAL var3_rdy_o :  std_logic;
  SIGNAL dat_o :  std_logic_vector(15 downto 0);
  SIGNAL ack_o :  std_logic;

BEGIN

  -- Instantiate the Unit Under Test (UUT)
  uut: nanofip PORT MAP(
    rate_i => rate_i,
    subs_i => subs_i,
    s_id_o => s_id_o,
    m_id_i => m_id_i,
    c_id_i => c_id_i,
    p3_lgth_i => p3_lgth_i,
    fd_rstn_o => fd_rstn_o,
    fd_wdgn_i => fd_wdgn_i,
    fd_txer_i => fd_txer_i,
    fd_txena_o => fd_txena_o,
    fd_txck_o => fd_txck_o,
    fx_txd_o => fx_txd_o,
    fx_rxa_i => fx_rxa_i,
    fx_rxd_i => fx_rxd_i,
    uclk_i => uclk_i,
    slone_i => slone_i,
    nostat_i => nostat_i,
    rstin_i => rstin_i,
    rston_o => rston_o,
    var1_rdy_o => var1_rdy_o,
    var1_acc_i => var1_acc_i,
    var2_rdy_o => var2_rdy_o,
    var2_acc_i => var2_acc_i,
    var3_rdy_o => var3_rdy_o,
    var3_acc_i => var3_acc_i,
    wclk_i => wclk_i,
    dat_i => dat_i,
    dat_o => dat_o,
    adr_i => adr_i,
    rst_i => rst_i,
    stb_i => stb_i,
    ack_o => ack_o,
    we_i => we_i
    );

  tb : PROCESS
  BEGIN

    -- Wait 100 ns for global reset to finish
    wait for 100 ns;

    -- Place stimulus here

    wait; -- will wait forever
  END PROCESS;

END;
