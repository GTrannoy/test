--_________________________________________________________________________________________________
--                                                                                                |
--                                        |The nanoFIP|                                           |
--                                                                                                |
--                                        CERN,BE/CO-HT                                           |
--________________________________________________________________________________________________|
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--! @file wf_consumption.vhd
---------------------------------------------------------------------------------------------------

--! standard library
library IEEE; 

--! standard packages
use IEEE.STD_LOGIC_1164.all;  --! std_logic definitions
use IEEE.NUMERIC_STD.all;     --! conversion functions

--! specific packages
use work.WF_PACKAGE.all;      --! definitions of types, constants, entities

---------------------------------------------------------------------------------------------------
--                                                                                               --
--                                          wf_consumption                                        --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
--
--! @brief     
--
--
--! @author    Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)
--!            Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)
--
--
--! @date      11/01/2011
--
--
--! @version   v0.01
--
--
--! @details \n  
--
--!   \n<b>Dependencies:</b>    \n
--!     wf_prod_bytes_retriever \n
--!     WF_status_bytes_gen     \n
--!     wf_tx_serializer        \n
--
--
--!   \n<b>Modified by:</b>\n
--!     Evangelia Gousiou (Evangelia.Gousiou@cern.ch)
--
--
--!   \n\n<b>Last changes:</b>\n
--!     -> 
--
--
---------------------------------------------------------------------------------------------------
--
--! @todo 
--! ->  
--
--------------------------------------------------------------------------------------------------- 

---/!\----------------------------/!\----------------------------/!\-------------------------/!\---
--                               Sunplify Premier D-2009.12 Warnings                             --
-- -- --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --
--                                         No Warnings!                                          --
---------------------------------------------------------------------------------------------------


--=================================================================================================
--!                           Entity declaration for wf_consumption
--=================================================================================================
entity wf_consumption is

  port (
  -- INPUTS 
	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- nanoFIP User Interface, General signals (synchronized with uclk) 

      uclk_i                  : in std_logic;

      --! wf_cons_bytes_processor : for the storage of data bytes to the RAM or the DATO bus
      slone_i                 : in std_logic;

	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- Signal from the WF_reset_unit unit
      nfip_urst_i             : in std_logic;

	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- nanoFIP FIELDRIVE (actually from the WF_inputs_synchronizer)
      fd_rxd_i                : in std_logic;
      fd_rxd_r_edge_p_i       : in std_logic;
      fd_rxd_f_edge_p_i       : in std_logic; 

	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- nanoFIP User Interface, WISHBONE Slave (synchronized with wb_clk)

      --! wf_cons_bytes_processor : for the managment of the Consumption RAM
      clk_wb_i                : in std_logic;                    
      wb_adr_i                : in std_logic_vector(9 downto 0);
      wb_stb_r_edge_p_i       : in std_logic;
      wb_cyc_i                : in std_logic;

	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- Signals from the WF_engine_control
      --! wf_cons_bytes_processor : for the reception coordination 
      var_i                   : in t_var;
      byte_ready_p_i          : in std_logic;
      byte_index_i            : in std_logic_vector (7 downto 0);

      --! wf_rx_deserializer  : for the reseting of the wf_rx_deserializer unit
      rst_rx_unit_p_i         : in std_logic;

	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- Signals from the WF_rx_tx_osc
      --! WF_rx_deglitcher & wf_rx_deserializer : for the timing of the reception
      signif_edge_window_i    : in std_logic;
      adjac_bits_window_i     : in std_logic;
      sample_bit_p_i          : in std_logic;
      sample_manch_bit_p_i    : in std_logic;

    -----------------------------------------------------------------------------------------------
  -- OUTPUTS 
    -- nanoFIP User Interface, WISHBONE Slave outputs 
      data_o                  : out std_logic_vector (15 downto 0);
      wb_ack_cons_p_o         : out std_logic;                     

    -- Signals to the WF_engine_control
      byte_o                  : out std_logic_vector (7 downto 0);
      byte_ready_p_o          : out std_logic;
      fss_received_p_o        : out std_logic;
      crc_wrong_p_o           : out std_logic;
      fss_crc_fes_viol_ok_p_o : out std_logic;
      cons_var_rst_byte_1_o   : out std_logic_vector (7 downto 0); 
      cons_var_rst_byte_2_o    : out std_logic_vector (7 downto 0);
      cons_ctrl_byte_o        : out std_logic_vector (7 downto 0);
      cons_pdu_byte_o         : out std_logic_vector (7 downto 0);        
      cons_lgth_byte_o        : out std_logic_vector (7 downto 0); 

    -- Signals to the WF_tx_rx_osc
      rst_rx_osc_o            : out std_logic
    );

end entity wf_consumption;



--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture struc of wf_consumption is

  signal s_rxd_filtered, s_rxd_filtered_f_edge_p : std_logic;
  signal s_sample_bit_p, s_sample_manch_bit_p    : std_logic;
  signal s_byte_from_rx                          : std_logic_vector (7 downto 0); 

--=================================================================================================
--                                      architecture begin
--================================================================================================= 

begin
---------------------------------------------------------------------------------------------------

    Consumption_Level_1 : wf_cons_bytes_processor 
    port map(
      uclk_i                => uclk_i,
      nfip_urst_i           => nfip_urst_i, 
      slone_i               => slone_i,
      byte_ready_p_i        => byte_ready_p_i,
      var_i                 => var_i,
      byte_index_i          => byte_index_i,
      byte_i                => s_byte_from_rx,
      clk_wb_i              => clk_wb_i,   
      wb_adr_i              => wb_adr_i,   
      wb_stb_r_edge_p_i     => wb_stb_r_edge_p_i,   
      wb_cyc_i              => wb_cyc_i, 
      -------------------------------------------------
      wb_ack_cons_p_o       => wb_ack_cons_p_o, 
      data_o                => data_o,
      cons_ctrl_byte_o      => cons_ctrl_byte_o,
      cons_pdu_byte_o       => cons_pdu_byte_o,         
      cons_lgth_byte_o      => cons_lgth_byte_o,
      cons_var_rst_byte_1_o => cons_var_rst_byte_1_o, 
      cons_var_rst_byte_2_o => cons_var_rst_byte_2_o
      -------------------------------------------------
      ); 


---------------------------------------------------------------------------------------------------
    Consumption_Level_0_Deserializer: wf_rx_deserializer 
    port map (
      uclk_i                  => uclk_i,
      nfip_urst_i             => nfip_urst_i,
      rst_rx_unit_p_i         => rst_rx_unit_p_i,
      sample_bit_p_i          => s_sample_bit_p,
      signif_edge_window_i    => signif_edge_window_i,
      adjac_bits_window_i     => adjac_bits_window_i,
      rxd_f_edge_p_i          => fd_rxd_f_edge_p_i,
      rxd_r_edge_p_i          => fd_rxd_r_edge_p_i,
      rxd_filtered_i          => s_rxd_filtered,
      rxd_filtered_f_edge_p_i => s_rxd_filtered_f_edge_p,
      sample_manch_bit_p_i    => s_sample_manch_bit_p,
      -------------------------------------------------
      byte_ready_p_o          => byte_ready_p_o,
      byte_o                  => s_byte_from_rx,
      fss_crc_fes_viol_ok_p_o => fss_crc_fes_viol_ok_p_o,
      rst_rx_osc_o            => rst_rx_osc_o,
      fss_received_p_o        => fss_received_p_o,
      crc_wrong_p_o           => crc_wrong_p_o
      -------------------------------------------------
      );
 

---------------------------------------------------------------------------------------------------
    Consumption_Level_0_Deglitcher : WF_rx_deglitcher 
    generic map (c_DEGLITCH_LGTH => 10)
    port map(
      uclk_i                  => uclk_i,
      nfip_urst_i             => nfip_urst_i,
      rxd_i                   => fd_rxd_i,
      sample_bit_p_i          => sample_bit_p_i,
      sample_manch_bit_p_i    => sample_manch_bit_p_i,
      -------------------------------------------------
      rxd_filtered_o          => s_rxd_filtered,
      rxd_filtered_f_edge_p_o => s_rxd_filtered_f_edge_p,
      sample_manch_bit_p_o    => s_sample_manch_bit_p,
      sample_bit_p_o          => s_sample_bit_p
      -------------------------------------------------
      );


 ---------------------------------------------------------------------------------------------------
      byte_o                  <= s_byte_from_rx;
  
end architecture struc;

--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------
