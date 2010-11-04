---------------------------------------------------------------------------------------------------
--! @file WF_tx.vhd
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
--                                            WF_tx                                              --
--                                                                                               --
--                                        CERN, BE/CO/HT                                         --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
-- unit name:  WF_tx
--
--
--! @brief     Serializes the WorldFIP data.
--
--
--! @author    Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)
--!            Evangelia Gousiou (Evangelia.Gousiou@cern.ch)
--
--
--! @date 07/2010
--
--
--! @version v0.03
--
--! @details\n 
--
--!   \n<b>Dependencies:</b>\n
--!     WF_engine           \n
--!     tx_engine           \n
--!     clk_gen             \n
--!     WF_reset_unit         \n
--!     consumed_ram        \n
--
--
--!   \n<b>Modified by:</b>\n
--!     Erik van der Bij     \n
--!     Pablo Alvarez Sanchez \n
--!     Evangelia Gousiou      \n
--
---------------------------------------------------------------------------------------------------
--
--!   \n\n<b>Last changes:</b>\n
--!     -> v0.02  PAS Entity Ports added, start of architecture content
--!     -> v0.03  EG  timing changes; tx_clk_p_buff_i got 1 more bit
--!                      briefly byte_index_i needed to arrive 1 clock tick earlier       
--
---------------------------------------------------------------------------------------------------
--
--! @todo -> comments!!
--
---------------------------------------------------------------------------------------------------


--=================================================================================================
--!                               Entity declaration for WF_tx_rx
--=================================================================================================
entity WF_tx is
  generic(C_TXCLKBUFFLENTGTH: natural);
  port (
  -- INPUTS 
    -- User Interface general signals (synchronized) 
    uclk_i :            in std_logic;  --! 40MHz clock

    -- Signal from the WF_reset_unit unit
    nFIP_urst_i :        in std_logic;  --! internal reset
    
    -- Signals from the WF_engine_control
    start_produce_p_i : in std_logic;  --! indication that WF_engine_control is in prod_watchdog state 
                                       -- a correct id_dat asking for a produced var has been 
                                       -- received and ............ 

    byte_ready_p_i :    in std_logic;  --! indication that a byte is ready to be delivered   
    last_byte_p_i :     in std_logic;  --! indication that it is the last byte of data
                                       --  CRC bytes follow

    -- Signals from the WF_prod_bytes_to_tx
    byte_i :            in std_logic_vector (7 downto 0);             
                                       --! data byte to be delivered 

     -- Signal from the WF_rx_tx_osc    
    tx_clk_p_buff_i :   in std_logic_vector (C_TXCLKBUFFLENTGTH-1 downto 0);
                                       --! clk for transmission synchronization 

  -- OUTPUTS

    -- Signal to WF_engine_control
    request_byte_p_o :  out std_logic;

    -- nanoFIP output signals
    tx_data_o :         out std_logic; --! transmitter serial data
    tx_enable_o :       out std_logic  --! transmitter enable
    );

end entity WF_tx;



--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of WF_tx is


  type tx_state_t  is (idle, send_fss, send_data_byte, send_crc_bytes, send_queue, stop_transmission);

  signal tx_state, nx_tx_state :               tx_state_t;
  signal s_prepare_to_produce, s_sending_FSS : std_logic;
  signal s_sending_data, s_sending_CRC :       std_logic;    
  signal s_sending_QUEUE, s_start_crc_p :  std_logic;
  signal s_data_bit_to_crc_p :std_logic;
  signal s_txd, s_decr_index_p :  std_logic;
  signal s_bit_index_load, s_decr_index :      std_logic;
  signal s_bit_index_is_zero, s_stop_transmission :    std_logic;
  signal s_bit_index, s_bit_index_top :        unsigned(4 downto 0);
  signal s_byte :                              std_logic_vector (7 downto 0);
  signal s_crc_bytes_manch :                    std_logic_vector (31 downto 0);
  signal s_crc_bytes,s_data_byte_manch : std_logic_vector (15 downto 0);


--=================================================================================================
--                                      architecture begin
--=================================================================================================  
begin

---------------------------------------------------------------------------------------------------

--!@brief Transmitter's state machine: the state machine is divided in three parts (a clocked 
--! process to store the current state, a combinatorial process to manage state transitions and 
--! finally a combinatorial process to manage the output signals), which are the 3 processes that
--! follow. 

--! The signal tx_clk_p_buff_i is used for the synchronization of the state transitions of the
--! machine as well as of the actions on the output signals. 

-- The following drawing shows the transitions of the signal tx_clk_p_buff_i with respect to
-- the signal tx_clk (line driver half bit clock).

-- tx_clk:           __________|----------------|________________|----------------|_______________
-- tx_clk_p_buff (3):          |0|0|0|1                          |0|0|0|1
-- tx_clk_p_buff (2):          |0|0|1|0                          |0|0|1|0
-- tx_clk_p_buff (1):          |0|1|0|0                          |0|1|0|0
-- tx_clk_p_buff (0):          |1|0|0|0                          |1|0|0|0


-- tx states analysis:

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- "idle state": signals initializations

-- jump to "send_fss" state after a pulse on the signal start_produce_p_i (controlled by the
-- WF_engine_control)

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- "send_fss" state: delivery of the manchester encoded bits of the Frame Start Sequence (including
-- preamble and Frame Start delimiter).
-- 32 bits to be sent (2 encoded bytes)
-- bit delivery starts after each        tx_clk_p_buff (1) assertion (Bits_Delivery process)
-- the s_bit_index is updated after each tx_clk_p_buff (3) assertion (s_bit_index is ahead of the
-- bit being sent)

-- jump to "send_data_byte" state after the beginning of the 32nd bit delivery and after
-- the tx_clk_p_buff(3) assertion.
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --

-- "send_data_byte" state: delivery of manchester encoded bits of data that arrive from the
-- WF_prod_bytes_to_tx unit (byte_i), with the coordination of the WF_engine_control (byte_ready_p_i)
-- request of a new byte on  tx_clk_p_buff (0) assertion (with s_bit_index = 0)
-- bit delivery        after tx_clk_p_buff (1) assertion
-- new byte available  after tx_clk_p_buff (2) assertion (to be sent on the next tx_clk_p_buff (1))
-- s_bit_index updated after tx_clk_p_buff (3) assertion (the s_bit_index here loops several times
--                                                       (between 0 and 16 for each byte, until the
--                                                                      last_byte_p_i gives a pulse)

-- the first data byte from the WF_prod_bytes_to_tx unit is already available after the assertion of the
-- start_produce_p_i signal; for the rest, there is a request of a new byte when the s_bit_index
-- arrives to zero and on the assertion of the tx_clk_p_buff (0). A pulse on the request_byte signal
-- triggers the WF_control_engine to send a new address to the memory of the produced_vars unit (new
-- address available on tx_clk_p_buff (1)), which in turn will give an output one uclk cycle later
-- (on tx_clk_p_buff (2)), exactly on the assertion of the byte_ready_p_i. Finally the first bit of
-- this new byte starts being delivered after tx_clk_p_buff (3) assertion.

-- jump to "send_crc_bytes" state after the arrival of the last_byte_p_i pulse (on the
-- tx_clk_p_buff (2), along with the byte_ready_p_i). Differently than in the previous case, now
-- the state transition takes place after the tx_clk_p_buff (2) assertion. This is essential in
-- order to force the s_bit_index (which is updated after tx_clk_p_buff(3) assertion) to the
-- s_bit_index_top indicated by the "send_crc_bytes" state (31 bits) and not to the one of the
-- "send_data_byte" state (16 bits).
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --

-- "send_crc_bytes" state: delivery of the two manchester encoded bytes that come out of the CRC 
-- calculator unit (2 bytes).

-- bit delivery starts after each        tx_clk_p_buff (1) assertion (Bits_Delivery process)
-- the s_bit_index is updated after each tx_clk_p_buff (3) assertion (s_bit_index is ahead of the
-- bit being sent)

-- jump to "send_queue" state after the arrival of the last_byte_p_i pulse (on the tx_clk_p_buff(2)
-- along with the byte_ready_p_i). As before, the state transition is essential before the update
-- of the s_bit_index
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  

--!@brief synchronous process Receiver_FSM_Sync:

  Transmitter_FSM_Sync: process(uclk_i)
  begin
    if rising_edge(uclk_i) then
      if nFIP_urst_i = '1' then
        tx_state <= idle;
      else
        tx_state <= nx_tx_state;
      end if;
    end if;
  end process;

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
--!@brief combinatorial process Transmitter_FSM_Comb_State_Transitions:
--! definition of the state transitions of the FSM

  Transmitter_FSM_Comb_State_Transitions: process (tx_state, last_byte_p_i, s_bit_index_is_zero,
                                                             start_produce_p_i,  tx_clk_p_buff_i)
  begin
    nx_tx_state <= idle;

    case tx_state is 

      when idle =>
                           if start_produce_p_i = '1' then
                             nx_tx_state <= send_fss;
                           else
                             nx_tx_state <= idle;
                           end if;

      when send_fss =>
                           if s_bit_index_is_zero = '1'  and  tx_clk_p_buff_i(C_TXCLKBUFFLENTGTH-1) = '1' then 
                             nx_tx_state <= send_data_byte;
                           else
                             nx_tx_state <= send_fss;
                           end if;

      when send_data_byte =>
                           if last_byte_p_i = '1' then
                             nx_tx_state <= send_crc_bytes;
                           else
                             nx_tx_state <= send_data_byte;
                           end if;

      when send_crc_bytes =>
                           if s_bit_index_is_zero = '1' and  tx_clk_p_buff_i(C_TXCLKBUFFLENTGTH-2) = '1' then 
                             nx_tx_state <= send_queue;
                           else
                             nx_tx_state <= send_crc_bytes;
                           end if;

      when send_queue =>
                           if s_bit_index_is_zero = '1' and  tx_clk_p_buff_i(C_TXCLKBUFFLENTGTH-2) = '1' then 
                             nx_tx_state <= stop_transmission;
                           else
                             nx_tx_state <= send_queue;
                           end if;   

      when stop_transmission =>
                           if tx_clk_p_buff_i(C_TXCLKBUFFLENTGTH-2) = '1' then 
                             nx_tx_state <= idle;
                           else
                             nx_tx_state <= stop_transmission;
                           end if;  



      when others =>
                           nx_tx_state <= idle;
    end case;
  end process;


 --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
--!@brief combinatorial process Transmitter_FSM_Comb_Output_Signals:
--! definition of the output signals of the FSM

  Transmitter_FSM_Comb_Output_Signals:  process ( tx_state )
  begin

    case tx_state is 

      when idle => 
                -- initializations   
                s_decr_index         <= '0';
                s_prepare_to_produce <= '1';
                s_sending_FSS        <= '0';
                s_sending_data       <= '0';
                s_sending_CRC        <= '0';
                s_sending_QUEUE      <= '0';
                s_stop_transmission  <= '0';


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- -- 
      when send_fss =>

                s_decr_index         <= '0';
                s_prepare_to_produce <= '0';
                s_sending_FSS        <= '1';
                s_sending_data       <= '0';
                s_sending_CRC        <= '0';
                s_sending_QUEUE      <= '0';
                s_stop_transmission  <= '0';


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- -- 
      when send_data_byte  => 

                s_decr_index         <= '0';
                s_prepare_to_produce <= '0';
                s_sending_FSS        <= '0';
                s_sending_data       <= '1';
                s_sending_CRC        <= '0';
                s_sending_QUEUE      <= '0';
                s_stop_transmission  <= '0';


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- -- 
       when send_crc_bytes =>
                s_decr_index         <= '0';
                s_prepare_to_produce <= '0';
                s_sending_FSS        <= '0';
                s_sending_data       <= '0';
                s_sending_CRC        <= '1';
                s_sending_QUEUE      <= '0';
                s_stop_transmission  <= '0';


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --
      when send_queue =>
                s_decr_index         <= '0';
                s_prepare_to_produce <= '0';
                s_sending_FSS        <= '0';
                s_sending_data       <= '0';
                s_sending_CRC        <= '0';
                s_sending_QUEUE      <= '1';
                s_stop_transmission  <= '0';


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --
      when stop_transmission =>
                s_decr_index         <= '0';
                s_prepare_to_produce <= '0';
                s_sending_FSS        <= '0';
                s_sending_data       <= '0';
                s_sending_CRC        <= '0';
                s_sending_QUEUE      <= '0';
                s_stop_transmission  <= '1';

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --
      when others => 
                s_decr_index         <= '0';
                s_prepare_to_produce <= '0';
                s_sending_FSS        <= '0';
                s_sending_data       <= '0';
                s_sending_CRC        <= '0';
                s_sending_QUEUE      <= '0';
                s_stop_transmission  <= '0';

    end case;
  end process;


---------------------------------------------------------------------------------------------------
--@brief Instantiation of a manchester encoder for a data byte (8 bits long)
data_byte_manc_encoder: WF_manch_encoder 
  generic map(word_length  => 8)
  port map(
    word_i       => s_byte,
    word_manch_o => s_data_byte_manch
      );

---------------------------------------------------------------------------------------------------
--@brief Instantiation of a manchester encoder for the CRC bytes (16 bits long)
crc_bytes_manc_encoder: WF_manch_encoder 
  generic map(word_length => 16)
  port map(
    word_i       => s_crc_bytes,
    word_manch_o => s_crc_bytes_manch
      );


---------------------------------------------------------------------------------------------------
--!@brief CRC calculator
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
-- Instantiation of the CRC unit 
  crc_generation: WF_crc 
    generic map( 
      c_GENERATOR_POLY_length => 16)
    port map(
      uclk_i             => uclk_i,
      nFIP_urst_i         => nFIP_urst_i,
      start_CRC_p_i      => s_start_crc_p,
      data_bit_ready_p_i => s_data_bit_to_crc_p,
      data_bit_i         => s_txd,
      CRC_o              => s_crc_bytes,
      CRC_ok_p           => open);
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
-- concurrent signals assignement for the crc_generator inputs

  s_start_crc_p       <= s_sending_FSS and s_bit_index_is_zero and  tx_clk_p_buff_i(C_TXCLKBUFFLENTGTH-1);
  -- the CRC calculation starts when at the end of the FSS (beginning of data bytes delivery)

  s_data_bit_to_crc_p <= s_sending_data and s_bit_index(0) and tx_clk_p_buff_i(C_TXCLKBUFFLENTGTH-1);
  -- only the 1st part of a manchester encoded bit goes to the CRC calculator 


---------------------------------------------------------------------------------------------------
--@brief Managment of the pointer that indicates which bit of a manchester encoded byte is to be
--! delivered. According to the state of the FSM, a byte may be a FSS one, or a data byte or a
--! CRC or a FES byte. 
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
-- Instantiation of a bits counter:  
    Outgoing_Bits_Index: WF_decr_counter
    generic map(counter_length => 5)
    port map(
      uclk_i              => uclk_i,
      nFIP_urst_i          => nFIP_urst_i,      
      counter_top         => s_bit_index_top,
      counter_load_i      => s_bit_index_load,
      counter_decr_p_i    => s_decr_index_p,
      counter_o           => s_bit_index,
      counter_is_zero_o   => s_bit_index_is_zero);

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
-- Combinatorial process that according to the state of the FSM sets the values to the
-- Outgoing_Bits_Index inputs

  Bit_Index: process (s_prepare_to_produce,s_sending_FSS, s_sending_data, s_sending_crc,
                      s_sending_QUEUE, s_bit_index_is_zero,tx_clk_p_buff_i)
  begin

    if s_prepare_to_produce ='1' then
      s_bit_index_top  <= to_unsigned (FSS'length - 1, s_bit_index'length);   
      s_bit_index_load <= '1';
      s_decr_index_p   <= '0';
      

    elsif s_sending_FSS = '1' then
      s_bit_index_top  <= to_unsigned (15, s_bit_index'length);
      s_bit_index_load <= s_bit_index_is_zero and  tx_clk_p_buff_i(C_TXCLKBUFFLENTGTH-1);
      s_decr_index_p   <= tx_clk_p_buff_i(C_TXCLKBUFFLENTGTH-1);

    elsif s_sending_data = '1' then
      s_bit_index_top  <= to_unsigned (15, s_bit_index'length);
      s_bit_index_load <= s_bit_index_is_zero and  tx_clk_p_buff_i(C_TXCLKBUFFLENTGTH-1);
      s_decr_index_p   <= tx_clk_p_buff_i(C_TXCLKBUFFLENTGTH-1);

    elsif s_sending_crc = '1' then
      s_bit_index_top  <= to_unsigned (s_crc_bytes_manch'length-1, s_bit_index'length); 
      s_bit_index_load <= s_bit_index_is_zero and  tx_clk_p_buff_i(C_TXCLKBUFFLENTGTH-1);
      s_decr_index_p   <= tx_clk_p_buff_i(C_TXCLKBUFFLENTGTH-1);

    elsif s_sending_QUEUE = '1' then
      s_bit_index_top  <= to_unsigned (FRAME_END'length - 1, s_bit_index'length); 
      s_bit_index_load <= s_bit_index_is_zero and  tx_clk_p_buff_i(C_TXCLKBUFFLENTGTH-1);
      s_decr_index_p   <= tx_clk_p_buff_i(C_TXCLKBUFFLENTGTH-1);

    else
      s_bit_index_top  <= to_unsigned (FSS'length - 1, s_bit_index'length); 
      s_bit_index_load <= '0';
      s_decr_index_p   <= '0';
    end if;
  end process;


--------------------------------------------------------------------------------------------------
--!@brief Instantiation of the unit that according to the state of the FSM and the
--! bits index counter, outputs FSS, data, CRC or FES manchester encoded bits to the txd_o.
--! The unit also and manages the tx_enable_o signal.
  bits_to_txd: WF_bits_to_txd
    port map(
      uclk_i              => uclk_i,
      nFIP_urst_i         => nFIP_urst_i,          
      txd_bit_index_i     => s_bit_index,
      data_byte_manch_i   => s_data_byte_manch, 
      crc_byte_manch_i    => s_crc_bytes_manch, 
      sending_FSS_i       => s_sending_FSS,
      sending_data_i      => s_sending_data, 
      sending_crc_i       => s_sending_crc,
      sending_QUEUE_i     => s_sending_queue,
      stop_transmission_i => s_stop_transmission,
      tx_clk_p_buff_i     => tx_clk_p_buff_i,  
      txd_o               => s_txd,     
      tx_enable_o         => tx_enable_o);

--------------------------------------------------------------------------------------------------
Input_Byte_Sampling: process(uclk_i)
  begin
    if rising_edge(uclk_i) then
      if nFIP_urst_i = '1' then
        s_byte   <= (others => '0');

      else      

        if byte_ready_p_i = '1' then
          s_byte <= byte_i;

        end if;
      end if;
    end if;
  end process;


---------------------------------------------------------------------------------------------------
  tx_data_o <= s_txd;

  request_byte_p_o    <= s_sending_data and s_bit_index_is_zero and  tx_clk_p_buff_i(C_TXCLKBUFFLENTGTH-4);
  -- request for a new byte from the WF_prod_bytes_to_tx unit (passing from WF_engine_control)


end architecture rtl;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------