--_________________________________________________________________________________________________
--                                                                                                |
--                                        |The nanoFIP|                                           |
--                                                                                                |
--                                        CERN,BE/CO-HT                                           |
--________________________________________________________________________________________________|
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--! @file WF_production.vhd                                                                       |
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
--                                         WF_production                                         --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
--
--! @brief     The unit groups the main actions that regard data production.
--!            It instantiates the units:
--!
--!              o WF_tx_serializer       : that receives bytes from the WF_prod_bytes_retriever,
--!                                         encodes them (Manchester 2), adds the FSS, FCS & FES
--!                                         fields and puts one by one bits to the FIELDRIVE output
--!                                         FD_TXD. Also handles the nanoFIP output FD_TXENA.   
--!
--!              o WF_prod_bytes_retriever: that retrieves
--!                                           o user-data bytes: from the Produced RAM or the
--!                                             "nanoFIP User Interface, NON-WISHBONE" bus DAT_I, 
--!                                           o PDU,Ctrl bytes : from the WF_package 
--!                                           o MPS,nFIP status: from the WF_status_bytes_gen
--!                                           o LGTH byte      : from the WF_prod_data_lgth_calc
--!                                         and following the signals from the external unit
--!                                         WF_engine_control forwards them to the WF_tx_serializer. 
--!
--!              o WF_status_bytes_gen     : that receives information from the WF_consumption unit,
--!                                          the "FIELDRIVE" and "User Interface,NON-WISHBONE"inputs
--!                                          and outputs, for the generation of the nanoFIP & MPS
--!                                          status bytes 
--!                                          
--!              o WF_prod_permit          : that signals the user that a variable can safely be
--!                                          written (through the "nanoFIP User Interface,
--!                                          NON-WISHBONE" signal VAR3_RDY)
--!
--!                                         _________________________________
--!                                        |                                 | 
--!                                        |          WF_prod_permit         | 
--!                                        |_________________________________|
--!                                                         ^
--!                                         _________________________________     ________________
--!                                        |                                 |   |                |
--!                                        |      WF_prod_bytes_retriever    | < | WF_status_bytes|
--!                                        |                                 |   |      _gen      |
--!                                        |_________________________________|   |________________|
--!                                                         ^
--!                                         _________________________________
--!                                        |                                 | 
--!                                        |         WF_tx_serializerr       |
--!                                        |_________________________________|
--!                                                         ^
--!                          _______________________________________________________________
--!                         0__________________________FIELDBUS____________________________O    
--!
--!            Note: In the entity declaration of this unit, below each input signal, we mark
--!            which of the instantiated units needs it.     
--!
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
--!   \n<b>Dependencies:</b>           \n
--!            WF_reset_unit           \n
--!            WF_consumption          \n
--!            WF_engine_control       \n
--!            WF_tx_rx_osc            \n
--!            WF_model_constr_decoder \n
--
--
--!   \n<b>Modified by:</b>\n
--
---------------------------------------------------------------------------------------------------
--
--!   \n\n<b>Last changes:</b>\n
--!     -> 
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

      slone_i                 : in std_logic;
      -- used by: WF_prod_bytes_retriever for the selection of data bytes from the RAM or the DAT_I
      -- used by: WF_status_bytes_gen because the MPS status is different in memory & stand-alone                                          

      nostat_i                : in std_logic;
      -- used by: WF_prod_bytes_retriever for the delivery or not of the nanoFIP status byte


	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- Signal from the WF_reset_unit unit

      nfip_rst_i              : in std_logic;


	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- nanoFIP User Interface, WISHBONE Slave

      wb_clk_i                : in std_logic;                    
      wb_adr_i                : in std_logic_vector(8 downto 0);
      wb_data_i               : in std_logic_vector(7 downto 0);
       -- used by: WF_prod_bytes_retriever for the managment of the Production RAM


	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- Signal from the WF_wb_controller

      wb_ack_prod_p_i         : in std_logic;  
       -- used by: WF_prod_bytes_retriever for the latching of the wb_data_i

 
	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- nanoFIP User Interface, NON-WISHBONE (synchronized with uclk)

      slone_data_i            : in std_logic_vector(15 downto 0);
      -- used by: WF_prod_bytes_retriever for the bytes retreival in stand-alone mode

      var1_acc_i              : in std_logic; 
      var2_acc_i              : in std_logic; 
      var3_acc_i              : in std_logic;
      -- used by: WF_status_bytes_gen for the nanoFIP status byte, bits 2, 3


	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- nanoFIP FIELDRIVE (synchronized with uclk)

      fd_txer_i               : in  std_logic;
      fd_wdgn_i               : in  std_logic;
      -- used by: WF_status_bytes_gen for the nanoFIP status byte, bits 6, 7


	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- Signals from the WF_engine_control

      byte_index_i            : in std_logic_vector (7 downto 0);
      data_length_i           : in std_logic_vector (7 downto 0);
      var_i                   : in t_var;-- also for the WF_prod_permit for the VAR3_RDY generation
      -- used by: WF_prod_bytes_retriever for the definition of the bytes to be delivered

      byte_request_accept_p_i : in std_logic;
      last_byte_p_i           : in std_logic;
      start_prod_p_i          : in std_logic;
      -- used by: WF_tx_serializer for the delivery coordination


	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- Signals from the WF_consumption

      var1_rdy_i              : in std_logic;
      var2_rdy_i              : in std_logic;
      nfip_status_r_fcser_p_i : in std_logic;
      nfip_status_r_tler_i    : in std_logic;
      -- used by: WF_status_bytes_gen for the generation of the nanoFIP status byte, bits 2, 4, 5 


	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- Signal from the WF_rx_tx_osc

      tx_clk_p_buff_i         : in std_logic_vector (c_TX_CLK_BUFF_LGTH-1 downto 0);
      -- used by: WF_tx_serializer for the transmission synchronization

   
 	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --	
    -- Signals from the WF_model_constr_decoder unit

      constr_id_dec_i         : in  std_logic_vector (7 downto 0);
      model_id_dec_i          : in  std_logic_vector (7 downto 0);
      -- used by: WF_prod_bytes_retriever for the production of a var_identif


  -------------------------------------------------------------------------------------------------
  -- OUTPUTS


    -- Signal to the WF_engine_control
      byte_request_p_o        : out std_logic;--! request for a new byte to be transmitted; pulse
                                              --! at the end of the transmission of a previous byte


    -- nanoFIP FIELDRIVE outputs
      tx_data_o               : out std_logic; --! transmitter data
      tx_enable_o             : out std_logic; --! transmitter enable


    -- nanoFIP User Interface, NON-WISHBONE outputs
      u_cacer_o               : out std_logic; --! nanoFIP status byte, bit 2
      r_fcser_o               : out std_logic; --! nanoFIP status byte, bit 5
      u_pacer_o               : out std_logic; --! nanoFIP status byte, bit 3
      r_tler_o                : out std_logic; --! nanoFIP status byte, bit 4
      var3_rdy_o              : out std_logic  --! signals the user that data can safely be written

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
--                                       Production Permit                                       --
--------------------------------------------------------------------------------------------------- 
--! @brief Instantiation of the WF_prod_permit unit

  production_VAR3_RDY_generation: WF_prod_permit
  port map(
    uclk_i      => uclk_i,
    nfip_rst_i  => nfip_rst_i,
    var_i       => var_i,
      -----------------------------------------------
    var3_rdy_o  => s_var3_rdy
      -----------------------------------------------
      );



---------------------------------------------------------------------------------------------------
--                                          Bytes Retreival                                      --
--------------------------------------------------------------------------------------------------- 
--!@brief Instantiation of the WF_prod_bytes_retriever unit

    production_bytes_retriever : WF_prod_bytes_retriever
    port map(
      uclk_i               => uclk_i, 
      model_id_dec_i       => model_id_dec_i, 
      constr_id_dec_i      => constr_id_dec_i,
      slone_i              => slone_i,  
      nostat_i             => nostat_i, 
      nfip_rst_i           => nfip_rst_i,
      wb_clk_i             => wb_clk_i,   
      wb_adr_i             => wb_adr_i,   
      wb_ack_prod_p_i      => wb_ack_prod_p_i,
      nFIP_status_byte_i   => s_stat,  
      mps_status_byte_i    => s_mps,
      var_i                => var_i,  
      byte_index_i         => byte_index_i,  
      byte_being_sent_p_i  => byte_request_accept_p_i,
      data_length_i        => data_length_i, 
      wb_data_i            => wb_data_i,
      slone_data_i         => slone_data_i,
      var3_rdy_i           => s_var3_rdy,
      -----------------------------------------------
      rst_status_bytes_p_o => s_rst_status_bytes_p, 
      byte_o               => s_byte_to_tx
      -----------------------------------------------
      );



---------------------------------------------------------------------------------------------------
--                                    Status Byte Generation                                     --
--------------------------------------------------------------------------------------------------- 
--!@brief Instantiation of the WF_status_bytes_gen unit

    production_status_bytes_generator : WF_status_bytes_gen 
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
--                                           Serializer                                          --
--------------------------------------------------------------------------------------------------- 
--!@brief Instantiation of the WF_tx_serializer unit

    production_serializer: WF_tx_serializer 
    generic map(c_TX_CLK_BUFF_LGTH => c_TX_CLK_BUFF_LGTH)
    PORT MAP(
      uclk_i                   => uclk_i,
      nfip_rst_i               => nfip_rst_i,
      start_prod_p_i           => start_prod_p_i,
      byte_request_accept_p_i  => byte_request_accept_p_i,
      byte_i                   => s_byte_to_tx,
      last_byte_p_i            => last_byte_p_i,
      tx_clk_p_buff_i          => tx_clk_p_buff_i,
      -----------------------------------------------
      tx_data_o                => tx_data_o,
      byte_request_p_o         => byte_request_p_o,
      tx_enable_o              => tx_enable_o
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