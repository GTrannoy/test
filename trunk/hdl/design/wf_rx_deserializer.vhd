--_________________________________________________________________________________________________
--                                                                                                |
--                                        |The nanoFIP|                                           |
--                                                                                                |
--                                        CERN,BE/CO-HT                                           |
--________________________________________________________________________________________________|
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--! @file WF_rx_deserializer.vhd                                                                  |
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
--                                       WF_rx_deserializer                                      --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
--
--! @brief     De-serialization of the "nanoFIP FIELDRIVE" input signal fd_rxd and construction
--!            of bytes of data to be provided to:
--!              o the WF_engine_control unit,       for the contents of ID_DAT frames
--!              o the WF_cons_bytes_processor unit, for the contents of consumed RP_DAT frames.
--!            The unit is also responsible for the identification of the FSS and FES fields of
--!            ID_DAT and RP_DAT frames and the verification of their FCS and Manchester 2 (manch.)
--!            encoding.
--!            At the end of a frame (FES detection) either the fss_crc_fes_manch_ok_p_o pulse
--!            is assserted, indicating a frame with with correct FSS, CRC, FES and manch. encoding
--!            or the pulse crc_or_manch_wrong_p_o is asserted indicating an error on the CRC or
--!            manch. encoding.
--!            If a FES is not detected after the reception of more than 8 bytes for an ID_DAT or
--!            more than 134 bytes for a RP_DAT the unit is reset by the WF_engine_control.
--!
--!            Remark: We refer to
--!              o a significant edge                : for the edge of a manch. encoded bit
--!                (bit 0: _|-, bit 1: -|_).
--!
--!              o a transition	                     : for the moment in between two adjacent bits,
--!                that may or may not result in an edge (eg. a 0 followed by a 0 will give an edge
--!                _|-|_|-, but a 0 followed by a 1 will not _|--|_ ).
--!
--!              o the sampling of a manch. bit      : for the moments when a manch. encoded bit
--!                should be sampled, before and after a significant edge.
--!
--!              o the sampling of a bit             : for the sampling of only the 1st part,
--!                before the transition.
--!
--!                Example:
--!                  bits               :  0   1
--!                  manch. encoded     : _|- -|_
--!                  significant edge   :  ^   ^
--!                  transition         :    ^
--!                  sample_manch_bit_p : ^ ^ ^ ^
--!                  sample_bit_p       : ^   ^   (this sampling will give the 0 and the 1)
--!
--!
--!            Reminder:
--!
--!            Consumed RP_DAT frame structure :
--!           _______ _______ ______  _______ ______ ________________ _______  ___________ _______
--!          |__PRE__|__FSD__|_Ctrl_||__PDU__|_LGTH_|_..ApplicData.._|__MPS__||____FCS____|__FES__|
--!
--
--
--! @author    Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)\n
--!            Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)    \n
--
--
--! @date      15/02/2011
--
--
--! @version   v0.05
--
--
--! @details \n
--
--!   \n<b>Dependencies:</b>         \n
--!            WF_reset_unit         \n
--!            WF_rx_osc             \n
--!            WF_rx_deglitcher      \n
--!            WF_engine_control     \n
--
--
--!   \n<b>Modified by:</b>          \n
--!            Pablo Alvarez Sanchez \n
--!             Evangelia Gousiou    \n
--
---------------------------------------------------------------------------------------------------
--
--!   \n\n<b>Last changes:</b>\n
--!     -> 09/2009 v0.01 PAS First version \n
--!     -> 10/2010 v0.02 EG  state switch_to_deglitched added;
--!                          output signal rx_osc_rst_o added; signals renamed;
--!                          state machine rewritten (moore style);
--!                          units WF_rx_manch_code_check and Incoming_Bits_Index created;
--!                          each manch bit of FES checked (bf was just each bit, so any D5 was FES)
--!                          code cleaned-up + commented.\n
--!     -> 12/2010 v0.03 EG  CRC_ok pulse transfered 16 bits later to match the FES;
--!                          like this we confirm that the CRC_ok_p arrived just before the FES,
--!                          and any 2 bytes that could by chanche be seen as CRC, are neglected.
--!                          FSM data_field_byte state: redundant code removed:
--!                          "s_fes_wrong_bit = '1' and s_manch_code_viol_p = '1' then idle"
--!                          code(more!)cleaned-up
--!     -> 01/2011 v0.04 EG  changed way of detecting the FES to be able to detect a FES even if
--!                          bytes with size different than 8 have preceeded.
--!                          crc_or_manch_wrong_p_o replaced the crc_wrong_p_o.
--!     -> 02/2011 v0.05 EG  changed crc pulse transfer; removed switch to deglitch state
--                           s_fes_detected_p removed and s_byte_ready_p_d1; if bytes arrive with
--                           bits not x8, the fss_crc_fes_manch_ok_p_o stays 0 (bc of s_CRC_ok_p_d)
--                           and the crc_or_manch_wrong_p_o is asserted.
--
---------------------------------------------------------------------------------------------------
--
--! @todo
--! ->
--
---------------------------------------------------------------------------------------------------



--=================================================================================================
--!                           Entity declaration for WF_rx_deserializer
--=================================================================================================

entity WF_rx_deserializer is

  port (
  -- INPUTS
    -- nanoFIP User Interface general signal
    uclk_i                  : in std_logic; --! 40 MHz clock

    -- Signal from the WF_reset_unit
    nfip_rst_i              : in std_logic; --! nanoFIP internal reset

    -- Signal from the WF_engine_control unit
    rx_rst_i                : in std_logic; --! reset during production or
                                            --! reset pulse when consumption is lasting more than
                                            --! expected (ID_DAT > 8 bytes, RP_DAT > 134 bytes)

    -- Signals from the WF_rx_deglitcher
    fd_rxd_f_edge_p_i       : in std_logic; --! indicates a falling edge on the deglitched fd_rxd
    fd_rxd_r_edge_p_i       : in std_logic; --! indicates a rising edge on the deglitched fd_rxd
    fd_rxd_i                : in std_logic; --! deglitched fd_rxd

    -- Signals from the WF_rx_osc unit
    manch_code_viol_p_i     : in std_logic; --! pulse upon Manchester code violation
    sample_manch_bit_p_i    : in std_logic; --! pulse indicating the sampling of a manch. bit
    sample_bit_p_i          : in std_logic; --! pulse indicating the sampling of a bit
    signif_edge_window_i    : in std_logic; --! time window where a significant edge is expected
    adjac_bits_window_i     : in std_logic; --! time window where a transition between adjacent
                                            --! bits is expected


  -- OUTPUTS
    -- Signals to the WF_consumption and the WF_engine_control units
    byte_o                  : out std_logic_vector (7 downto 0) ;   --! retrieved data byte
    byte_ready_p_o          : out std_logic; --! pulse indicating a new retrieved data byte
    fss_crc_fes_manch_ok_p_o: out std_logic; --! indication of a frame (ID_DAT or RP_DAT) with
                                             --! correct FSS, FES, CRC and manch. encoding

    -- Signal to the WF_production and the WF_engine_control units
    crc_or_manch_wrong_p_o  : out std_logic; --! indication of a wrong CRC or manch. encoding on a
                                             --! ID_DAT or RP_DAT; pulse after the FES detection

    -- Signal to the WF_engine_control unit
    fss_received_p_o        : out std_logic; --! pulse after the reception of a correct FSS (ID/RP)

    -- Signal to the WF_rx_osc unit
    rx_osc_rst_o            : out std_logic  --! resets the clk recovery procedure
);

end entity WF_rx_deserializer;


--=================================================================================================
--!                                    architecture declaration
--=================================================================================================
architecture rtl of WF_rx_deserializer is

  -- states of the receiver's state machine
  type rx_st_t  is (idle, pre_field_first_f_edge, pre_field_r_edge, pre_field_f_edge,
                    fsd_field, ctrl_data_fcs_fes_fields);

  signal rx_st, nx_rx_st                                                               : rx_st_t;
  signal s_idle, s_receiving_pre, s_receiving_fsd, s_receiving_bytes                   : std_logic;
  signal s_fsd_bit, s_fes_bit, s_fsd_wrong_bit, s_fsd_last_bit, s_fes_wrong_bit        : std_logic;
  signal s_fes_detected_p, s_write_bit_to_byte_p                                       : std_logic;
  signal s_byte_ready_p, s_byte_ready_p_d1                                             : std_logic;
  signal s_manch_r_edge_p, s_manch_f_edge_p, s_bit_r_edge_p, s_edge_out_manch_window_p : std_logic;
  signal s_manch_bit_index_load, s_decr_manch_bit_index_p, s_manch_bit_index_is_zero   : std_logic;
  signal s_manch_not_ok, s_CRC_ok_p,s_CRC_ok_p_d, s_CRC_ok_p_found                     : std_logic;
  signal s_manch_code_viol_p_d7, s_load_manch_viol_couner                              : std_logic;
  signal s_decr_manch_viol_couner, s_rst_manch_viol_couner                             : std_logic;
  signal s_session_timedout                                                            : std_logic;
  signal s_manch_viol_c                                                    : unsigned (2 downto 0);
  signal s_manch_bit_index, s_manch_bit_index_top                          : unsigned (3 downto 0);
  signal s_byte                                                   : std_logic_vector  (7 downto 0);
  signal s_arriving_fes                                           : std_logic_vector (15 downto 0);


--=================================================================================================
--!                                       architecture begin
--=================================================================================================
  begin

---------------------------------------------------------------------------------------------------
--                                       Deserializer's FSM                                      --
---------------------------------------------------------------------------------------------------

--!@brief Receiver's state machine: the state machine is divided in three parts (a clocked process
--! to store the current state, a combinatorial process to manage state transitions and finally a
--! combinatorial process to manage the output signals), which are the three processes that follow.

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
--!@brief Synchronous process Deserializer_FSM_Sync: storage of the current state of the FSM

  Deserializer_FSM_Sync: process (uclk_i)
    begin
      if rising_edge (uclk_i) then
        if nfip_rst_i = '1' then
          rx_st <= idle;
        else
          rx_st <= nx_rx_st;
        end if;
      end if;
    end process;


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
--!@brief Combinatorial process Deserializer_FSM_Comb_State_Transitions: definition of the state
--! transitions of the FSM.

  Deserializer_FSM_Comb_State_Transitions: process (s_bit_r_edge_p, s_edge_out_manch_window_p,
                                                    rx_rst_i, fd_rxd_f_edge_p_i, s_manch_r_edge_p,
                                                    s_fsd_wrong_bit, s_manch_f_edge_p, rx_st,
                                                    s_fsd_last_bit, s_fes_detected_p, s_session_timedout)
  begin

    -- During the PRE, the WF_rx_osc is trying to synchronize to the transmitter's clock and every
    -- edge detected in the deglitched FD_RXD is taken into account. At this phase, the unit uses
    -- the WF_rx_osc signals adjac_bits_window_i and signif_edge_window_i and if edges are found
    -- outside those windows the unit goes back to idle and the WF_rx_osc is reset.
    -- For the rest of the frame, the unit is just sampling the deglitched FD_RXD on the moments
    -- specified by the WF_rx_osc signals sample_manch_bit_p_i and sample_bit_p_i.

  case rx_st is


    when idle =>                                               -- in idle state until falling
                        if fd_rxd_f_edge_p_i = '1' then        -- edge detection
                          nx_rx_st <= pre_field_first_f_edge;

                        elsif rx_rst_i = '1' then              -- nanoFIP producing or 
                          nx_rx_st <= idle;                    -- nanoFIP consuming and an excessive
                                                               -- number of bytes has arrived

                        elsif s_session_timedout = '1' then    -- independant timeout
                          nx_rx_st <= idle;

                        else
                          nx_rx_st <= idle;
                        end if;


    when pre_field_first_f_edge =>
                        if s_manch_r_edge_p = '1' then         -- arrival of a "manch."
                          nx_rx_st <= pre_field_r_edge;        -- rising edge

                        elsif s_edge_out_manch_window_p = '1' then -- arrival of any other edge
                          nx_rx_st <= idle;

                        elsif rx_rst_i = '1' then              -- nanoFIP producing or 
                          nx_rx_st <= idle;                    -- nanoFIP consuming and an excessive
                                                               -- number of bytes has arrived

                        elsif s_session_timedout = '1' then    -- independant timeout
                          nx_rx_st <= idle;

                        else
                          nx_rx_st <= pre_field_first_f_edge;
                        end if;


    when pre_field_r_edge =>
                        if s_manch_f_edge_p = '1' then         -- arrival of a manch. falling edge
                          nx_rx_st <= pre_field_f_edge;        -- note: several loops between
                                                               -- a rising and a falling edge are
                                                               -- expected for the PRE

                        elsif s_edge_out_manch_window_p = '1' then -- arrival of any other edge
                           nx_rx_st <= idle;

                        elsif rx_rst_i = '1' then              -- nanoFIP producing or 
                          nx_rx_st <= idle;                    -- nanoFIP consuming and an excessive
                                                               -- number of bytes has arrived

                        elsif s_session_timedout = '1' then    -- independant timeout
                          nx_rx_st <= idle;

                        else
                           nx_rx_st <= pre_field_r_edge;
                        end if;


    when pre_field_f_edge =>
                        if s_manch_r_edge_p = '1' then         -- arrival of a manch. rising edge
                          nx_rx_st <= pre_field_r_edge;

                        elsif s_bit_r_edge_p = '1' then        -- arrival of a rising edge between
                          nx_rx_st <=  fsd_field;              -- adjacent bits, signaling the
                                                               -- beginning of the 1st V+ violation
                                                               -- of the FSD

                        elsif s_edge_out_manch_window_p = '1' then -- arrival of any other edge
                          nx_rx_st <= idle;

                        elsif rx_rst_i = '1' then              -- nanoFIP producing or 
                          nx_rx_st <= idle;                    -- nanoFIP consuming and an excessive
                                                               -- number of bytes has arrived

                        elsif s_session_timedout = '1' then    -- independant timeout
                          nx_rx_st <= idle;

                        else
                          nx_rx_st <= pre_field_f_edge;
                         end if;

    -- For the monitoring of the FSD, the unit is sampling each manch. bit of the incoming
    -- filtered FD_RXD and it is comparing it to the nominal bit of the FSD (through the signal
    -- s_fsd_wrong_bit). If a wrong bit is received, the state machine jumps back to idle,
    -- whereas if the complete byte is correctly received, it jumps to the ctrl_data_fcs_fes_fields

    when fsd_field =>
                        if s_fsd_last_bit = '1' then           -- reception of the last(15th)
                          nx_rx_st <= ctrl_data_fcs_fes_fields;-- FSD bit

                        elsif s_fsd_wrong_bit = '1' then       -- wrong bit
                          nx_rx_st <= idle;

                        elsif rx_rst_i = '1' then              -- nanoFIP producing or 
                          nx_rx_st <= idle;                    -- nanoFIP consuming and an excessive
                                                               -- number of bytes has arrived

                        elsif s_session_timedout = '1' then    -- independant timeout
                          nx_rx_st <= idle;

                        else
                          nx_rx_st <= fsd_field;
                        end if;


    -- nanoFIP can receive ID_DATs of a predefined length of 8 bytes and RP_DATs of any length
    -- (not predefined) up to 134 bytes (FSS+Ctrl+PDU_TYPE+LGTH+125 application_data+MPS+FCS+FES).
    -- The WF_engine_control unit is following the amount of bytes being received and in case
    -- their number exceeds the expected one, it activates the signal rx_rst_i.
    -- Therefore, the Receiver_FSM stays in the ctrl_data_fcs_fes_fields state until the arrival
    -- of a correct FES, or until the arrival of a reset signal from the WF_engine_control.

    when ctrl_data_fcs_fes_fields =>
                        if s_fes_detected_p = '1' then
                          nx_rx_st <= idle;

                        elsif rx_rst_i = '1' then              -- nanoFIP producing or 
                          nx_rx_st <= idle;                    -- nanoFIP consuming and an excessive
                                                               -- number of bytes has arrived

                        elsif s_session_timedout = '1' then    -- independant timeout
                          nx_rx_st <= idle;

                        else
                          nx_rx_st <= ctrl_data_fcs_fes_fields;
                        end if;


    when others =>
                        nx_rx_st <= idle;

  end case;
  end process;

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
--!@brief Combinatorial process Deserializer_FSM_Comb_Output_Signals: definition of the output
--! signals of the FSM

  Deserializer_FSM_Comb_Output_Signals: process (rx_st)

  begin

    case rx_st is

    when idle =>
                  ------------------------------------
                   s_idle                    <= '1';
                  ------------------------------------
                   s_receiving_pre           <= '0';
                   s_receiving_fsd           <= '0';
                   s_receiving_bytes         <= '0';


    when pre_field_first_f_edge | pre_field_r_edge | pre_field_f_edge =>

                   s_idle                    <= '0';
                  ------------------------------------
                   s_receiving_pre           <= '1';
                  ------------------------------------
                   s_receiving_fsd           <= '0';
                   s_receiving_bytes         <= '0';


    when fsd_field =>

                   s_idle                    <= '0';
                   s_receiving_pre           <= '0';
                  ------------------------------------
                   s_receiving_fsd           <= '1';
                  ------------------------------------
                   s_receiving_bytes         <= '0';


    when ctrl_data_fcs_fes_fields =>

                   s_idle                    <= '0';
                   s_receiving_pre           <= '0';
                   s_receiving_fsd           <= '0';
                  ------------------------------------
                   s_receiving_bytes         <= '1';
                  ------------------------------------


    when others =>

                   s_idle                    <= '0';
                   s_receiving_pre           <= '0';
                   s_receiving_fsd           <= '0';
                   s_receiving_bytes         <= '0';

    end case;
  end process;



---------------------------------------------------------------------------------------------------
--                                         Bytes Creation                                        --
---------------------------------------------------------------------------------------------------

--!@brief Synchronous process Append_Bit_To_Byte: creation of bytes of data.
--! A new bit of the deglitched FD_RXD is appended to the output byte that is being formed when the
--! Deserializer's FSM is in the "ctrl_data_fcs_fes_fields" state, on the "sample_bit_p_i" moments.

  Append_Bit_To_Byte: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if nfip_rst_i = '1' then
        s_byte_ready_p_d1 <='0';
        s_byte            <= (others => '0');
      else

        s_byte_ready_p_d1 <= s_byte_ready_p;

        if s_write_bit_to_byte_p = '1' then
          s_byte          <= s_byte(6 downto 0) & fd_rxd_i;

        end if;
      end if;
    end if;
  end process;

 --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  s_write_bit_to_byte_p   <= s_receiving_bytes and sample_bit_p_i;
  s_byte_ready_p          <= s_receiving_bytes and s_manch_bit_index_is_zero and sample_manch_bit_p_i
                                                                           and (not s_fes_detected_p);



---------------------------------------------------------------------------------------------------
--                                      FSD & FES followers                                      --
---------------------------------------------------------------------------------------------------

--!@brief Instantiation of a counter that manages the position of an incoming deglitched FD_RXD bit
--! inside a manch. encoded byte (16 bits).

  Incoming_Bits_Index: WF_decr_counter
  generic map (g_counter_lgth => 4)
  port map (
    uclk_i            => uclk_i,
    nfip_rst_i        => nfip_rst_i,
    counter_top       => s_manch_bit_index_top,
    counter_load_i    => s_manch_bit_index_load,
    counter_decr_p_i  => s_decr_manch_bit_index_p,
    ---------------------------------------------------
    counter_o         => s_manch_bit_index,
    counter_is_zero_o => s_manch_bit_index_is_zero);
    ---------------------------------------------------


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  -- FSD aux signals concurrent assignments:

  s_fsd_bit           <= s_receiving_fsd   and c_FSD (to_integer(s_manch_bit_index));
  s_fsd_last_bit      <= s_manch_bit_index_is_zero and sample_manch_bit_p_i;
  s_fsd_wrong_bit     <= (s_fsd_bit xor fd_rxd_i) and sample_manch_bit_p_i;

  -- FES aux signals concurrent assignments :

  s_fes_bit           <= s_receiving_bytes and c_FES (to_integer(s_manch_bit_index));
  s_fes_wrong_bit     <= (s_fes_bit xor fd_rxd_i) and sample_manch_bit_p_i;


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
--!@brief Combinatorial process that according to the state of the FSM sets values to the
--! Incoming_Bits_Index inputs.

  Bit_Index: process (s_idle,s_receiving_pre, s_receiving_fsd, s_receiving_bytes,
                      s_manch_bit_index_is_zero,sample_manch_bit_p_i)
  begin

    if s_idle ='1' then                 -- counter re-initialization after a reception
      s_manch_bit_index_top    <= to_unsigned (0, s_manch_bit_index_top'length);
      s_manch_bit_index_load   <= '1';
      s_decr_manch_bit_index_p <= '0';

    elsif s_receiving_pre = '1' then    -- preparation for the FSD byte
      s_manch_bit_index_top    <= to_unsigned(c_FSD'left-2,s_manch_bit_index_top'length);
      -- FSD'left-2: bc the 1st bit of the FSD has been covered at the state PRE_field_f_edge
      s_manch_bit_index_load   <= s_manch_bit_index_is_zero and sample_manch_bit_p_i;
      s_decr_manch_bit_index_p <= '0';

    elsif s_receiving_fsd = '1' then    -- counting FSD manch. encoded bits
      s_manch_bit_index_top    <= to_unsigned (0, s_manch_bit_index_top'length);
      s_manch_bit_index_load   <= '0';
      s_decr_manch_bit_index_p <= sample_manch_bit_p_i;

    elsif s_receiving_bytes = '1' then  -- counting manch. encoded data bits
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
--!@brief Synchronous process FES_Detector: The s_arriving_fes register is storing the last 16
--! manch. encoded bits received and the s_fes_detected_p indicates whether they match the FES.

  FES_Detector: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if s_receiving_bytes = '0' then
        s_arriving_fes <= (others =>'0');

      elsif s_receiving_bytes = '1' and sample_manch_bit_p_i = '1' then

        s_arriving_fes <= s_arriving_fes (14 downto 0) & fd_rxd_i;

      end if;
    end if;
  end process;

  --  --  --  --  --  --  --  --  --  --  --
  s_fes_detected_p <= '1' when (s_arriving_fes = c_FES) and s_byte_ready_p_d1='1' else '0';-- pulse
                                                                              -- upon FES detection


---------------------------------------------------------------------------------------------------
--                                        CRC Verification                                       --
---------------------------------------------------------------------------------------------------

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
--!@brief Instantiation of the CRC calculator unit that verifies the received FCS field.

  CRC_Verification : WF_crc
  port map (
    uclk_i             => uclk_i,
    nfip_rst_i         => nfip_rst_i,
    start_crc_p_i      => s_receiving_fsd,
    data_bit_ready_p_i => s_write_bit_to_byte_p,
    data_bit_i         => fd_rxd_i,
    crc_o              => open,
   ---------------------------------------------------
    crc_ok_p_o         => s_CRC_ok_p);
   ---------------------------------------------------

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
--!@brief Synchronous process that checks the position of the CRC bytes in the frame: the 1 uclk-
--! wide crc_ok_p coming from the CRC calculator is delayed for 1 complete byte. The matching of
--! this delayed pulse with the end of frame pulse (s_fes_detected_p), would confirm that the two
--! last bytes received before the FES were the correct CRC.

  CRC_OK_pulse_delay: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if s_receiving_bytes = '0' then
        s_CRC_ok_p_d       <= '0';
        s_CRC_ok_p_found   <= '0';
      else

        if s_CRC_ok_p = '1' then
          s_CRC_ok_p_found <= '1';
        end if;

        if s_byte_ready_p = '1' and s_CRC_ok_p_found = '1' then -- arrival of the next byte
          s_CRC_ok_p_d     <= '1';                              -- (FES normally)
          s_CRC_ok_p_found <= '0';

        else
          s_CRC_ok_p_d     <= '0';
        end if;

      end if;
    end if;
  end process;



---------------------------------------------------------------------------------------------------
--                                  Manch. Encoding Verification                                 --
---------------------------------------------------------------------------------------------------

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
--!@brief The Manch_Code_Viol_Counter is used for the transfering of manch_code_viol_p_i pulses
--! (appearing upon manch. code violations) by 7 bits. Like this we manage to separate violations
--! belonging to the FES from the those that may appear within a frame after the FSS and before
--! the FES.
--! The counter is
--! loaded : upon violation detection after the FSS (manch_code_viol_p_i and s_receiving_bytes) and
--! counts : upon the reception of a new bit (s_write_bit_to_byte_p).
--! If the transfered pulse is still within the s_receiving_bytes window (which indicates that the
--! frame has still not finished and therefore the violation has occured in the data part)
--! the signal s_manch_not_ok gets activated and stays active until the end of the frame.
 
  Manch_Code_Viol_Counter: WF_decr_counter
  generic map (g_counter_lgth => 3)
  port map (
    uclk_i            => uclk_i,
    nfip_rst_i        => s_rst_manch_viol_couner,
    counter_top       => (others => '1'),
    counter_load_i    => s_load_manch_viol_couner,
    counter_decr_p_i  => s_decr_manch_viol_couner, 
    counter_is_zero_o => open,
   ---------------------------------------------------
    counter_o         => s_manch_viol_c);
   ---------------------------------------------------

  s_rst_manch_viol_couner  <= (not s_receiving_bytes) or nfip_rst_i;
  s_load_manch_viol_couner <= manch_code_viol_p_i and s_receiving_bytes;
  s_decr_manch_viol_couner <= '1' when (s_write_bit_to_byte_p='1') and (s_manch_viol_c > "000") else '0';
  s_manch_code_viol_p_d7   <= '1' when s_manch_viol_c = "001" else '0';


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
--!@brief Synchronous process that handles the s_manch_code_viol_p_d7 signal: If at any point after
--! the FSS and before the FES a code violation appears, the signal s_manch_not_ok stays
--! asserted until the end of the corresponding frame.

  Code_viol_detected: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if s_receiving_bytes = '0' then                         -- after the FSS
        s_manch_not_ok   <= '0';

       else
        if s_manch_code_viol_p_d7 ='1' then
          s_manch_not_ok <= '1';                              -- if a code violation appears
        end if;                                               -- that doesn't belong to the FES
      end if;
    end if;
  end process;



---------------------------------------------------------------------------------------------------
--                                  Independant Timeout Counter                                  --
---------------------------------------------------------------------------------------------------

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
--! @brief Instantiation of a WF_decr_counter relying only on the system clock, as an additional
--! way to go back to Idle state, in case any other logic is being stuck. The length of the counter
--! is defined using the slowest bit rate and considering reception of the upper limit of 134 bytes. 

  Session_Timeout_Counter: WF_decr_counter
  generic map (g_counter_lgth => 21)
  port map (
    uclk_i            => uclk_i,
    nfip_rst_i        => nfip_rst_i,
    counter_top       => (others => '1'),
    counter_load_i    => s_idle,
    counter_decr_p_i  => '1', -- on each uclk tick
    counter_o         => open,
    ---------------------------------------------------
    counter_is_zero_o => s_session_timedout);
    ---------------------------------------------------



---------------------------------------------------------------------------------------------------
--                                 Concurrent signal assignments                                 --
---------------------------------------------------------------------------------------------------
-- aux signals concurrent assignments :

  s_manch_r_edge_p          <= signif_edge_window_i and fd_rxd_r_edge_p_i;
  s_manch_f_edge_p          <= signif_edge_window_i and fd_rxd_f_edge_p_i;
  s_bit_r_edge_p            <= adjac_bits_window_i  and fd_rxd_r_edge_p_i;
  s_edge_out_manch_window_p <= (not signif_edge_window_i)and(fd_rxd_r_edge_p_i or fd_rxd_f_edge_p_i);


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  -- output signals concurrent assignments :

  byte_o                    <= s_byte;
  byte_ready_p_o            <= s_byte_ready_p_d1;
  rx_osc_rst_o              <= s_idle;
  fss_received_p_o          <= s_receiving_fsd  and s_fsd_last_bit;
  crc_or_manch_wrong_p_o    <= s_fes_detected_p and ((not s_CRC_ok_p_d) or s_manch_not_ok);
  fss_crc_fes_manch_ok_p_o  <= s_fes_detected_p and s_CRC_ok_p_d and (not s_manch_not_ok);


end architecture rtl;
--=================================================================================================
--                                        architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------