--________________________________________________________________________________________________|
--                                                                                                |
--                                        |The nanoFIP|                                           |
--                                                                                                |
--                                        CERN,BE/CO-HT                                           |
--________________________________________________________________________________________________|
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--! @file WF_rx.vhd                                                                               |
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
--                                              WF_rx                                            --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
--
--! @brief     De-serialization of the input signal fd_rxd and construction of bytes of data
--!            to be provided to the WF_cons_bytes_from_rx unit.
--
--!            Remark: We refer to a significant edge for an edge of a Manchester 2 (manch.) 
--!            encoded bit (eg: bit0: _|-, bit 1: -|_) and to a transition between adjacent bits
--!            for a transition that may or may not give an edge between adjacent bits 
--!            (e.g.: a 0 followed by a 0 will give an edge _|-|_|-, but a 0 followed by
--!            a 1 will not _|--|_ ).
--!            The term sample_manch_bit_p refers to the moments when a manch. encoded bit
--!            should be sampled (before and after a significant edge), whereas the 
--!            sample_bit_p includes only the sampling of the 1st part, before the transition. 
--
--
--! @author    Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)\n
--!            Evangelia Gousiou (Evangelia.Gousiou@cern.ch)         \n
--
--
--! @date      08/2010
--
--
--! @version   v0.02
--
--
--! @details \n 
--
--!   \n<b>Dependencies:</b>\n
--!     WF_reset_unit     \n
--!     WF_rx_tx_osc       \n
--!     WF_deglitcher       \n
--!     WF_engine_control    \n
--!     WF_inputs_synchronizer\n
-- 
-- 
--!   \n<b>Modified by:</b>\n
--!     Erik van der Bij    \n
--!     Pablo Alvarez Sanchez\n
--!     Evangelia Gousiou     \n
--
--------------------------------------------------------------------------------------------------- 
--
--!   \n\n<b>Last changes:</b>\n
--!     -> 09/2009 v0.01 PS First version \n
--!     -> 10/2010 v0.02 EG state switch_to_deglitched added;
--!                         output signal rst_rx_osc_o added; signals renamed;
--!                         state machine rewritten (mealy style); 
--!                         units WF_manch_code_viol_check and Incoming_Bits_Index created;
--!                         each manch bit of FES checked (bf was just each bit, so any D5 was FES) 
--!                         code cleaned-up + commented.\n
--      
---------------------------------------------------------------------------------------------------
--
--! @todo
--! -> 
--
---------------------------------------------------------------------------------------------------


---/!\----------------------------/!\----------------------------/!\--------------------------/!\--
--                                    Sunplify Premier Warnings                                  --
-- -- --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --
--                                         No Warnings                                           --
---------------------------------------------------------------------------------------------------


--=================================================================================================
--!                                 Entity declaration for WF_rx
--=================================================================================================

entity WF_rx is

  port (
  -- INPUTS 
    -- User interface general signal 
    uclk_i :                  in std_logic; --! 40MHz clock
 
    -- Signal from the WF_reset_unit
    nFIP_urst_i :             in std_logic; --! internal reset

    -- Signal from the WF_engine_control
    rst_rx_unit_p_i :         in std_logic; --! signals that more bytes than expected are being
                                            --! received (ex: ID_DAT > 8 bytes etc) and the unit
                                            --! has to be reset
    
    -- Signals from the WF_rx_tx_osc    
    signif_edge_window_i :    in std_logic; --! time window where a significant edge is expected 
    adjac_bits_window_i :     in std_logic; --! time window where a transition between adjacent
                                            --! bits is expected


    -- Signals from WF_inputs_synchronizer
    rxd_r_edge_i :            in std_logic; --! indicates a rising edge on fd_rxd
    rxd_f_edge_i :            in std_logic; --! indicates a falling edge on fd_rxd  

    -- Signals from the WF_deglitcher
    rxd_filtered_o :          in std_logic; --! deglitched fd_rxd
    rxd_filtered_f_edge_p_i : in std_logic; --! falling edge on the deglitched fd_rxd  
    sample_manch_bit_p_i :    in std_logic; --! pulse indicating a valid sampling time for a manch. bit 
    sample_bit_p_i :          in std_logic; --! pulse indicating a valid sampling time for a bit


  -- OUTPUTS
    -- Signals to the WF_consumed and WF_engine_control 	
    byte_o :                  out std_logic_vector (7 downto 0) ;     --! retrieved data byte
    byte_ready_p_o :          out std_logic; --! pulse indicating a valid retrieved data byte

    -- Signals to the WF_engine_control
    FSS_CRC_FES_viol_ok_p_o : out std_logic; --! indication of a frame with a correct FSS,FES,CRC
                                             --! and with no unexpected manch code violations
    CRC_wrong_p_o :           out std_logic; --! indication of a wrong CRC reception
    FSS_received_p_o :        out std_logic; --! indication of a correct FSS reception

    -- Signal to the WF_rx_tx_osc
    rst_rx_osc_o :            out std_logic  --! resets the clock recovery procedure of the rx_osc
);

end entity WF_rx;


--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of WF_rx is
  
  -- states of the receiver's state machine
  type rx_st_t  is (idle, preamble_field_first_f_edge, preamble_field_r_edge,preamble_field_f_edge,
                    frame_start_field, switch_to_deglitched, data_field_byte);

  signal rx_st, nx_rx_st :                                           rx_st_t;
  signal s_manch_code_viol_p, s_CRC_ok_p, s_CRC_ok :                 std_logic;
  signal s_frame_start_last_bit, s_frame_end_wrong_bit :             std_logic;
  signal s_frame_end_detected_p, s_frame_end_detection :             std_logic;
  signal s_manch_code_violations, s_switching_to_deglitched :        std_logic;
  signal s_receiving_FSS, s_receiving_bytes, s_receiving_preamble :  std_logic;
  signal s_decr_bit_index_p, s_bit_index_load, s_bit_index_is_zero : std_logic;
  signal s_byte_ready_p, s_write_bit_to_byte, s_idle :               std_logic;
  signal s_bit_r_edge,s_FSS_bit,s_FES_bit, s_frame_start_wrong_bit : std_logic;
  signal s_manch_r_edge, s_manch_f_edge,s_edge_outside_manch_window: std_logic;
  signal s_bit_index, s_bit_index_top :                              unsigned(3 downto 0);
  signal s_byte :                                                    std_logic_vector (7 downto 0);


--=================================================================================================
--                                      architecture begin
--=================================================================================================  
  begin

---------------------------------------------------------------------------------------------------
--!@brief Receiver's state machine: the state machine is divided in three parts (a clocked process
--! to store the current state, a combinatorial process to manage state transitions and finally a
--! combinatorial process to manage the output signals), which are the three processes that follow.
--! The unit, is firstly following the input data stream for monitoring the preamble field, and
--! then switches to following the deglitched signal for the rest of the data. It is responsible
--! for the detection of the the preamble, FSS and FES of a received ID_DAT or consumed
--! RP_DAT frame, as well as for the formation of bytes of data.
--! The main outputs of the unit (byte_o and byte_ready_p_o) are the main inputs of the unit
--! WF_cons_bytes_from_rx.
  
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
--!@brief synchronous process Receiver_FSM_Sync: storage of the current state of the FSM

   Receiver_FSM_Sync: process(uclk_i)
    begin
      if rising_edge(uclk_i) then
        if nFIP_urst_i = '1' then
          rx_st <= idle;
        else
          rx_st <= nx_rx_st;
        end if;
      end if;
  end process;
 

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
--!@brief Combinatorial process Receiver_FSM_Comb_StateTransitions:
--! definition of the state transitions of the FSM.
  
  Receiver_FSM_Comb_State_Transitions: process (s_manch_code_viol_p,s_bit_r_edge, s_manch_r_edge,
                                                s_frame_start_last_bit, rxd_filtered_f_edge_p_i,
                                                s_frame_start_wrong_bit, s_manch_f_edge, rx_st,
                                                s_frame_end_detected_p, s_frame_end_wrong_bit,
                                                rxd_f_edge_i, s_edge_outside_manch_window,
                                                rst_rx_unit_p_i)
  
  begin
  nx_rx_st <= idle;
  
  case rx_st is 

    -- For the monitoring of the preamble, the unit is following the rising and falling edges of
    -- fd_rxd. For the rest of the frame, the deglitched signal (rxd_filtered) is used.

    when idle =>                                                     -- in idle state until falling    
                        if rxd_f_edge_i = '1' then                   -- edge detection
                          nx_rx_st <= preamble_field_first_f_edge;
                        else
                          nx_rx_st <= idle;
                        end if;	
   
    when preamble_field_first_f_edge=>
                        if s_manch_r_edge = '1' then                 -- arrival of a manch.  
                          nx_rx_st <= preamble_field_r_edge;         -- rising edge

                        elsif s_edge_outside_manch_window = '1' then -- arrival of any other edge 
                          nx_rx_st <= idle;                      
                        else 
                          nx_rx_st <= preamble_field_first_f_edge;
                        end if;	
  
    when preamble_field_r_edge =>  
                        if s_manch_f_edge = '1' then             -- arrival of a manch. falling edge 
                          nx_rx_st <= preamble_field_f_edge;     -- note: several loops between
                                                                 -- a rising and a falling edge are  
                                                                 -- expected for the preamble

                        elsif s_edge_outside_manch_window = '1' then -- arrival of any other edge
                           nx_rx_st <= idle;                     
                        else 
                           nx_rx_st <= preamble_field_r_edge;
                        end if;
	
    when preamble_field_f_edge =>  					
                        if s_manch_r_edge = '1' then             -- arrival of a manch. rising edge
                          nx_rx_st <= preamble_field_r_edge;                               
                        elsif s_bit_r_edge = '1' then            -- arrival of a bit rising edge,                  
                          nx_rx_st <=  switch_to_deglitched;     -- signaling the beginning of the 
                                                                 -- first V+ violation  
                                                  
                        elsif s_edge_outside_manch_window = '1' then -- arrival of any other edge
                          nx_rx_st <= idle;                         
                        else 
                          nx_rx_st <= preamble_field_f_edge;
                         end if;				

    -- A small delay is expected between the rxd and the rxd_filtered (output of the
    -- WF_rx_deglitcher) which means that the last falling edge of the preamble of rxd arrives
    -- earlier than the one of the rxd_filtered. The state switch_to_deglitched is used for
    -- this purpose. 

    when switch_to_deglitched =>
                        if rxd_filtered_f_edge_p_i = '1' then
                          nx_rx_st <= frame_start_field; 
                        else
                          nx_rx_st <= switch_to_deglitched;
                        end if;

    -- For the monitoring of the frame start delimiter, the unit is sampling each manch. bit of
    -- the incoming filtered signal and it is comparing it to the nominal bit of the frame start
    -- delimiter. If a wrong bit is received, the state machine jumps back to idle, whereas if
    -- the complete byte is correctly received, it jumps to the data_field_byte state.  
   
    when frame_start_field =>
                        if s_frame_start_last_bit = '1' then         -- reception of the last(15th)  
                          nx_rx_st <= data_field_byte;               -- FSS bit

                        elsif s_frame_start_wrong_bit = '1' then     -- wrong bit
                          nx_rx_st <= idle;
  
                        else
                          nx_rx_st <= frame_start_field;		
                        end if;


     
    when data_field_byte =>
                        if s_frame_end_detected_p = '1' or rst_rx_unit_p_i = '1' then
                          nx_rx_st <= idle;

                        elsif s_frame_end_wrong_bit = '1' and s_manch_code_viol_p = '1' then
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

  Receiver_FSM_Comb_Output_Signals: process (rx_st)

  begin
  
    case rx_st is 
  
    when idle =>
                   s_idle                    <= '1';
                   s_receiving_preamble      <= '0';
                   s_switching_to_deglitched <= '0';
                   s_receiving_FSS           <= '0';
                   s_receiving_bytes         <= '0';

                                 
    when preamble_field_first_f_edge | preamble_field_r_edge | preamble_field_f_edge =>

                   s_idle                    <= '0';
                   s_receiving_preamble      <= '1';
                   s_switching_to_deglitched <= '0';
                   s_receiving_FSS           <= '0';
                   s_receiving_bytes         <= '0';

    when switch_to_deglitched =>

                   s_idle                    <= '0';
                   s_receiving_preamble      <= '0';
                   s_switching_to_deglitched <= '1';
                   s_receiving_FSS           <= '0';
                   s_receiving_bytes         <= '0';



    when frame_start_field =>

                   s_idle                    <= '0';
                   s_receiving_preamble      <= '0';
                   s_switching_to_deglitched <= '0';
                   s_receiving_FSS           <= '1';
                   s_receiving_bytes         <= '0';

   
    when data_field_byte =>

                   s_idle                    <= '0';
                   s_receiving_preamble      <= '0';
                   s_switching_to_deglitched <= '0';
                   s_receiving_FSS           <= '0';
                   s_receiving_bytes         <= '1';

 
    when others => 

                   s_idle                    <= '0';
                   s_receiving_preamble      <= '0';
                   s_switching_to_deglitched <= '0';
                   s_receiving_FSS           <= '0';
                   s_receiving_bytes         <= '0';
    
    end case;	
  end process;


---------------------------------------------------------------------------------------------------
--!@brief Instantiation of a counter that manages the position of an incoming deglitched bit
--! inside a manch encoded byte  (16 bits)  
    Incoming_Bits_Index: WF_decr_counter
    generic map(counter_length => 4)
    port map(
      uclk_i              => uclk_i,
      nFIP_urst_i         => nFIP_urst_i,      
      counter_top         => s_bit_index_top,
      counter_load_i      => s_bit_index_load,
      counter_decr_p_i    => s_decr_bit_index_p,
      counter_o           => s_bit_index,
      counter_is_zero_o   => s_bit_index_is_zero);


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
-- Combinatorial process that according to the state of the FSM sets the values to the
-- Incoming_Bits_Index inputs

  Bit_Index: process (s_idle,s_receiving_preamble, s_switching_to_deglitched, s_receiving_FSS,
                      s_receiving_bytes, s_bit_index_is_zero,sample_manch_bit_p_i)
  begin

    if s_idle ='1' then                       -- counter re-initialization after a reception
      s_bit_index_top    <= to_unsigned (0, s_bit_index_top'length);   
      s_bit_index_load   <= '1';
      s_decr_bit_index_p <= '0';
      

    elsif s_receiving_preamble = '1' then     -- no action
      s_bit_index_top    <= to_unsigned (0, s_bit_index_top'length);
      s_bit_index_load   <= '0';
      s_decr_bit_index_p <= '0';

    elsif s_switching_to_deglitched = '1' then -- preparation for FSS
      s_bit_index_top    <= to_unsigned(FRAME_START'left-1,s_bit_index_top'length);
      s_bit_index_load   <= s_bit_index_is_zero and sample_manch_bit_p_i;
      s_decr_bit_index_p <= '0';

    elsif s_receiving_FSS = '1' then          -- counting FSS bits
      s_bit_index_top    <= to_unsigned (0, s_bit_index_top'length);
      s_bit_index_load   <= '0';
      s_decr_bit_index_p <= sample_manch_bit_p_i;

    elsif s_receiving_bytes = '1' then        -- preparation for FSS & counting data bits
      s_bit_index_top    <= to_unsigned (FRAME_END'left, s_bit_index_top'length); 
      s_bit_index_load   <= s_bit_index_is_zero and sample_manch_bit_p_i;
      s_decr_bit_index_p <= sample_manch_bit_p_i;

    else
      s_bit_index_top    <= to_unsigned (0, s_bit_index_top'length); 
      s_bit_index_load   <= '0';
      s_decr_bit_index_p <= '0';
    end if;
  end process;

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
  -- aux signals concurrent assignments:
  s_FSS_bit         <= s_receiving_FSS   and FRAME_START (to_integer(s_bit_index));  
  s_FES_bit         <= s_receiving_bytes and FRAME_END (to_integer(resize(s_bit_index,4)));

  s_frame_start_wrong_bit <= (s_FSS_bit xor rxd_filtered_o) and sample_manch_bit_p_i;     
  s_frame_start_last_bit  <= s_bit_index_is_zero and sample_manch_bit_p_i;


  s_frame_end_wrong_bit  <= (s_FES_bit xor rxd_filtered_o) and sample_manch_bit_p_i;   
  s_frame_end_detected_p <= s_frame_end_detection and sample_manch_bit_p_i and s_bit_index_is_zero; 


---------------------------------------------------------------------------------------------------
--!@brief Synchronous process Append_Bit_To_Byte: creation of bytes of data.
--! a new bit of the deglitched input signal is appended to the output
--! byte when s_write_bit_to_byte is enabled.

  Append_Bit_To_Byte: process (uclk_i)
    begin
      if rising_edge(uclk_i) then
        if nFIP_urst_i = '1' then
          byte_ready_p_o <='0'; 
          s_byte         <= (others => '0');
        else

          byte_ready_p_o <= s_byte_ready_p; 

          if s_write_bit_to_byte = '1' then
           s_byte        <= s_byte(6 downto 0) & rxd_filtered_o;  
          end if;

        end if;
      end if;
    end process;
 --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
  s_write_bit_to_byte <= s_receiving_bytes and sample_bit_p_i;
  s_byte_ready_p      <= s_receiving_bytes and s_bit_index_is_zero and sample_manch_bit_p_i
                                                     and (not s_frame_end_detected_p);


---------------------------------------------------------------------------------------------------
 --!@brief Instantiation of the CRC calculator unit
  Check_CRC : WF_crc 
  generic map(c_GENERATOR_POLY_length => 16) 
  port map(
    uclk_i             => uclk_i,
    nFIP_urst_i       => nFIP_urst_i,
    start_CRC_p_i      => s_receiving_FSS,
    data_bit_ready_p_i => s_write_bit_to_byte,
    data_bit_i         => rxd_filtered_o,
    CRC_o              => open,
    CRC_ok_p           => s_CRC_ok_p);

---------------------------------------------------------------------------------------------------
 --!@brief Instantiation of the unit that checks for code violations
  Check_code_violations: WF_manch_code_viol_check
  port map(
    uclk_i                => uclk_i,
    nFIP_urst_i          => nFIP_urst_i,
    serial_input_signal_i => rxd_filtered_o,
    sample_bit_p_i        => sample_bit_p_i,
    sample_manch_bit_p_i  => sample_manch_bit_p_i,
    manch_code_viol_p_o   => s_manch_code_viol_p);

 --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
--!@brief Synchronous process that manages the signals regarding CRC errors and code violations.
--! If the calculated CRC is correct the signal s_CRC_ok stays asserted until the end of the 
--! corresponding frame.
--! Similarly, if at any point after the FSS and before the FES a code violation appears, the 
--! signal s_manch_code_violations stays asserted until the end of the corresponding frame.    

  CRC_Code_viol_signals: process(uclk_i)
    begin
      if rising_edge(uclk_i) then
        if nFIP_urst_i = '1' then
          s_CRC_ok                    <= '0';
          s_manch_code_violations     <= '0';	

        else

          if s_receiving_bytes = '0' then
            s_CRC_ok                  <= '0';		
            s_manch_code_violations   <= '0';


          else
            if s_CRC_ok_p = '1' then 
               s_CRC_ok               <= '1';
            end if;

            if s_manch_code_viol_p ='1' and s_frame_end_wrong_bit ='1' then  
              s_manch_code_violations <= '1';                     -- if a code violation appears                   
                                                                  -- that doesn't belong to the FES         
            end if;                                            

          end if;
        end if;
      end if;
    end process;


---------------------------------------------------------------------------------------------------
--!@brief Synchronous process FES_Detector: creation of a window that is activated at the 
--! beginning of an incoming byte and stays active as long as 16 incoming manch. bits match the FES. 

  FES_Detector: process(uclk_i)
    begin
      if rising_edge(uclk_i) then
        if nFIP_urst_i = '1' then
          s_frame_end_detection   <= '1';

        else
          if s_bit_index_is_zero = '1' and sample_manch_bit_p_i = '1' then 
            s_frame_end_detection <= '1';

          elsif  s_frame_end_wrong_bit = '1' then
            s_frame_end_detection <= '0';
          end if;

        end if;
      end if;
    end process;

---------------------------------------------------------------------------------------------------
-- aux signals concurrent assignments:

  s_manch_r_edge              <= signif_edge_window_i and rxd_r_edge_i;
  s_manch_f_edge              <= signif_edge_window_i and rxd_f_edge_i;
  s_bit_r_edge                <= adjac_bits_window_i and ( rxd_r_edge_i);
  s_edge_outside_manch_window <= (not signif_edge_window_i)and(rxd_r_edge_i or rxd_f_edge_i);

---------------------------------------------------------------------------------------------------
  -- output signals:
  byte_o                  <= s_byte; 
  rst_rx_osc_o            <= s_idle;
  FSS_received_p_o        <= s_receiving_FSS and s_frame_start_last_bit;
  CRC_wrong_p_o           <= s_frame_end_detected_p and (not s_CRC_ok);
  FSS_CRC_FES_viol_ok_p_o <= s_frame_end_detected_p and s_CRC_ok and (not s_manch_code_violations);

end architecture rtl;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------