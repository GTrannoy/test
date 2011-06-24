--_________________________________________________________________________________________________
--                                                                                                |
--                                        |The nanoFIP|                                           |
--                                                                                                |
--                                        CERN,BE/CO-HT                                           |
--________________________________________________________________________________________________|
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
-- File         WF_engine_control.vhd                                                             |
---------------------------------------------------------------------------------------------------

-- Standard library
library IEEE;
-- Standard packages
use IEEE.STD_LOGIC_1164.all; -- std_logic definitions
use IEEE.NUMERIC_STD.all;    -- conversion functions

-- Specific packages
use work.WF_PACKAGE.all;     -- definitions of types, constants, entities


---------------------------------------------------------------------------------------------------
--                                                                                               --
--                                        WF_engine_control                                      --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
--
-- Description  The WF_engine_control is following the reception of an incoming ID_DAT frame and
--                o identifies the variable to be treated
--                o signals accordingly the WF_production and WF_consumption units.
--              During the production or consumption the unit is keeping track of the amounts of
--              produced and consumed bytes.
--
--
--              Reminder:
--
--              ID_DAT frame structure :
--               ___________ ______  _______ ______  ___________ _______
--              |____FSS____|_Ctrl_||__Var__|_SUBS_||____FCS____|__FES__|
--
--
--              Produced RP_DAT frame structure :
--               ___________ ______  _______ ______ _________________ _______ _______  ___________ _______
--              |____FSS____|_Ctrl_||__PDU__|_LGTH_|__..User-Data..__|_nstat_|__MPS__||____FCS____|__FES__|
--
--
--              Consumed RP_DAT frame structure :
--               ___________ ______  _______ ______ _________________________ _______  ___________ _______
--              |____FSS____|_Ctrl_||__PDU__|_LGTH_|_____..Applic-Data.._____|__MPS__||____FCS____|__FES__|
--
--
--              Turnaround time : Time between the end of the reception of an ID_DAT frame
--              requesting for a variable to be produced and the starting of the delivery of a
--              produced RP_DAT frame.
--
--              Silence time    : Maximum time that nanoFIP waits for a consumed RP_DAT frame after
--              the reception of an ID_DAT frame indicating a variable to be consumed.
--
--
-- Authors      Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)
--              Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)
--
--
-- Date         15/01/2011
--
--
-- Version      v0.04
--
--
-- Depends on   WF_reset_unit
--              WF_fd_transmitter
--              WF_fd_receiver
--
--
---------------------------------------------------------------------------------------------------
--
-- Last changes
--     07/2009  v0.01  EB  First version
--     08/2010  v0.02  EG  E0 added as broadcast
--                         PDU,length,ctrl bytes of RP_DAT checked bf VAR1_RDY/ var_2_rdy assertion;
--                         if ID_DAT>8 bytes or RP_DAT>133 (bf reception of a FES) go to idle;
--                         state consume_wait_FSS, for the correct use of the silence time(time
--                         stops counting when an RP_DAT frame has started)
--     12/2010  v0.03  EG  state machine rewritten moore style; removed check on slone mode
--                         for #bytes>4; in slone no broadcast
--     01/2011  v0.04  EG  signals named according to their origin; signals var_rdy (1,2,3),
--                         assert_rston_p_o,rst_nfip_and_fd_p_o, nFIP status bits and
--                         rx_byte_ready_p_o removed cleaning-up+commenting
--     02/2011  v0.05  EG  Independant timeout counter added; time counter 18 digits instead of 15
--                         id_dat_frame_ok: corrected mistake if rx_fss_crc_fes_ok_p not
--                         activated; rx reset during production (rx_rst_o);
--                         cons_bytes_excess_o added
--                         tx_completed_p_i added (bf for the engine ctrl production was finished
--                         after the delivery of the last data byte (MPS))
--
---------------------------------------------------------------------------------------------------



--=================================================================================================
--                          Entity declaration for WF_engine_control
--=================================================================================================
entity WF_engine_control is
  port (
  -- INPUTS
    --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --
    -- nanoFIP User Interface, General signals
    uclk_i                     : in std_logic;                     -- 40 MHz clock
    nostat_i                   : in std_logic;                     -- if negated, nFIP status is sent
    slone_i                    : in std_logic;                     -- stand-alone mode

    -- nanoFIP WorldFIP Settings
    p3_lgth_i                  : in std_logic_vector (2 downto 0); -- produced var user-data length
    rate_i                     : in std_logic_vector (1 downto 0); -- WorldFIP bit rate
    subs_i                     : in std_logic_vector (7 downto 0); -- subscriber number coding

    --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --
    -- Signal from the WF_reset_unit
    nfip_rst_i                 : in std_logic;                     -- nanoFIP internal reset


    --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --
    -- Signal from the WF_fd_transmitter unit

    tx_completed_p_i           : in std_logic;                     -- pulse upon termination of a
                                                                   -- produced RP_DAT transmission

    tx_byte_request_p_i        : in std_logic;                     -- used for the counting of the
                                                                   -- # produced bytes

    --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --
    -- Signals from the WF_fd_receiver unit

    rx_byte_i                  : in std_logic_vector (7 downto 0); -- deserialized ID_DAT/ RP_DAT byte
    rx_byte_ready_p_i          : in std_logic; -- indication of a new byte on rx_byte_i

    rx_fss_crc_fes_ok_p_i      : in std_logic; -- indication of a frame (ID_DAT or RP_DAT) with
                                               -- correct FSS, FES and CRC

    rx_crc_wrong_p_i           : in std_logic; -- indication of a frame with a wrong CRC
                                               -- pulse upon FES detection

    rx_fss_received_p_i        : in std_logic; -- pulse upon FSS detection (ID/ RP_DAT)



  -------------------------------------------------------------------------------------------------
  -- OUTPUTS

    --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --
    -- Signal to the WF_fd_transmitter unit
    tx_start_p_o               : out std_logic; -- launches the transmitters
    tx_byte_request_accept_p_o : out std_logic; -- answer to tx_byte_request_p_i
    tx_last_data_byte_p_o      : out std_logic; -- indication of the last data-byte
                                                -- (CRC & FES not included)

    --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --
    -- Signal to the WF_production unit
    prod_data_lgth_o           : out std_logic_vector (7 downto 0); -- # bytes of the Conrol & Data
                                                                    -- fields of a prod RP_DAT frame

    --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --
    -- Signal to the WF_fd_receiver
    rx_rst_o                   : out std_logic; -- reset during production or
                                                -- reset pulse when consumption is lasting more than
                                                -- expected (ID_DAT > 8 bytes, RP_DAT > 133 bytes)

    --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --
    -- Signal to the WF_consumption unit
    cons_bytes_excess_o        : out std_logic; -- indication of a consumed RP_DAT frame with more
                                                -- than 133 bytes

    --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --
    -- Signals to the WF_production & WF_consumption
    prod_cons_byte_index_o     : out std_logic_vector (7 downto 0); -- index of the byte being
                                                                    -- consumed/ produced

    --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --
    -- Signals to the WF_production, WF_consumption, WF_reset_unit
    var_o                      : out t_var     -- variable received by a valid ID_DAT frame
                                               -- that concerns this station
    );
end entity WF_engine_control;



--=================================================================================================
--                                    architecture declaration
--=================================================================================================
architecture rtl of WF_engine_control is


  type control_st_t  is (idle,
                         id_dat_control_byte, id_dat_var_byte, id_dat_subs_byte, id_dat_frame_ok,
                         consume_wait_FSS, consume,
                         produce_wait_turnar_time, produce);

  signal control_st, nx_control_st                                                     : control_st_t;
  signal s_idle_state, s_id_dat_ctrl_byte, s_id_dat_var_byte, s_id_dat_frame_ok        : std_logic;
  signal s_cons_wait_FSS, s_consuming                                                  : std_logic;
  signal s_prod_wait_turnar_time, s_producing                                          : std_logic;
  signal s_var_aux, s_var                                                              : t_var;
  signal s_var_identified                                                              : std_logic;
  signal s_time_c_top, s_turnaround_time, s_silence_time                  : unsigned (17 downto 0);
  signal s_time_c_load, s_time_c_is_zero                                               : std_logic;
  signal s_session_timedout                                                            : std_logic;
  signal s_rx_bytes_c, s_prod_bytes_c                                      : unsigned (7 downto 0);
  signal s_rx_byte_index, s_prod_byte_index                        : std_logic_vector (7 downto 0);
  signal s_prod_bytes_c_rst, s_prod_bytes_c_inc                                        : std_logic;
  signal s_rx_bytes_c_rst, s_rx_bytes_c_inc                                            : std_logic;
  signal s_tx_start_prod_p, s_tx_byte_request_accept_p, s_tx_byte_request_accept_p_d1  : std_logic;
  signal s_tx_byte_request_accept_p_d2, s_tx_last_data_byte_p, s_tx_last_data_byte_p_d : std_logic;
  signal s_prod_data_lgth                                          : std_logic_vector (7 downto 0);
  signal s_prod_data_lgth_match                                                        : std_logic;
  signal s_broadcast_var                                                               : std_logic;
  signal s_prod_or_cons                                            : std_logic_vector (1 downto 0);

--=================================================================================================
--                                       architecture begin
--=================================================================================================
begin


---------------------------------------------------------------------------------------------------
--                                       engine_control FSM                                      --
---------------------------------------------------------------------------------------------------

-- Central control FSM: the state machine is divided in three parts (a clocked process
-- to store the current state, a combinatorial process to manage state transitions and finally a
-- combinatorial process to manage the output signals), which are the three processes that follow.

-- The FSM stays in idle until the reception of a FSS from the WF_fd_receiver.
-- It continues by checking one by one the bytes of the frame as they arrive:
--   o if the Control byte corresponds to an ID_DAT,
--   o if the variable byte corresponds to a defined variable,
--   o if the subscriber byte matches the station's address, or if the variable is a broadcast
--   o and if the frame finishes with a correct CRC and FES.
-- If the received variable is a produced (var_presence, var_identif, var_3, var_jc3) the FSM stays
-- in the "produce_wait_turnar_time" state until the expiration of the turnaround time and then
-- jumps to the "produce" state, waiting for the WF_fd_serializer to finish the transmission;
-- then it goes back to idle.
-- If the received variable is a consumed (var_1, var_2, var_rst, var_jc1) the FSM stays in the
-- "consume_wait_FSS" state until the arrival of a FSS or the expiration of the silence time.
-- After the arrival of a FSS the FSM jumps to the "consume" state, where it stays until the
-- WF_fd_receiver receives a FES.

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Synchronous process Engine_Control_FSM_Sync: storage of the current state of the FSM

  Engine_Control_FSM_Sync: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if nfip_rst_i = '1' then
        control_st <= idle;
      else
        control_st <= nx_control_st;
      end if;
    end if;
  end process;

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Combinatorial process Engine_Control_FSM_Comb_State_Transitions: definition of the state
-- transitions of the FSM.

  Engine_Control_FSM_Comb_State_Transitions: process (s_time_c_is_zero, s_prod_or_cons,subs_i,
                                                      rx_crc_wrong_p_i, s_session_timedout,
                                                      rx_fss_crc_fes_ok_p_i, s_broadcast_var,
                                                      s_var_identified,rx_byte_ready_p_i,rx_byte_i,
                                                      control_st,rx_fss_received_p_i,tx_completed_p_i,
                                                      s_rx_bytes_c)

  begin


    case control_st is

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      when idle                     =>

        if rx_fss_received_p_i = '1' then      -- FSS arrived
          nx_control_st <= id_dat_control_byte;

        else
          nx_control_st <= idle;
        end if;


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      when id_dat_control_byte      =>

        if s_session_timedout = '1' then       -- independent timeout
          nx_control_st <= idle;

        elsif (rx_byte_ready_p_i = '1') and (rx_byte_i(5 downto 0) = c_ID_DAT_CTRL_BYTE) then
          nx_control_st <= id_dat_var_byte;    -- check of ID_DAT Control byte

        elsif rx_byte_ready_p_i = '1' then
          nx_control_st <= idle;               -- byte different than the expected ID_DAT Control

        else
          nx_control_st <= id_dat_control_byte;-- ID_DAT Control byte being arriving
        end if;


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      when id_dat_var_byte          =>

        if s_session_timedout = '1' then       -- independent timeout
          nx_control_st <= idle;

        elsif (rx_byte_ready_p_i = '1') and (s_var_identified = '1') then
          nx_control_st <= id_dat_subs_byte;   -- check of the ID_DAT variable

        elsif rx_byte_ready_p_i = '1' then
          nx_control_st <= idle;               -- byte not corresponding to an expected variable

        else
          nx_control_st <= id_dat_var_byte;    -- ID_DAT variable byte being arriving
        end if;


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      when id_dat_subs_byte         =>

        if s_session_timedout = '1' then     -- independent timeout
          nx_control_st <= idle;

        elsif (rx_byte_ready_p_i = '1') and ((rx_byte_i = subs_i) or (s_broadcast_var = '1')) then
          nx_control_st <= id_dat_frame_ok;  -- check of the ID_DAT subscriber
                                             -- or if it is a broadcast variable
                                             -- note: broadcast consumed vars are only treated in
                                             -- memory mode, but at this moment we do not do this
                                             -- check as the var_rst which is broadcast is treated
                                             -- also in stand-alone mode.

        elsif rx_byte_ready_p_i = '1' then   -- not the station's address, neither a broadcast
          nx_control_st <= idle;

        else
          nx_control_st <= id_dat_subs_byte; -- ID_DAT subscriber byte being arriving
        end if;


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      when id_dat_frame_ok          =>

        if s_session_timedout = '1' then             -- independent timeout
          nx_control_st <= idle;

        elsif (rx_fss_crc_fes_ok_p_i = '1') and (s_prod_or_cons = "10") then
          nx_control_st <= produce_wait_turnar_time; -- ID_DAT frame ok! station has to produce

        elsif (rx_fss_crc_fes_ok_p_i = '1') and (s_prod_or_cons = "01") then
          nx_control_st <= consume_wait_FSS;         -- ID_DAT frame ok! station has to consume

        elsif (s_rx_bytes_c > 2)  then               -- 3 bytes after the arrival of the subscriber
          nx_control_st <= idle;                     -- byte, a FES has not been detected

        else
          nx_control_st <= id_dat_frame_ok;          -- CRC & FES bytes being arriving
        end if;


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      when produce_wait_turnar_time =>

        if s_session_timedout = '1' then             -- independent timeout
          nx_control_st <= idle;

        elsif s_time_c_is_zero = '1' then            -- turnaround time passed
          nx_control_st <= produce;

        else
          nx_control_st <= produce_wait_turnar_time; -- waiting for turnaround time to pass
        end if;


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      when consume_wait_FSS         =>

        if s_session_timedout = '1' then       -- independent timeout
          nx_control_st <= idle;

        elsif rx_fss_received_p_i = '1' then   -- FSS of the consumed RP_DAT arrived
          nx_control_st <= consume;

        elsif s_time_c_is_zero = '1' then      -- if the FSS of the consumed RP_DAT frame doesn't
          nx_control_st <= idle;               -- arrive before the expiration of the silence time,
                                               -- the engine goes back to idle
        else
          nx_control_st <= consume_wait_FSS;   -- counting silence time
        end if;


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      when consume                  =>

        if s_session_timedout = '1' then       -- independent timeout
          nx_control_st <= idle;

        elsif (rx_fss_crc_fes_ok_p_i = '1') or -- the cons frame arrived to the end, as expected
              (rx_crc_wrong_p_i = '1')      or -- FES detected but wrong CRC or wrong # bits
              (s_rx_bytes_c > 130)        then -- no FES detected after the max number of bytes

          nx_control_st <= idle;               -- back to idle

        else
          nx_control_st <= consume;            -- consuming bytes
        end if;


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      when produce                  =>

        if s_session_timedout = '1' then       -- independent timeout
          nx_control_st <= idle;

        elsif tx_completed_p_i = '1' then      -- end of production (including CRC and FES)
          nx_control_st <= idle;

        else
          nx_control_st <= produce;            -- producing bytes
        end if;


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      when others                   =>
          nx_control_st <= idle;
    end case;
  end process;

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Combinatorial process Engine_Control_FSM_Comb_Output_Signals : definition of the output
-- signals of the FSM

  Engine_Control_FSM_Comb_Output_Signals: process (control_st)
  begin

    case control_st is

      when idle =>

                 ---------------------------------
                  s_idle_state            <= '1';
                 ---------------------------------
                  s_id_dat_ctrl_byte      <= '0';
                  s_id_dat_var_byte       <= '0';
                  s_id_dat_frame_ok       <= '0';
                  s_prod_wait_turnar_time <= '0';
                  s_cons_wait_FSS         <= '0';
                  s_consuming             <= '0';
                  s_producing             <= '0';


      when id_dat_control_byte =>

                 s_idle_state            <= '0';
                 ---------------------------------
                  s_id_dat_ctrl_byte      <= '1';
                 ---------------------------------
                  s_id_dat_var_byte       <= '0';
                  s_id_dat_frame_ok       <= '0';
                  s_prod_wait_turnar_time <= '0';
                  s_cons_wait_FSS         <= '0';
                  s_consuming             <= '0';
                  s_producing             <= '0';


      when id_dat_var_byte =>

                  s_idle_state            <= '0';
                  s_id_dat_ctrl_byte      <= '0';
                 ---------------------------------
                  s_id_dat_var_byte       <= '1';
                 ---------------------------------
                  s_id_dat_frame_ok       <= '0';
                  s_prod_wait_turnar_time <= '0';
                  s_cons_wait_FSS         <= '0';
                  s_consuming             <= '0';
                  s_producing             <= '0';


      when id_dat_subs_byte =>

                  s_idle_state            <= '0';
                  s_id_dat_ctrl_byte      <= '0';
                  s_id_dat_var_byte       <= '0';
                  s_id_dat_frame_ok       <= '0';
                  s_prod_wait_turnar_time <= '0';
                  s_cons_wait_FSS         <= '0';
                  s_consuming             <= '0';
                  s_producing             <= '0';


      when id_dat_frame_ok =>

                  s_idle_state            <= '0';
                  s_id_dat_ctrl_byte      <= '0';
                  s_id_dat_var_byte       <= '0';
                 ---------------------------------
                  s_id_dat_frame_ok       <= '1';
                 ---------------------------------
                  s_prod_wait_turnar_time <= '0';
                  s_cons_wait_FSS         <= '0';
                  s_consuming             <= '0';
                  s_producing             <= '0';


      when produce_wait_turnar_time =>

                  s_idle_state            <= '0';
                  s_id_dat_ctrl_byte      <= '0';
                  s_id_dat_var_byte       <= '0';
                  s_id_dat_frame_ok       <= '0';
                 ---------------------------------
                  s_prod_wait_turnar_time <= '1';
                 ---------------------------------
                  s_cons_wait_FSS         <= '0';
                  s_consuming             <= '0';
                  s_producing             <= '0';


      when consume_wait_FSS =>

                  s_idle_state            <= '0';
                  s_id_dat_ctrl_byte      <= '0';
                  s_id_dat_var_byte       <= '0';
                  s_id_dat_frame_ok       <= '0';
                  s_prod_wait_turnar_time <= '0';
                 ---------------------------------
                  s_cons_wait_FSS         <= '1';
                 ---------------------------------
                  s_consuming             <= '0';
                  s_producing             <= '0';


      when consume =>

                  s_idle_state            <= '0';
                  s_id_dat_ctrl_byte      <= '0';
                  s_id_dat_var_byte       <= '0';
                  s_id_dat_frame_ok       <= '0';
                  s_prod_wait_turnar_time <= '0';
                  s_cons_wait_FSS         <= '0';
                 ---------------------------------
                  s_consuming             <= '1';
                 ---------------------------------
                  s_producing             <= '0';


      when produce =>

                  s_idle_state            <= '0';
                  s_id_dat_ctrl_byte      <= '0';
                  s_id_dat_var_byte       <= '0';
                  s_id_dat_frame_ok       <= '0';
                  s_prod_wait_turnar_time <= '0';
                  s_cons_wait_FSS         <= '0';
                  s_consuming             <= '0';
                 ---------------------------------
                  s_producing             <= '1';
                 ---------------------------------


      when others =>

                 ---------------------------------
                  s_idle_state            <= '1';
                 ---------------------------------
                  s_id_dat_ctrl_byte      <= '0';
                  s_id_dat_var_byte       <= '0';
                  s_id_dat_frame_ok       <= '0';
                  s_prod_wait_turnar_time <= '0';
                  s_cons_wait_FSS         <= '0';
                  s_consuming             <= '0';
                  s_producing             <= '0';

    end case;
  end process;



---------------------------------------------------------------------------------------------------
--                   Counters for the number of bytes being received or produced                 --
---------------------------------------------------------------------------------------------------

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Instantiation of the WF_prod_data_lgth_calc unit that calculates the amount of bytes that have
-- to be transmitted when a variable is produced; the RP_DAT.Control, RP_DAT.Data.MPS_status and
-- RP_DAT.Data.nanoFIP_status bytes are included; The FSS, CRC and FES bytes are not included!

  Produced_Data_Length_Calculator: WF_prod_data_lgth_calc
  port map (
    slone_i            => slone_i,
    nostat_i           => nostat_i,
    p3_lgth_i          => p3_lgth_i,
    var_i              => s_var,
    -------------------------------------------------------
    prod_data_lgth_o   => s_prod_data_lgth);
    -------------------------------------------------------

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Instantiation of a WF_incr_counter for the counting of the number of the bytes that are
-- being produced. The counter is reset at the "produce_wait_turnar_time" state of the FSM and
-- counts bytes following the "tx_byte_request_p_i" pulse in the "produce" state.

  Prod_Bytes_Counter: WF_incr_counter
  generic map (g_counter_lgth => 8)
  port map (
    uclk_i            => uclk_i,
    reinit_counter_i  => s_prod_bytes_c_rst,
    incr_counter_i    => s_prod_bytes_c_inc,
    counter_is_full_o => open,
    -------------------------------------------------------
    counter_o         => s_prod_bytes_c);
    -------------------------------------------------------

  --  --  --  --  --  --  --  --  --  --  --
  -- when s_prod_data_lgth bytes have been counted,the signal s_prod_data_lgth_match is activated
  s_prod_data_lgth_match <= '1' when s_prod_bytes_c = unsigned (s_prod_data_lgth) else '0';


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Instantiation of a WF_incr_counter for the counting of the number of bytes that are
-- being received. The same counter is used for the bytes of an ID_DAT frame or a consumed RP_DAT
-- frame (that is why the name of the counter is s_rx_bytes_c and not s_cons_bytes_c!)
-- Regarding an ID_DAT frame : the FSS, Control, var and SUBS bytes are being followed by the
-- Engine_Control_FSM; the counter is used for the counting of the bytes from then on and until
-- the arrival of a FES. Therefore, the counter is reset at the "id_dat_subs_byte" state and counts
-- bytes following the "rx_byte_ready_p_i" pulse in the "id_dat_frame_ok" state.
-- Regarding a RP_DAT frame  : the counter is reset at the "consume_wait_FSS" state and counts
-- bytes following the "rx_byte_ready_p_i" pulse in the "consume" state.

  Rx_Bytes_Counter: WF_incr_counter
  generic map (g_counter_lgth => 8)
  port map (
    uclk_i            => uclk_i,
    reinit_counter_i  => s_rx_bytes_c_rst,
    incr_counter_i    => s_rx_bytes_c_inc,
    counter_is_full_o => open,
    -------------------------------------------------------
    counter_o         => s_rx_bytes_c);
    -------------------------------------------------------

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Combinatorial process Inputs_for_Rx_and_Prod_Byte_Counters: The process gives values to
-- the signals reinit_counter_i and incr_counter_i of the Prod_Bytes_Counter and
-- Rx_Bytes_Counter according to the state of the FSM.

  Inputs_for_Rx_and_Prod_Byte_Counters: process (s_id_dat_frame_ok, s_consuming, tx_byte_request_p_i,
                                     s_producing, rx_byte_ready_p_i, s_rx_bytes_c, s_prod_bytes_c)
  begin

    if s_id_dat_frame_ok = '1' then
      s_prod_bytes_c_rst <= '1';
      s_prod_bytes_c_inc <= '0';
      s_prod_byte_index  <= (others => '0');

      s_rx_bytes_c_rst   <= '0';
      s_rx_bytes_c_inc   <= rx_byte_ready_p_i;
      s_rx_byte_index    <= (others => '0');


    elsif s_consuming = '1' then
      s_prod_bytes_c_rst <= '1';
      s_prod_bytes_c_inc <= '0';
      s_prod_byte_index  <= (others => '0');

      s_rx_bytes_c_rst   <= '0';
      s_rx_bytes_c_inc   <= rx_byte_ready_p_i;
      s_rx_byte_index    <= std_logic_vector (s_rx_bytes_c);


    elsif s_producing = '1' then
      s_rx_bytes_c_rst   <= '1';
      s_rx_bytes_c_inc   <= '0';
      s_rx_byte_index    <= (others => '0');

      s_prod_bytes_c_rst <= '0';
      s_prod_bytes_c_inc <= tx_byte_request_p_i;
      s_prod_byte_index  <= std_logic_vector (s_prod_bytes_c);


    else
      s_prod_bytes_c_rst <= '1';
      s_prod_bytes_c_inc <= '0';
      s_prod_byte_index  <= (others => '0');

      s_rx_bytes_c_rst   <= '1';
      s_rx_bytes_c_inc   <= '0';
      s_rx_byte_index    <= (others => '0');

    end if;
  end process;



---------------------------------------------------------------------------------------------------
--                                  Independant Timeout Counter                                  --
---------------------------------------------------------------------------------------------------

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Instantiation of a WF_decr_counter relying only on the system clock as an additional
-- way to go back to Idle state, in case any other logic is being stuck.

  Session_Timeout_Counter: WF_decr_counter
  generic map (g_counter_lgth => 21)
  port map (
    uclk_i            => uclk_i,
    nfip_rst_i        => nfip_rst_i,
    counter_top       => (others => '1'),
    counter_load_i    => s_idle_state,
    counter_decr_p_i  => '1', -- on each uclk tick
    counter_o         => open,
    ---------------------------------------------------
    counter_is_zero_o => s_session_timedout);
    ---------------------------------------------------



---------------------------------------------------------------------------------------------------
--                                   Turnaround & Silence times                                  --
---------------------------------------------------------------------------------------------------

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Instantiation of a WF_decr_counter for the counting of turnaround and silence times.
-- The same counter is used in both cases. The signal s_time_c_top initializes the counter
-- to either the turnaround or the silence time. If after the correct arrival of an ID_DAT frame
-- the identified variable is a produced one the counter loads to the turnaround time, whereas if
-- it had been a consumed variable it loads to the silence. The counting takes place during the
-- states "produce_wait_turnar_time" and "consume_wait_FSS" respectively.

  Turnaround_and_Silence_Time_Counter: WF_decr_counter
  generic map (g_counter_lgth => 18)
  port map (
    uclk_i            => uclk_i,
    nfip_rst_i        => nfip_rst_i,
    counter_top       => s_time_c_top,
    counter_load_i    => s_time_c_load,
    counter_decr_p_i  => '1', -- on each uclk tick
    counter_o         => open,
    -------------------------------------------------------
    counter_is_zero_o => s_time_c_is_zero);
    -------------------------------------------------------


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- retrieval of the turnaround and silence times (in equivalent number of uclk ticks) from the
-- c_TIMEOUTS_TABLE declared in the WF_package unit.

  s_turnaround_time <= to_unsigned((c_TIMEOUTS_TABLE(to_integer(unsigned(rate_i))).turnaround),
                                                                         s_turnaround_time'length);
  s_silence_time    <= to_unsigned((c_TIMEOUTS_TABLE(to_integer(unsigned(rate_i))).silence),
                                                                         s_turnaround_time'length);

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Combinatorial process Inputs_for_Turnaround_and_Silence_Time_Counter: The process gives values
-- to the counter_top_i and counter_load_i inputs of the Turnaround_and_Silence_Time_Counter,
-- according to the state of the FSM and the type of received variable (s_prod_or_cons).

  Inputs_for_Turnaround_and_Silence_Time_Counter: process (s_prod_wait_turnar_time, s_turnaround_time,
                                                    s_id_dat_frame_ok, s_prod_or_cons,
                                                    s_cons_wait_FSS, s_silence_time)
  begin

    if s_id_dat_frame_ok = '1' and s_prod_or_cons = "10" then
      s_time_c_load <= '1'; -- counter loads
      s_time_c_top  <= s_turnaround_time;

    elsif s_id_dat_frame_ok = '1' and s_prod_or_cons = "01" then
      s_time_c_load <= '1'; -- counter loads
      s_time_c_top  <= s_silence_time;

    elsif s_prod_wait_turnar_time = '1' then
      s_time_c_load <= '0'; -- counter counts
      s_time_c_top  <= s_silence_time;

    elsif s_cons_wait_FSS = '1' then
      s_time_c_load <= '0';  -- counter counts
      s_time_c_top  <= s_silence_time;

    else
      s_time_c_load <= '1';
      s_time_c_top  <= s_silence_time;

    end if;
  end process;



---------------------------------------------------------------------------------------------------
--                   Identification of the variable received by an ID_DAT frame                  --
---------------------------------------------------------------------------------------------------

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- The following process generates the signals:
--   o internal signal s_var_aux that locks to the value of the ID_DAT.Identifier.Variable byte
--     upon its arrival
--   o output signal var_o (or s_var, used also internally by the WF_prod_data_lgth_calc) that
--     locks to the value of the ID_DAT.Identifier.Variable byte at the end of the reception of a
--     valid ID_DAT frame, if the specified station address concerns the station.
--     For a produced var this takes place at the "produce_wait_turnar_time" state, and
--     for a consumed at the "consume" state (not in the "consume_wait_silence_time", as at this
--     state there is no knowledge that a consumed RP_DAT frame will indeed arrive).

  ID_DAT_var: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if nfip_rst_i = '1' then
        s_var_aux           <= var_whatever;
        s_var               <= var_whatever;
        s_prod_or_cons      <= "00";
        s_broadcast_var     <= '0';
      else

        -------------------------------------------------------------------------------------------
        if (s_idle_state = '1') or (s_id_dat_ctrl_byte = '1')  then    -- new frame initializations
          s_var_aux         <= var_whatever;
          s_var             <= var_whatever;
          s_prod_or_cons    <= "00";
          s_broadcast_var   <= '0';


        -------------------------------------------------------------------------------------------
        elsif (s_id_dat_var_byte = '1') and (rx_byte_ready_p_i = '1') then      -- var byte arrived

          --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
          if rx_byte_i = c_VARS_ARRAY(c_VAR_PRESENCE_INDEX).hexvalue then
            s_var_aux       <= var_presence;
            s_prod_or_cons  <= c_VARS_ARRAY(c_VAR_PRESENCE_INDEX).prod_or_cons;
            s_broadcast_var <= c_VARS_ARRAY(c_VAR_PRESENCE_INDEX).broadcast;

          --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
           elsif rx_byte_i = c_VARS_ARRAY(c_VAR_IDENTIF_INDEX).hexvalue then
             s_var_aux       <= var_identif;
             s_prod_or_cons  <= c_VARS_ARRAY(c_VAR_IDENTIF_INDEX).prod_or_cons;
             s_broadcast_var <= c_VARS_ARRAY(c_VAR_IDENTIF_INDEX).broadcast;

          --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
           elsif rx_byte_i = c_VARS_ARRAY(c_VAR_1_INDEX).hexvalue then
             s_var_aux       <= var_1;
             s_prod_or_cons  <= c_VARS_ARRAY(c_VAR_1_INDEX).prod_or_cons;
             s_broadcast_var <= c_VARS_ARRAY(c_VAR_1_INDEX).broadcast;

          --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
           elsif rx_byte_i = c_VARS_ARRAY(c_VAR_2_INDEX).hexvalue then
             s_var_aux       <= var_2;
             s_prod_or_cons  <= c_VARS_ARRAY(c_VAR_2_INDEX).prod_or_cons;
             s_broadcast_var <= c_VARS_ARRAY(c_VAR_2_INDEX).broadcast;

          --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
           elsif rx_byte_i = c_VARS_ARRAY(c_VAR_3_INDEX).hexvalue then
             s_var_aux       <= var_3;
             s_prod_or_cons  <= c_VARS_ARRAY(c_VAR_3_INDEX).prod_or_cons;
             s_broadcast_var <= c_VARS_ARRAY(c_VAR_3_INDEX).broadcast;

          --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
           elsif rx_byte_i = c_VARS_ARRAY(c_VAR_RST_INDEX).hexvalue then
             s_var_aux       <= var_rst;
             s_prod_or_cons  <= c_VARS_ARRAY(c_VAR_RST_INDEX).prod_or_cons;
             s_broadcast_var <= c_VARS_ARRAY(c_VAR_RST_INDEX).broadcast;

          --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
           elsif rx_byte_i = c_VARS_ARRAY(c_VAR_JC1_INDEX).hexvalue then
             s_var_aux       <= var_jc1;
             s_prod_or_cons  <= c_VARS_ARRAY(c_VAR_JC1_INDEX).prod_or_cons;
             s_broadcast_var <= c_VARS_ARRAY(c_VAR_JC1_INDEX).broadcast;

          --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
           elsif rx_byte_i = c_VARS_ARRAY(c_VAR_JC3_INDEX).hexvalue then
             s_var_aux       <= var_jc3;
             s_prod_or_cons  <= c_VARS_ARRAY(c_VAR_JC3_INDEX).prod_or_cons;
             s_broadcast_var <= c_VARS_ARRAY(c_VAR_JC3_INDEX).broadcast;

          --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
           else
             s_var_aux       <= var_whatever;
             s_prod_or_cons  <= "00";
             s_broadcast_var <= '0';
          end if;


        -------------------------------------------------------------------------------------------
        elsif (s_prod_wait_turnar_time = '1') or (s_consuming = '1') then             -- ID_DAT OK!

         s_var              <= s_var_aux;

        end if;
      end if;
    end if;
  end process;


--  --  --  --  --  --  --  --  --  --  --   --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Concurrent signal assignment (used by the FSM)

  s_var_identified <= '1' when rx_byte_i = c_VARS_ARRAY(c_VAR_PRESENCE_INDEX).hexvalue or
                               rx_byte_i = c_VARS_ARRAY(c_VAR_IDENTIF_INDEX).hexvalue  or
                               rx_byte_i = c_VARS_ARRAY(c_VAR_RST_INDEX).hexvalue      or
                               rx_byte_i = c_VARS_ARRAY(c_VAR_1_INDEX).hexvalue        or
                               rx_byte_i = c_VARS_ARRAY(c_VAR_2_INDEX).hexvalue        or
                               rx_byte_i = c_VARS_ARRAY(c_VAR_3_INDEX).hexvalue        or
                               rx_byte_i = c_VARS_ARRAY(c_VAR_JC1_INDEX).hexvalue      or
                               rx_byte_i = c_VARS_ARRAY(c_VAR_JC3_INDEX).hexvalue
                 else '0';



---------------------------------------------------------------------------------------------------
--                                       Introducing delays                                      --
---------------------------------------------------------------------------------------------------

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Registering the signals tx_last_data_byte_p_o, tx_byte_request_accept_p_o, tx_start_p_o

  process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if nfip_rst_i = '1' then
        tx_last_data_byte_p_o         <= '0';
        s_tx_last_data_byte_p_d       <= '0';
        s_tx_byte_request_accept_p_d1 <= '0';
        s_tx_byte_request_accept_p_d2 <= '0';
        s_tx_start_prod_p             <= '0';

      else
        s_tx_last_data_byte_p_d       <= s_tx_last_data_byte_p;
        tx_last_data_byte_p_o         <= s_tx_last_data_byte_p_d;
        s_tx_byte_request_accept_p_d1 <= s_tx_byte_request_accept_p;
        s_tx_byte_request_accept_p_d2 <= s_tx_byte_request_accept_p_d1;
        s_tx_start_prod_p             <= (s_prod_wait_turnar_time and s_time_c_is_zero);
      end if;
    end if;
  end process;

  s_tx_byte_request_accept_p <= s_producing and (tx_byte_request_p_i or s_tx_start_prod_p);
  s_tx_last_data_byte_p      <= s_producing and s_prod_data_lgth_match and tx_byte_request_p_i;


---------------------------------------------------------------------------------------------------
--                                 Concurrent Signal Assignments                                 --
---------------------------------------------------------------------------------------------------
-- variable received by a valid ID_DAT frame that concerns this station
  var_o                      <= s_var;

-- number of bytes of the Control & Data fields of a produced RP_DAT frame
  prod_data_lgth_o           <= s_prod_data_lgth;

-- response to WF_tx_serializer request for a byte
  tx_byte_request_accept_p_o <= s_tx_byte_request_accept_p_d2;

-- index of the byte being consumed or produced
  prod_cons_byte_index_o     <= s_prod_byte_index when s_producing = '1' else s_rx_byte_index;

-- The WF_rx_deserializer is reset if the number of bytes that have arrived exceeds the expected
-- one (ID_DAT >8 bytes and consumed RP_DAT > 133 bytes).
-- It also stays reset during a production session.
-- Note: the first 5 bytes of an ID_DAT and 2 bytes of an RP_DAT have been covered in the other
-- states of the Engine_Control_FSM and the s_rx_bytes_c starts counting from 0!
  rx_rst_o                   <= '1' when (s_id_dat_frame_ok = '1'and (s_rx_bytes_c > 2))   or 
                                         ((s_consuming = '1')    and (s_rx_bytes_c > 130)) or
                                         (s_prod_wait_turnar_time = '1' or s_producing = '1') else '0';

-- indication of a consumed RP_DAT frame with more than 133 bytes 
  cons_bytes_excess_o        <= '1' when (s_consuming = '1') and (s_rx_bytes_c > 130) else '0';

-- production starts after the expiration of the turnaround time
  tx_start_p_o               <= s_tx_start_prod_p;

---------------------------------------------------------------------------------------------------


end architecture rtl;

--=================================================================================================
--                                        architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------