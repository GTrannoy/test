--_________________________________________________________________________________________________
--                                                                                                |
--                                        |The nanoFIP|                                           |
--                                                                                                |
--                                        CERN,BE/CO-HT                                           |
--________________________________________________________________________________________________|
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--! @file wf_rx_deserializer.vhd                                                                  |
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
--                                              wf_rx_deserializer                               --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
--
--! @brief     De-serialization of the input signal fd_rxd and construction of bytes of data
--!            to be provided to the wf_cons_bytes_processor unit.
--
--!            Remark: We refer to a significant edge for an edge of a Manchester 2 (manch.) 
--!            encoded bit (eg: bit0: _|-, bit 1: -|_) and to a transition between adjacent bits
--!            for a transition that may or may not give an edge between adjacent bits 
--!            (e.g.: a 0 followed by a 0 will give an edge _|-|_|-, but a 0 followed by
--!            a 1 will not _|--|_ ).
--!            The term sample_manch_bit_p refers to the moments when a manch. encoded bit
--!            should be sampled (before and after a significant edge), whereas the 
--!            sample_bit_p includes only the sampling of the 1st part, before the transition. 
--!            Example:
--!                    bit                : 0 
--!                    manch. encoded     : _|-
--!                    sample_manch_bit_p : ^ ^
--!                    sample_bit_p       : ^    (this sampling will give the 0)
--
--
--! @author    Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)\n
--!            Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)    \n
--
--
--! @date      9/12/2010
--
--
--! @version   v0.03
--
--
--! @details \n 
--
--!   \n<b>Dependencies:</b>  \n
--!     WF_reset_unit         \n
--!     WF_rx_tx_osc          \n
--!     wf_rx_deglitcher         \n
--!     WF_engine_control     \n
--!     WF_inputs_synchronizer\n
-- 
-- 
--!   \n<b>Modified by:</b>   \n
--!     Pablo Alvarez Sanchez \n
--!     Evangelia Gousiou     \n
--
--------------------------------------------------------------------------------------------------- 
--
--!   \n\n<b>Last changes:</b>\n
--!     -> 09/2009 v0.01 PAS First version \n
--!     -> 10/2010 v0.02 EG  state switch_to_deglitched added;
--!                          output signal rst_rx_osc_o added; signals renamed;
--!                          state machine rewritten (mealy style); 
--!                          units WF_manch_code_viol_check and Incoming_Bits_Index created;
--!                          each manch bit of FES checked (bf was just each bit, so any D5 was FES) 
--!                          code cleaned-up + commented.\n
--!     -> 12/2010 v0.02 EG  CRC_ok pulse transfered 16 bits later to match the FES;
--!                          like this we confirm that the CRC_ok_p arrived just before the FES,
--!                          and any 2 bytes that could by chanche be seen as CRC, are neglected.  
--!                          FSM data_field_byte state: redundant code removed:
--!                          "s_fes_wrong_bit = '1' and s_manch_code_viol_p = '1' then idle"
--!                          code(more!)cleaned-up
--      
---------------------------------------------------------------------------------------------------
--
--! @todo
--! -> 
--
---------------------------------------------------------------------------------------------------

---/!\----------------------------/!\----------------------------/!\-------------------------/!\---
--                               Sunplify Premier D-2009.12 Warnings                             --
-- -- --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --
--                                         No Warnings                                           --
---------------------------------------------------------------------------------------------------


--=================================================================================================
--!                                 Entity declaration for wf_rx_deserializer
--=================================================================================================

entity wf_rx_deserializer is

  port (
  -- INPUTS 
    -- nanoFIP User Interface general signal 
    uclk_i                  : in std_logic; --! 40MHz clock
 
    -- Signal from the WF_reset_unit
    nfip_urst_i             : in std_logic; --! nanoFIP internal reset

    -- Signal from the WF_engine_control
    rst_rx_unit_p_i         : in std_logic; --! reset of the unit
                                            --! in cases when more bytes than expected are being
                                            --! received (ex: ID_DAT > 8 bytes etc)
    
    -- Signals from the WF_rx_tx_osc    
    signif_edge_window_i    : in std_logic; --! time window where a significant edge is expected 
    adjac_bits_window_i     : in std_logic; --! time window where a transition between adjacent
                                            --! bits is expected


    -- Signals from the WF_inputs_synchronizer
    rxd_r_edge_p_i          : in std_logic; --! indicates a rising edge on fd_rxd
    rxd_f_edge_p_i          : in std_logic; --! indicates a falling edge on fd_rxd  

    -- Signals from the wf_rx_deglitcher
    rxd_filtered_i          : in std_logic; --! deglitched fd_rxd
    rxd_filtered_f_edge_p_i : in std_logic; --! falling edge on the deglitched fd_rxd  
    sample_manch_bit_p_i    : in std_logic; --! pulse indicating the sampling of a manch. bit 
    sample_bit_p_i          : in std_logic; --! pulse indicating the sampling of a bit


  -- OUTPUTS
    -- Signals to the WF_consumed and WF_engine_control 	
    byte_o                  : out std_logic_vector (7 downto 0) ;     --! retrieved data byte
    byte_ready_p_o          : out std_logic; --! pulse indicating a valid retrieved data byte

    -- Signals to the WF_engine_control
    fss_crc_fes_viol_ok_p_o : out std_logic; --! indication of a frame with a correct FSS,FES,CRC
                                             --! and with no unexpected manch. code violations
    crc_wrong_p_o           : out std_logic; --! indication of a wrong CRC reception
    fss_received_p_o        : out std_logic; --! pulse after the reception of a correct FSS

    -- Signal to the WF_rx_tx_osc
    rst_rx_osc_o            : out std_logic  --! reset of the clock recovery procedure of rx_osc
);

end entity wf_rx_deserializer;


--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of wf_rx_deserializer is
  
  -- states of the receiver's state machine
  type rx_st_t  is (idle, pre_field_first_f_edge, pre_field_r_edge, pre_field_f_edge,
                    fsd_field, switch_to_deglitched, data_fcs_fes_fields);

  signal rx_st, nx_rx_st                                          : rx_st_t;
  signal s_manch_code_viol_p, s_CRC_ok_p, s_CRC_ok_p_d16          : std_logic;
  signal s_fsd_last_bit, s_fes_wrong_bit, s_sample_manch_bit_p_d1 : std_logic;
  signal s_fes_detected_p, s_fes_detection_window                 : std_logic;
  signal s_manch_code_violations, s_switching_to_deglitched       : std_logic;
  signal s_receiving_fsd, s_receiving_bytes, s_receiving_pre      : std_logic;
  signal s_decr_manch_bit_index_p, s_manch_bit_index_load         : std_logic;
  signal s_manch_bit_index_is_zero, s_edge_outside_manch_window_p : std_logic;
  signal s_byte_ready_p, s_write_bit_to_byte, s_idle              : std_logic;
  signal s_bit_r_edge_p,s_fsd_bit,s_fes_bit, s_fsd_wrong_bit      : std_logic;
  signal s_manch_r_edge_p, s_manch_f_edge_p                       : std_logic;
  signal s_manch_bit_index, s_manch_bit_index_top                 : unsigned(3 downto 0);
  signal s_byte                                                   : std_logic_vector (7 downto 0);
  signal s_CRC_ok_p_buff                                          : std_logic_vector (14 downto 0);


--=================================================================================================
--                                      architecture begin
--=================================================================================================  
  begin

---------------------------------------------------------------------------------------------------
--!@brief Receiver's state machine: the state machine is divided in three parts (a clocked process
--! to store the current state, a combinatorial process to manage state transitions and finally a
--! combinatorial process to manage the output signals), which are the three processes that follow.
--! The unit starts by following directly the input data stream (fd_rxd) for the identification of
--! the preamble field (PRE), and then switches to following the filtered signal rxd_filtered,
--! until the end of the frame. It is responsible for the detection of the the PRE, FSD and FES
--! of a received ID_DAT or consumed RP_DAT frame, as well as for the formation of bytes of data.
--! The main outputs of the unit (byte_o and byte_ready_p_o) are the main inputs of the unit
--! wf_cons_bytes_processor.
  
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
--!@brief Synchronous process Receiver_FSM_Sync: storage of the current state of the FSM

   Receiver_FSM_Sync: process (uclk_i)
    begin
      if rising_edge (uclk_i) then
        if nfip_urst_i = '1' then
          rx_st <= idle;
        else
          rx_st <= nx_rx_st;
        end if;
      end if;
  end process;
 

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
--!@brief Combinatorial process Receiver_FSM_Comb_StateTransitions:
--! definition of the state transitions of the FSM.
  
  Receiver_FSM_Comb_State_Transitions: process (s_bit_r_edge_p, s_edge_outside_manch_window_p,
                                                s_fsd_wrong_bit, s_manch_f_edge_p, rx_st,
                                                s_fsd_last_bit, rxd_filtered_f_edge_p_i,
                                                s_fes_detected_p, rst_rx_unit_p_i,
                                                rxd_f_edge_p_i, s_manch_r_edge_p)
  
  begin
  nx_rx_st <= idle;
  
  case rx_st is 

    -- During the PRE, the rx_osc (in the WF_osc_rx_tx unit) is trying to synchronize to the
    -- transmitter's clock, therefore the signal is expected to be clean and every edge detected
    -- is taken into account. For the rest of the frame, the unit uses the filtered version of the
    -- signal, cleaned of faulty edges/ glitches.

    when idle =>                                               -- in idle state until falling    
                        if rxd_f_edge_p_i = '1' then           -- edge detection
                          nx_rx_st <= pre_field_first_f_edge;
                        else
                          nx_rx_st <= idle;
                        end if;	
   
    when pre_field_first_f_edge=>
                        if s_manch_r_edge_p = '1' then         -- arrival of a "manch."  
                          nx_rx_st <= pre_field_r_edge;        -- rising edge

                        elsif s_edge_outside_manch_window_p = '1' then -- arrival of any other edge 
                          nx_rx_st <= idle;                      
                        else 
                          nx_rx_st <= pre_field_first_f_edge;
                        end if;	
  
    when pre_field_r_edge =>  
                        if s_manch_f_edge_p = '1' then         -- arrival of a "manch."falling edge 
                          nx_rx_st <= pre_field_f_edge;        -- note: several loops between
                                                               -- a rising and a falling edge are  
                                                               -- expected for the PRE

                        elsif s_edge_outside_manch_window_p = '1' then -- arrival of any other edge
                           nx_rx_st <= idle;                     
                        else 
                           nx_rx_st <= pre_field_r_edge;
                        end if;
	
    when pre_field_f_edge =>  					
                        if s_manch_r_edge_p = '1' then         -- arrival of a "manch." rising edge
                          nx_rx_st <= pre_field_r_edge;                               
                        elsif s_bit_r_edge_p = '1' then        -- arrival of a "bit" rising edge,                  
                          nx_rx_st <=  switch_to_deglitched;   -- signaling the beginning of the 
                                                               -- first V+ violation of the FSD
                                                  
                        elsif s_edge_outside_manch_window_p = '1' then -- arrival of any other edge
                          nx_rx_st <= idle;                         
                        else 
                          nx_rx_st <= pre_field_f_edge;
                         end if;				

    -- There is a half-bit-clock period of delay between the rxd and the rxd_filtered (output of the
    -- WF_rx_deglitcher) which means that the last falling edge of the PRE of rxd arrives
    -- earlier than the one of the rxd_filtered. The state switch_to_deglitched is used for
    -- this purpose. 

    when switch_to_deglitched =>
                        if rxd_filtered_f_edge_p_i = '1' then
                          nx_rx_st <= fsd_field; 
                        else
                          nx_rx_st <= switch_to_deglitched;
                        end if;

    -- For the monitoring of the FSD, the unit is sampling each manch. bit of the incoming
    -- filtered signal and it is comparing it to the nominal bit of the FSD (through the signal
    -- s_fsd_wrong_bit). If a wrong bit is received, the state machine jumps back to idle,
    -- whereas if the complete byte is correctly received, it jumps to the data_fcs_fes_fields state.
   
    when fsd_field =>
                        if s_fsd_last_bit = '1' then           -- reception of the last(15th)  
                          nx_rx_st <= data_fcs_fes_fields;     -- FSD bit

                        elsif s_fsd_wrong_bit = '1' then       -- wrong bit
                          nx_rx_st <= idle;
  
                        else
                          nx_rx_st <= fsd_field;		
                        end if;


    -- nanoFIP can receive ID_DATs of a predefined length of 8 bytes and RP_DATs of any length 
    -- (not predefined) up to 134 bytes (FSS+Ctrl+124_data_bytes+nanoFIP_status+MPS+FCS+FES).
    -- The control_engine unit is the one following the amount of data bytes being received.
    -- Therefore, the Receiver_FSM stays in the data_fcs_fes_fields state until the arrival of a
    -- correct FES, or until the arrival of a reset signal(rst_rx_unit_p_i)from the control_engine.  
    when data_fcs_fes_fields =>
                        if s_fes_detected_p = '1' or rst_rx_unit_p_i = '1' then
                          nx_rx_st <= idle;
                        else
                          nx_rx_st <= data_fcs_fes_fields;
                        end if;	

    when others => 
                        nx_rx_st <= idle;
  end case;	
  end process;
  
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
--!@brief Combinatorial process Receiver_FSM_Comb_Output_Signals:
--! definition of the output signals of the FSM

  Receiver_FSM_Comb_Output_Signals: process (rx_st)

  begin
  
    case rx_st is 
  
    when idle =>
                   s_idle                    <= '1';
                   s_receiving_pre           <= '0';
                   s_switching_to_deglitched <= '0';
                   s_receiving_fsd           <= '0';
                   s_receiving_bytes         <= '0';

                                 
    when pre_field_first_f_edge | pre_field_r_edge | pre_field_f_edge =>

                   s_idle                    <= '0';
                   s_receiving_pre           <= '1';
                   s_switching_to_deglitched <= '0';
                   s_receiving_fsd           <= '0';
                   s_receiving_bytes         <= '0';

    when switch_to_deglitched =>

                   s_idle                    <= '0';
                   s_receiving_pre           <= '0';
                   s_switching_to_deglitched <= '1';
                   s_receiving_fsd           <= '0';
                   s_receiving_bytes         <= '0';



    when fsd_field =>

                   s_idle                    <= '0';
                   s_receiving_pre           <= '0';
                   s_switching_to_deglitched <= '0';
                   s_receiving_fsd           <= '1';
                   s_receiving_bytes         <= '0';

   
    when data_fcs_fes_fields =>

                   s_idle                    <= '0';
                   s_receiving_pre           <= '0';
                   s_switching_to_deglitched <= '0';
                   s_receiving_fsd           <= '0';
                   s_receiving_bytes         <= '1';

 
    when others => 

                   s_idle                    <= '0';
                   s_receiving_pre           <= '0';
                   s_switching_to_deglitched <= '0';
                   s_receiving_fsd           <= '0';
                   s_receiving_bytes         <= '0';
    
    end case;	
  end process;


---------------------------------------------------------------------------------------------------
--!@brief Instantiation of a counter that manages the position of an incoming deglitched bit
--! inside a manch. encoded byte  (16 bits)  
  Incoming_Bits_Index: WF_decr_counter
  generic map(g_counter_lgth => 4)
  port map(
    uclk_i              => uclk_i,
    nfip_urst_i         => nfip_urst_i,      
    counter_top         => s_manch_bit_index_top,
    counter_load_i      => s_manch_bit_index_load,
    counter_decr_p_i    => s_decr_manch_bit_index_p,
    ---------------------------------------------------
    counter_o           => s_manch_bit_index,
    counter_is_zero_o   => s_manch_bit_index_is_zero);
    ---------------------------------------------------

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
-- Combinatorial process that according to the state of the FSM sets values to the
-- Incoming_Bits_Index inputs

  Bit_Index: process (s_idle,s_receiving_pre, s_switching_to_deglitched, s_receiving_fsd,
                      s_receiving_bytes, s_manch_bit_index_is_zero,sample_manch_bit_p_i)
  begin

    if s_idle ='1' then                        -- counter re-initialization after a reception
      s_manch_bit_index_top    <= to_unsigned (0, s_manch_bit_index_top'length);   
      s_manch_bit_index_load   <= '1';
      s_decr_manch_bit_index_p <= '0';
      

    elsif s_receiving_pre = '1' then           -- no action
      s_manch_bit_index_top    <= to_unsigned (0, s_manch_bit_index_top'length);
      s_manch_bit_index_load   <= '0';
      s_decr_manch_bit_index_p <= '0';

    elsif s_switching_to_deglitched = '1' then -- preparation for the fsd_field byte
      -- FSD'left-1: bc the 1st bit of the FSD has been covered at the state PRE_field_f_edge
      s_manch_bit_index_top    <= to_unsigned(FSD'left-1,s_manch_bit_index_top'length); 
      s_manch_bit_index_load   <= s_manch_bit_index_is_zero and sample_manch_bit_p_i;
      s_decr_manch_bit_index_p <= '0';

    elsif s_receiving_fsd = '1' then           -- counting FSD manch. encoded bits
      s_manch_bit_index_top    <= to_unsigned (0, s_manch_bit_index_top'length);
      s_manch_bit_index_load   <= '0';
      s_decr_manch_bit_index_p <= sample_manch_bit_p_i;

    elsif s_receiving_bytes = '1' then        -- counting manch. encoded data bits 
      s_manch_bit_index_top    <= to_unsigned (15, s_manch_bit_index_top'length); 
      s_manch_bit_index_load   <= s_manch_bit_index_is_zero and sample_manch_bit_p_i;
      s_decr_manch_bit_index_p <= sample_manch_bit_p_i;

    else
      s_manch_bit_index_top    <= to_unsigned (0, s_manch_bit_index_top'length); 
      s_manch_bit_index_load   <= '0';
      s_decr_manch_bit_index_p <= '0';
    end if;
  end process;

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
  -- aux signals concurrent assignments:
  s_fsd_bit        <= s_receiving_fsd   and FSD (to_integer(s_manch_bit_index));  
  s_fes_bit        <= s_receiving_bytes and FES (to_integer(s_manch_bit_index));


  s_fsd_wrong_bit  <= (s_fsd_bit xor rxd_filtered_i) and sample_manch_bit_p_i;     
  s_fsd_last_bit   <= s_manch_bit_index_is_zero and sample_manch_bit_p_i;


  s_fes_wrong_bit  <= (s_fes_bit xor rxd_filtered_i) and sample_manch_bit_p_i;   
  s_fes_detected_p <=s_fes_detection_window and sample_manch_bit_p_i and s_manch_bit_index_is_zero; 


---------------------------------------------------------------------------------------------------
--!@brief Synchronous process Append_Bit_To_Byte: creation of bytes of data.
--! a new bit of the (deglitched) input signal is appended to the output
--! byte when s_write_bit_to_byte is enabled.

  Append_Bit_To_Byte: process (uclk_i)
    begin
      if rising_edge (uclk_i) then
        if nfip_urst_i = '1' then
          byte_ready_p_o <='0'; 
          s_byte         <= (others => '0');
        else

          byte_ready_p_o <= s_byte_ready_p; 

          if s_write_bit_to_byte = '1' then
           s_byte        <= s_byte(6 downto 0) & rxd_filtered_i;  
          end if;

        end if;
      end if;
    end process;
 --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
  s_write_bit_to_byte <= s_receiving_bytes and sample_bit_p_i;
  s_byte_ready_p      <= s_receiving_bytes and s_manch_bit_index_is_zero and sample_manch_bit_p_i
                                                                      and (not s_fes_detected_p);


---------------------------------------------------------------------------------------------------
 --!@brief Instantiation of the CRC calculator unit
  Check_CRC : WF_crc 
  generic map(c_GENERATOR_POLY_length => 16) 
  port map(
    uclk_i             => uclk_i,
    nfip_urst_i        => nfip_urst_i,
    start_crc_p_i      => s_receiving_fsd,
    data_bit_ready_p_i => s_write_bit_to_byte,
    data_bit_i         => rxd_filtered_i,
    crc_o              => open,
    --------------------------------------------
    crc_ok_p           => s_CRC_ok_p);
    --------------------------------------------

---------------------------------------------------------------------------------------------------
 --!@brief Instantiation of the unit that checks for code violations
  Check_code_violations: WF_manch_code_viol_check
  port map(
    uclk_i                => uclk_i,
    nfip_urst_i           => nfip_urst_i,
    serial_input_signal_i => rxd_filtered_i,
    sample_bit_p_i        => sample_bit_p_i,
    sample_manch_bit_p_i  => sample_manch_bit_p_i,
    -----------------------------------------------
    manch_code_viol_p_o   => s_manch_code_viol_p);
    -----------------------------------------------

 --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
--!@brief Synchronous process that manages the code violations signal.
--! If at any point after the FSS and before the FES a code violation appears, the 
--! signal s_manch_code_violations stays asserted until the end of the corresponding frame.    

  Code_viol: process (uclk_i)
    begin
      if rising_edge (uclk_i) then
        if nfip_urst_i = '1' then
          s_manch_code_violations     <= '0';	

        else

          if s_receiving_bytes = '0' then                         -- after the FSS
            s_manch_code_violations   <= '0';

          else

            if s_manch_code_viol_p ='1' and s_fes_wrong_bit ='1' then  
              s_manch_code_violations <= '1';                     -- if a code violation appears                   
                                                                  -- that doesn't belong to the FES         
            end if;                                            

          end if;
        end if;
      end if;
    end process;


---------------------------------------------------------------------------------------------------
--!@brief Synchronous process that manages the CRC signal.
--! The crc_ok_p coming from the CRC calculator unit is delayed for 16 manch. encoded bits.
--! The matching of this delayed pulse with the end of frame pulse (s_fes_detected_p), would
--! confirm that the two last bytes received before the FES were the correct CRC.

  CRC_OK_pulse_delay: process (uclk_i)
    begin
      if rising_edge (uclk_i) then
        if nfip_urst_i = '1' then
          s_CRC_ok_p_buff         <= (others => '0');
          s_sample_manch_bit_p_d1 <= '0';

        else
          s_sample_manch_bit_p_d1 <= sample_manch_bit_p_i;  -- delay for the synch of s_crc_ok_p
                                                            -- with s_sample_manch_bit_p_d1
          if s_receiving_bytes = '0' then
            s_CRC_ok_p_buff       <= (others => '0');

          else

            if s_sample_manch_bit_p_d1 = '1' then          -- a delay is added to s_CRC_ok_p with 
                                                           -- each manch. bit arrival. In total 15 
                                                           -- delays have to be added in order to
                                                           -- arrive to the FES.
              s_CRC_ok_p_buff     <= s_CRC_ok_p_buff(13 downto 0) & s_CRC_ok_p;
            end if;

          end if;
        end if;
      end if; 
    end process;


  s_crc_ok_p_d16 <= s_CRC_ok_p_buff(14);                   -- pulse 1 half-bit-clock period long


---------------------------------------------------------------------------------------------------
--!@brief Synchronous process FES_Detector: creation of a window that is activated at the 
--! beginning of an incoming byte and stays active as long as 16 incoming manch. bits match the FES. 

  FES_Detector: process (uclk_i)
    begin
      if rising_edge (uclk_i) then
        if nfip_urst_i = '1' then
          s_fes_detection_window   <= '1';

        else
          if s_manch_bit_index_is_zero = '1' and sample_manch_bit_p_i = '1' then 
            s_fes_detection_window <= '1';

          elsif  s_fes_wrong_bit = '1' then
            s_fes_detection_window <= '0';
          end if;

        end if;
      end if;
    end process;

---------------------------------------------------------------------------------------------------
-- aux signals concurrent assignments:

  s_manch_r_edge_p              <= signif_edge_window_i and rxd_r_edge_p_i;
  s_manch_f_edge_p              <= signif_edge_window_i and rxd_f_edge_p_i;
  s_bit_r_edge_p                <= adjac_bits_window_i and ( rxd_r_edge_p_i);
  s_edge_outside_manch_window_p <= (not signif_edge_window_i)and(rxd_r_edge_p_i or rxd_f_edge_p_i);

---------------------------------------------------------------------------------------------------
  -- output signals concurrent assignments:
  byte_o                        <= s_byte; 
  rst_rx_osc_o                  <= s_idle;
  fss_received_p_o              <= s_receiving_fsd and s_fsd_last_bit;
  crc_wrong_p_o                 <= s_fes_detected_p and (not s_crc_ok_p_d16);
  fss_crc_fes_viol_ok_p_o       <= s_fes_detected_p and s_crc_ok_p_d16 and (not s_manch_code_violations);

end architecture rtl;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------