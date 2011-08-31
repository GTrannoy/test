--_________________________________________________________________________________________________
--                                                                                                |
--                                        |The nanoFIP|                                           |
--                                                                                                |
--                                        CERN,BE/CO-HT                                           |
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--                                                                                               --
--                                          WF_consumption                                       --
--                                                                                               --
---------------------------------------------------------------------------------------------------
-- File         WF_consumption.vhd 
--
-- Description  The unit groups the main actions that regard data consumption.
--              It instantiates the units:
--
--              o WF_cons_bytes_processor : for the handling of consumed RP_DAT data bytes as they
--                                          arrive from the WF_fd_receiver (registration to the RAM
--                                          or outputting to the DAT_O).
--
--
--              o WF_cons_outcome         : for the validation of the consumed frame at the end of
--                                          its arrival (in terms of FSS, Ctrl, PDU_TYPE, Lgth &
--                                          CRC bytes) and the generation of the
--                                          "nanoFIP User Interface,NON-WISHBONE" outputs VAR1_RDY
--                                          and VAR2_RDY (for var_1, var_2) or of the internal
--                                          signals for the nanoFIP and the FIELDRIVE resets (var_rst).
--
--                                ___________________________________________________________
--                               |                       WF_consumption                      |
--                               |                                                           |
--                               |       _____________________________________________       |
--                               |      |                                             |      |
--                               |      |                WF_cons_outcome              |      |
--                               |      |                                             |      |
--                               |      |_____________________________________________|      |
--                               |                                                           |
--                               |       _____________________________________________       |
--                               |      |                                             |      |
--                               |      |            WF_cons_bytes_processor          |      |
--                               |      |                                             |      |
--                               |      |_____________________________________________|      |
--                               |___________________________________________________________|
--                                                            /\
--                                ___________________________________________________________
--                               |                                                           |
--                               |                       WF_fd_receiver                      |
--                               |___________________________________________________________|
--                                                            /\
--                             ___________________________________________________________________
--                           0_____________________________FIELDBUS______________________________O
--
--
--              Note : In the entity declaration of this unit, below each input signal, we mark
--              for which of the instantiated units it is essential.
--
--
-- Authors      Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)
--              Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)
-- Date         11/01/2011
-- Version      v0.01
-- Depends on   WF_reset_unit
--              WF_fd_receiver
--              WF_engine_control
----------------
-- Last changes
--     01/2011  EG  v0.01  first version
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
--                               GNU LESSER GENERAL PUBLIC LICENSE                                |
--                              ------------------------------------                              |
-- This source file is free software; you can redistribute it and/or modify it under the terms of |
-- the GNU Lesser General Public License as published by the Free Software Foundation; either     |
-- version 2.1 of the License, or (at your option) any later version.                             |
-- This source is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;       |
-- without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.      |
-- See the GNU Lesser General Public License for more details.                                    |
-- You should have received a copy of the GNU Lesser General Public License along with this       |
-- source; if not, download it from http://www.gnu.org/licenses/lgpl-2.1.html                     |
---------------------------------------------------------------------------------------------------



--=================================================================================================
--                                      Libraries & Packages
--=================================================================================================

-- Standard library
library IEEE;
use IEEE.STD_LOGIC_1164.all; -- std_logic definitions
use IEEE.NUMERIC_STD.all;    -- conversion functions
-- Specific library
library work;
use work.WF_PACKAGE.all;     -- definitions of types, constants, entities


--=================================================================================================
--                           Entity declaration for WF_consumption
--=================================================================================================
entity WF_consumption is

  port (
  -- INPUTS
	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- nanoFIP User Interface, General signals

      uclk_i                 : in std_logic;
      -- used by: all the units

      slone_i                : in std_logic;
      -- used by: WF_cons_bytes_processor for selecting the data storage (RAM or DAT_O bus)
      -- used by: WF_cons_outcome for the VAR2_RDY signal (stand-alone mode does not treat var_2)


	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- nanoFIP WorldFIP Settings

       subs_i                : in std_logic_vector (7 downto 0);
      -- used by: WF_cons_outcome for checking if the 2 bytes of a var_rst match the station's addr


	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- Signal from the WF_reset_unit

      nfip_rst_i             : in std_logic;
      -- used by: all the units


	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- Signals from the WF_fd_receiver

      rx_byte_i              : in std_logic_vector (7 downto 0);
      rx_byte_ready_p_i      : in std_logic;
      -- used by: WF_cons_bytes_processor

      rx_fss_crc_fes_ok_p_i  : in std_logic;
      rx_crc_wrong_p_i       : in std_logic;
      -- used by: WF_cons_outcome


	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- nanoFIP User Interface, WISHBONE Slave

      wb_clk_i               : in std_logic;
      wb_adr_i               : in std_logic_vector (8 downto 0);
      -- used by: WF_cons_bytes_processor for the managment of the Consumption RAM


	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- Signals from the WF_engine_control unit

      cons_bytes_excess_i    : in std_logic;
      -- used by: WF_cons_outcome

      var_i                  : in t_var;
      -- used by: WF_cons_bytes_processor and WF_cons_outcome

      byte_index_i           : in std_logic_vector (7 downto 0);
      -- used by: WF_cons_bytes_processor for the reception coordination
      -- used by: WF_cons_outcome for the validation of the Length byte


	--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- Signal from the WF_jtag_controller unit
    jc_mem_adr_rd_i          : in std_logic_vector (8 downto 0);


    -----------------------------------------------------------------------------------------------
  -- OUTPUTS

    -- nanoFIP User Interface, NON-WISHBONE outputs
      var1_rdy_o             : out std_logic;
      var2_rdy_o             : out std_logic;

    -- Signals to the WF_jtag_controller
      jc_start_p_o           : out std_logic;

    -- nanoFIP User Interface, WISHBONE Slave outputs
      data_o                 : out std_logic_vector (15 downto 0);

    -- Signals to the WF_production
      nfip_status_r_tler_p_o : out std_logic;

    -- Signals to the WF_reset_unit
      assert_rston_p_o       : out std_logic;
      rst_nfip_and_fd_p_o    : out std_logic;

    -- Signals to the WF_jtag_controller unit
    jc_mem_data_o            : out std_logic_vector (7 downto 0)
    );

end entity WF_consumption;



--=================================================================================================
--                                architecture declaration
--=================================================================================================
architecture struc of WF_consumption is

  signal s_cons_ctrl_byte, s_cons_pdu_byte, s_cons_lgth_byte : std_logic_vector (7 downto 0);
  signal s_cons_var_rst_byte_1, s_cons_var_rst_byte_2        : std_logic_vector (7 downto 0);

--=================================================================================================
--                                       architecture begin
--=================================================================================================
begin


---------------------------------------------------------------------------------------------------
--                                   Consumed Bytes Processing                                   --
---------------------------------------------------------------------------------------------------

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
    jc_mem_adr_rd_i       => jc_mem_adr_rd_i,
   --------------------------------------------------------
    data_o                => data_o,
    jc_mem_data_o         => jc_mem_data_o,
    cons_ctrl_byte_o      => s_cons_ctrl_byte,
    cons_pdu_byte_o       => s_cons_pdu_byte,
    cons_lgth_byte_o      => s_cons_lgth_byte,
    cons_var_rst_byte_1_o => s_cons_var_rst_byte_1,
    cons_var_rst_byte_2_o => s_cons_var_rst_byte_2);
   --------------------------------------------------------



---------------------------------------------------------------------------------------------------
--                                      Consumption Outcome                                      --
---------------------------------------------------------------------------------------------------

  Consumption_Outcome : WF_cons_outcome
  port map (
    uclk_i                 => uclk_i,
    slone_i                => slone_i,
    subs_i                 => subs_i,
    nfip_rst_i             => nfip_rst_i,
    rx_fss_crc_fes_ok_p_i  => rx_fss_crc_fes_ok_p_i,
    rx_crc_wrong_p_i       => rx_crc_wrong_p_i,
    cons_bytes_excess_i    => cons_bytes_excess_i,
    var_i                  => var_i,
    byte_index_i           => byte_index_i,
    cons_ctrl_byte_i       => s_cons_ctrl_byte,
    cons_pdu_byte_i        => s_cons_pdu_byte,
    cons_lgth_byte_i       => s_cons_lgth_byte,
    cons_var_rst_byte_1_i  => s_cons_var_rst_byte_1,
    cons_var_rst_byte_2_i  => s_cons_var_rst_byte_2,
   --------------------------------------------------------
    var1_rdy_o             => var1_rdy_o,
    var2_rdy_o             => var2_rdy_o,
    jc_start_p_o           => jc_start_p_o,
    nfip_status_r_tler_p_o => nfip_status_r_tler_p_o,
    assert_rston_p_o       => assert_rston_p_o,
    rst_nfip_and_fd_p_o    => rst_nfip_and_fd_p_o);
   --------------------------------------------------------


end architecture struc;
--=================================================================================================
--                                        architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------