---------------------------------------------------------------------------------------------------
--! @file WF_tx_rx.vhd
---------------------------------------------------------------------------------------------------

--! standard library
library IEEE;

--! standard packages
use IEEE.STD_LOGIC_1164.all;  --! std_logic definitions
use IEEE.NUMERIC_STD.all;     --! conversion functions

--! specific packages
use work.WF_PACKAGE.all;      --! definitions of supplemental types, subtypes, constants

---------------------------------------------------------------------------------------------------
--                                                                                               --
--                                              WF_tx_rx                                         --
--                                                                                               --
--                                           CERN, BE/CO/HT                                      --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
-- unit name: WF_tx_rx
--
--! @brief Serializes and deserializes the WorldFIP data.
--!
--! Used in the NanoFIP design. \n
--! On reception it depacketises the data and only presents the actual data
--! contents. It also verifies the FCS (Frame Checksum, CRC).\n
--! On transmission it packetises the data and adds the FCS.
--! The unit WF_rx_tx_osc recovers the carrier clock during 
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
--! WF_engine           \n
--! tx_engine           \n
--! clk_gen             \n
--! WF_reset_unit         \n
--! consumed_ram        \n
--!
--!
--! <b>References:</b>\n
--! 
--! 
--!
--! <b>Modified by:</b>\n
--! Author:  Pablo Alvarez Sanchez
---------------------------------------------------------------------------------------------------
--! \n\n<b>Last changes:</b>\n
--! 07/07/2009  v0.01  PAAS  First version \n
--!
---------------------------------------------------------------------------------------------------
--! @todo Define I/O signals \n
--!
---------------------------------------------------------------------------------------------------



--=================================================================================================
--! Entity declaration for WF_tx_rx
--=================================================================================================
entity WF_tx_rx is

  port (
    uclk_i :                  in std_logic; --! User Clock
    nFIP_urst_i :              in std_logic;
    rst_rx_unit_p_i :       in std_logic;
    start_produce_p_i :       in std_logic;
    byte_ready_p_i :          in std_logic;
    byte_i :                  in std_logic_vector (7 downto 0);
    last_byte_p_i :           in std_logic;
    fd_rxd :                  in std_logic;
    fd_rxd_edge_i :           in std_logic;
    fd_rxd_r_edge_i :         in std_logic;
    fd_rxd_f_edge_i :         in std_logic; 
    rate_i :                  in std_logic_vector (1 downto 0);
    request_byte_p_o :        out std_logic;
    tx_data_o :               out std_logic;
    tx_enable_o :             out std_logic;
    d_clk_o :                 out std_logic;
    byte_ready_p_o :          out std_logic;
    byte_o :                  out std_logic_vector (7 downto 0);
    FSS_received_p_o :        out std_logic;
    CRC_wrong_p_o :           out std_logic;
    FSS_CRC_FES_viol_ok_p_o : out std_logic
    );

end entity WF_tx_rx;



--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of WF_tx_rx is

  signal s_d_filtered, s_first_fe :                  std_logic;
  signal s_rx_data_filtered_f_edge_p :               std_logic;   
  signal s_rx_bit_clk_p, s_rx_manch_clk_p :          std_logic;
  signal s_sample_bit_p, s_sample_manch_bit_p :      std_logic;
  signal s_signif_edge_window, s_adjac_bits_window : std_logic;
  signal s_clk_fixed_carrier_p_d : std_logic_vector (C_TXCLKBUFFLENTGTH - 1 downto 0); 

--=================================================================================================
--                                      architecture begin
--================================================================================================= 

begin
---------------------------------------------------------------------------------------------------
  tx: WF_tx 
    generic map(C_TXCLKBUFFLENTGTH => C_TXCLKBUFFLENTGTH)
    PORT MAP(
      uclk_i            => uclk_i,
      nFIP_urst_i        => nFIP_urst_i,
      start_produce_p_i => start_produce_p_i,
      byte_ready_p_i    => byte_ready_p_i,
      byte_i            => byte_i,
      last_byte_p_i     => last_byte_p_i,
      tx_clk_p_buff_i   => s_clk_fixed_carrier_p_d,
      tx_data_o         => tx_data_o,
      request_byte_p_o  => request_byte_p_o,
      tx_enable_o       => tx_enable_o
      );
  
---------------------------------------------------------------------------------------------------
  rx: WF_rx 
    PORT MAP(
      uclk_i                  => uclk_i,
      nFIP_urst_i              => nFIP_urst_i,
      rst_rx_unit_p_i       => rst_rx_unit_p_i,
      sample_bit_p_i          => s_sample_bit_p,
      signif_edge_window_i    => s_signif_edge_window,
      adjac_bits_window_i     => s_adjac_bits_window,
      rxd_f_edge_i            => fd_rxd_f_edge_i,
      rxd_r_edge_i            => fd_rxd_r_edge_i,
      rxd_filtered_o          => s_d_filtered,
      rxd_filtered_f_edge_p_i => s_rx_data_filtered_f_edge_p,
      sample_manch_bit_p_i    => s_sample_manch_bit_p,
      byte_ready_p_o          => byte_ready_p_o,
      byte_o                  => byte_o,
      FSS_CRC_FES_viol_ok_p_o => FSS_CRC_FES_viol_ok_p_o,
      rst_rx_osc_o => s_first_fe,
      FSS_received_p_o         => FSS_received_p_o,
      CRC_wrong_p_o           => CRC_wrong_p_o
      );


---------------------------------------------------------------------------------------------------  
  rx_tx_osc :WF_rx_tx_osc
    generic map(C_PERIODS_COUNTER_LENGTH => 11,
                C_QUARTZ_PERIOD          => 24.8,
                C_TXCLKBUFFLENTGTH       => 4)


    port map(
      uclk_i                  => uclk_i,
      nFIP_urst_i              => nFIP_urst_i, 
      rxd_edge_i              => fd_rxd_edge_i,      
      rxd_f_edge_i            => fd_rxd_f_edge_i,
      rst_rx_osc_i => s_first_fe, 
      rate_i                  => rate_i,  
      tx_clk_p_buff_o         => s_clk_fixed_carrier_p_d,
      tx_clk_o                => d_clk_o,
      rx_manch_clk_p_o        => s_rx_manch_clk_p,
      rx_bit_clk_p_o          => s_rx_bit_clk_p, 
      rx_signif_edge_window_o => s_signif_edge_window,
      rx_adjac_bits_window_o  => s_adjac_bits_window
      );

---------------------------------------------------------------------------------------------------
  deglitcher : WF_rx_deglitcher 
    generic map (C_ACULENGTH => 10)
    Port map( uclk_i                  => uclk_i,
              nFIP_urst_i              => nFIP_urst_i,
              rxd_i                   => fd_rxd,
              sample_bit_p_i          => s_rx_bit_clk_p,
              sample_manch_bit_p_i    => s_rx_manch_clk_p,
              rxd_filtered_o          => s_d_filtered,
              rxd_filtered_f_edge_p_o => s_rx_data_filtered_f_edge_p,
              sample_manch_bit_p_o    => s_sample_manch_bit_p,
              sample_bit_p_o          => s_sample_bit_p
              );
  
  
end architecture rtl;

--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------
