--=================================================================================================
--! @file wf_tx.vhd
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
--                                            wf_tx                                              --
--                                                                                               --
--                                        CERN, BE/CO/HT                                         --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
-- unit name:  wf_tx
--
--
--! @brief     Serialises the WorldFIP data.
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
--!     wf_engine           \n
--!     tx_engine           \n
--!     clk_gen             \n
--!     reset_logic         \n
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
--!                      briefly add_offset_i needed to arrive 1 clock tick earlier       
--
---------------------------------------------------------------------------------------------------
--
--! @todo -> comments!!
--
---------------------------------------------------------------------------------------------------


--=================================================================================================
--!                               Entity declaration for wf_tx_rx
--=================================================================================================
entity wf_tx is
  generic(
    C_CLKFCDLENTGTH :  natural := 4 );
  port (
  -- INPUTS 
    -- user interface general signals 
    uclk_i :            in std_logic; --! 40MHz clock

    -- Signal from the reset_logic unit
    nFIP_rst_i :        in std_logic; --! internal reset
    
    -- Signals from the wf_engine_control
    start_produce_p_i : in std_logic; --! indication that wf_engine_control is in prod_watchdog state 
                                      -- a correct id_dat asking for a produced var has been 
                                      -- received and ............ 
    byte_ready_p_i :    in std_logic; --! indication that a byte is ready to be delivered   
    last_byte_p_i :     in std_logic; --! indication that it is the last byte of data
                                      --  crc bytes follow

    -- Signals from the wf_produced_vars
    byte_i :            in std_logic_vector(7 downto 0); --! byte of data to be delivered 

     -- Signal from the wf_rx_tx_osc    
    tx_clk_p_buff_i :   in std_logic_vector(C_CLKFCDLENTGTH-1 downto 0);--!clk for transmission synch
                                                                                      -- ronization 

  -- OUTPUTS

    -- Signal to wf_engine_control
    request_byte_p_o :  out std_logic;

    -- nanoFIP output signals
    tx_data_o :         out std_logic;
    tx_enable_o :       out std_logic
    );

end entity wf_tx;



--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of wf_tx is


  type tx_state_t  is (idle, send_fss, send_data_byte, send_crc_bytes, send_queue);

  signal tx_state, nx_tx_state :               tx_state_t;

  signal s_start_crc_p :                       std_logic;
  signal s_d_to_crc_rdy_p :                    std_logic;
  signal s_data_bit, s_tx_enable :             std_logic;
  signal s_load_pointer, s_decr_pointer :      std_logic;
  signal s_nx_data_to_crc, s_tx_finished_p :   std_logic;
  signal s_pointer_is_zero, s_pointer_is_one : std_logic;
  signal s_byte :                              std_logic_vector(7 downto 0);
  signal s_manchester_crc :                    std_logic_vector(31 downto 0);
  signal s_crc, s_manchester_byte :            std_logic_vector(15 downto 0);
  signal s_pointer, s_top_pointer :            unsigned(4 downto 0);


--=================================================================================================
--                                      architecture begin
--=================================================================================================  
begin

---------------------------------------------------------------------------------------------------
 --!@brief instantiation of the crc calculator unit 
  crc_generation: wf_crc 
    generic map( 
      c_GENERATOR_POLY_length => 16)
    port map(
      uclk_i => uclk_i,
      nFIP_rst_i => nFIP_rst_i,
      start_crc_p_i => s_start_crc_p,
      data_bit_ready_p_i  => s_d_to_crc_rdy_p,
      data_bit_i  => s_nx_data_to_crc,
      crc_o  => s_crc,
      crc_ok_p => open
      );

     s_nx_data_to_crc <= s_data_bit;

---------------------------------------------------------------------------------------------------
--!@brief Transmitter's state machine: the state machine is divided in three parts (a clocked 
--! process to store the current state, a combinatorial process to manage state transitions and 
--! finally a combinatorial process to manage the output signals), which are the 3 processes that
--! follow. The unit, 

--! The signal tx_clk_p_buff_i is used for the synchronization of all the transitions and actions
--! in the unit. 

-- The following draft drawing shows the transitions of the signal tx_clk_p_buff_i with respect to
-- the transmission clock tx_clk (tx_clk is not used in this unit, but it may be used by the
-- receiver for the decoding and synchronization of the incoming data)

-- tx_clk:           __________|----------------|________________|----------------|_______________
-- tx_clk_p_buff (2):          |0|0|1|0                          |0|0|1|0
-- tx_clk_p_buff (1):          |0|1|0|0                          |0|1|0|0
-- tx_clk_p_buff (0):          |1|0|0|0                          |1|0|0|0

-- idle state: signals initializations
-- jump to send_fss state after a pulse arrival from the signal start_produce_p_i (controlled by the
-- wf_engine_control)

-- send_fss state: delivery of the manchester encoded bits of the Frame Start Sequence (including
-- preamble and Frame Start delimiter).
-- 32 bits to be sent (2 encoded bytes)
-- bit delivery after tx_clk_p_buff (0) assertion
-- s_pointer updated after tx_clk_p_buff (2) assertion

-- jump to send_data_byte state after the 32nd bit delivery (after tx_clk_p_buff(0) assertion),
-- and after tx_clk_p_buff(2) assertion

-- send_data_byte state: delivery of manchester encoded bits of data that arrive from the
-- wf_produced_vars unit (byte_i), with the coordination of the wf_engine_control (byte_ready_p_i)
-- bit delivery after tx_clk_p_buff (0) assertion
-- s_pointer updated after tx_clk_p_buff (2) assertion

-- jump to send_crc_byte state after the delivery of the required bytes and the arrival of the
-- last_byte_p_i pulse (after the assertion of tx_clk_p_buff (1). a pulse on last_byte_p_i arrives
-- after a pulse on the request_byte_p_o if the number of bytes sent maches the requested one)
-- therefore, the transition to the state send_crc_byte takes places after after the assertion of
-- tx_clk_p_buff (1), which is 1 uclk tick earlier than in the previous transitions. This earlier
-- transition to the send_crc_byte state is essential in order to force the s_pointer (which is
-- considered on tx_clk_p_buff(2)) to the s_top_pointer indicated by the send_crc_byte state (31).

-- send_crc_byte state: delivery of the two manchester encoded bytes that come out of the crc 
-- calculator unit.
-- bit delivery after tx_clk_p_buff (0) assertion
-- s_pointer updated after tx_clk_p_buff (2) assertion

--

-- request to wf_engine_control for a new byte when s_pointer is emptied (previous byte is sent)
-- after the assertion of tx_clk_p_buff(0)
-- arrivals of a new byte (byte_i) from the wf_produced_vars and of the byte_ready_p_i
-- confirmation from the wf_engine_control on the next uclk cycle. 
-- buffering of byte_i, and availability after tx_clk_p_buff(1) assertion for the next cycle
-- concurrent manchester encoding

-- state change to send_crc_byte after the delivery of all the bytes and the assertion of the
-- signal last_byte_p_i (which happens after the a request_byte_p_ib pulse  of  
-- and after tx_clk_p_buff(1) assertion. The earlier transition to the send_crc_byte state is
-- essential in order to force the s_pointer (which is considered on tx_clk_p_buff(2)) to the
-- s_top_pointer indicated by the send_crc_byte state (31).

-- send_data_byte state: reception of bytes of data from wf_produced_vars, encoding and delivery
-- request o
-- with the s_pointer emptys and tx_clk_p_buff (0) is activated. The wf_engine_control replys 
-- with assertying the input byte_ready_p_i on the next uclk tick. Finally on tx_clk_p_buff (2)
-- the 1st bit of the new byte is delivered. In this state each time a byte of data is sent after the
-- assesment of tx_clk_p_buff (0). The pointer s_pointer is counting the bits of a byte that are
-- being sent and it is decreased after the assesment of tx_clk_p_buff (2) 
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
--!@brief synchronous process Receiver_FSM_Sync:

  Transmitter_FSM_Sync: process(uclk_i)
  begin
    if rising_edge(uclk_i) then
      if nFIP_rst_i = '1' then
        tx_state <= idle;
      else
        tx_state <= nx_tx_state;
      end if;
    end if;
  end process;

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
--!@brief combinatorial process Transmitter_FSM_Comb_State_Transitions:
--! definition of the state transitions of the FSM

  Transmitter_FSM_Comb_State_Transitions: process (tx_state, last_byte_p_i, s_pointer_is_zero,
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
                           if s_pointer_is_zero = '1'  and  tx_clk_p_buff_i(C_CLKFCDLENTGTH-1) = '1' then -- was 2
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
                           if s_pointer_is_zero = '1' and  tx_clk_p_buff_i(C_CLKFCDLENTGTH-2) = '1' then -- was 1
                             nx_tx_state <= send_queue;
                           else
                             nx_tx_state <= send_crc_bytes;
                           end if;

      when send_queue =>
                           if s_pointer_is_zero = '1' and  tx_clk_p_buff_i(C_CLKFCDLENTGTH-2) = '1' then -- was 1
                             nx_tx_state <= idle;
                           else
                             nx_tx_state <= send_queue;
                           end if;      

      when others =>
                           nx_tx_state <= idle;
    end case;
  end process;


 --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
--!@brief combinatorial process Transmitter_FSM_Comb_Output_Signals:
--! definition of the output signals of the FSM

  Transmitter_FSM_Comb_Output_Signals:  process ( tx_state, s_pointer_is_zero, s_manchester_crc,
                                                 s_pointer, tx_clk_p_buff_i, s_manchester_byte )
  begin

    case tx_state is 

      when idle =>         -- initializations    
                           s_decr_pointer <= '0';
                           s_data_bit <= '0';
                           s_tx_enable <= '0';
                           request_byte_p_o <= '0';
                           s_d_to_crc_rdy_p <= '0';
                           s_start_crc_p <= '0';
                           s_load_pointer <= '1';
                           s_tx_finished_p <= '0';

                           -- preparations for the next state
   
                           s_top_pointer <= to_unsigned ( FSS'length - 1, s_pointer'length );
                                                              -- initialize according to
                                                              -- the data that will be
                                                              -- sent at the next state: 
                                                              -- FSS: 31 manchester encoded bits

  

                           
      when send_fss =>
                           s_tx_enable <= '1';                -- data being sent;transmitter enabld

                           s_decr_pointer <= tx_clk_p_buff_i(C_CLKFCDLENTGTH-1);-- was 2

                           s_data_bit <= FSS ( to_integer (s_pointer) ); -- 31 predefined manchester
                                                              -- encoded bits

                           request_byte_p_o <= '0';           -- FSS predefined bytes
                                                              -- no request from control_engine
                           s_d_to_crc_rdy_p <= '0';           -- FSS not used in crc calculations

                           -- preparations for the next state
                           s_top_pointer <= to_unsigned ( 15, s_pointer'length );
                                                              -- initialize according to
                                                              -- the data that will be
                                                              -- sent at the next state: 
                                                              -- 1 byte: 16 manchester encoded bits

                           s_load_pointer <= s_pointer_is_zero and  tx_clk_p_buff_i(C_CLKFCDLENTGTH-1);  -- was 2
                                                              -- pointer loaded at
                                                              -- the end of this state

                           s_start_crc_p <= s_pointer_is_zero and  tx_clk_p_buff_i(C_CLKFCDLENTGTH-1);   --was 2

                           s_tx_finished_p <= '0';


      when send_data_byte  => 
                           s_tx_enable <= '1';                  -- data being sent;transmitter enabld

                           s_decr_pointer <= tx_clk_p_buff_i (C_CLKFCDLENTGTH-1); -- was 2

                           s_data_bit <= s_manchester_byte (to_integer (resize ( s_pointer, 4 ))); -- 16 manchester encoded bits

                           s_top_pointer <= to_unsigned ( 15, s_pointer'length ); 

                           s_load_pointer <= s_pointer_is_zero and  tx_clk_p_buff_i(C_CLKFCDLENTGTH-1);  --was 2

                           s_d_to_crc_rdy_p <= tx_clk_p_buff_i(C_CLKFCDLENTGTH-1) and s_pointer(0);  -- was 2

                           request_byte_p_o <= s_pointer_is_zero and  tx_clk_p_buff_i(C_CLKFCDLENTGTH-4);

                           s_start_crc_p <= '0';

                           s_tx_finished_p <= '0';


       when send_crc_bytes =>
                           s_top_pointer <=to_unsigned(s_manchester_crc'length-1,s_pointer'length); 
                           s_load_pointer <= s_pointer_is_zero and tx_clk_p_buff_i(C_CLKFCDLENTGTH-1);  -- was 2
                           s_decr_pointer <= tx_clk_p_buff_i(C_CLKFCDLENTGTH-1);  -- was 2
                           s_data_bit <= s_manchester_crc(to_integer(resize(s_pointer,5))); -- crc: 31 manchester encoded bits
                           s_tx_enable <= '1';

                           s_d_to_crc_rdy_p <= '0';
                           request_byte_p_o <= '0';
                           s_start_crc_p <= '0';
        -- I enable the crc shift register at the bit boundaries by 
        -- inverting s_pointer(0)                         

                           s_tx_finished_p <= '0';
 

      when send_queue =>
                           s_top_pointer <= to_unsigned ( FRAME_END'length - 1, s_pointer'length ); 
                           s_load_pointer <= s_pointer_is_zero and  tx_clk_p_buff_i(C_CLKFCDLENTGTH-1);  -- was 2
                           s_decr_pointer <= tx_clk_p_buff_i(C_CLKFCDLENTGTH-1);  -- was 2
                           s_data_bit <= FRAME_END(to_integer(resize(s_pointer,4))); -- Frame_End 16 manchester encoded bits
                           s_tx_enable <= '1';
                           s_tx_finished_p <= s_pointer_is_zero and  tx_clk_p_buff_i(C_CLKFCDLENTGTH-2);  -- was 1

                           s_d_to_crc_rdy_p <= '0';
                           request_byte_p_o <= '0';
                           s_start_crc_p <= '0';

      when others => 

    end case;
  end process;

---------------------------------------------------------------------------------------------------


  process(uclk_i)
  begin
    if rising_edge(uclk_i) then
      if nFIP_rst_i = '1' then
        s_byte <= (others => '0');
      else      
        if byte_ready_p_i = '1' then
          s_byte <= byte_i;
        end if;
      end if;
    end if;
  end process;

---------------------------------------------------------------------------------------------------
--! @brief combinatorial process Manchester_Encoder_byte: The process takes a byte (8 bits) and
--! creates its manchester encoded equivalent (16 bits). Each bit '1' is replaced by '10' and each
--! bit '0' by '01'. 

  Manchester_Encoder_byte: process(s_byte)
  begin
    for I in byte_i'range loop
      s_manchester_byte(I*2) <= not s_byte(I);
      s_manchester_byte(I*2+1) <=  s_byte(I);
    end loop;
  end process;

---------------------------------------------------------------------------------------------------
--! @brief combinatorial process Manchester_Encoder_crc_byte: The process takes a byte (8 bits) and
--! creates its manchester encoded equivalent (16 bits). Each bit '1' is replaced by '10' and each
--! bit '0' by '01'. 

  Manchester_Encoder_crc_byte: process(s_crc)
  begin
    for I in s_crc'range loop
      s_manchester_crc(I*2) <= not s_crc(I);
      s_manchester_crc(I*2+1) <=  s_crc(I);
    end loop;
  end process;


---------------------------------------------------------------------------------------------------
--! @brief synchronous process tx_Outputs:managment of nanoFIP output signals tx_data and tx_enable 
--! tx_data: placement of bits of data to the output of the unit
--! tx_enable: flip-floped s_tx_enable (s_tx_enable is activated during bits delivery: from the 
--! beginning of tx_state send_fss until the end of send_queue state)  

  Bits_Delivery: process(uclk_i)
  begin
    if rising_edge(uclk_i) then
      if nFIP_rst_i = '1' then
        tx_data_o <= '0';
        tx_enable_o <= '0';
      else
        if  tx_clk_p_buff_i(C_CLKFCDLENTGTH-3) = '1' then -- was 0
          tx_data_o <= s_data_bit;
        end if;
      tx_enable_o <= s_tx_enable;
      end if;
    end if;
  end process;

---------------------------------------------------------------------------------------------------
--! @brief synchronous process Outgoing_Bits_Pointer: Managment of the pointer that indicates which
--! bit of a manchester encoded byte is to be sent (16 bits)  

  Outgoing_Bits_Pointer: process(uclk_i)
  begin
    if rising_edge(uclk_i) then
      if nFIP_rst_i = '1' then
        s_pointer <= (others => '0');
      else

        if s_load_pointer = '1' then
          s_pointer <= s_top_pointer;
        elsif s_decr_pointer = '1' then
          s_pointer <= s_pointer - 1;
        end if;
      end if;
    end if;
  end process;

---------------------------------------------------------------------------------------------------
  s_pointer_is_zero <= '1' when s_pointer = to_unsigned(0,s_pointer'length) else '0';
  s_pointer_is_one <= '1' when s_pointer = to_unsigned(1,s_pointer'length) else '0';


end architecture rtl;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------