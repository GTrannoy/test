--_________________________________________________________________________________________________
--                                                                                                |
--                                        |The nanoFIP|                                           |
--                                                                                                |
--                                        CERN,BE/CO-HT                                           |
--________________________________________________________________________________________________|
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--! @file WF_consumption.vhd                                                                      |
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
--                                          WF_consumption                                       --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
--
--! @brief     The unit groups the main actions that regard data consumption.
--!            It instantiates the units:
--!
--!              o WF_cons_bytes_processor : for the handling of received RP_DAT data bytes as they
--!                                          arrive from the WF_fd_receiver (registration to the RAM
--!                                          or outputting to the DAT_O).
--!
--!
--!              o WF_cons_outcome         : for the validation of the consumed frame at the end of
--!                                          its arrival (in terms of FSS, Ctrl, PDU_TYPE, Lgth,
--!                                          CRC bytes & manch. encoding) and the generation of the
--!                                          "nanoFIP User Interface,NON-WISHBONE" outputs VAR1_RDY
--!                                          and VAR2_RDY (for var_1, var_2) or of the internal
--!                                          signals for the nanoFIP and FIELDRIVE resets (var_rst).
--!
--!                                ___________________________________________________________
--!                               |                       WF_consumption                      |
--!                               |                                                           |
--!                               |       _____________________________________________       |
--!                               |      |                                             |      |
--!                               |      |                WF_cons_outcome              |      |
--!                               |      |                                             |      |
--!                               |      |_____________________________________________|      |
--!                               |                                                           |
--!                               |       _____________________________________________       |
--!                               |      |                                             |      |
--!                               |      |            WF_cons_bytes_processor          |      |
--!                               |      |                                             |      |
--!                               |      |_____________________________________________|      |
--!                               |___________________________________________________________|
--!                                                            /\
--!                                ___________________________________________________________
--!                               |                                                           |
--!                               |                       WF_fd_receiver                      |
--!                               |___________________________________________________________|
--!                                                            /\
--!                             ___________________________________________________________________
--!                           0_____________________________FIELDBUS______________________________O
--!
--!
--!            Important Notice : The WF_rx_deserializer is "blindly" responsible for the formation
--!            of bytes arriving to the FD_RXD input. The bytes belong to either RP_DAT or ID_DAT
--!            frames. The WF_cons_bytes_processor is in charge of the RP_DATs, whereas the
--!            external unit WF_engine_control is in charge of the ID_DATs.
--!
--!            Note : In the entity declaration of this unit, below each input signal, we mark
--!            which of the instantiated units needs it.
--
--
--! @author    Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch) \n
--!            Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)     \n
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
--!   \n<b>Dependencies:</b>     \n
--!            WF_reset_unit     \n
--!            WF_fd_receiver    \n
--!            WF_engine_control \n
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



--=================================================================================================
--!                           Entity declaration for WF_consumption
--=================================================================================================
entity WF_consumption is

  port (
  -- INPUTS
	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- nanoFIP User Interface, General signals

      uclk_i                      : in std_logic;
      -- used by: all the units

      slone_i                     : in std_logic;
      -- used by: WF_cons_bytes_processor for selecting the data storage (RAM or DAT_O bus)
      -- used by: WF_cons_outcome for the VAR2_RDY signal (stand-alone mode does not treat var_2)


	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- nanoFIP WorldFIP Settings

       subs_i                     : in std_logic_vector (7 downto 0);
      -- used by: WF_cons_outcome for checking if the 2 bytes of a var_rst match the station's addr


	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- Signal from the WF_reset_unit

      nfip_rst_i                  : in std_logic;
      -- used by: all the units


	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- Signals from the WF_fd_receiver

      rx_byte_i                   : in std_logic_vector (7 downto 0);
      rx_byte_ready_p_i           : in std_logic;
      rx_fss_crc_fes_manch_ok_p_i : in std_logic;
      rx_crc_or_manch_wrong_p_i   : in std_logic;


	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- nanoFIP User Interface, WISHBONE Slave

      wb_clk_i                    : in std_logic;
      wb_adr_i                    : in std_logic_vector(8 downto 0);
      -- used by: WF_cons_bytes_processor for the managment of the Consumption RAM


	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- Signals from the WF_engine_control unit

      var_i                       : in t_var;
      -- used by: WF_cons_bytes_processor and WF_cons_outcome

      byte_index_i                : in std_logic_vector (7 downto 0);
      -- used by: WF_cons_bytes_processor for the reception coordination
      -- used by: WF_cons_outcome for the validation of the Length byte


    -----------------------------------------------------------------------------------------------
  -- OUTPUTS

    -- nanoFIP User Interface, NON-WISHBONE outputs
      var1_rdy_o                  : out std_logic;
      var2_rdy_o                  : out std_logic;

    -- nanoFIP User Interface, WISHBONE Slave outputs
      data_o                      : out std_logic_vector (15 downto 0);

    -- Signals to the WF_produce
      nfip_status_r_tler_p_o      : out std_logic;

    -- Signals to the WF_reset_unit
      assert_rston_p_o            : out std_logic;
      rst_nfip_and_fd_p_o         : out std_logic
    );

end entity WF_consumption;



--=================================================================================================
--!                                architecture declaration
--=================================================================================================
architecture struc of WF_consumption is

  signal s_cons_ctrl_byte, s_cons_pdu_byte, s_cons_lgth_byte       : std_logic_vector (7 downto 0);
  signal s_cons_var_rst_byte_1, s_cons_var_rst_byte_2              : std_logic_vector (7 downto 0);


--=================================================================================================
--!                                   architecture begin
--=================================================================================================
begin


---------------------------------------------------------------------------------------------------
--                                       Bytes Processing                                        --
---------------------------------------------------------------------------------------------------
--! @brief Instantiation of the WF_cons_bytes_processor unit that is "consuming" data bytes
--! arriving from the WF_rx_deserializer, by registering them to the Consumed memories or by
--! transferring them to the "nanoFIP User Interface, NON_WISHBONE" output bus DAT_O.

  Consumption_Bytes_Processor : WF_cons_bytes_processor
  port map (
    uclk_i                => uclk_i,
    nfip_rst_i            => nfip_rst_i,
    slone_i               => slone_i,
    byte_ready_p_i        => rx_byte_ready_p_i,
    var_i                 => var_i,
    byte_index_i          => byte_index_i,
    byte_i                => rx_byte_i,
    wb_clk_i              => wb_clk_i,
    wb_adr_i              => wb_adr_i,
   --------------------------------------------------------
    data_o                => data_o,
    cons_ctrl_byte_o      => s_cons_ctrl_byte,
    cons_pdu_byte_o       => s_cons_pdu_byte,
    cons_lgth_byte_o      => s_cons_lgth_byte,
    cons_var_rst_byte_1_o => s_cons_var_rst_byte_1,
    cons_var_rst_byte_2_o => s_cons_var_rst_byte_2);
   --------------------------------------------------------



---------------------------------------------------------------------------------------------------
--                                            Outcome                                           --
---------------------------------------------------------------------------------------------------
--! @brief Instantiation of the WF_cons_outcome unit that is generating :
--! the "nanoFIP User Interface, NON_WISHBONE" output signal  R_TLER,
--! the "nanoFIP User Interface, NON_WISHBONE" output signals VAR1_RDY & VAR2_RDY (for a var_1/2) or
--! the  nanoFIP internal signals rst_nFIP_and_FD_p and assert_RSTON_p            (for a var_rst).

  Consumption_Outcome : WF_cons_outcome
  port map (
    uclk_i                      => uclk_i,
    slone_i                     => slone_i,
    subs_i                      => subs_i,
    nfip_rst_i                  => nfip_rst_i,
    rx_fss_crc_fes_manch_ok_p_i => rx_fss_crc_fes_manch_ok_p_i,
    rx_crc_or_manch_wrong_p_i   => rx_crc_or_manch_wrong_p_i,
    var_i                       => var_i,
    rx_byte_index_i             => byte_index_i,
    cons_ctrl_byte_i            => s_cons_ctrl_byte,
    cons_pdu_byte_i             => s_cons_pdu_byte,
    cons_lgth_byte_i            => s_cons_lgth_byte,
    cons_var_rst_byte_1_i       => s_cons_var_rst_byte_1,
    cons_var_rst_byte_2_i       => s_cons_var_rst_byte_2,
   --------------------------------------------------------
    var1_rdy_o                  => var1_rdy_o,
    var2_rdy_o                  => var2_rdy_o,
    nfip_status_r_tler_p_o      => nfip_status_r_tler_p_o,
    assert_rston_p_o            => assert_rston_p_o,
    rst_nfip_and_fd_p_o         => rst_nfip_and_fd_p_o);
   --------------------------------------------------------


end architecture struc;
--=================================================================================================
--                                        architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------