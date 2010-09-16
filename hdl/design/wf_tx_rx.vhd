--===========================================================================
--! @file wf_tx_rx.vhd
--===========================================================================

--! standard library
library IEEE;

--! standard packages
use IEEE.STD_LOGIC_1164.all;  --! std_logic definitions
use IEEE.NUMERIC_STD.all;     --! conversion functions

--! specific packages
use work.WF_PACKAGE.all;      --! definitions of supplemental types, subtypes, constants

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
--! The unit wf_rx_tx_osc recovers the carrier clock during 
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
--! wf_reset_unit         \n
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
    uclk_i :             in std_logic; --! User Clock
    nFIP_rst_i :         in std_logic;
    reset_rx_unit_p_i :  in std_logic;
    start_produce_p_i :  in std_logic;
    request_byte_p_o :   out std_logic;
    byte_ready_p_i :     in std_logic;
    byte_i :             in std_logic_vector (7 downto 0);
    last_byte_p_i :      in std_logic;
    d_a_i :              in std_logic;
    rate_i :             in std_logic_vector (1 downto 0);
    tx_data_o :          out std_logic;
    tx_enable_o :        out std_logic;
    d_clk_o :            out std_logic;
    byte_ready_p_o :     out std_logic;
    byte_o :             out std_logic_vector (7 downto 0);
    last_byte_p_o :      out std_logic;
    fss_decoded_p_o :    out std_logic;
    code_violation_p_o : out std_logic;
    crc_wrong_p_o :      out std_logic;
    crc_ok_p_o :         out std_logic
    );

end entity wf_tx_rx;



-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--! ARCHITECTURE OF wf_tx_rx
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
architecture rtl of wf_tx_rx is

  constant C_CLKFCDLENTGTH :  natural := 4;

  signal s_data_in_d3 : std_logic_vector (2 downto 0);
  signal s_data_in_r_edge, s_data_in_f_edge : std_logic;
  signal s_d_filtered : std_logic;
  signal s_first_fe : std_logic;   
  signal s_clk_carrier_p : std_logic;
  signal s_clk_bit_180_p, s_sample_bit_p, s_sample_manch_bit_p  : std_logic;
  signal s_edge_window, edge_180_window : std_logic;
  signal s_data_in_edge : std_logic;   
  signal s_clk_fixed_carrier_p_d : std_logic_vector (C_CLKFCDLENTGTH - 1 downto 0); 
begin




  process(uclk_i)
  begin
    if rising_edge(uclk_i) then
      s_data_in_d3 <= s_data_in_d3(1 downto 0) & d_a_i;
    end if;
  end process;

  s_data_in_r_edge <= (not s_data_in_d3(2)) and s_data_in_d3(1); -- 1st flip-flop not considered (metastability) 
                                                                 -- transition on input signal of less than 2 clock cycles are not considered
  s_data_in_f_edge <= s_data_in_d3(2) and (not s_data_in_d3(1));
  s_data_in_edge <= s_data_in_f_edge or s_data_in_r_edge;






  tx: wf_tx 
    generic map(C_CLKFCDLENTGTH => C_CLKFCDLENTGTH)
    PORT MAP(
      uclk_i            => uclk_i,
      nFIP_rst_i        => nFIP_rst_i,
      start_produce_p_i => start_produce_p_i,
      byte_ready_p_i    => byte_ready_p_i,
      byte_i            => byte_i,
      last_byte_p_i     => last_byte_p_i,
      tx_clk_p_buff_i   => s_clk_fixed_carrier_p_d,
      tx_data_o         => tx_data_o,
      request_byte_p_o  => request_byte_p_o,
      tx_enable_o       => tx_enable_o
      );
  

  rx: wf_rx 
    PORT MAP(
      uclk_i               => uclk_i,
      nFIP_rst_i           => nFIP_rst_i,
      reset_rx_unit_p_i    => reset_rx_unit_p_i,
      sample_bit_p_i       => s_sample_bit_p,
      signif_edge_window_i => s_edge_window,
      adjac_bits_window_i  => edge_180_window,
      rx_data_f_edge_i     => s_data_in_f_edge,
      rx_data_r_edge_i     => s_data_in_r_edge,
      rx_data_filtered_i   => s_d_filtered,
      sample_manch_bit_p_i => s_sample_manch_bit_p,
      byte_ready_p_o       => byte_ready_p_o,
      byte_o               => byte_o,
      last_byte_p_o        => last_byte_p_o,
      fss_decoded_p_o      => fss_decoded_p_o,
      crc_ok_p_o           => crc_ok_p_o,
      wait_d_first_f_edge_o=> s_first_fe,
      code_violation_p_o   => code_violation_p_o,
      crc_wrong_p_o        => crc_wrong_p_o
      );

  
  rx_tx_osc :wf_rx_tx_osc

    generic map(C_COUNTER_LENGTH => 11,
                C_QUARTZ_PERIOD  => 24.8,
                C_CLKFCDLENTGTH  => C_CLKFCDLENTGTH)


    port map(
      uclk_i                  => uclk_i,
      nFIP_rst_i              => nFIP_rst_i, 
      d_edge_i                => s_data_in_edge,      
      rx_data_f_edge_i        => s_data_in_f_edge,
      wait_d_first_f_edge_i   => s_first_fe, 
      rate_i                  => rate_i,  
      tx_clk_p_buff_o         => s_clk_fixed_carrier_p_d,
      tx_clk_o                => d_clk_o,
      rx_manch_clk_p_o        => s_clk_carrier_p,
      rx_bit_clk_p_o          => s_clk_bit_180_p, 
      rx_signif_edge_window_o => s_edge_window,
      rx_adjac_bits_window_o  => edge_180_window
      );

  deglitcher : wf_rx_deglitcher 
    generic map (C_ACULENGTH => 10)
    Port map( uclk_i               => uclk_i,
              nFIP_rst_i           => nFIP_rst_i,
              rx_data_i            => s_data_in_d3(2),
              sample_bit_p_i       => s_clk_bit_180_p,
              sample_manch_bit_p_i => s_clk_carrier_p,
              rx_data_filtered_o   => s_d_filtered,
              sample_manch_bit_p_o => s_sample_manch_bit_p,
              sample_bit_p_o       => s_sample_bit_p
              );
  
  
end architecture rtl;
-------------------------------------------------------------------------------
--                          E N D   O F   F I L E
-------------------------------------------------------------------------------
