--===========================================================================
--! @file wf_tx_rx.vhd
--! @brief Serialises and deserialises the WorldFIP data
--===========================================================================
--! Standard library
library IEEE;
--! Standard packages
use IEEE.STD_LOGIC_1164.all; --! std_logic definitions
use IEEE.NUMERIC_STD.all;    --! conversion functions

use work.wf_package.all;

-------------------------------------------------------------------------------
--                                                                           --
--                                 wf_tx_rx                                 --
--                                                                           --
--                               CERN, BE/CO/HT                              --
--                                                                           --
-------------------------------------------------------------------------------
--
-- unit name: wf_tx_rx
--
--! @brief Serialises and deserialises the WorldFIP data.
--!
--! Used in the NanoFIP design. \n
--! On reception it depacketises the data and only presents the actual data
--! contents. It also verifies the FCS (Frame Checksum, CRC).\n
--! On transmission it packetises the data and adds the FCS.
--! The unit wf_rx_osc recovers the carrier clock during 
--!
--! @author Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)
--
--! @date 07/07/2009
--
--! @version v0.01
--
--! @details 
--!
--! <b>Dependencies:</b>\n
--! wf_engine           \n
--! tx_engine           \n
--! clk_gen             \n
--! reset_logic         \n
--! consumed_ram        \n
--!
--!
--! <b>References:</b>\n
--! 
--! 
--!
--! <b>Modified by:</b>\n
--! Author:  Pablo Alvarez Sanchez
-------------------------------------------------------------------------------
--! \n\n<b>Last changes:</b>\n
--! 07/07/2009  v0.01  PAAS  First version \n
--!
-------------------------------------------------------------------------------
--! @todo Define I/O signals \n
--!
-------------------------------------------------------------------------------



--============================================================================
--! Entity declaration for wf_tx_rx
--============================================================================
entity wf_tx_rx is

  port (
    uclk_i    : in std_logic; --! User Clock
    rst_i     : in std_logic;

    start_send_p_i  : in std_logic;
    request_byte_p_o : out std_logic;
    byte_ready_p_i : in std_logic;
    byte_i : in std_logic_vector(7 downto 0);
    last_byte_p_i : in std_logic;

--   clk_fixed_carrier_p_o : out std_logic;
    d_o : out std_logic;
    d_e_o : out std_logic;
    d_clk_o : out std_logic;
    
    d_a_i : in std_logic;
    
    rate_i    : in std_logic_vector(1 downto 0);
    
    byte_ready_p_o : out std_logic;
    byte_o : out std_logic_vector(7 downto 0);
    last_byte_p_o : out std_logic;
    fss_decoded_p_o : out std_logic;
    code_violation_p_o : out std_logic;
    crc_bad_p_o : out std_logic;
    crc_ok_p_o : out std_logic

    );

end entity wf_tx_rx;



-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--! ARCHITECTURE OF wf_tx_rx
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
architecture rtl of wf_tx_rx is

  constant C_CLKFCDLENTGTH :  natural := 3;

  signal s_d_d : std_logic_vector(2 downto 0);
  signal s_d_re, s_d_fe : std_logic;
  signal s_clk_fixed_carrier_p : std_logic;
  signal s_d_filtered : std_logic;
  signal s_d_ready_p : std_logic;
  signal s_load_phase : std_logic;   
  signal s_clk_carrier_p : std_logic;
  signal s_clk_bit_180_p  : std_logic;
  signal s_edge_window, edge_180_window : std_logic;
  signal s_d_edge : std_logic;   
  signal s_clk_fixed_carrier_p_d : std_logic_vector(C_CLKFCDLENTGTH - 1 downto 0); 
begin




  process(uclk_i)
  begin
    if rising_edge(uclk_i) then
      s_d_d <= s_d_d(1 downto 0) & d_a_i;
      s_d_re <= (not s_d_d(2)) and s_d_d(1) and s_d_d(0);
      s_d_fe <= (s_d_d(2)) and (not s_d_d(1)) and (not s_d_d(0));
    end if;
  end process;

  s_d_edge <= s_d_fe or s_d_re;

  uwf_tx: wf_tx 
    generic map(C_CLKFCDLENTGTH => C_CLKFCDLENTGTH)
    PORT MAP(
      uclk_i => uclk_i,
      rst_i => rst_i,
      start_send_p_i => start_send_p_i,
      request_byte_p_o => request_byte_p_o,
      byte_ready_p_i => byte_ready_p_i,
      byte_i => byte_i,
      last_byte_p_i => last_byte_p_i,
--      clk_fixed_carrier_p_i => s_clk_fixed_carrier_p,
      clk_fixed_carrier_p_d_i => s_clk_fixed_carrier_p_d,
      d_o => d_o,
      d_e_o => d_e_o
      );
  

  uwf_rx: wf_rx 
    PORT MAP(
      uclk_i => uclk_i,
      rst_i => rst_i,
      byte_ready_p_o => byte_ready_p_o,
      byte_o => byte_o,
      last_byte_p_o => last_byte_p_o,
      fss_decoded_p_o => fss_decoded_p_o,
      crc_ok_p_o => crc_ok_p_o,
      
      d_fe_i => s_d_fe,
      d_re_i => s_d_re,
      
      d_filtered_i => s_d_filtered,
      s_d_ready_p_i => s_d_ready_p,
      load_phase_o => s_load_phase,
      
      clk_bit_180_p_i => s_clk_bit_180_p,
      edge_window_i => s_edge_window,
      edge_180_window_i => edge_180_window

      );


  
  uwf_rx_osc :wf_rx_osc

    generic map(C_OSC_LENGTH => 20,
                C_QUARTZ_PERIOD => 25.0,
                C_CLKFCDLENTGTH => C_CLKFCDLENTGTH)


    port map(
      uclk_i   => uclk_i, --! User Clock
      rst_i   => rst_i, 
      d_edge_i   => s_d_fe,
      load_phase_i   => s_load_phase, 

      
      --! Bit rate         \n
      --! 00: 31.25 kbit/s \n
      --! 01: 1 Mbit/s     \n
      --! 10: 2.5 Mbit/s   \n
      --! 11: reserved, do not use
      rate_i   => rate_i,  --! Bit rate

      clk_fixed_carrier_p_o     => s_clk_fixed_carrier_p,
      clk_fixed_carrier_p_d_o   => s_clk_fixed_carrier_p_d,
      clk_fixed_carrier_o   => d_clk_o,
      
      clk_carrier_p_o     => s_clk_carrier_p,
      clk_carrier_180_p_o => open,

      clk_bit_p_o      => open,
      clk_bit_90_p_o   => open, 
      clk_bit_180_p_o  => s_clk_bit_180_p, 
      clk_bit_270_p_o  => open, 
      
      edge_window_o  => s_edge_window,
      edge_180_window_o => edge_180_window,

      phase_o  => open
      );

  Udeglitcher : deglitcher 
    generic map (C_ACULENGTH => 10)
    Port map( uclk_i => uclk_i,
              d_i => s_d_d(2),
              d_o => s_d_filtered,
              carrier_p_i  => s_clk_carrier_p,
              d_ready_p_o => s_d_ready_p);
  
  
end architecture rtl;
-------------------------------------------------------------------------------
--                          E N D   O F   F I L E
-------------------------------------------------------------------------------