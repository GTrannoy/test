--_________________________________________________________________________________________________
--                                                                                                |
--                                        |The nanoFIP|                                           |
--                                                                                                |
--                                        CERN,BE/CO-HT                                           |
--________________________________________________________________________________________________|
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--! @file WF_production.vhd
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
--                                          WF_production                                        --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
--
--! @brief     The unit gathers the main actions that regard data production.
--!            It instantiates the units:
--!
--!              o WF_tx_serializerr       : that receives bytes from the WF_prod_bytes_retriever,
--!                                          encodes them (Manchester 2), adds the FSS, FCS & FES
--!                                          fields and puts one by one the encoded bits to the 
--!                                          FIELDRIVE output FD_TXD.   
--!              o WF_prod_bytes_retriever : that retreives user-data bytes from the Produced RAM 
--!                                          or the "nanoFIP User Interface, NON-WISHBONE" data bus
--!                                          DAT_I, and other bytes(PDU,LGTH,Ctrl,MPS,nFIP status)
--!                                          from the WF_package, WF_status_bytes_gen,
--!                                          WF_prod_data_lgth_calc units.
--!              o WF_status_bytes_gen     : that receives information from the WF_consumption
--!                                          
--!              o WF_prod_permit          : that handles the"nanoFIP User Interface, NON-WISHBONE"
--!                                          signal VAR3_RDY
--!
--!                                __       _________________________________
--!                               |        |                                 | 
--!                            Level 2     |          WF_prod_permit         | 
--!                               |__      |_________________________________|
--!                                                         ^
--!                                __       _________________________________     ________________
--!                               |        |                                 |   |                |
--!                           Level 1      |      WF_prod_bytes_retriever    | < | WF_status_bytes|
--!                               |        |                                 |   |      _gen      |
--!                               |__      |_________________________________|   |________________|
--!                                                         ^
--!                                __       _________________________________
--!                               |        |                                 | 
--!                            Level 0     |         WF_tx_serializerr       |
--!                               |__      |_________________________________|
--! 
--!                          _______________________________________________________________
--!                         0__________________________FIELDBUS____________________________O    

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
--!     WF_prod_bytes_retriever \n
--!     WF_status_bytes_gen     \n
--!     WF_tx_serializer        \n
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
--!                           Entity declaration for WF_production
--=================================================================================================

entity WF_production is

  port (
  -- INPUTS 
	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- nanoFIP User Interface, General signals (synchronized with uclk) 

      uclk_i                  : in std_logic;

      --! WF_prod_bytes_retriever : for the selection of data bytes from the RAM or the DATI bus
      --! WF_status_bytes_gen : the MPS status byte is different according to the operational mode
      slone_i                 : in std_logic;
                                           
      --! WF_prod_bytes_retriever : for the delivery or not of the nanoFIP status byte
      nostat_i                : in std_logic;

	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- Signal from the WF_reset_unit unit
      nfip_rst_i              : in std_logic;

	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- nanoFIP User Interface, WISHBONE Slave (synchronized with wb_clk)

      --! WF_prod_bytes_retriever : for the managment of the Production RAM
      wb_clk_i                : in std_logic;                    
      wb_adr_i                : in std_logic_vector(9 downto 0);
      wb_data_i               : in std_logic_vector(7 downto 0);
      wb_cyc_i                : in std_logic;
      wb_stb_r_edge_p_i       : in std_logic;
      wb_we_i                 : in std_logic; 

	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- nanoFIP User Interface, NON-WISHBONE (synchronized with uclk)

      --! WF_prod_bytes_retriever : for the bytes retreival in stand-alone mode
      slone_data_i            : in std_logic_vector(15 downto 0);

      --! WF_status_bytes_gen : for the nanoFIP status byte, bits 2, 3
      var1_acc_i              : in std_logic; 
      var2_acc_i              : in std_logic; 
      var3_acc_i              : in std_logic;

	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- nanoFIP FIELDRIVE (synchronized with uclk)

      --! WF_status_bytes_gen : for the nanoFIP status byte, bits 6, 7
      fd_txer_i               : in  std_logic;
      fd_wdgn_i               : in  std_logic;

	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- Signals from the WF_engine_control

      --! WF_prod_bytes_retriever : for the definition of the bytes to be delivered
      byte_index_i            : in std_logic_vector (7 downto 0);
      data_length_i           : in std_logic_vector (7 downto 0);
      var_i                   : in t_var;      

      --! WF_tx_serializer : for the delivery coordination
      byte_ready_p_i          : in std_logic;
      last_byte_p_i           : in std_logic;
      start_prod_p_i          : in std_logic;


	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- Signals from the WF_consumption
      --! WF_status_bytes_gen : for the generation of the nanoFIP status byte, bits 2, 4, 5 
      var1_rdy_i              : in std_logic;
      var2_rdy_i              : in std_logic;
      nfip_status_r_fcser_p_i : in std_logic;
      nfip_status_r_tler_i    : in std_logic;

	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- Signal from the WF_rx_tx_osc

      -- WF_tx_serializer : for the transmission synchronization
      tx_clk_p_buff_i         : in std_logic_vector (c_TX_CLK_BUFF_LGTH-1 downto 0);
   
 	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --	
    -- Signals from the WF_model_constr_decoder unit

      --! WF_prod_bytes_retriever : for the production of a var_identif
      constr_id_dec_i         : in  std_logic_vector (7 downto 0);
      model_id_dec_i          : in  std_logic_vector (7 downto 0);

  -------------------------------------------------------------------------------------------------
  -- OUTPUTS
	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- Signal to the WF_engine_control
      request_byte_p_o        : out std_logic;

	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- nanoFIP FIELDRIVE outputs
      tx_data_o               : out std_logic; --! transmitter data
      tx_enable_o             : out std_logic; --! transmitter enable

	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- nanoFIP User Interface, NON-WISHBONE outputs
      u_cacer_o               : out std_logic; --! nanoFIP status byte, bit 2
      r_fcser_o               : out std_logic; --! nanoFIP status byte, bit 5
      u_pacer_o               : out std_logic; --! nanoFIP status byte, bit 3
      r_tler_o                : out std_logic; --! nanoFIP status byte, bit 4
      var3_rdy_o              : out std_logic; --! signals the user that data can safely be written

	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- nanoFIP User Interface, WISHBONE Slave (synchronized with wb_clk) output
      wb_ack_prod_p_o         : out std_logic  --! WISHBONE acknowledge

      );
end entity WF_production;


--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture struc of WF_production is

  signal s_byte_to_tx, s_stat, s_mps      : std_logic_vector (7 downto 0);       
  signal s_var3_rdy, s_rst_status_bytes_p : std_logic;
 

--=================================================================================================
--                                      architecture begin
--=================================================================================================  
begin


---------------------------------------------------------------------------------------------------
--                             Production Level 3 : VAR3_RDY generator                           --
--------------------------------------------------------------------------------------------------- 
  VAR3_RDY_generation: WF_prod_permit
  port map(
    uclk_i      => uclk_i,
    nfip_rst_i  => nfip_rst_i,
    var_i       => var_i,
      -----------------------------------------------
    var3_rdy_o  => s_var3_rdy
      -----------------------------------------------
      );



---------------------------------------------------------------------------------------------------
--                               Production Level 1 : Bytes Retreival                            --
--------------------------------------------------------------------------------------------------- 
--!@brief Instantiation of the WF_prod_bytes_retriever unit

    production_level_1 : WF_prod_bytes_retriever
    port map(
      uclk_i               => uclk_i, 
      model_id_dec_i       => model_id_dec_i, 
      constr_id_dec_i      => constr_id_dec_i,
      slone_i              => slone_i,  
      nostat_i             => nostat_i, 
      nfip_rst_i           => nfip_rst_i,
      wb_clk_i             => wb_clk_i,   
      wb_adr_i             => wb_adr_i,   
      wb_stb_r_edge_p_i    => wb_stb_r_edge_p_i, 
      wb_cyc_i             => wb_cyc_i,  
      wb_we_i              => wb_we_i, 
      nFIP_status_byte_i   => s_stat,  
      mps_status_byte_i    => s_mps,
      var_i                => var_i,  
      byte_index_i         => byte_index_i,  
      byte_ready_p_i       => byte_ready_p_i,
      data_length_i        => data_length_i, 
      wb_data_i            => wb_data_i,
      slone_data_i         => slone_data_i,
      var3_rdy_i           => s_var3_rdy,
      -----------------------------------------------
      rst_status_bytes_p_o => s_rst_status_bytes_p, 
      byte_o               => s_byte_to_tx,
      wb_ack_prod_p_o      => wb_ack_prod_p_o  
      -----------------------------------------------
      );



---------------------------------------------------------------------------------------------------
--                           Production Level 1 : Status Byte generation                         --
--------------------------------------------------------------------------------------------------- 
--!@brief Instantiation of the WF_status_bytes_gen unit

    status_bytes_gen : WF_status_bytes_gen 
    port map(
      uclk_i                  => uclk_i,
      nfip_rst_i              => nfip_rst_i,
      slone_i                 => slone_i,
      fd_wdgn_i               => fd_wdgn_i,
      fd_txer_i               => fd_txer_i,
      nfip_status_r_fcser_p_i => nfip_status_r_fcser_p_i,
      var1_rdy_i              => var1_rdy_i,
      var2_rdy_i              => var2_rdy_i,
      var3_rdy_i              => s_var3_rdy,
      var1_acc_i              => var1_acc_i,
      var2_acc_i              => var2_acc_i,
      var3_acc_i              => var3_acc_i,
      nfip_status_r_tler_i    => nfip_status_r_tler_i,
      rst_status_bytes_p_i    => s_rst_status_bytes_p,
      -----------------------------------------------
      u_cacer_o               => u_cacer_o,
      u_pacer_o               => u_pacer_o,
      r_tler_o                => r_tler_o,
      r_fcser_o               => r_fcser_o,
      nFIP_status_byte_o      => s_stat,
      mps_status_byte_o       => s_mps
      -----------------------------------------------
      );



---------------------------------------------------------------------------------------------------
--                                Production Level 0 : Serializer                                --
--------------------------------------------------------------------------------------------------- 
--!@brief Instantiation of the WF_tx_serializer unit

    production_level_0: WF_tx_serializer 
    generic map(c_TX_CLK_BUFF_LGTH => c_TX_CLK_BUFF_LGTH)
    PORT MAP(
      uclk_i            => uclk_i,
      nfip_rst_i        => nfip_rst_i,
      start_prod_p_i    => start_prod_p_i,
      byte_ready_p_i    => byte_ready_p_i,
      byte_i            => s_byte_to_tx,
      last_byte_p_i     => last_byte_p_i,
      tx_clk_p_buff_i   => tx_clk_p_buff_i,
      -----------------------------------------------
      tx_data_o         => tx_data_o,
      request_byte_p_o  => request_byte_p_o,
      tx_enable_o       => tx_enable_o
      -----------------------------------------------
      );

    var3_rdy_o  <= s_var3_rdy;


end architecture struc;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------