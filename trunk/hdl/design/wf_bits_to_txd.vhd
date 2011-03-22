--_________________________________________________________________________________________________
--                                                                                                |
--                                        |The nanoFIP|                                           |
--                                                                                                |
--                                        CERN,BE/CO-HT                                           |
--________________________________________________________________________________________________|
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--! @file WF_bits_to_txd.vhd                                                                      |
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
--                                        WF_bits_to_txd                                         --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
--
--! @brief     According to the state of the FSM of the WF_tx_serializer, the unit is responsible
--!            for putting in nanoFIP's output FD_TXD one by one all the bits required for the
--!            formation of the RP_DAT frame (that is: manch. encoded FSS, data, CRC and FES bits).
--!            The unit also manages the output FD_TXENA.
--
--
--! @author    Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch) \n
--!            Evangelia Gousiou (Evangelia.Gousiou@cern.ch)         \n
--
--
--! @date      07/01/2011
--
--
--! @version   v0.03
--
--
--! @details \n
--
--!   \n<b>Dependencies:</b>\n
--!            WF_reset_unit    \n
--!            WF_tx_osc        \n
--!            WF_tx_serializer \n
--
--
--!   \n<b>Modified by:</b>\n
--!            Evangelia Gousiou (Evangelia.Gousiou@cern.ch)
--
---------------------------------------------------------------------------------------------------
--
--!   \n\n<b>Last changes:</b>\n
--!     ->   8/2010  v0.02  EG  tx_enable has to be synched with txd! sending_fss not enough;
--!                             need for tx_clk_p_buff signal
--!     -> 7/1/2011  v0.03  EG  tx_enable now starts 1 uclk tick earlier, at the same moment as txd
--!                             becomes 1 for the 1st bit of preamble
--!                             signals s_tx_enable & s_start_tx_enable removed for simplification
--
---------------------------------------------------------------------------------------------------
--
--! @todo
--!   ->
--
---------------------------------------------------------------------------------------------------



--=================================================================================================
--!                           Entity declaration for WF_bits_to_txd
--=================================================================================================

entity WF_bits_to_txd is
  port (
  -- INPUTS
    -- nanoFIP User Interface, General signals
    uclk_i              : in std_logic;                     --! 40 MHz clock

    -- Signal from the WF_reset_unit
    nfip_rst_i          : in std_logic;                     --! nanoFIP internal reset

   -- Signals from the WF_tx_serializer unit
    crc_byte_manch_i    : in std_logic_vector (31 downto 0);--! manch. encoded CRC bytes to be sent
    data_byte_manch_i   : in std_logic_vector (15 downto 0);--! manch. encoded data byte to be sent
    sending_fss_i       : in std_logic;                     --! WF_tx_serializer FSM states
    sending_data_i      : in std_logic;                     --! -------"----"-----"--------
    sending_crc_i       : in std_logic;                     --! -------"----"-----"--------
    sending_fes_i       : in std_logic;                     --! -------"----"-----"--------
    stop_transmission_i : in std_logic;                     --! -------"----"-----"--------
    txd_bit_index_i     : in unsigned(4 downto 0);          --! index of a bit inside a byte


    -- Signals from the WF_tx_osc unit
    tx_clk_p_i          : in std_logic;                     --!clk for transmission synchronization


  -- OUTPUTS
    -- nanoFIP FIELDRIVE outputs
    txd_o               : out std_logic;                    --! FD_TXD
    tx_enable_o         : out std_logic                     --! FD_TXENA
      );
end entity WF_bits_to_txd;


--=================================================================================================
--!                                    architecture declaration
--=================================================================================================
architecture rtl of WF_bits_to_txd is


--=================================================================================================
--!                                       architecture begin
--=================================================================================================
begin

---------------------------------------------------------------------------------------------------
--! @brief Synchronous process Bits_Delivery: handling of nanoFIP output signal FD_TXD by
--! placing bits of data according to the state of WF_tx_serializer's state machine (sending_fss,
--! sending_data, sending_crc, sending_fes, stop_transmission) and to the counter txd_bit_index.
--! The delivery is synchronised by the tx_clk_p_buff(1) signal.

  Bits_Delivery: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if nfip_rst_i = '1' then
        txd_o     <= '0';

      else

        if  tx_clk_p_i = '1' then

          if sending_fss_i = '1' then
            txd_o <= c_FSS (to_integer (txd_bit_index_i));   -- FSS: 2 bytes long (no need to resize)

          elsif sending_data_i = '1' then
            txd_o <= data_byte_manch_i (to_integer (resize(txd_bit_index_i, 4)));    -- 1 data-byte

          elsif sending_crc_i = '1' then
            txd_o <= crc_byte_manch_i (to_integer (txd_bit_index_i));          -- CRC: 2 bytes long

          elsif sending_fes_i = '1' then
            txd_o <= c_FES(to_integer (resize(txd_bit_index_i,4)));                  -- FES: 1 byte

          else
            txd_o <= '0';

          end if;
        end if;
      end if;
    end if;
  end process;



---------------------------------------------------------------------------------------------------
--!@brief Synchronous process FD_TXENA_Generator: The nanoFIP output FD_TXENA is activated at the
--! same moment as the first bit of the PRE starts being delivered and stays asserted until the
--! end of the delivery of the last FES bit.

  FD_TXENA_Generator: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if nfip_rst_i = '1' then
        tx_enable_o     <= '0';

      else

        if ((sending_fss_i = '1') or (sending_data_i = '1') or -- tx sending bits
           (sending_crc_i = '1') or (sending_fes_i = '1') or (stop_transmission_i = '1')) then

          if  tx_clk_p_i = '1' then         -- in order to synchronise the
            tx_enable_o <= '1';             -- activation of tx_enable with the
          end if;                           -- the delivery of the 1st FSS bit
                                            -- FD_TXD (FSS)    :________|-----|___________|--------
                                            -- tx_clk_p_buff(1):______|-|___|-|___|-|___|-|___|-|__
                                            -- sending_FSS     :___|-------------------------------
                                            -- FD_TXENA        :________|--------------------------
        else
          tx_enable_o   <= '0';
        end if;

     end if;
    end if;
  end process;


end architecture rtl;
--=================================================================================================
--                                        architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------