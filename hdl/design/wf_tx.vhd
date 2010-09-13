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
--!     wf_reset_unit         \n
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
--!                               Entity declaration for wf_tx_rx
--=================================================================================================
entity wf_tx is
  generic(
    C_CLKFCDLENTGTH :  natural := 4 );
  port (
  -- INPUTS 
    -- user interface general signals 
    uclk_i :            in std_logic;  --! 40MHz clock

    -- Signal from the wf_reset_unit unit
    nFIP_rst_i :        in std_logic;  --! internal reset
    
    -- Signals from the wf_engine_control
    start_produce_p_i : in std_logic;  --! indication that wf_engine_control is in prod_watchdog state 
                                       -- a correct id_dat asking for a produced var has been 
                                       -- received and ............ 

    byte_ready_p_i :    in std_logic;  --! indication that a byte is ready to be delivered   
    last_byte_p_i :     in std_logic;  --! indication that it is the last byte of data
                                       --  crc bytes follow

    -- Signals from the wf_produced_vars
    byte_i :            in std_logic_vector (7 downto 0);             
                                       --! data byte to be delivered 

     -- Signal from the wf_rx_tx_osc    
    tx_clk_p_buff_i :   in std_logic_vector (C_CLKFCDLENTGTH-1 downto 0);
                                       --! clk for transmission synchronization 

  -- OUTPUTS

    -- Signal to wf_engine_control
    request_byte_p_o :  out std_logic;

    -- nanoFIP output signals
    tx_data_o :         out std_logic; --! transmitter serial data
    tx_enable_o :       out std_logic  --! transmitter enable
    );

end entity wf_tx;



--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of wf_tx is


  type tx_state_t  is (idle, send_fss, send_data_byte, send_crc_bytes, send_queue);

  signal tx_state, nx_tx_state :               tx_state_t;

  signal s_start_crc_p :                       std_logic;
  signal s_data_bit_to_crc_p :                 std_logic;
  signal s_data_bit, s_tx_enable :             std_logic;
  signal s_bit_index_load, s_decr_index :      std_logic;
  signal s_bit_index_is_zero :                 std_logic;
  signal s_bit_index, s_bit_index_top :        unsigned(4 downto 0);
  signal s_byte :                              std_logic_vector (7 downto 0);
  signal s_manchester_crc :                    std_logic_vector (31 downto 0);
  signal s_crc_byte_manch, s_byte_manch :      std_logic_vector (15 downto 0);


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
      uclk_i             => uclk_i,
      nFIP_rst_i         => nFIP_rst_i,
      start_crc_p_i      => s_start_crc_p,
      data_bit_ready_p_i => s_data_bit_to_crc_p,
      data_bit_i         => s_data_bit,
      crc_o              => s_crc_byte_manch,
      crc_ok_p           => open
      );

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
-- wf_engine_control)

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
-- wf_produced_vars unit (byte_i), with the coordination of the wf_engine_control (byte_ready_p_i)
-- request of a new byte on  tx_clk_p_buff (0) assertion (with s_bit_index = 0)
-- bit delivery        after tx_clk_p_buff (1) assertion
-- new byte available  after tx_clk_p_buff (2) assertion (to be sent on the next tx_clk_p_buff (1))
-- s_bit_index updated after tx_clk_p_buff (3) assertion (the s_bit_index here loops several times
--                                                       (between 0 and 16 for each byte, until the
--                                                                      last_byte_p_i gives a pulse)

-- the first data byte from the wf_produced_vars unit is already available after the assertion of the
-- start_produce_p_i signal; for the rest, there is a request of a new byte when the s_bit_index
-- arrives to zero and on the assertion of the tx_clk_p_buff (0). A pulse on the request_byte signal
-- triggers the wf_control_engine to send a new address to the memory of the produced_vars unit (new
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

-- "send_crc_bytes" state: delivery of the two manchester encoded bytes that come out of the crc 
-- calculator unit (2 bytes).

-- bit delivery starts after each        tx_clk_p_buff (1) assertion (Bits_Delivery process)
-- the s_bit_index is updated after each tx_clk_p_buff (3) assertion (s_bit_index is ahead of the
-- bit being sent)

-- jump to "send_queue" state after the arrival of the last_byte_p_i pulse (on the tx_clk_p_buff(2)
-- along with the byte_ready_p_i). As before, the state transition is essential before the update
-- of the s_bit_index
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 





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
                           if s_bit_index_is_zero = '1'  and  tx_clk_p_buff_i(C_CLKFCDLENTGTH-1) = '1' then 
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
                           if s_bit_index_is_zero = '1' and  tx_clk_p_buff_i(C_CLKFCDLENTGTH-2) = '1' then 
                             nx_tx_state <= send_queue;
                           else
                             nx_tx_state <= send_crc_bytes;
                           end if;

      when send_queue =>
                           if s_bit_index_is_zero = '1' and  tx_clk_p_buff_i(C_CLKFCDLENTGTH-2) = '1' then 
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

  Transmitter_FSM_Comb_Output_Signals:  process ( tx_state, s_bit_index_is_zero, s_manchester_crc,
                                                 s_bit_index, tx_clk_p_buff_i, s_byte_manch )
  begin

    case tx_state is 

      when idle => 
                -- initializations    
                s_decr_index        <= '0';
                s_data_bit          <= '0';
                s_tx_enable         <= '0';
                request_byte_p_o    <= '0';
                s_data_bit_to_crc_p <= '0';
                s_start_crc_p       <= '0';
                s_bit_index_load    <= '1';

                -- preparations for the next state
   
                s_bit_index_top     <= to_unsigned ( FSS'length - 1, s_bit_index'length );
                                                           -- initialize according to
                                                           -- the data that will be
                                                           -- sent at the next state: 
                                                           -- FSS: 31 manchester encoded bits

  

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- -- 
      when send_fss =>

                s_tx_enable         <= '1';                -- data being sent;transmitter enabld

                s_decr_index        <= tx_clk_p_buff_i(C_CLKFCDLENTGTH-1);

                s_data_bit          <= FSS (to_integer (s_bit_index));
                                                           -- 31 predefined manch encoded bits

                request_byte_p_o    <= '0';                -- predefined bytes; no request for
                                                           -- bytes from control_engine
                                                           
                s_data_bit_to_crc_p <= '0';                -- FSS not used in crc calculations


                -- preparations for the next state
                s_bit_index_top     <= to_unsigned ( 15, s_bit_index'length );
                                                           -- initialization according to the
                                                           -- data that will be sent at the next
                                                           -- state:1 byte(16 manch encoded bits)

                s_bit_index_load    <= s_bit_index_is_zero and  tx_clk_p_buff_i(C_CLKFCDLENTGTH-1);
                                                           -- pointer loaded at
                                                           -- the end of this state

                s_start_crc_p       <= s_bit_index_is_zero and  tx_clk_p_buff_i(C_CLKFCDLENTGTH-1);
                                                           -- beginning of considering data bits
                                                           -- for the crc calculation when the 
                                                           -- 1st bit of data is to be sent 
                                                           -- (note: the crc calculator uses the
                                                           -- signal s_data_bit, not tx_data_o)


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- -- 
      when send_data_byte  => 

                s_tx_enable         <= '1';                -- data being sent;transmitter enabld


                s_bit_index_load    <= s_bit_index_is_zero and  tx_clk_p_buff_i(C_CLKFCDLENTGTH-1);
                                                           -- index reinitialized to
                                                           -- s_bit_index_top at the end of each
                                                           -- byte transmission

                s_bit_index_top     <= to_unsigned (15, s_bit_index'length ); 

                s_decr_index        <= tx_clk_p_buff_i (C_CLKFCDLENTGTH-1); 
                                         
                s_data_bit          <= s_byte_manch (to_integer (resize (s_bit_index, 4)));

                request_byte_p_o    <= s_bit_index_is_zero and  tx_clk_p_buff_i(C_CLKFCDLENTGTH-4);
                                                           -- request for a new byte from
                                                           -- wf_produced_vars (passing from
                                                           -- wf_engine_control)
                                                             
                s_data_bit_to_crc_p <= s_bit_index(0) and tx_clk_p_buff_i(C_CLKFCDLENTGTH-1);
                                                           -- only the 1st part of the manch
                                                           -- encoded bit goes to the crc
                                                           -- calculator 

                s_start_crc_p       <= '0';


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- -- 
       when send_crc_bytes =>

                s_tx_enable         <= '1';

                s_bit_index_load    <= s_bit_index_is_zero and tx_clk_p_buff_i(C_CLKFCDLENTGTH-1);

                s_bit_index_top     <= to_unsigned (s_manchester_crc'length-1, s_bit_index'length); 

                s_decr_index        <= tx_clk_p_buff_i(C_CLKFCDLENTGTH-1);

                s_data_bit          <= s_manchester_crc (to_integer(s_bit_index)); 

                request_byte_p_o    <= '0';
                s_data_bit_to_crc_p <= '0';
                s_start_crc_p       <= '0';

 
      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --
      when send_queue =>

                s_tx_enable         <= '1';

                s_bit_index_load    <= s_bit_index_is_zero and  tx_clk_p_buff_i(C_CLKFCDLENTGTH-1);  

                s_bit_index_top     <= to_unsigned (FRAME_END'length - 1, s_bit_index'length); 

                s_decr_index        <= tx_clk_p_buff_i(C_CLKFCDLENTGTH-1);

                s_data_bit          <= FRAME_END(to_integer(resize(s_bit_index,4))); 

                s_data_bit_to_crc_p <= '0';
                request_byte_p_o    <= '0';
                s_start_crc_p       <= '0';


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --
      when others => 

                s_decr_index        <= '0';
                s_data_bit          <= '0';
                s_tx_enable         <= '0';
                request_byte_p_o    <= '0';
                s_data_bit_to_crc_p <= '0';
                s_start_crc_p       <= '0';
                s_bit_index_load    <= '1';
                s_bit_index_top     <= (others=>'0');


    end case;
  end process;



---------------------------------------------------------------------------------------------------


Input_Byte_Sampling: process(uclk_i)
  begin
    if rising_edge(uclk_i) then
      if nFIP_rst_i = '1' then
        s_byte   <= (others => '0');

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
      s_byte_manch(I*2)   <= not s_byte(I);
      s_byte_manch(I*2+1) <= s_byte(I);
    end loop;
  end process;

---------------------------------------------------------------------------------------------------
--! @brief combinatorial process Manchester_Encoder_crc_byte: The process takes a byte (8 bits) and
--! creates its manchester encoded equivalent (16 bits). Each bit '1' is replaced by '10' and each
--! bit '0' by '01'. 

  Manchester_Encoder_crc_byte: process(s_crc_byte_manch)
  begin
    for I in s_crc_byte_manch'range loop
      s_manchester_crc(I*2)   <= not s_crc_byte_manch(I);
      s_manchester_crc(I*2+1) <= s_crc_byte_manch(I);
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
        tx_data_o   <= '0';
        tx_enable_o <= '0';
      else

        if  tx_clk_p_buff_i(C_CLKFCDLENTGTH-3) = '1' then 
          tx_data_o <= s_data_bit;
        end if;

      tx_enable_o   <= s_tx_enable;

      end if;
    end if;
  end process;

---------------------------------------------------------------------------------------------------
--! @brief synchronous process Outgoing_Bits_Index: Managment of the pointer that indicates which
--! bit of a manchester encoded byte is to be sent  

  Outgoing_Bits_Index: process(uclk_i)
  begin
    if rising_edge(uclk_i) then
      if nFIP_rst_i = '1' then
        s_bit_index   <= (others => '0');
      else

        if s_bit_index_load = '1' then
          s_bit_index <= s_bit_index_top;

        elsif s_decr_index = '1' then
          s_bit_index <= s_bit_index - 1;

        end if;
      end if;
    end if;
  end process;

 --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
  s_bit_index_is_zero <= '1' when s_bit_index = to_unsigned(0,s_bit_index'length) else '0';


end architecture rtl;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------