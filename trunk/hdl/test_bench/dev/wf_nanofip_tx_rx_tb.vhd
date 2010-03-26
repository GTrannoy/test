
--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   17:02:13 08/17/2009
-- Design Name:   wf_tx_rx
-- Module Name:   C:/ohr/CernFIP/trunk/software/ISE/CernFIP/wf_tx_rx_tb.vhd
-- Project Name:  CernFIP
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: wf_tx_rx
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
use IEEE.math_real.all;
use work.wf_package.all;
use work.wf_sim_package.all;


ENTITY nanofip_tx_rx_tb_vhd IS
END nanofip_tx_rx_tb_vhd;

ARCHITECTURE behavior OF nanofip_tx_rx_tb_vhd IS 


--constant C_MES_ARRAY : t_mes_array := (0 => (data => ("01", "02", "03", "04", "05", "06", 


  --Inputs
  SIGNAL uclk_i :  std_logic := '0';
  SIGNAL rst_i :  std_logic := '0';

  SIGNAL d_a_i :  std_logic := '0';
  SIGNAL rate :  std_logic_vector(1 downto 0) := (others=>'0');

  --Outputs
  SIGNAL d_1_to_2, d_1e_o, d_2_to_1, d_2e_o : std_logic;


  SIGNAL byte_ready_p_o :  std_logic;
  SIGNAL byte_o :  std_logic_vector(7 downto 0);
  SIGNAL last_byte_p_o :  std_logic;
  
  signal tx1_rx_i, tx2_rx_i : t_tx_rx_i; 
  signal tx1_rx_o, tx2_rx_o : t_tx_rx_o; 
  signal mes_array, dec_array : t_mes_array; 
  signal request1_byte_p, request2_byte_p : std_logic;
  signal s_glitch, d_1_to_2_glitchy : std_logic;
  
  
  --Inputs
  SIGNAL fd_wdgn_i :  std_logic := '0';
  SIGNAL fd_txer_i :  std_logic := '0';
  SIGNAL fx_rxa_i :  std_logic := '0';
  SIGNAL fx_rxd_i :  std_logic := '0';
  
  SIGNAL slone_i :  std_logic := '0';
  SIGNAL nostat_i :  std_logic := '0';
  SIGNAL rstin_i :  std_logic := '0';
  SIGNAL var1_acc_i :  std_logic := '0';
  SIGNAL var2_acc_i :  std_logic := '0';
  SIGNAL var3_acc_i :  std_logic := '0';
  SIGNAL wclk_i :  std_logic := '0';
  SIGNAL stb_i :  std_logic := '0';
  SIGNAL we_i :  std_logic := '0';
  SIGNAL rate_i :  std_logic_vector(1 downto 0) := (others=>'0');
  SIGNAL subs_i :  std_logic_vector(7 downto 0) := (others=>'0');
  SIGNAL m_id_i :  std_logic_vector(3 downto 0) := (others=>'0');
  SIGNAL c_id_i :  std_logic_vector(3 downto 0) := (others=>'0');
  SIGNAL p3_lgth_i :  std_logic_vector(2 downto 0) := "010";
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
    signal nanofip_config : t_nanofip_config;
BEGIN

  -- Instantiate the Unit Under Test (UUT)
  uut1: wf_tx_rx PORT MAP(
    uclk_i => uclk_i,
    rst_i => rst_i,
    start_send_p_i => tx1_rx_i.start_send_p,
    request_byte_p_o => request1_byte_p,
    byte_ready_p_i => tx1_rx_i.byte_ready_p,
    byte_i => tx1_rx_i.byte,
    last_byte_p_i => tx1_rx_i.last_byte,
    d_o => d_1_to_2,
    d_e_o => d_1e_o,
    d_a_i => d_2_to_1,
    rate_i => nanofip_config.rate,
    byte_ready_p_o => tx1_rx_o.byte_ready_p,
    byte_o => tx1_rx_o.byte,
    last_byte_p_o => tx1_rx_o.last_byte_p
    );
  

  -- Instantiate the Unit Under Test (UUT)
  uut: nanofip PORT MAP(
    rate_i => nanofip_config.rate,
    subs_i => nanofip_config.subs,
    s_id_o => s_id_o,
    m_id_i => nanofip_config.m_id,
    c_id_i => nanofip_config.c_id,
    p3_lgth_i => p3_lgth_i,
    fd_rstn_o => fd_rstn_o,
    fd_wdgn_i => fd_wdgn_i,
    fd_txer_i => fd_txer_i,
    fd_txena_o => fd_txena_o,
    fd_txck_o => fd_txck_o,
    fx_txd_o => d_2_to_1,
    fx_rxa_i => fx_rxa_i,
    fx_rxd_i => d_1_to_2,
    uclk_i => uclk_i,
    slone_i => nanofip_config.slone,
    nostat_i => nanofip_config.nostat,
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
  
  nanofip_config.rate  <= std_logic_vector(to_unsigned(c_2M5_rate_pos,2));
  nanofip_config.subs  <= x"7F";
  nanofip_config.m_id   <= std_logic_vector(to_unsigned(5,4));
  nanofip_config.c_id    <= x"c";
  nanofip_config.p3_lgth   <= std_logic_vector(to_unsigned(3,3));
  nanofip_config.slone   <= '0';
  nanofip_config.nostat    <= '1';
  

  process
  begin
    uclk_i <= '0';
    wait for 13 ns;
    uclk_i <= '1';
    wait for 12 ns;
  end process;

  process
    variable vRand : real;
    variable u1 : integer := 3;
    variable u2 : integer := 7;
    variable v_rand_time : time;
  begin
    uniform(seed1 => u1,seed2 => u2,x => vRand);
    v_rand_time := (vRand)*(1 us)+9.5 us;
    s_glitch <= '0';
    wait for v_rand_time;
    uniform(seed1 => u1,seed2 => u2,x => vRand);
    v_rand_time := (vRand)*(200 ns);
    s_glitch <= '0';
    wait for v_rand_time;
  end process;
  d_1_to_2_glitchy <= d_1_to_2 xor s_glitch;
  
  rst_i <= '0', '1' after 110 ns, '0' after 1600 ns;
  rstin_i <= '1', '0' after 110 ns, '1' after 2600 ns;
--s_mes_period <= 1 ms;


  sendp : PROCESS
  BEGIN
    init(tx1_rx_i);
    -- Wait 100 ns for global reset to finish
    wait until falling_edge(rst_i);
    wait for 1 us;

    for I in c_var_array'range loop
      if c_var_array(I).response = consume then
      prod_var(clk_i  => uclk_i, substation => nanofip_config.subs, tx_rx_i => tx1_rx_i, request_byte_p => request1_byte_p, 
              nanofip_config => nanofip_config, var_pos => I, mes_array => mes_array );
      wait for 100 us;
      end if;
    end loop;

    for I in c_var_array'range loop
      if c_var_array(I).response = produce then
      req_var(clk_i  => uclk_i, substation => nanofip_config.subs, tx_rx_i => tx1_rx_i, request_byte_p => request1_byte_p, 
              nanofip_config => nanofip_config, var_pos => I, mes_array => mes_array );
      wait for 100 us;
      end if;
    end loop;



    wait;
  END PROCESS;

  getp : PROCESS
  BEGIN

    -- Wait 100 ns for global reset to finish
    wait for 1 us;
    while true loop
      get_array(clk_i => uclk_i, C_MES_ARRAY => mes_array, dec_array => dec_array, tx_rx_o=> tx2_rx_o);
    end loop;
  END PROCESS;

END;
