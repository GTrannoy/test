--=================================================================================================
--! @file wf_bits_to_txd.vhd
--=================================================================================================

--! standard library
library IEEE; 

--! standard packages
use IEEE.STD_LOGIC_1164.all;  --! std_logic definitions
use IEEE.NUMERIC_STD.all;     --! conversion functions

--! specific packages
use work.WF_PACKAGE.all;      --! definitions of supplemental types, subtypes, constants

---------------------------------------------------------------------------------------------------
--                                                                                               --
--                                 wf_bits_to_txd                                        --
--                                                                                               --
--                                  CERN, BE/CO/HT                                               --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
--
--! @brief     In stand-alone mode, the unit is responsible for transering the two desirialized
--!            bytes from the filedbus to the 2bytes long bus DAT_O. The bytes are put in the bus 
--!            one by one as they arrive.
--!            Note: After the reception of a correct FCS and the FES the signal VAR1_RDY/ VAR2_RDY
--!            is asserted and that signals the user that the data in DAT_O are valid and stable.  
--
--
--! @author    Pablo Alvarez Sanchez (pablo.alvarez.sanchez@cern.ch)
--!            Evangelia Gousiou (evangelia.gousiou@cern.ch)
--
--
--! @date      06/2010
--
--
--! @version   v0.02
--
--
--! @details \n  
--
--!   \n<b>Dependencies:</b>\n
--
--
--!   \n<b>Modified by:</b>\n
--!     Evangelia Gousiou (Evangelia.Gousiou@cern.ch)
--
--------------------------------------------------------------------------------------------------- 
--
--!   \n\n<b>Last changes:</b>\n
--
--------------------------------------------------------------------------------------------------- 
--
--! @todo 
--!   -> 
--
--------------------------------------------------------------------------------------------------- 


--=================================================================================================
--!                           Entity declaration for wf_bits_to_txd
--=================================================================================================

entity wf_bits_to_txd is
  generic(C_TXCLKBUFFLENTGTH: natural);
  port (
  -- INPUTS 
    -- User Interface general signals 
    uclk_i :           in std_logic;                     --! 40MHz clock

    -- Signal from the wf_reset_unit unit
    nFIP_u_rst_i :       in std_logic;                     --! internal reset

   -- Signals from wf_tx
    txd_bit_index_i :     in unsigned(4 downto 0);
    data_byte_manch_i :   in std_logic_vector (15 downto 0);
    crc_byte_manch_i :    in std_logic_vector (31 downto 0);
    sending_FSS_i :       in std_logic;
    sending_data_i :      in std_logic;
    sending_crc_i :       in std_logic;
    sending_QUEUE_i :     in std_logic;
    stop_transmission_i : in std_logic;
    

    -- Signals for the receiver wf_tx_rx_osc
    tx_clk_p_buff_i :   in std_logic_vector (C_TXCLKBUFFLENTGTH-1 downto 0);
                                       --! clk for transmission synchronization 
 

  -- OUTPUTS
    -- Signal to wf_prod_bytes_to_tx
    txd_o :               out std_logic;
    tx_enable_o :         out std_logic
      );
end entity wf_bits_to_txd;


--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of wf_bits_to_txd is

signal s_start_tx_enable, s_tx_enable : std_logic;

--=================================================================================================
--                                      architecture begin
--=================================================================================================  
  begin

---------------------------------------------------------------------------------------------------
--! @brief synchronous process tx_Outputs:managment of nanoFIP output signals tx_data and tx_enable 
--! tx_data: placement of bits of data to the output of the unit
--! tx_enable: flip-floped s_tx_enable (s_tx_enable is activated during bits delivery: from the 
--! beginning of tx_state send_fss until the end of send_queue state)  

  Bits_Delivery: process(uclk_i)
  begin
    if rising_edge(uclk_i) then
      if nFIP_u_rst_i = '1' then
        txd_o   <= '0';

      else

        if  tx_clk_p_buff_i(C_TXCLKBUFFLENTGTH-3) = '1' then 

          if sending_FSS_i = '1' then
            txd_o           <= FSS (to_integer (txd_bit_index_i));

          elsif sending_data_i = '1' then
            txd_o           <= data_byte_manch_i (to_integer (resize (txd_bit_index_i, 4)));

          elsif sending_crc_i = '1' then
            txd_o           <= crc_byte_manch_i (to_integer(txd_bit_index_i)); 

          elsif sending_QUEUE_i = '1' then
            txd_o           <= FRAME_END(to_integer(resize(txd_bit_index_i,4)));

          else
            txd_o           <= '0'; 

          end if;
        end if;
      end if;
    end if;
  end process;


------------------------------------------------------------------------------------------------
  s_tx_enable <= sending_FSS_i or sending_data_i or sending_crc_i or sending_QUEUE_i or stop_transmission_i;
                                                           -- beginning of considering data bits
                                                           -- for the CRC calculation when the 
                                                           -- 1st bit of data is to be sent 
                                                           -- (note: the CRC calculator uses the
                                                           -- signal s_bit, not tx_data_o)


  tx_enable_manager: process(uclk_i)
  begin
    if rising_edge(uclk_i) then
      if nFIP_u_rst_i = '1' then
        tx_enable_o   <= '0';
        s_start_tx_enable <= '0';

      else

        if s_tx_enable = '1' then
          if  tx_clk_p_buff_i(C_TXCLKBUFFLENTGTH-3) = '1' then 
            s_start_tx_enable <= '1';
          end if;
        else
          s_start_tx_enable <= '0';
        end if;   
        
        tx_enable_o   <= s_tx_enable and s_start_tx_enable;     

      end if;
    end if;
  end process;


end architecture rtl;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------