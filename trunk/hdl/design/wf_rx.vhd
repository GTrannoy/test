--=================================================================================================
--! @file wf_rx.vhd
--! @brief Deserialises the WorldFIP data
--=================================================================================================
--! Standard library
library IEEE;

--! Standard packages
use IEEE.STD_LOGIC_1164.all; --! std_logic definitions
use IEEE.NUMERIC_STD.all;    --! conversion functions

use work.wf_package.all;

---------------------------------------------------------------------------------------------------
--                                                                                               --
--                                   wf_rx                                                       --
--                                                                                               --
--                               CERN, BE/CO/HT                                                  --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
-- unit name: wf_rx
--
--! @brief Deserialisation of the input signal fd_rxd (buffered) and construction of bytes of data
--! to be provided to the wf_consumed unit.
--!
--!
--!
--! @author	    Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)
--!             Evangelia Gousiou (Evangelia.Gousiou@cern.ch)
--!
--! @date 08/2010
--
--! @version v0.02
--
--! @details 
--!
--! <b>Dependencies:</b>\n
--! wf_rx_tx_osc\n
--! wf_deglitcher\n
--! wf_tx_rx\n
--! 
--! 
--!
--!
--! <b>References:</b>\n
--! 
--! 
--!
--! <b>Modified by:</b>\n
--! Author: Erik van der Bij
--!         Pablo Alvarez Sanchez
--!         Evangelia Gousiou
---------------------------------------------------------------------------------------------------
--! \n\n<b>Last changes:</b>\n
--! 07/10 state switch_to_deglitched added
--!       output signal wait_d_first_f_edge_o added
--!       signals renamed
--!       code cleaned-up + commented
--!      
---------------------------------------------------------------------------------------------------
--! @todo Define I/O signals \n
--!
---------------------------------------------------------------------------------------------------



--=================================================================================================
--! Entity declaration for wf_rx
--=================================================================================================
entity wf_rx is

  port (
  -- Inputs 
    -- user interface general signals 
    uclk_i :                in std_logic; --! 40MHz clock
    rst_i :                 in std_logic; --! global reset
    
    -- signals from the wf_rx_tx_osc    
	signif_edge_window_i :  in std_logic; --! time window where a significant edge is expected 
    adjac_bits_window_i :   in std_logic; --! time window where a transition between adjacent
                                          --!  bits is expected


    -- signals from wf_tx_rx
    rx_data_r_edge_i :      in std_logic; --!indicates a rising edge on the buffered rxd(rx_data_i)
	rx_data_f_edge_i :      in std_logic; --! indicates a falling edge on the d_1  

    -- signal from the wf_deglitcher
    rx_data_filtered_i :    in std_logic; --! deglitched serial input signal 
    sample_manch_bit_p_i:   in std_logic; --! 
    sample_bit_p_i :        in std_logic; --! 


  -- Outputs

    -- needed by the wf_consumed and wf_engine_control 	
	byte_ready_p_o :        out std_logic;                     --! indication of a valid data byte
    byte_o :                out std_logic_vector(7 downto 0) ; --! retreived data byte

    -- needed by the wf_engine_control
    crc_ok_p_o :            out std_logic;
    crc_wrong_p_o :         out std_logic; 
    fss_decoded_p_o :       out std_logic;   	
    last_byte_p_o :         out std_logic;
    
    -- needed by the status_gen 
    code_violation_p_o :    out std_logic;   --! indicator of a manchester 2 code violation

    -- needed by the wf_rx_tx_osc
    wait_d_first_f_edge_o : out std_logic    --! indicator of the rx state machine being in idle
                                             --state, expecting for the preamble's 1st falling edge 
);

end entity wf_rx;



---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
--! rtl architecture of wf_rx
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
architecture rtl of wf_rx is
  
  -- states of the receiver's state machine
  type rx_st_t  is (idle, preamble_field_first_fe, preamble_field_re, preamble_field_fe,
                    frame_start_field, switch_to_deglitched, data_field_byte);
  -- signals
  signal rx_st, nx_rx_st :  rx_st_t;

  signal pointer, s_start_pointer :                                        unsigned(4 downto 0);
  signal s_decr_pointer, s_load_pointer, s_pointer_is_zero :                          std_logic;

  signal s_sample_bit_p_d1, s_sample_bit_p_d2, s_rx_data_filtered_f_edge :            std_logic;
  signal s_manch_r_edge, s_manch_f_edge, s_edge_outside_manch_window, s_bit_r_edge :  std_logic;


  signal s_frame_start_bit, s_queue_bit :                                             std_logic;
  signal s_frame_start_correct_bit, s_frame_start_wrong_bit, s_frame_start_last_bit : std_logic;
  signal s_frame_end_detected_p, s_frame_end_detection, s_frame_end_wrong_bit :       std_logic;
  
  signal s_violation_check, s_code_violation :                                        std_logic;
  signal s_calculate_crc, s_crc_ok_p, s_crc_ok, s_start_crc_p :                       std_logic;

  signal s_byte_ok, s_write_bit_to_byte, s_rx_data_filtered_d:                        std_logic;

  signal s_byte :                                                  std_logic_vector(7 downto 0);

  signal s_rx_data_filtered_buff :                                 std_logic_vector(1 downto 0);


 
  begin
---------------------------------------------------------------------------------------------------
 --!@brief instantiation of the crc calculator unit
  cmp_wf_crc : wf_crc 
  generic map( 
			c_poly_length => 16) 
  port map(
    uclk_i => uclk_i,
    rst_i => rst_i,
    start_p_i => s_start_crc_p,
    d_rdy_p_i  => s_write_bit_to_byte,
	d_i  => rx_data_filtered_i,
	crc_o  => open,
	crc_rdy_p_o => open,
	crc_ok_p => s_crc_ok_p
);

---------------------------------------------------------------------------------------------------
--!@brief Receiver's state machine: the state machine is divided in three parts (a clocked process
--! to store the current state, a combinatorial process to manage state transitions and finally a
--! combinatorial process to manage the output signals), which are the three processes that follow.
--! The unit, is firstly following the input data stream (from the buffered input rx_data_i) for 
--! monitoring the preamble field, and then switches to following the deglitched signal for
--! the rest of the data. It is responsible for the detection of the the preamble, frame start
--! delimiter and queue fields of a received id_dat or consumed rp_dat frame, as well as for the
--! formation of bytes of data out of the serial input. The main outputs of the unit (byte_o and
--! byte_ready_p_o) are the main inputs of the units wf_consumed_vars and wf_engine_control.
  
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
--!@brief synchronous process Receiver_FSM_Sync: storage of the current state of the FSM

   Receiver_FSM_Sync: process(uclk_i)
    begin
      if rising_edge(uclk_i) then
        if rst_i = '1' then
          rx_st <= idle;
		else
          rx_st <= nx_rx_st;
        end if;
      end if;
  end process;
 

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
--!@brief combinatorial process Receiver_FSM_Comb_StateTransitions:
--! definition of the state transitions of the FSM
  
  Receiver_FSM_Comb_State_Transitions: process (s_frame_start_last_bit, s_rx_data_filtered_f_edge,
                                                s_frame_start_wrong_bit, s_manch_f_edge, rx_st,
                                                s_frame_end_detected_p, s_frame_end_wrong_bit,
                                                rx_data_f_edge_i, s_edge_outside_manch_window,
                                                s_code_violation,s_bit_r_edge, s_manch_r_edge )
  
  begin
  nx_rx_st <= idle;
  
  case rx_st is 

    -- for the monitoring of the preamble, directly the input rx_data_i is used and the unit is following
    -- its rising and falling edges. The deglitched signal is still not reliable.
    -- for the rest of the frame, the deglitched signal is used.

    when idle =>                                      -- in idle state until falling edge detection   
                        if rx_data_f_edge_i = '1' then
                          nx_rx_st <= preamble_field_first_fe;--nxt state:preamble 1st falling edge
                        else
                          nx_rx_st <= idle;
                        end if;	
   
    when preamble_field_first_fe=>
                        if s_manch_r_edge = '1' then         -- arrival of a manchester rising edge 
                           nx_rx_st <= preamble_field_re;     -- jump to preamble rising edge state
                        elsif s_edge_outside_manch_window = '1' then  -- arrival of any other edge, 
                           nx_rx_st <= idle;                         --  jump back to the beginning
                        else 
                           nx_rx_st <= preamble_field_first_fe;
                        end if;	
  
    when preamble_field_re =>  
                         if s_manch_f_edge = '1' then       -- arrival of a manchester falling edge 
                          nx_rx_st <= preamble_field_fe;     -- jump to preamble falling edge state
                                                            -- note: 4 loops between a rising and a
                                                     --  falling edge are expected for the preamble
                         elsif s_edge_outside_manch_window = '1' then  -- arrival of any other edge
                            nx_rx_st <= idle;                         -- jump back to the beginning
                         else 
                            nx_rx_st <= preamble_field_re;
                         end if;
	
    when preamble_field_fe =>  					
                         if s_manch_r_edge = '1' then        -- arrival of a manchester rising edge
                            nx_rx_st <= preamble_field_re;         -- jump to preamble falling edge                         
                         elsif s_bit_r_edge = '1' then              -- arrival of a bit rising edge                  
                          nx_rx_st <=  switch_to_deglitched;      -- signaling the beginning of the 
                                                                              -- first V+ violation                                                    
                         elsif s_edge_outside_manch_window = '1' then  -- arrival of any other edge
                            nx_rx_st <= idle;                         -- jump back to the beginning
                         else 
                            nx_rx_st <= preamble_field_fe;
                         end if;				

    -- A small delay is expected between the rx_data_i and the rx_data_filtered_i (output of the
    -- deglitcher) which means that the last falling edge of the preamble of rx_data_i arrives
    -- earlier than the one of the rx_data_filtered_i. the state switch_to _deglitched is used for
    -- this purpose. 

    when switch_to_deglitched =>
                           if s_rx_data_filtered_f_edge = '1' then
                            nx_rx_st <= frame_start_field; 
                           else
                             nx_rx_st <= switch_to_deglitched;
                           end if;

    -- For the monitoring of the frame start delimiter, the unit is sampling each manchester bit of
    -- the incoming d_filtered signal and it is comparing it to the nominal bit of the frame start
    -- delimiter field. If a wrong bit is received, the state machine jumps back to idle, whereas if
    -- the complete byte is correctly received, it jumps to the data_field_byte state.  
   
    when frame_start_field =>
                         if s_frame_start_last_bit = '1' then-- reception of the last (15th) bit of  
                           nx_rx_st <= data_field_byte;   -- the fss, jump to data_field_byte state

                         elsif s_frame_start_wrong_bit = '1' then          -- wrong frame start bit
                           nx_rx_st <= idle;                          -- jump back to the beginning
  
                         else
                           nx_rx_st <= frame_start_field;		
                         end if;

    
    when data_field_byte =>
                         if s_frame_end_detected_p = '1' then
                            nx_rx_st <= idle;
					-- Is there a code violation that does not correspond to the queue pattern?
                         elsif s_frame_end_wrong_bit = '1' and s_code_violation = '1' then
                            nx_rx_st <= idle;				
                         else
                            nx_rx_st <= data_field_byte;
                         end if;	
    when others => 
                         nx_rx_st <= idle;
  end case;	
  end process;
  
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
--!@brief combinatorial process Receiver_FSM_Comb_Output_Signals:
--! definition of the output signals of the FSM

  Receiver_FSM_Comb_Output_Signals: process (rx_st, pointer,sample_manch_bit_p_i,s_pointer_is_zero,
                                             s_frame_start_last_bit, s_frame_end_detected_p,
                                             s_code_violation,s_frame_end_wrong_bit,sample_bit_p_i)

  begin
  
    case rx_st is 
  
    when idle =>
                        -- initializations:
                         wait_d_first_f_edge_o <= '1'; -- signal for rx_osc

                         s_start_pointer <= to_unsigned(0,s_start_pointer'length);
                         s_load_pointer <= '0'; 
                         s_decr_pointer <= '0';
                         s_frame_start_bit <='0';
                         fss_decoded_p_o <= '0';
                         s_write_bit_to_byte <= '0';
                         s_byte_ok <= '0';
                         s_start_crc_p <= '0';
                         s_calculate_crc <= '0';
                         code_violation_p_o <= '0';
                         s_queue_bit <= '0';

                                 
    when preamble_field_first_fe =>
                         wait_d_first_f_edge_o <= '0';

                         s_start_pointer <= to_unsigned(0,s_start_pointer'length);
                         s_load_pointer <= '0'; 
                         s_decr_pointer <= '0';
                         s_frame_start_bit <='0';
                         fss_decoded_p_o <= '0';
                         s_write_bit_to_byte <= '0';
                         s_byte_ok <= '0';
                         s_start_crc_p <= '0';
                         s_calculate_crc <= '0';
                         code_violation_p_o <= '0';
                         s_queue_bit <= '0';

  
    when preamble_field_re =>
                         wait_d_first_f_edge_o <= '0';
                         s_start_pointer <= to_unsigned(0,s_start_pointer'length);
                         s_load_pointer <= '0'; 
                         s_decr_pointer <= '0';
                         s_frame_start_bit <='0';
                         fss_decoded_p_o <= '0';
                         s_write_bit_to_byte <= '0';
                         s_byte_ok <= '0';
                         s_start_crc_p <= '0';
                         s_calculate_crc <= '0';
                         code_violation_p_o <= '0';
                         s_queue_bit <= '0';


    when preamble_field_fe =>
                         wait_d_first_f_edge_o <= '0';
                         s_start_pointer <= to_unsigned(0,s_start_pointer'length);
                         s_load_pointer <= '0'; 
                         s_decr_pointer <= '0';
                         s_frame_start_bit <='0';
                         fss_decoded_p_o <= '0';
                         s_write_bit_to_byte <= '0';
                         s_byte_ok <= '0';
                         s_start_crc_p <= '0';
                         s_calculate_crc <= '0';
                         code_violation_p_o <= '0';
                         s_queue_bit <= '0';

  
    when switch_to_deglitched =>

                         s_load_pointer <= '1'; 
                         s_frame_start_bit <= FRAME_START(to_integer(pointer)); 
                         s_start_pointer <= to_unsigned(FRAME_START'left-1,s_start_pointer'length);

                         wait_d_first_f_edge_o <= '0';
                         s_decr_pointer <= '0';
                         fss_decoded_p_o <= '0';
                         s_write_bit_to_byte <= '0';
                         s_byte_ok <= '0';
                         s_start_crc_p <= '0';
                         s_calculate_crc <= '0';
                         code_violation_p_o <= '0';
                         s_queue_bit <= '0';


    when frame_start_field =>
                         s_load_pointer <=  s_pointer_is_zero and sample_manch_bit_p_i; 
                         s_frame_start_bit <= FRAME_START(to_integer(pointer)); 
                         s_start_pointer <= to_unsigned(FRAME_END'left,s_start_pointer'length);
                         s_decr_pointer <= sample_manch_bit_p_i;
                         fss_decoded_p_o <= s_frame_start_last_bit;
                         s_start_crc_p <= '1';
                         s_calculate_crc <= '1';
                         --code_violation_p_o <= s_frame_end_wrong_bit and s_code_violation;

                         s_queue_bit <= '0';
                         wait_d_first_f_edge_o <= '0';
                         s_write_bit_to_byte <= '0';
                         s_byte_ok <= '0';

   
    when data_field_byte =>

                         s_load_pointer <=  s_pointer_is_zero and sample_manch_bit_p_i; 
                         s_start_pointer <= to_unsigned(FRAME_END'left,s_start_pointer'length);
                         s_decr_pointer <= sample_manch_bit_p_i;
                         s_write_bit_to_byte <= sample_bit_p_i;
                         s_byte_ok <= s_pointer_is_zero and sample_manch_bit_p_i and 
                                     ((not s_frame_end_detected_p) and (not s_code_violation));

                         s_queue_bit <= FRAME_END(to_integer(resize(pointer,4)));                                          
                         code_violation_p_o <= '0';

                         s_start_crc_p <= '0';
                         s_calculate_crc <= '1';
                         s_frame_start_bit <= '0'; 
                         wait_d_first_f_edge_o <= '0';
                         fss_decoded_p_o <= '0';
 
    when others => 
    
    end case;	
  end process;

---------------------------------------------------------------------------------------------------
-- concurrent signal assignments concerning edges detection for the preamble field

  s_manch_r_edge <= signif_edge_window_i and rx_data_r_edge_i;
  s_manch_f_edge <= signif_edge_window_i and rx_data_f_edge_i;
  s_bit_r_edge <= adjac_bits_window_i and ( rx_data_r_edge_i);
  s_edge_outside_manch_window <= (not signif_edge_window_i)and (rx_data_r_edge_i or rx_data_f_edge_i);

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
-- concurrent signal assignments concerning the frame start field (used in frame_start_field state)

  s_frame_start_wrong_bit <= (s_frame_start_bit xor rx_data_filtered_i) and sample_bit_p_i;     
  s_frame_start_last_bit <= s_pointer_is_zero and sample_manch_bit_p_i;

 --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --                                                         
-- concurrent signal assignments concerning the frame end field (used in data_field_byte state)

  s_frame_end_wrong_bit <= (s_queue_bit xor  rx_data_filtered_i) and sample_bit_p_i;   
  s_frame_end_detected_p <= s_frame_end_detection and sample_manch_bit_p_i and s_pointer_is_zero;                                           

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
-- extra concurrent signal assignments

 s_code_violation <= (not (rx_data_filtered_i xor s_rx_data_filtered_d)) and s_violation_check;
 s_pointer_is_zero <= '1' when pointer = 0 else '0';

-- s_frame_start_last_bit <= s_pointer_is_zero and s_frame_start_correct_bit and sample_manch_bit_p_i;

---------------------------------------------------------------------------------------------------
--!@brief synchronous process Frame_End_Detector: creation of a window that is activated at the 
--! beginning of an incoming byte and stays active as long as 14 incoming bits match the FES 

  Frame_End_Detector: process(uclk_i)
    begin
      if rising_edge(uclk_i) then
        if rst_i = '1' then
          s_frame_end_detection <= '1';

        elsif s_pointer_is_zero = '1' and sample_manch_bit_p_i = '1' then 
          s_frame_end_detection <= '1';
        elsif  s_frame_end_wrong_bit = '1' then
           s_frame_end_detection <= '0';
        end if;
      end if;
  end process;

---------------------------------------------------------------------------------------------------
--!@brief synchronous process Incoming_Bits_Pointer: managment of the pointer that indicates the 
--! position inside a manchester encoded byte of the incoming deglitched signal (16 bits)  

  Incoming_Bits_Pointer: process(uclk_i)
    begin
      if rising_edge(uclk_i) then
        if rst_i = '1' then
          pointer <= (others => '0');
        else

          if s_load_pointer = '1' then
            pointer <= s_start_pointer;
           elsif s_decr_pointer = '1' then
            pointer <= pointer - 1;
          end if;
        end if;
      end if;
    end process;

---------------------------------------------------------------------------------------------------
--!@brief synchronous process Append_Bit_To_Byte: creation of bytes of data.
--! a new bit of the deglitched input signal is appended to the output
--! byte when s_write_bit_to_byte is enabled.

  Append_Bit_To_Byte: process (uclk_i)
    begin
      if rising_edge(uclk_i) then
        if rst_i = '1' then
          s_byte <= (others => '0');
        else

          if s_write_bit_to_byte = '1' then
           s_byte <= s_byte(6 downto 0) & rx_data_filtered_i;  
          end if;
       end if;
     end if;
  end process;

---------------------------------------------------------------------------------------------------
  process(uclk_i)
    begin
      if rising_edge(uclk_i) then
        if rst_i = '1' then
          s_crc_ok <= '0';	
	    else

          if s_calculate_crc='0' then
            s_crc_ok <= '0';		
          elsif s_crc_ok_p = '1' and s_calculate_crc='1' then 
             s_crc_ok <= '1';
          end if;
      end if;
    end if;
  end process;

---------------------------------------------------------------------------------------------------
--!@brief synchronous process Detect_f_edge_rx_data_filtered: detection of a falling edge on the 
--! deglitched input signal (rx_data_filtered). A buffer is used to store the last 2 bits of the 
--! signal. A falling edge is detected if the last bit of the buffer (new bit) is a zero and the 
--! first (old) is a one. 

  Detect_f_edge_rx_data_filtered: process(uclk_i)
    begin
      if rising_edge(uclk_i) then 
        if rst_i = '1' then
          s_rx_data_filtered_buff <= (others => '0');
          s_rx_data_filtered_f_edge <= '0';
        else

          -- buffer s_rx_data_filtered_buff keeps the last 2 bits of rx_data_filtered_i
          s_rx_data_filtered_buff <= s_rx_data_filtered_buff(0) & rx_data_filtered_i;
          -- falling edge detected if last bit is a 0 and previous was a 1
          s_rx_data_filtered_f_edge<=s_rx_data_filtered_buff(1)and(not s_rx_data_filtered_buff(0));
        end if;
      end if;
end process; 

---------------------------------------------------------------------------------------------------
--!@brief synchronous process Check_Code_Violations:in order to check the existance code violations
--! the deglitched input signal is delayed by half reception period.
-- As the following drawing roughly indicates, a violation exists if the signal and its delayed
-- version are identical on........... 

--                             0    V-    1
--   rx_data_filtered_i:     __|--|____|--|__ 
--   s_rx_data_filtered_d:      __|--|____|--|__
--   s_violation_check:           ^    ^     ^

  Check_code_violations: process(uclk_i)
    begin
      if rising_edge(uclk_i) then 
         if rst_i = '1' then
           byte_ready_p_o <= '0'; 
           s_violation_check <='0';
           s_rx_data_filtered_d <='0';

         else
           if sample_manch_bit_p_i = '1' then
             s_rx_data_filtered_d <= rx_data_filtered_i; 
           end if;
            s_violation_check <= s_sample_bit_p_d2;
            s_sample_bit_p_d2 <= s_sample_bit_p_d1;
            s_sample_bit_p_d1 <= sample_bit_p_i;
            byte_ready_p_o <= s_byte_ok and (not s_frame_end_detected_p); 
         end if;
      end if;
  end process; 

---------------------------------------------------------------------------------------------------
  -- output signals that have also been used in this unit's processes:
  byte_o <= s_byte; 
  last_byte_p_o <= s_frame_end_detected_p;
  crc_ok_p_o <= s_frame_end_detected_p and s_crc_ok;
  crc_wrong_p_o <= s_frame_end_detected_p and (not s_crc_ok);

end architecture rtl;
---------------------------------------------------------------------------------------------------
--                          E N D   O F   F I L E
---------------------------------------------------------------------------------------------------