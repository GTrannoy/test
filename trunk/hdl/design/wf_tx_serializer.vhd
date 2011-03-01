--_________________________________________________________________________________________________
--                                                                                                |
--                                        |The nanoFIP|                                           |
--                                                                                                |
--                                        CERN,BE/CO-HT                                           |
--________________________________________________________________________________________________|
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--! @file WF_tx_serializer.vhd                                                                    |
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
--                                        WF_tx_serializer                                       --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
-- unit name:  WF_tx_serializer
--
--
--! @brief     The unit is generating the nanoFIP FIELDRIVE outputs FD_TXD and FD_TXENA. It is
--!            retreiving bytes of data from:
--!              o the WF_production (from the Ctrl until the MPS)
--!              o WF_package        (FSS, FES)
--!              o and the WF_CRC    (CRC bytes).
--!            It encodes the bytes to the Manchester 2 scheme and outputs one by one the encoded
--!            bits on the moments indicated by the tx_clk_p_buff signal.
--!            After the delivery of a byte, it is requesting from the WF_engine_control for a new
--!            one; the WF_engine_control is updating the signal byte_index, input to the
--!            WF_prod_bytes_retriever that indicates which byte to be retrieved from the memory or
--!            the DAT_I bus, and when the new byte becomes available asserts the signal
--!            byte_request_accept_p_i. When the byte_index reaches the expected amount of bytes to
--!            be transmitted, the WF_engine_control asserts the last_byte_p_i which signals the
--!            unit to proceed with the transmission of the CRC bytes and the FES.
--!
--!
--!            Reminder:
--!
--!            Produced RP_DAT frame structure :
--!             ___________ ______  _______ ______ _________________ _______ _______  ___________ _______
--!            |____FSS____|_Ctrl_||__PDU__|_LGTH_|__..User-Data..__|_nstat_|__MPS__||____FCS____|__FES__|
--!
--!                        |------------- Bytes from the WF_production -------------|
--!
--
--
--! @author    Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch) \n
--!            Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)     \n
--
--
--! @date      21/01/2011
--
--
--! @version   v0.04
--
--! @details\n
--
--!   \n<b>Dependencies:</b>     \n
--!            WF_engine_control \n
--!            WF_production     \n
--!            WF_tx_osc         \n
--!            WF_reset_unit     \n
--
--
--!   \n<b>Modified by:</b>\n
--!            Pablo Alvarez Sanchez  \n
--!            Evangelia Gousiou      \n
--
---------------------------------------------------------------------------------------------------
--
--!   \n\n<b>Last changes:</b>\n
--!     -> v0.02     2009  PAS Entity Ports added, start of architecture content
--!     -> v0.03  07/2010  EG  timing changes; tx_clk_p_buff_i got 1 more bit
--!                            briefly byte_index_i needed to arrive 1 clock tick earlier
--!                            renamed from tx to tx_serializer;
--!                            stop_transmission state added for the synch of txena
--!     -> v0.04  01/2011  EG  sync_to_txck state added to start always with the bits 1,2,3 of the
--!                            clock buffer available(tx_start_p_i may arrive at any time)
--
---------------------------------------------------------------------------------------------------
--
--! @todo -> bit simpler?
--
---------------------------------------------------------------------------------------------------


--=================================================================================================
--!                               Entity declaration for WF_tx_serializer
--=================================================================================================
entity WF_tx_serializer is
  port (
  -- INPUTS
    -- nanoFIP User Interface, General signals
    uclk_i                  : in std_logic;                     --! 40 MHz clock

    -- Signal from the WF_reset_unit
    nfip_rst_i              : in std_logic;                     --! nanoFIP internal reset

    -- Signals from the WF_production
    byte_i                  : in std_logic_vector (7 downto 0); --! byte to be delivered

    -- Signals from the WF_engine_control unit
    tx_start_p_i            : in std_logic;  --! indication for the start of the production
    byte_request_accept_p_i : in std_logic;  --! indication that a byte is ready to be delivered
    last_byte_p_i           : in std_logic;  --! indication of the last byte before the CRC bytes

     -- Signal from the WF_tx_osc
    tx_clk_p_buff_i         : in std_logic_vector (c_TX_CLK_BUFF_LGTH-1 downto 0);
                                             --! clk for the transmission synchronization


  -- OUTPUTS

    -- Signal to the WF_engine_control unit
    byte_request_p_o        : out std_logic;

    -- Signal to the WF_tx_osc unit
    tx_osc_rst_p_o          : out std_logic;

    -- nanoFIP FIELDRIVE outputs
    tx_data_o               : out std_logic; --! transmitter serial data
    tx_enable_o             : out std_logic  --! transmitter enable
    );

end entity WF_tx_serializer;



--=================================================================================================
--!                                    architecture declaration
--=================================================================================================
architecture rtl of WF_tx_serializer is

  type tx_state_t  is (idle, sync_to_txck, send_fss, send_data_byte, send_crc_bytes,
                                                     send_fes, stop_transmission);

  signal tx_state, nx_tx_state                                                     : tx_state_t;
  signal s_session_timedout : std_logic;
  signal s_prepare_to_produce, s_sending_fss, s_sending_data, s_sending_crc        : std_logic;
  signal s_sending_fes, s_stop_transmission, s_start_crc_p, s_data_bit_to_crc_p    : std_logic;
  signal s_txd, s_decr_index_p, s_bit_index_load, s_bit_index_is_zero              : std_logic;
  signal s_bit_index, s_bit_index_top                                   : unsigned (4 downto 0);
  signal s_byte                                                : std_logic_vector  (7 downto 0);
  signal s_crc_bytes_manch                                     : std_logic_vector (31 downto 0);
  signal s_crc_bytes, s_data_byte_manch                        : std_logic_vector (15 downto 0);


--=================================================================================================
--                                        architecture begin
--=================================================================================================
begin


--! The signal tx_clk_p_buff_i is used for the synchronization of the state transitions of the
--! machine as well as of the actions on the output signals.

-- The following drawing shows the transitions of the signal tx_clk_p_buff_i with respect to
-- the nanoFIP FIELDRIVE output FD_TXCK (line driver half bit clock).

-- FD_TXCK          : _________|-------...---------|________...________|-------...---------|_______
-- tx_clk_p_buff (3):        |0|0|0|1                                |0|0|0|1
-- tx_clk_p_buff (2):        |0|0|1|0                                |0|0|1|0
-- tx_clk_p_buff (1):        |0|1|0|0                                |0|1|0|0
-- tx_clk_p_buff (0):        |1|0|0|0                                |1|0|0|0


--! A new bit is delivered after the assertion of tx_clk_p_buff (1).

--! The counter Outgoing_Bits_Index that keeps the index of a bit being delivered is updated after
--! the delivery of the bit, after the tx_clk_p_buff (3) assertion. The counter is ahead of the
--! bit being sent.

--! In the sending_bytes state, where the unit is expecting data bytes from the
--! WF_prod_bytes_retriever, the unit delivers a request for a new byte after the tx_clk_p_buff (0)
--! assertion, when the Outgoing_Bits_Index counter is empty (which means that the last bit of a
--! previous byte is now being delivered).
--! The WF_engine_control responds to the request by sending a new address to the
--! WF_prod_bytes_retriever for the retreival of a byte from the memory or the stand-alone bus.
--! The byte becomes available at the byte_request_accept_p_i pulse, 2 cycles after the request,
--! and starts being transmitted at the tx_clk_p_buff (1) of the next FD_TXCK cycle.

---------------------------------------------------------------------------------------------------
--                                       Serializer's FSM                                        --
---------------------------------------------------------------------------------------------------
--!@brief Serializer's state machine: the state machine is divided in three parts (a clocked
--! process to store the current state, a combinatorial process to manage state transitions and
--! finally a combinatorial process to manage the output signals), which are the 3 processes that
--! follow.

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
--!@brief Synchronous process Serializer_FSM_Sync:

  Serializer_FSM_Sync: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if nfip_rst_i = '1' then
        tx_state <= idle;
      else
        tx_state <= nx_tx_state;
      end if;
    end if;
  end process;

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
--!@brief Combinatorial process Serializer_FSM_Comb_State_Transitions

  Serializer_FSM_Comb_State_Transitions: process (tx_state, last_byte_p_i, s_bit_index_is_zero,
                                                  s_session_timedout,tx_start_p_i, tx_clk_p_buff_i)
  begin
    nx_tx_state <= idle;

    case tx_state is

      when idle =>
                           if tx_start_p_i = '1' then
                             nx_tx_state <= sync_to_txck;
                           else
                             nx_tx_state <= idle;
                           end if;


      when sync_to_txck =>
                           if tx_clk_p_buff_i(c_TX_CLK_BUFF_LGTH-4) = '1' then
                             nx_tx_state <= send_fss;

                           elsif s_session_timedout = '1' then
                             nx_tx_state <= idle;

                           else
                             nx_tx_state <= sync_to_txck;
                           end if;


      when send_fss =>
                           if (s_bit_index_is_zero = '1')  and  (tx_clk_p_buff_i(c_TX_CLK_BUFF_LGTH-1) = '1') then
                             nx_tx_state <= send_data_byte;

                           elsif s_session_timedout = '1' then
                             nx_tx_state <= idle;

                           else
                             nx_tx_state <= send_fss;
                           end if;


      when send_data_byte =>
                           if last_byte_p_i = '1' then
                             nx_tx_state <= send_crc_bytes;

                           elsif s_session_timedout = '1' then
                             nx_tx_state <= idle;

                           else
                             nx_tx_state <= send_data_byte;
                           end if;


      when send_crc_bytes =>
                           if (s_bit_index_is_zero = '1') and  (tx_clk_p_buff_i(c_TX_CLK_BUFF_LGTH-2) = '1') then
                             nx_tx_state <= send_fes;      -- state change early enough (tx_clk_p_buff_i(2))
                                                           -- for the Outgoing_Bits_Index, that is loaded on
                                                           -- tx_clk_p_buff_i(3), to get the 31 as top value
                           elsif s_session_timedout = '1' then
                             nx_tx_state <= idle;

                           else
                             nx_tx_state <= send_crc_bytes;

                           end if;


      when send_fes =>
                           if (s_bit_index_is_zero = '1') and  (tx_clk_p_buff_i(c_TX_CLK_BUFF_LGTH-2) = '1') then
                             nx_tx_state <= stop_transmission; -- state change early enough (tx_clk_p_buff_i(2))
                                                               -- for the Outgoing_Bits_Index that is loaded on
                                                               -- tx_clk_p_buff_i(3) to get the 15 as top value
                           elsif s_session_timedout = '1' then
                             nx_tx_state <= idle;

                           else
                             nx_tx_state <= send_fes;
                           end if;


      when stop_transmission =>
                           if tx_clk_p_buff_i(c_TX_CLK_BUFF_LGTH-2) = '1' then
                             nx_tx_state <= idle;

                           elsif s_session_timedout = '1' then
                             nx_tx_state <= idle;

                           else
                             nx_tx_state <= stop_transmission;
                           end if;


      when others =>
                           nx_tx_state <= idle;
    end case;
  end process;


 --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
--!@brief Combinatorial process Serializer_FSM_Comb_Output_Signals

  Serializer_FSM_Comb_Output_Signals:  process ( tx_state )
  begin

    case tx_state is

      when idle | sync_to_txck =>

                  ---------------------------------
                    s_prepare_to_produce <= '1';
                  ---------------------------------
                    s_sending_fss        <= '0';
                    s_sending_data       <= '0';
                    s_sending_crc        <= '0';
                    s_sending_fes        <= '0';
                    s_stop_transmission  <= '0';


      when send_fss =>

                    s_prepare_to_produce <= '0';
                  ---------------------------------
                    s_sending_fss        <= '1';
                  ---------------------------------
                    s_sending_data       <= '0';
                    s_sending_crc        <= '0';
                    s_sending_fes         <= '0';
                    s_stop_transmission  <= '0';


      when send_data_byte  =>

                    s_prepare_to_produce <= '0';
                    s_sending_fss        <= '0';
                  ---------------------------------
                    s_sending_data       <= '1';
                  ---------------------------------
                    s_sending_crc        <= '0';
                    s_sending_fes        <= '0';
                    s_stop_transmission  <= '0';


       when send_crc_bytes =>

                    s_prepare_to_produce <= '0';
                    s_sending_fss        <= '0';
                    s_sending_data       <= '0';
                  ---------------------------------
                    s_sending_crc        <= '1';
                  ---------------------------------
                    s_sending_fes        <= '0';
                    s_stop_transmission  <= '0';


      when send_fes =>

                    s_prepare_to_produce <= '0';
                    s_sending_fss        <= '0';
                    s_sending_data       <= '0';
                    s_sending_crc        <= '0';
                  ---------------------------------
                    s_sending_fes        <= '1';
                  ---------------------------------
                    s_stop_transmission  <= '0';


      when stop_transmission =>

                    s_prepare_to_produce <= '0';
                    s_sending_fss        <= '0';
                    s_sending_data       <= '0';
                    s_sending_crc        <= '0';
                    s_sending_fes        <= '0';
                  ---------------------------------
                    s_stop_transmission  <= '1';
                  ---------------------------------


      when others =>

                     s_prepare_to_produce <= '0';
                     s_sending_fss        <= '0';
                     s_sending_data       <= '0';
                     s_sending_crc        <= '0';
                     s_sending_fes        <= '0';
                     s_stop_transmission  <= '0';

    end case;
  end process;



---------------------------------------------------------------------------------------------------
--                                        Input Byte Retrieval                                   --
---------------------------------------------------------------------------------------------------

Input_Byte_Retrieval: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if nfip_rst_i = '1' then
        s_byte   <= (others => '0');

      else

        if byte_request_accept_p_i = '1' then
          s_byte <= byte_i;

        end if;
      end if;
    end if;
  end process;



---------------------------------------------------------------------------------------------------
--                                      Manchester Encoding                                      --
---------------------------------------------------------------------------------------------------

  s_data_byte_manch <= f_manch_encoder (s_byte);
  s_crc_bytes_manch <= f_manch_encoder (s_crc_bytes);



---------------------------------------------------------------------------------------------------
--                                        CRC calculation                                        --
---------------------------------------------------------------------------------------------------

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
--!@brief Instantiation of the CRC unit

  crc_generation: WF_crc
  port map (
    uclk_i                => uclk_i,
    nfip_rst_i            => nfip_rst_i,
    start_crc_p_i         => s_start_crc_p,
    data_bit_ready_p_i    => s_data_bit_to_crc_p,
    data_bit_i            => s_txd,
    crc_ok_p_o            => open,
   -------------------------------------------------
    crc_o                 => s_crc_bytes);
   -------------------------------------------------

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- concurrent signals assignement for the crc_generator inputs

  s_start_crc_p       <= s_sending_fss and s_bit_index_is_zero and  tx_clk_p_buff_i(c_TX_CLK_BUFF_LGTH-1);
  -- the CRC calculation starts when at the end of th  e FSS (beginning of data bytes delivery)

  s_data_bit_to_crc_p <= s_sending_data and s_bit_index(0) and tx_clk_p_buff_i(c_TX_CLK_BUFF_LGTH-1);
  -- only the 1st part of a manchester encoded bit goes to the CRC calculator



---------------------------------------------------------------------------------------------------
--                                        Bits delivery                                          --
---------------------------------------------------------------------------------------------------

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
--@brief Managment of the pointer that indicates which bit of a manchester encoded byte is to be
--! delivered. According to the state of the FSM, a byte may be a FSS one, or a data byte or a
--! CRC or a FES byte.

  Outgoing_Bits_Index: WF_decr_counter
  generic map (g_counter_lgth => 5)
  port map (
    uclk_i              => uclk_i,
    nfip_rst_i          => nfip_rst_i,
    counter_top         => s_bit_index_top,
    counter_load_i      => s_bit_index_load,
    counter_decr_p_i    => s_decr_index_p,
   -----------------------------------------------
    counter_o           => s_bit_index,
    counter_is_zero_o   => s_bit_index_is_zero);
   -----------------------------------------------


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Combinatorial process that according to the state of the FSM sets the values to the
-- Outgoing_Bits_Index inputs.

  Bit_Index: process (s_prepare_to_produce,s_sending_fss, s_sending_data, s_sending_crc,
                      s_sending_fes, s_bit_index_is_zero,tx_clk_p_buff_i)
  begin

    if s_prepare_to_produce ='1' then
      s_bit_index_top  <= to_unsigned (c_FSS'length - 1, s_bit_index'length);
      s_bit_index_load <= '1';
      s_decr_index_p   <= '0';


    elsif s_sending_fss = '1' then     -- sending the 16 FSS manch. bits
      s_bit_index_top  <= to_unsigned (15, s_bit_index'length);
      s_bit_index_load <= s_bit_index_is_zero and  tx_clk_p_buff_i(c_TX_CLK_BUFF_LGTH-1);
      s_decr_index_p   <= tx_clk_p_buff_i(c_TX_CLK_BUFF_LGTH-1);


    elsif s_sending_data = '1' then    -- sending bytes of 16 manch. bits (several loops here)
      s_bit_index_top  <= to_unsigned (15, s_bit_index'length);
      s_bit_index_load <= s_bit_index_is_zero and  tx_clk_p_buff_i(c_TX_CLK_BUFF_LGTH-1);
      s_decr_index_p   <= tx_clk_p_buff_i(c_TX_CLK_BUFF_LGTH-1);


    elsif s_sending_crc = '1' then     -- sending the 32 manch. CRC bits
      s_bit_index_top  <= to_unsigned (s_crc_bytes_manch'length-1, s_bit_index'length);
      s_bit_index_load <= s_bit_index_is_zero and  tx_clk_p_buff_i(c_TX_CLK_BUFF_LGTH-1);
      s_decr_index_p   <= tx_clk_p_buff_i(c_TX_CLK_BUFF_LGTH-1);


    elsif s_sending_fes = '1' then   -- sending the 16 manch. FSS
      s_bit_index_top  <= to_unsigned (c_FES'length - 1, s_bit_index'length);
      s_bit_index_load <= s_bit_index_is_zero and  tx_clk_p_buff_i(c_TX_CLK_BUFF_LGTH-1);
      s_decr_index_p   <= tx_clk_p_buff_i(c_TX_CLK_BUFF_LGTH-1);


    else
      s_bit_index_top  <= to_unsigned (c_FSS'length - 1, s_bit_index'length);
      s_bit_index_load <= '0';
      s_decr_index_p   <= '0';

    end if;
  end process;


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
--!@brief Instantiation of the unit that according to the state of the FSM and the
--! bits index counter, outputs FSS, data, CRC or FES manchester encoded bits to the txd_o.
--! The unit also generates the tx_enable_o signal.

  bits_to_txd: WF_bits_to_txd
  port map (
    uclk_i              => uclk_i,
    nfip_rst_i          => nfip_rst_i,
    txd_bit_index_i     => s_bit_index,
    data_byte_manch_i   => s_data_byte_manch,
    crc_byte_manch_i    => s_crc_bytes_manch,
    sending_fss_i       => s_sending_fss,
    sending_data_i      => s_sending_data,
    sending_crc_i       => s_sending_crc,
    sending_fes_i       => s_sending_fes,
    stop_transmission_i => s_stop_transmission,
    tx_clk_p_i          => tx_clk_p_buff_i(c_TX_CLK_BUFF_LGTH-3),
   ---------------------------------------------
    txd_o               => s_txd,
    tx_enable_o         => tx_enable_o);
   ---------------------------------------------



---------------------------------------------------------------------------------------------------
--                                  Independant Timeout Counter                                  --
---------------------------------------------------------------------------------------------------

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
--! @brief Instantiation of a WF_decr_counter relying only on the system clock as an additional
--! way to go back to Idle state,  in case any other logic is being stuck.

  Session_Timeout_Counter: WF_decr_counter
  generic map (g_counter_lgth => 21)
  port map (
    uclk_i            => uclk_i,
    nfip_rst_i        => nfip_rst_i,
    counter_top       => (others => '1'),
    counter_load_i    => s_prepare_to_produce,
    counter_decr_p_i  => '1', -- on each uclk tick
    counter_o         => open,
    ---------------------------------------------------
    counter_is_zero_o => s_session_timedout);
    ---------------------------------------------------



---------------------------------------------------------------------------------------------------
--                                              Outputs                                          --
---------------------------------------------------------------------------------------------------

  tx_data_o           <= s_txd;

  tx_osc_rst_p_o      <= s_session_timedout;

  byte_request_p_o    <= s_sending_data and s_bit_index_is_zero and  tx_clk_p_buff_i(c_TX_CLK_BUFF_LGTH-4);
  -- request for a new byte from the WF_prod_bytes_retriever unit (passing from WF_engine_control)


end architecture rtl;
--=================================================================================================
--                                        architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------