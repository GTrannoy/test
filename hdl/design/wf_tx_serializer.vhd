--_________________________________________________________________________________________________
--                                                                                                |
--                                         |The nanoFIP|                                          |
--                                                                                                |
--                                         CERN,BE/CO-HT                                          |
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--                                                                                                |
--                                        WF_tx_serializer                                        |
--                                                                                                |
---------------------------------------------------------------------------------------------------
-- File         WF_tx_serializer.vhd                                                              |
--                                                                                                |
-- Description  The unit is generating the nanoFIP FIELDRIVE outputs FD_TXD and FD_TXENA.         |
--              It is retreiving bytes of data from:                                              |
--                o the WF_production (from the CTRL byte until the MPS)                          |
--                o WF_package        (FSS and FES bytes)                                         |
--                o and the WF_CRC    (FCS bytes).                                                |
--                                                                                                |
--              It encodes the bytes to the Manchester 2 scheme and outputs one by one the        |
--              encoded bits on the moments indicated by the WF_tx_osc unit.                      |
--                                                                                                |
--              Reminder of the Produced RP_DAT frame structure :                                 |
--   ___________ ______  _______ ______ _________________ _______ _______  ___________ _______    |
--  |____FSS____|_CTRL_||__PDU__|_LGTH_|__..User-Data..__|_nstat_|__MPS__||____FCS____|__FES__|   |
--                                                                                                |
--              |------------- Bytes from the WF_production -------------|                        |
--                                                                                                |
--                                                                                                |
-- Authors      Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)                             |
--              Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)                                 |
-- Date         07/2011                                                                           |
-- Version      v0.05                                                                             |
-- Depends on   WF_engine_control                                                                 |
--              WF_production                                                                     |
--              WF_tx_osc                                                                         |
--              WF_reset_unit                                                                     |
----------------                                                                                  |
-- Last changes                                                                                   |
--     v0.02     2009  PAS Entity Ports added, start of architecture content                      |
--     v0.03  07/2010  EG  timing changes; tx_sched_p_buff_i got 1 more bit                       |
--                         briefly byte_index_i needed to arrive 1 clock tick earlier             |
--                         renamed from tx to tx_serializer;                                      |
--                         stop_transmission state added for the synch of txena                   |
--     v0.04  01/2011  EG  sync_to_txck state added to start always with the bits 1,2,3 of the    |
--                         clock buffer available(tx_start_p_i may arrive at any time)            |
--                         tx_completed_p_o signal added                                          |
--     v0.05  07/2011  EG  bits_to_txd unit removed                                               |
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
--                               Entity declaration for WF_tx_serializer
--=================================================================================================
entity WF_tx_serializer is port(
  -- INPUTS
    -- nanoFIP User Interface, General signals
    uclk_i                  : in std_logic;                     -- 40 MHz clock

    -- Signal from the WF_reset_unit
    nfip_rst_i              : in std_logic;                     -- nanoFIP internal reset

    -- Signals from the WF_production
    byte_i                  : in std_logic_vector (7 downto 0); -- byte to be delivered

    -- Signals from the WF_engine_control unit
    tx_start_p_i            : in std_logic;  -- indication for the start of the production
    byte_request_accept_p_i : in std_logic;  -- indication that a byte is ready to be delivered
    last_byte_p_i           : in std_logic;  -- indication of the last data byte
                                             --  (CRC, FES not included)

     -- Signal from the WF_tx_osc
    tx_sched_p_buff_i       : in std_logic_vector (c_TX_SCHED_BUFF_LGTH-1 downto 0);
                                             -- pulses for the transmission synchronization


  -- OUTPUTS

    -- Signal to the WF_engine_control unit
    tx_byte_request_p_o     : out std_logic; -- request for a new byte
    tx_completed_p_o        : out std_logic; -- pulse upon the end of transmission

    -- Signal to the WF_tx_osc unit
    tx_osc_rst_p_o          : out std_logic; -- oscillator reset after a transmission error

    -- nanoFIP FIELDRIVE outputs
    tx_data_o               : out std_logic; -- transmitter serial data
    tx_enable_o             : out std_logic);-- transmitter enable

end entity WF_tx_serializer;



--=================================================================================================
--                                    architecture declaration
--=================================================================================================
architecture rtl of WF_tx_serializer is

  -- FSM
  type tx_st_t  is (idle, sync_to_txck, send_fss, send_data_byte,
                              send_crc_bytes, send_fes, stop_transmission);
  signal tx_st, nx_tx_st                                          : tx_st_t;
  signal s_prepare_to_produce, s_sending_fss, s_sending_data      : std_logic;
  signal s_sending_crc, s_sending_fes, s_stop_transmission        : std_logic;
  -- bits counter
  signal s_bit_index_decr_p,s_bit_index_load, s_bit_index_is_zero : std_logic;
  signal s_bit_index, s_bit_index_top                             : unsigned (4 downto 0);
  -- transmitter output
  signal s_txd                                                    : std_logic;
  -- byte to be transmitted
  signal s_data_byte                                              : std_logic_vector  (7 downto 0);
  signal s_data_byte_manch                                        : std_logic_vector (15 downto 0);
  -- CRC calculations
  signal s_start_crc_p, s_data_bit_to_crc_p                       : std_logic;
  signal s_crc_bytes                                              : std_logic_vector (15 downto 0);
  signal s_crc_bytes_manch                                        : std_logic_vector (31 downto 0);
  -- independant timeout counter
  signal s_session_timedout                                       : std_logic;


--=================================================================================================
--                                       architecture begin
--=================================================================================================
begin

-- The signal tx_sched_p_buff_i is used for the scheduling of the state transitions of the machine
-- as well as of the actions on the output signals.

-- The following drawing shows the transitions of the signal tx_sched_p_buff_i with respect to
-- the nanoFIP FIELDRIVE output FD_TXCK (line driver half bit clock).

-- FD_TXCK           : _________|-------...---------|________...________|-------...---------|____
-- tx_sched_p_buff(3):        |0|0|0|1                                |0|0|0|1
-- tx_sched_p_buff(2):        |0|0|1|0                                |0|0|1|0
-- tx_sched_p_buff(1):        |0|1|0|0                                |0|1|0|0
-- tx_sched_p_buff(0):        |1|0|0|0                                |1|0|0|0
----------------------
-- new byte request  :         ^
-- new byte ready    :         . . ^
-- 1st bit of new                   . . . . . . . . . . . . . . . . . .^
-- byte delivery     :
-- bit counter       :               [                  15              . . .][          14  

-- A new bit is delivered after the assertion of tx_sched_p_buff (1).

-- The counter Outgoing_Bits_Index that keeps the index of a bit being delivered is updated after
-- the delivery of the bit, after the tx_sched_p_buff (3) assertion. The counter is ahead of the
-- bit being sent.

-- In the sending_bytes state, where the unit is expecting data bytes from the WF_production,
-- the unit delivers a request for a new byte after the tx_sched_p_buff (0) assertion,
-- and when the Outgoing_Bits_Index counter is empty (which means that the last bit of a previous
-- byte is now being delivered).
-- The WF_engine_control responds to the request by sending a new address to the WF_production
-- for the retreival of a byte from the memory or the stand-alone bus.
-- The byte becomes available at the byte_request_accept_p_i pulse, 2 cycles after the request,
-- and starts being transmitted at the tx_sched_p_buff (1) of the next FD_TXCK cycle.

-- The WF_engine_control is the one keeping track of the amount of bytes delivered and asserts
-- the last_byte_p_i signal accordingly; after the arrival of this signal the serializer's FSM
-- proceeds with the transmission of the CRC and the FES bytes and then goes back to idle.

-- To add a rubust layer of protection to the FSM, we have added a counter, dependant only on the
-- system clock, that from any state can bring the FSM back to idle. At any bit rate the
-- transmission of the longest RP_DAT should not last more than 35ms. Hence, we have generated a
-- 21 bits counter that will bring the machine back to idle if more than 52ms (complete 21 bit
-- counter) have passed since it has left this idle state.

---------------------------------------------------------------------------------------------------
--                                       Serializer's FSM                                        --
---------------------------------------------------------------------------------------------------
-- Serializer's state machine: the state machine is divided in three parts (a clocked
-- process to store the current state, a combinatorial process to manage state transitions and
-- finally a combinatorial process to manage the output signals), which are the 3 processes that
-- follow.

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Synchronous process Serializer_FSM_Sync:

  Serializer_FSM_Sync: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if nfip_rst_i = '1' then
        tx_st <= idle;
      else
        tx_st <= nx_tx_st;
      end if;
    end if;
  end process;

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Combinatorial process Serializer_FSM_Comb_State_Transitions

  Serializer_FSM_Comb_State_Transitions: process (tx_st, last_byte_p_i, s_bit_index_is_zero,
                                                  s_session_timedout,tx_start_p_i, tx_sched_p_buff_i)
  begin
    nx_tx_st <= idle;

    case tx_st is

      when idle =>
                         if tx_start_p_i = '1' then       -- trigger from wf_engine_control
                           nx_tx_st <= sync_to_txck;
                         else
                           nx_tx_st <= idle;
                         end if;


      when sync_to_txck =>                                -- synch to the free running FD_TXTCK 
                         if s_session_timedout = '1' then
                           nx_tx_st <= idle;

                         elsif tx_sched_p_buff_i(c_TX_SCHED_BUFF_LGTH-4) = '1' then
                           nx_tx_st <= send_fss;

                         else
                           nx_tx_st <= sync_to_txck;
                         end if;


      when send_fss =>                                    -- delivery of 2 FSS bytes
                         if s_session_timedout = '1' then
                           nx_tx_st <= idle;
 
                         elsif (s_bit_index_is_zero = '1')  and  (tx_sched_p_buff_i(c_TX_SCHED_BUFF_LGTH-1) = '1') then
                           nx_tx_st <= send_data_byte;

                         else
                           nx_tx_st <= send_fss;
                         end if;


      when send_data_byte =>                              -- delivery of several data bytes
                                                          -- until the last_byte_p_i notification
                         if s_session_timedout = '1' then
                           nx_tx_st <= idle;              

                         elsif last_byte_p_i = '1' then
                           nx_tx_st <= send_crc_bytes;

                         else
                           nx_tx_st <= send_data_byte;
                         end if;


      when send_crc_bytes =>                              -- delivery of 2 CRC bytes
                         if s_session_timedout = '1' then
                           nx_tx_st <= idle;

                         elsif (s_bit_index_is_zero = '1') and  (tx_sched_p_buff_i(c_TX_SCHED_BUFF_LGTH-2) = '1') then
                           nx_tx_st <= send_fes;           -- state change early enough (tx_sched_p_buff_i(2))
                                                           -- for the Outgoing_Bits_Index, that is loaded on
                                                           -- tx_sched_p_buff_i(3), to get the 31 as top value
                         else
                           nx_tx_st <= send_crc_bytes;
                         end if;


      when send_fes =>                                    -- delivery of 1 FES byte
                         if s_session_timedout = '1' then
                           nx_tx_st <= idle;

                         elsif (s_bit_index_is_zero = '1') and  (tx_sched_p_buff_i(c_TX_SCHED_BUFF_LGTH-2) = '1') then
                           nx_tx_st <= stop_transmission; -- state change early enough (tx_sched_p_buff_i(2))
                                                          -- for the Outgoing_Bits_Index that is loaded on
                                                          -- tx_sched_p_buff_i(3) to get the 15 as top value
                         else
                           nx_tx_st <= send_fes;
                         end if;


      when stop_transmission =>
                                                          -- 
                         if s_session_timedout = '1' then
                           nx_tx_st <= idle;

                         elsif tx_sched_p_buff_i(c_TX_SCHED_BUFF_LGTH-2) = '1' then
                           nx_tx_st <= idle;

                         else
                           nx_tx_st <= stop_transmission;
                         end if;


      when others =>
                           nx_tx_st <= idle;
    end case;
  end process;


 --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Combinatorial process Serializer_FSM_Comb_Output_Signals

  Serializer_FSM_Comb_Output_Signals:  process ( tx_st )
  begin

    case tx_st is

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
        s_data_byte   <= (others => '0');
      else

        if byte_request_accept_p_i = '1' then
          s_data_byte <= byte_i;

        end if;
      end if;
    end if;
  end process;



---------------------------------------------------------------------------------------------------
--                                      Manchester Encoding                                      --
---------------------------------------------------------------------------------------------------

  s_data_byte_manch <= f_manch_encoder (s_data_byte);
  s_crc_bytes_manch <= f_manch_encoder (s_crc_bytes);



---------------------------------------------------------------------------------------------------
--                                        CRC calculation                                        --
---------------------------------------------------------------------------------------------------

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Instantiation of the CRC unit

  crc_generation: WF_crc
  port map(
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

  s_start_crc_p       <= s_sending_fss and s_bit_index_is_zero and  tx_sched_p_buff_i(c_TX_SCHED_BUFF_LGTH-1);
  -- the CRC calculation starts when at the end of th  e FSS (beginning of data bytes delivery)

  s_data_bit_to_crc_p <= s_sending_data and s_bit_index(0) and tx_sched_p_buff_i(c_TX_SCHED_BUFF_LGTH-1);
  -- only the 1st part of a manchester encoded bit goes to the CRC calculator



---------------------------------------------------------------------------------------------------
--                                         Bits counter                                          --
---------------------------------------------------------------------------------------------------

-- Managment of the pointer that indicates which bit of a manchester encoded byte is to be
-- delivered. According to the state of the FSM, a byte may be a FSS one, or a data byte or a
-- CRC or a FES byte.

  Outgoing_Bits_Index: WF_decr_counter
  generic map(g_counter_lgth => 5)
  port map(
    uclk_i              => uclk_i,
    nfip_rst_i          => nfip_rst_i,
    counter_top         => s_bit_index_top,
    counter_load_i      => s_bit_index_load,
    counter_decr_p_i    => s_bit_index_decr_p,
   -----------------------------------------------
    counter_o           => s_bit_index,
    counter_is_zero_o   => s_bit_index_is_zero);
   -----------------------------------------------

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  s_bit_index_top    <= to_unsigned (15, s_bit_index'length)                         when s_sending_fss = '1' or s_sending_data = '1' else
                        to_unsigned (s_crc_bytes_manch'length-1, s_bit_index'length) when s_sending_crc = '1' else
                        to_unsigned (c_FES'length - 1, s_bit_index'length)           when s_sending_fes = '1' else
                        to_unsigned (c_FSS'length - 1, s_bit_index'length);

  s_bit_index_load   <= (s_bit_index_is_zero and  tx_sched_p_buff_i(c_TX_SCHED_BUFF_LGTH-1)) when
                          (s_sending_fss = '1' or s_sending_data = '1' or s_sending_crc = '1' or s_sending_fes = '1') else
                        '1' when s_prepare_to_produce ='1' else
                        '0';

  s_bit_index_decr_p <= tx_sched_p_buff_i(c_TX_SCHED_BUFF_LGTH-1) when
                        (s_sending_fss = '1' or s_sending_data = '1' or s_sending_crc = '1' or s_sending_fes = '1') else '0';



---------------------------------------------------------------------------------------------------
--                                        Bits delivery                                          --
---------------------------------------------------------------------------------------------------

-- Synchronous process Bits_Delivery: handling of nanoFIP output signal FD_TXD by
-- placing bits of data according to the state of WF_tx_serializer's state machine and to the
-- counter s_bit_index. The delivery takes place upon a tx_sched_p_buff_i(c_TX_SCHED_BUFF_LGTH-3)
-- pulse.

  Bits_Delivery: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if nfip_rst_i = '1' then
        s_txd     <= '0';
      else

        if  tx_sched_p_buff_i(c_TX_SCHED_BUFF_LGTH-3) = '1' then

          if s_sending_fss = '1' then
            s_txd <= c_FSS (to_integer (s_bit_index));   -- FSS: 2 bytes long (no need to resize)

          elsif s_sending_data = '1' then
            s_txd <= s_data_byte_manch (to_integer (resize(s_bit_index, 4))); -- 1 data-byte at a time

          elsif s_sending_crc = '1' then
            s_txd <= s_crc_bytes_manch (to_integer (s_bit_index));            -- CRC: 2 bytes long

          elsif s_sending_fes = '1' then
            s_txd <= c_FES(to_integer (resize(s_bit_index,4)));               -- FES: 1 byte

          else
            s_txd <= '0';

          end if;
        end if;
      end if;
    end if;
  end process;



---------------------------------------------------------------------------------------------------
--                                       TXENA generation                                        --
---------------------------------------------------------------------------------------------------

-- Synchronous process FD_TXENA_Generator: The nanoFIP output FD_TXENA is activated at the
-- same moment as the first bit of the PRE starts being delivered and stays asserted until the
-- end of the delivery of the last FES bit.

  FD_TXENA_Generator: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if nfip_rst_i = '1' then
        tx_enable_o     <= '0';

      else

        if ((s_sending_fss = '1') or (s_sending_data = '1') or -- tx sending bits
           (s_sending_crc = '1') or (s_sending_fes = '1') or (s_stop_transmission = '1')) then

          if  tx_sched_p_buff_i(c_TX_SCHED_BUFF_LGTH-3) = '1' then
                                            -- in order to synchronise the
            tx_enable_o <= '1';             -- activation of tx_enable with the
                                            -- the delivery of the 1st FSS bit
          end if;                           -- FD_TXD (FSS)      :________|-----|___________|--------
                                            -- tx_sched_p_buff(1):______|-|___|-|___|-|___|-|___|-|__
                                            -- sending_FSS       :___|-------------------------------
                                            -- FD_TXENA          :________|--------------------------
        else
          tx_enable_o   <= '0';
        end if;

     end if;
    end if;
  end process;



---------------------------------------------------------------------------------------------------
--                                  Independant Timeout Counter                                  --
---------------------------------------------------------------------------------------------------

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Instantiation of a WF_decr_counter relying only on the system clock as an additional
-- way to go back to Idle state,  in case any other logic is being stuck.

  Session_Timeout_Counter: WF_decr_counter
  generic map(g_counter_lgth => 21)
  port map(
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

  tx_completed_p_o    <= s_stop_transmission and tx_sched_p_buff_i(c_TX_SCHED_BUFF_LGTH-2);

  tx_byte_request_p_o <= s_sending_data and s_bit_index_is_zero and  tx_sched_p_buff_i(c_TX_SCHED_BUFF_LGTH-4);
  -- request for a new byte from the WF_prod_bytes_retriever unit (passing from WF_engine_control)



end architecture rtl;
--=================================================================================================
--                                        architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------