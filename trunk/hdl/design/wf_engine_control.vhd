--_________________________________________________________________________________________________
--                                                                                                |
--                                        |The nanoFIP|                                           |
--                                                                                                |
--                                        CERN,BE/CO-HT                                           |
--________________________________________________________________________________________________|
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--! @file WF_engine_control.vhd                                                                  
---------------------------------------------------------------------------------------------------

--! Standard library
library IEEE;

--! Standard packages
use IEEE.STD_LOGIC_1164.all; --! std_logic definitions
use IEEE.NUMERIC_STD.all;    --! conversion functions

use work.WF_PACKAGE.all;     --! definitions of types, constants, entities


---------------------------------------------------------------------------------------------------  
--                                                                                               --
--                                        WF_engine_control                                      --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
--
--! @brief     The WF_engine_control is following the reception of an incoming ID_DAT frame and
--!              o identifies the variable to be treated
--!              o signals accordingly the WF_production and WF_consumption units.
--!            Its main output var_i is crucial for the units WF_cons_bytes_processor and
--!            WF_prod_bytes_retriever as it defines the structure of the frames that are expected
--!            to arrive or to be produced.
--!
--!            ------------------------------------------------------------------------------------
--!            Reminder
--!
--!            ID_DAT frame structure :
--!             ___________ ______  _______ ______  ___________ _______
--!            |____FSS____|_Ctrl_||__Var__|_Subs_||____FCS____|__FES__|
--! 
--!
--!            Produced RP_DAT frame structure :
--!             ___________ ______  _______ ______ _________________ _______ _______  ___________ _______
--!            |____FSS____|_Ctrl_||__PDU__|_LGTH_|__..User-Data..__|_nstat_|__MPS__||____FCS____|__FES__|
--!
--!
--!            Consumed RP_DAT frame structure :
--!             ___________ ______  _______ ______ _________________________ _______  ___________ _______
--!            |____FSS____|_Ctrl_||__PDU__|_LGTH_|______..Pure-Data..______|__MPS__||____FCS____|__FES__|
--!
--!
--!            Turnaround time : Time between the end of the reception of an ID_DAT frame
--!            requesting for a variable to be produced and the starting of the delivery of a
--!            produced RP_DAT frame
--!
--!            Silence time    : Maximum time that nanoFIP waits for a consumed RP_DAT frame after
--!            the reception of an ID_DAT frame indicating a variable to be consumed
--
--
--! @author    Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)\n
--!            Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)    \n
--
--
--! @date      15/01/2011
--
--
--! @version   v0.04
--
--
--! @details \n 
--
--!   \n<b>Dependencies:</b>\n
--
--
--!   \n<b>Modified by:</b>   \n
--!     Pablo Alvarez Sanchez \n
--!     Evangelia Gousiou     \n
--
---------------------------------------------------------------------------------------------------
--
--!   \n\n<b>Last changes:</b>\n
--!     07/2009  v0.01  EB  First version \n
--!     08/2010  v0.02  EG  E0 added as broadcast \n
--!                         PDU,length,ctrl bytes of RP_DAT checked bf VAR1_RDY/ var_2_rdy assertion;
--!                         if ID_DAT>8 bytes or RP_DAT>134 (bf reception of a FES) go to idle; 
--!                         state consume_wait_FSS, for the correct use of the silence time(time
--!                         stops counting when an RP_DAT frame has started)
--!                         
--!     12/2010  v0.02  EG  removed check on slone mode for #bytes>4;
--!                         in slone no broadcast
--!     01/2011  v0.03  EG  signals named according to their origin; signals removed....
--
---------------------------------------------------------------------------------------------------
--
--! @todo  -> add FES detection
--!
---------------------------------------------------------------------------------------------------

---/!\----------------------------/!\----------------------------/!\-------------------------/!\---
--                               Synplify Premier D-2009.12 Warnings                             --
-- -- --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --
--                                         No Warnings                                           --
---------------------------------------------------------------------------------------------------


--=================================================================================================
--!                          Entity declaration for WF_engine_control
--=================================================================================================
entity WF_engine_control is

  generic (c_QUARTZ_PERIOD : real);

  port (
  -- INPUTS 
    --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  -- 
    -- nanoFIP User Interface, General signals (synchronized with uclk) 
    uclk_i                  : in std_logic;                     --! 40MHz clock
    nostat_i                : in std_logic;                     --! if negated, nFIP status is sent
    slone_i                 : in std_logic;                     --! stand-alone mode

    -- nanoFIP WorldFIP Settings (synchronized with uclk) 
    p3_lgth_i               : in std_logic_vector (2 downto 0); --! produced var user-data length
    rate_i                  : in std_logic_vector (1 downto 0); --! WorldFIP bit rate
    subs_i                  : in std_logic_vector (7 downto 0); --! subscriber number coding

    --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  -- 
    -- Signal from the WF_reset_unit
    nfip_urst_i             : in std_logic;                     --! nanoFIP internal reset


    --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --  
    -- Signals from the WF_production
    
    -- Signal from the WF_tx_serializer unit
    tx_request_byte_p_i     : in std_logic;                     --! 


    --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --  
    -- Signals from the WF_consumption

    -- Signals from the WF_rx_deserializer unit
    rx_byte_i               : in std_logic_vector(7 downto 0);--!deserialized ID_DAT or RP_DAT byte
    rx_byte_ready_p_i       : in std_logic;                   --! indication of a new byte on rx_byte_i
    rx_fss_crc_fes_manch_ok_p_i  : in std_logic; --! indication of a frame (ID_DAT or RP_DAT) with
                                                 --! correct FSS, FES, CRC and manch. encoding
    rx_crc_wrong_p_i        : in std_logic; --! indication of a frame with a wrong CRC (pulse after FES arrival)
    rx_fss_received_p_i     : in std_logic; --! pulse after a correct FSS detection (ID/ RP_DAT)



  -------------------------------------------------------------------------------------------------
  -- OUTPUTS

    --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  -- 
    -- Signals to the WF_production

    -- Signal to the WF_tx_serializer unit
    tx_byte_ready_p_o       : out std_logic;--! 
    tx_last_byte_p_o        : out std_logic;--! indication that it is the last data-byte
    tx_start_prod_p_o       : out std_logic;--! launches the transmitters's FSM 

    -- Signal to the WF_prod_bytes_retriever
    prod_data_length_o      : out std_logic_vector (7 downto 0); --! # bytes of the Conrol & Data
                                                                 --! fields of a prod RP_DAT frame


    --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  -- 
    -- Signals to the WF_consumption

    -- Signal to the WF_rx_deserializer
    rst_rx_unit_p_o         : out std_logic;--!if an FES has not arrived after 8 bytes of an ID_DAT
                                            --! or after 134 bytes of an RP_DAT, the state machine
                                            --! of the WF_rx_deserializer unit returns to idle state 

    --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  -- 
    -- Signals to the WF_production & WF_consumption

    -- Signal to the WF_cons_bytes_processor, WF_prod_bytes_retriever
    prod_cons_byte_index_o  : out std_logic_vector (7 downto 0);


    --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  -- 
    -- Signals to the WF_production, WF_consumption, WF_reset_unit 

    -- Signal to the WF_cons_bytes_processor, WF_prod_bytes_retriever, WF_reset_unit
    var_o                   : out t_var      --! variable received by a valid ID_DAT frame
                                             --! that concerns this station 
    );
end entity WF_engine_control;



--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of WF_engine_control is


  type control_st_t  is (idle,
                         id_dat_control_byte, id_dat_var_byte, id_dat_subs_byte, id_dat_frame_ok,
                         consume, consume_wait_FSS,
                         produce_wait_turnar_time, produce);

  signal control_st, nx_control_st  : control_st_t;
  signal s_var_aux, s_var, s_var_id : t_var;

  signal s_time_c_is_zero, s_broadcast_var, s_tx_start_prod_p, s_inc_rx_bytes_counter  : std_logic;
  signal s_producing, s_consuming, s_rst_prod_bytes_counter, s_inc_prod_bytes_counter  : std_logic;
  signal s_idle_state, s_id_dat_ctrl_byte, s_id_dat_var_byte, s_cons_wait_FSS          : std_logic;
  signal s_prod_data_length_match, s_tx_byte_ready_p, s_prod_wait_turnar_time          : std_logic;
  signal s_tx_byte_ready_p_d1, s_load_time_counter, s_tx_byte_ready_p_d2               : std_logic;
  signal s_rst_rx_bytes_counter, s_tx_last_byte_p_d, s_tx_last_byte_p                  : std_logic;
  signal s_id_dat_subs_byte, s_id_dat_frame_ok                                         : std_logic;
  signal s_rx_bytes_c, s_prod_bytes_c                                      : unsigned (7 downto 0);
  signal s_time_counter_top, s_time_c, s_turnaround_time, s_silence_time   : unsigned(14 downto 0);
  signal s_prod_data_length, s_tx_byte_index, s_rx_byte_index      : std_logic_vector (7 downto 0);
  signal s_produce_or_consume                                      : std_logic_vector (1 downto 0);


--=================================================================================================
--                                      architecture begin
--=================================================================================================
begin

---------------------------------------------------------------------------------------------------
--                                      engine_control FSM                                       --
---------------------------------------------------------------------------------------------------

--!@brief central control FSM: the state machine is divided in three parts (a clocked process
--! to store the current state, a combinatorial process to manage state transitions and finally a
--! combinatorial process to manage the output signals), which are the three processes that follow.

--! The FSM starts in idle and expects from the WF_rx_deserializer to indicate the arrival of the
--! FSS of an ID_DAT. It continues by checking one by one the bytes of the ID_DAT as they arrive:
--! if the Control byte is the nominal,
--! if the variable byte corresponds to a defined variable,
--! if the subscriber byte matches the station's address, or if the variable is a broadcast
--! and if the ID_DAT frame has been characterised as a valid one (the WF_rx_deserializer sends
--! a dedicated pulse at the end of the FES if the CRC has been correct and there have been no
--! unexpected manch. code violations throughout the frame).
--! If the received variable is a produced (var_presence, var_identif, var_3) the FSM stays
--! in the "produce_wait_turnar_time" state until the expiration of the turnaround time and then
--! jumps to the "produce" state, waiting for the WF_serializer to send its last data-byte; then
--! it goes back to idle.
--! If the received variable is a consumed (var_1, var_2, var_rst) the FSM stays in the
--! "consume_wait_FSS" state until the arrival of a FSS or the expiration of the silence time.
--! After the arrival of a FSS the FSM jumps to the "consume" state, where it waits for the 
--! WF_rx_deserializer to receive a FES.

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
--!@brief Synchronous process Engine_Control_FSM_Sync: storage of the current state of the FSM 
  
  Engine_Control_FSM_Sync: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if nfip_urst_i = '1' then
        control_st <= idle;
      else
        control_st <= nx_control_st;
      end if;
    end if;
  end process;

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
--!@brief Combinatorial process Engine_Control_FSM_Comb_State_Transitions: definition of the state
--! transitions of the FSM.

  Engine_Control_FSM_Comb_State_Transitions: process (s_time_c_is_zero,s_produce_or_consume,subs_i, 
                                                      rx_fss_crc_fes_manch_ok_p_i, s_broadcast_var,
                                                      s_var_id, rx_byte_ready_p_i,rx_byte_i, 
                                                      control_st, rx_fss_received_p_i,
                                                      s_rx_bytes_c, s_tx_last_byte_p,
                                                      rx_crc_wrong_p_i)

  begin


    case control_st is

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
      when idle                     =>

        if rx_fss_received_p_i = '1' then      -- correct FSS arrived
          nx_control_st <= id_dat_control_byte;

        else
          nx_control_st <= idle;
        end if;

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
      when id_dat_control_byte      => 
        if (rx_byte_ready_p_i = '1') and (rx_byte_i = c_ID_DAT_CTRL_BYTE) then 
          nx_control_st <= id_dat_var_byte;    -- check of ID_DAT Control byte

        elsif (rx_byte_ready_p_i = '1') then
          nx_control_st <= idle;               -- byte different than the expected ID_DAT Control

        else
          nx_control_st <= id_dat_control_byte;-- ID_DAT Control byte being arriving
        end if;
        
      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
      when id_dat_var_byte          =>    
  
        if (rx_byte_ready_p_i = '1') and (s_var_id /= var_whatever) then
          nx_control_st <= id_dat_subs_byte; -- check of the ID_DAT variable

        elsif  (rx_byte_ready_p_i = '1') then
          nx_control_st <= idle;             -- byte not corresponding to an expected variable

        else
          nx_control_st <= id_dat_var_byte;  -- ID_DAT variable byte being arriving
        end if;

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --         
      when id_dat_subs_byte         =>    
  
        if (rx_byte_ready_p_i = '1') and (rx_byte_i = subs_i) then
          nx_control_st <= id_dat_frame_ok;  -- check of the ID_DAT subscriber..

        elsif (rx_byte_ready_p_i = '1') and (s_broadcast_var = '1') then-- 
          nx_control_st <= id_dat_frame_ok;  -- ..or if it is a broadcast variable
                                             -- note: broadcast consumed vars are only treated in
                                             -- memory mode, but at this moment we do not do this
                                             -- check as the var_rst which is broadcast is treated
                                             -- also in stand-alone mode.

        elsif (rx_byte_ready_p_i = '1') then -- not the station's address, neither a broadcast
          nx_control_st <= idle;

        else
          nx_control_st <= id_dat_subs_byte; -- ID_DAT subscriber byte being arriving
        end if;
        
      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
      when id_dat_frame_ok          =>

        if (rx_fss_crc_fes_manch_ok_p_i = '1') and (s_produce_or_consume = "10") then
          nx_control_st <= produce_wait_turnar_time; -- CRC & FES check ok! station has to produce 

        elsif (rx_fss_crc_fes_manch_ok_p_i = '1') and (s_produce_or_consume = "01") then
          nx_control_st <= consume_wait_FSS;         -- CRC & FES check ok! station has to consume

        elsif (s_rx_bytes_c > 2)  then               -- 3 bytes after the arrival of the subscriber
          nx_control_st <= idle;                     -- byte, a FES has not been detected
                                                     -- s_rx_bytes_c: starts counting at this state

        else
          nx_control_st <= id_dat_frame_ok;          -- CRC & FES bytes being arriving
        end if;


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
      when produce_wait_turnar_time =>

        if s_time_c_is_zero = '1' then              -- turnaround time passed
          nx_control_st <= produce;           

        else
          nx_control_st <= produce_wait_turnar_time;-- waiting for turnaround time to pass
        end if;


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
      when consume_wait_FSS         =>

        if rx_fss_received_p_i = '1' then   -- FSS of the consumed RP_DAT arrived
          nx_control_st <= consume;
 
        elsif s_time_c_is_zero = '1' then   -- if the FSS of the consumed RP_DAT frame doesn't 
          nx_control_st <= idle;            -- arrive before the expiration of the silence time,
                                            -- the engine goes back to idle
 
        else
          nx_control_st <= consume_wait_FSS;-- counting silence time  
        end if;      


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
      when consume                  =>

        if (rx_fss_crc_fes_manch_ok_p_i = '1') or-- the cons RP_DAT frame arrived to the end,as expected
           (rx_crc_wrong_p_i = '1') or      -- FES detected but wrong CRC or manch. encoding  
           (s_rx_bytes_c > 130)      then   -- no FES detected after the max number of bytes

          nx_control_st <= idle;            -- back to idle

        else
          nx_control_st <= consume;         -- consuming bytes
        end if;

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
      when produce                  =>

        if s_tx_last_byte_p = '1' then      -- last byte to be produced
          nx_control_st <= idle;

        else
          nx_control_st <= produce;         -- producing bytes
        end if;

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
      when others                   =>
          nx_control_st <= idle;
    end case;                         
  end process;

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
--!@brief Combinatorial process Engine_Control_FSM_Comb_Output_Signals : definition of the output
--! signals of the FSM

  Engine_Control_FSM_Comb_Output_Signals: process (control_st)
  begin

    case control_st is

      when idle =>
                  --------------------------------
                  s_idle_state            <= '1';
                  --------------------------------
                  s_id_dat_ctrl_byte      <= '0';
                  s_id_dat_var_byte       <= '0';
                  s_id_dat_subs_byte      <= '0';
                  s_id_dat_frame_ok       <= '0';
                  s_prod_wait_turnar_time <= '0';
                  s_cons_wait_FSS         <= '0';
                  s_consuming             <= '0';
                  s_producing             <= '0';


      when id_dat_control_byte =>
                  s_idle_state            <= '0';
                  -------------------------------- 
                  s_id_dat_ctrl_byte      <= '1';
                  --------------------------------
                  s_id_dat_var_byte       <= '0';
                  s_id_dat_subs_byte      <= '0';
                  s_id_dat_frame_ok       <= '0';
                  s_prod_wait_turnar_time <= '0';
                  s_cons_wait_FSS         <= '0';
                  s_consuming             <= '0';
                  s_producing             <= '0';

      when id_dat_var_byte => 
                  s_idle_state            <= '0';
                  s_id_dat_ctrl_byte      <= '0';
                  --------------------------------
                  s_id_dat_var_byte       <= '1';
                  --------------------------------
                  s_id_dat_subs_byte      <= '0';
                  s_id_dat_frame_ok       <= '0';
                  s_prod_wait_turnar_time <= '0';
                  s_cons_wait_FSS         <= '0';
                  s_consuming             <= '0';
                  s_producing             <= '0';

      when id_dat_subs_byte =>
                  s_idle_state            <= '0';
                  s_id_dat_ctrl_byte      <= '0';
                  s_id_dat_var_byte       <= '0';
                  --------------------------------
                  s_id_dat_subs_byte      <= '1';
                  --------------------------------
                  s_id_dat_frame_ok       <= '0';
                  s_prod_wait_turnar_time <= '0';
                  s_cons_wait_FSS         <= '0';
                  s_consuming             <= '0';
                  s_producing             <= '0';

      when id_dat_frame_ok => 
                  s_idle_state            <= '0';
                  s_id_dat_ctrl_byte      <= '0';
                  s_id_dat_var_byte       <= '0';
                  s_id_dat_subs_byte      <= '0';
                  --------------------------------
                  s_id_dat_frame_ok       <= '1';
                  --------------------------------
                  s_prod_wait_turnar_time <= '0';
                  s_cons_wait_FSS         <= '0';
                  s_consuming             <= '0';
                  s_producing             <= '0';

      when produce_wait_turnar_time =>  
                  s_idle_state            <= '0';
                  s_id_dat_ctrl_byte      <= '0';
                  s_id_dat_var_byte       <= '0';
                  s_id_dat_subs_byte      <= '0';
                  s_id_dat_frame_ok       <= '0';
                  --------------------------------
                  s_prod_wait_turnar_time <= '1';
                  --------------------------------
                  s_cons_wait_FSS         <= '0';
                  s_consuming             <= '0';
                  s_producing             <= '0';

      when consume_wait_FSS =>
                  s_idle_state            <= '0';
                  s_id_dat_ctrl_byte      <= '0';
                  s_id_dat_var_byte       <= '0';
                  s_id_dat_subs_byte      <= '0';
                  s_id_dat_frame_ok       <= '0';
                  s_prod_wait_turnar_time <= '0';
                  --------------------------------
                  s_cons_wait_FSS         <= '1';
                  --------------------------------
                  s_consuming             <= '0';
                  s_producing             <= '0';

      when consume =>
                  s_idle_state            <= '0';
                  s_id_dat_ctrl_byte      <= '0';
                  s_id_dat_var_byte       <= '0';
                  s_id_dat_subs_byte      <= '0';
                  s_id_dat_frame_ok       <= '0';
                  s_prod_wait_turnar_time <= '0';
                  s_cons_wait_FSS         <= '0';
                  --------------------------------
                  s_consuming             <= '1';
                  --------------------------------
                  s_producing             <= '0';

      when produce =>
                  s_idle_state            <= '0';
                  s_id_dat_ctrl_byte      <= '0';
                  s_id_dat_var_byte       <= '0';
                  s_id_dat_subs_byte      <= '0';
                  s_id_dat_frame_ok       <= '0';
                  s_prod_wait_turnar_time <= '0';
                  s_cons_wait_FSS         <= '0';
                  s_consuming             <= '0';
                  --------------------------------
                  s_producing             <= '1';
                  --------------------------------


      when others =>  
                  --------------------------------
                  s_idle_state            <= '1';
                  --------------------------------
                  s_id_dat_ctrl_byte      <= '0';
                  s_id_dat_var_byte       <= '0';
                  s_id_dat_subs_byte      <= '0';
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
--! @brief Instantiation of the WF_prod_data_lgth_calc unit that calculates the total amount of
--! data-bytes that have to be transferred when a variable is produced (including the
--! RP_DAT.Control, RP_DAT.Data.MPS_status and RP_DAT.Data.nanoFIP_status bytes).

  Produced_Data_Length_Calculator: WF_prod_data_lgth_calc
  port map(
    slone_i            => slone_i,             
    nostat_i           => nostat_i,
    p3_lgth_i          => p3_lgth_i,
    var_i              => s_var,
    -------------------------------------------------------
    prod_data_length_o => s_prod_data_length
    -------------------------------------------------------
      ); 

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
--! @brief Instantiation of a WF_incr_counter for the counting of the number of the bytes that are
--! being produced. The counter is reset at the "produce_wait_turnar_time" state of the FSM and
--! counts bytes following the "tx_request_byte_p_i" pulse in the "produce" state.

  Produced_Bytes_Counter: WF_incr_counter
  generic map(g_counter_lgth => 8)
  port map(
    uclk_i            => uclk_i,
    nfip_urst_i       => nfip_urst_i,
    reinit_counter_i  => s_rst_prod_bytes_counter,
    incr_counter_i    => s_inc_prod_bytes_counter,
    -------------------------------------------------------
    counter_o         => s_prod_bytes_c,
    counter_is_full_o => open  
    -------------------------------------------------------
      );

  --  --  --  --  --  --  --  --  --  --  -- 
  -- when s_prod_data_length bytes have been counted,the signal s_prod_data_length_match is activated
  s_prod_data_length_match <= '1' when s_prod_bytes_c = unsigned (s_prod_data_length) else '0';


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  
--! @brief Instantiation of a WF_incr_counter for the counting of the number of bytes that are
--! being received by the WF_rx_deserializer unit. The same counter is used for the bytes of an
--! ID_DAT frame or a consumed RP_DAT frame (that is why the name of the counter is s_rx_bytes_c
--! and not s_cons_bytes_c!)
--! Regarding an ID_DAT frame : the FSS,Control, var and subs bytes are being followed by the state
--! machine and the counter is used for the counting of the bytes from then on until the arrival
--! of a FES. Therefore, the counter is reset at the "id_dat_subs_byte" state and counts bytes
--! following the "rx_byte_ready_p_i" pulse in the "id_dat_frame_ok" state.
--! Regarding a RP_DAT frame  : the counter is reset at the "consume_wait_FSS" state and counts
--! bytes following the "rx_byte_ready_p_i" pulse in the "consume" state.

  Rx_Bytes_Counter: WF_incr_counter
  generic map(g_counter_lgth => 8)
  port map(
    uclk_i            => uclk_i,
    nfip_urst_i       => nfip_urst_i,
    reinit_counter_i  => s_rst_rx_bytes_counter,
    incr_counter_i    => s_inc_rx_bytes_counter,
    -------------------------------------------------------
    counter_o         => s_rx_bytes_c,
    counter_is_full_o => open
    -------------------------------------------------------
      );

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  
--! @brief Combinatorial process Arguments_For_Both_Bytes_Counters: The process gives values to
--! the signals reinit_counter_i and incr_counter_i of the Produced_Bytes_Counter and 
--! Rx_Bytes_Counter according to the state of the FSM.

  Arguments_For_Both_Bytes_Counters: process (s_id_dat_frame_ok, s_consuming, tx_request_byte_p_i,
                                     s_producing, rx_byte_ready_p_i, s_rx_bytes_c, s_prod_bytes_c)
  begin

    if s_id_dat_frame_ok = '1' then
      s_rst_prod_bytes_counter <= '1';
      s_inc_prod_bytes_counter <= '0';
      s_tx_byte_index          <= (others => '0');

      s_rst_rx_bytes_counter   <= '0';
      s_inc_rx_bytes_counter   <= rx_byte_ready_p_i;
      s_rx_byte_index          <= (others => '0');  
  

    elsif s_consuming = '1' then
      s_rst_prod_bytes_counter <= '1';
      s_inc_prod_bytes_counter <= '0';
      s_tx_byte_index          <= (others => '0');

      s_rst_rx_bytes_counter   <= '0';
      s_inc_rx_bytes_counter   <= rx_byte_ready_p_i;
      s_rx_byte_index          <= std_logic_vector (s_rx_bytes_c);


    elsif s_producing = '1' then
      s_rst_rx_bytes_counter   <= '1';
      s_inc_rx_bytes_counter   <= '0';
      s_rx_byte_index          <= (others => '0'); 

      s_rst_prod_bytes_counter <= '0';
      s_inc_prod_bytes_counter <= tx_request_byte_p_i;
      s_tx_byte_index          <= std_logic_vector (s_prod_bytes_c);


    else
      s_rst_prod_bytes_counter <= '1';
      s_inc_prod_bytes_counter <= '0';
      s_tx_byte_index          <= (others => '0');

      s_rst_rx_bytes_counter   <= '1';
      s_inc_rx_bytes_counter   <= '0';
      s_rx_byte_index          <= (others => '0'); 

    end if;
  end process;


---------------------------------------------------------------------------------------------------
--                                   Turnaround & Silence times                                  --
---------------------------------------------------------------------------------------------------

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
--! @brief Instantiation of a WF_decr_counter for the counting of turnaround and silence times.
--! The same counter is used in both cases. The signal s_time_counter_top initializes the counter
--! to either the turnaround or the silence time. If after the correct arrival of an ID_DAT frame
--! the identified variable is a produced one the counter loads to the turnaround time, whereas if
--! it had been a consumed variable it loads to the silence. The counting takes place during the
--! states "produce_wait_turnar_time" and "consume_wait_FSS" respectively.

  Turnaround_and_Silence_Time_Counter: WF_decr_counter
  generic map(g_counter_lgth => 15)
  port map(
    uclk_i            => uclk_i,
    nfip_urst_i       => nfip_urst_i,
    counter_top       => s_time_counter_top,
    counter_load_i    => s_load_time_counter,
    counter_decr_p_i  => '1', -- on each uclk tick
    counter_o         => s_time_c,
    -------------------------------------------------------
    counter_is_zero_o => s_time_c_is_zero
    -------------------------------------------------------
      );

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
-- retrieval of the turnaround and silence times (in equivalent number of uclk ticks) from the
-- c_TIMEOUTS_TABLE declared in the WF_package unit. 

  s_turnaround_time <= to_unsigned((c_TIMEOUTS_TABLE(to_integer(unsigned(rate_i))).turnaround),
                                                                         s_turnaround_time'length);
  s_silence_time    <= to_unsigned((c_TIMEOUTS_TABLE(to_integer(unsigned(rate_i))).silence),
                                                                         s_turnaround_time'length);

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
--! @brief Combinatorial process Turnaround_and_Silence_Time_Counter_Arg: The process gives values
--! to the counter_top and counter_load_i inputs of the Turnaround_and_Silence_Time_Counter,
--! according to the state of the FSM and the type of received variable (s_produce_or_consume).

  Turnaround_and_Silence_Time_Counter_Arg: process (s_prod_wait_turnar_time, s_turnaround_time,
                                                    s_id_dat_frame_ok, s_produce_or_consume,
                                                    s_cons_wait_FSS, s_silence_time)
  begin

    if s_id_dat_frame_ok = '1'  and s_produce_or_consume = "10" then
      s_load_time_counter <= '1'; -- counter loads
      s_time_counter_top  <= s_turnaround_time;

    elsif s_id_dat_frame_ok = '1'  and s_produce_or_consume = "01" then
      s_load_time_counter <= '1'; -- counter loads
      s_time_counter_top  <= s_silence_time;

    elsif s_prod_wait_turnar_time = '1' then
      s_load_time_counter <= '0'; -- counter counts
      s_time_counter_top  <= s_silence_time;

    elsif s_cons_wait_FSS = '1' then
      s_load_time_counter <= '0';  -- counter counts
      s_time_counter_top  <= s_silence_time;

    else
      s_load_time_counter <= '1';
      s_time_counter_top  <= s_silence_time;

    end if;
  end process;


---------------------------------------------------------------------------------------------------
--                    Identification of the variable received by an ID_DAT frame                 --
---------------------------------------------------------------------------------------------------

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
--! The following two processes: ID_DAT_var_identifier and ID_DAT_var manage the
--! signals s_var_id, s_var_aux and s_var. All of them are used to keep the value of the
--! ID_DAT.Identifier.Variable byte of the incoming ID_DAT frame, but change their value on
--! different moments:
--! s_var_id  : is constantly following the incoming byte rx_byte_i 
--! s_var_aux : locks to the value of s_var_id when the ID_DAT.Identifier.Variable byte
--!             is received (in "id_dat_var_byte" state when "rx_byte_ready_p_i" is activated)
--! s_var     : locks to the value of s_var_aux at the end of the ID_DAT frame if the frame has
--!             been correct and the specified station address concerns the station.
--!             For a produced var this takes place at the "produce_wait_turnar_time" state, and
--!             for a consumed at the "consume" state (not in the "consume_wait_silence_time", as
--!             at this state it is not sure that a consumed RP_DAT frame will finally arrive).      
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
  
  ID_DAT_var_identifier: process (rx_byte_i)
  begin
    s_var_id <= var_whatever;
    for I in c_VARS_ARRAY'range loop
      if rx_byte_i = c_VARS_ARRAY(I).hexvalue then
        s_var_id <= c_VARS_ARRAY(I).var;
        exit;
      end if;
    end loop;
  end process;

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 

  ID_DAT_var: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if nfip_urst_i = '1' then 
        s_var       <= var_whatever;
        s_var_aux   <= var_whatever;
      else
        
        if s_idle_state = '1' then 
          s_var_aux <= var_whatever; 

        elsif (s_id_dat_var_byte = '1') and (rx_byte_ready_p_i = '1') then
          s_var_aux <= s_var_id;
        end if;
        
        if s_idle_state = '1' then 
          s_var     <= var_whatever;

        elsif (s_prod_wait_turnar_time = '1') or (s_consuming = '1') then 
          s_var     <= s_var_aux; 
        end if;
      end if;
    end if;
  end process;

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
--!@brief: Combinatorial process Var_Characteristics: management of the signals
--! s_produce_or_consume and s_broadcast_var, according to the value of s_var_aux.

  Var_Characteristics: process (s_var_aux)
  begin
    s_produce_or_consume       <= "00";
    s_broadcast_var            <= '0';

    for I in c_VARS_ARRAY'range loop

      if s_var_aux = c_VARS_ARRAY(I).var then

        if c_VARS_ARRAY(I).response = produce then
          s_produce_or_consume <= "10";
        else
          s_produce_or_consume <= "01";
        end if;
        exit;
      end if;
    end loop;

    if  ((s_var_aux = var_2) or (s_var_aux = var_rst)) then
      s_broadcast_var          <= '1';
    end if;

  end process;


---------------------------------------------------------------------------------------------------
--                                       Introducing delays                                      --
---------------------------------------------------------------------------------------------------

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
--!@brief: Essential buffering of the signals tx_last_byte_p_o, tx_byte_ready_p_o,tx_start_prod_p_o

  process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if nfip_urst_i = '1' then
        tx_last_byte_p_o     <= '0';
        s_tx_last_byte_p_d   <= '0';
        s_tx_byte_ready_p_d1 <= '0';
        s_tx_byte_ready_p_d2 <= '0';
        s_tx_start_prod_p    <= '0';

      else
        s_tx_last_byte_p_d   <= s_tx_last_byte_p;
        tx_last_byte_p_o     <= s_tx_last_byte_p_d;
        s_tx_byte_ready_p_d1 <= s_tx_byte_ready_p;
        s_tx_byte_ready_p_d2 <= s_tx_byte_ready_p_d1;
        s_tx_start_prod_p    <= (s_prod_wait_turnar_time and s_time_c_is_zero);
      end if;
    end if;
  end process;

  s_tx_byte_ready_p   <= s_producing and (tx_request_byte_p_i or s_tx_start_prod_p);

  s_tx_last_byte_p    <= s_producing and s_prod_data_length_match and tx_request_byte_p_i;


---------------------------------------------------------------------------------------------------
--                                 Concurrent Signal Assignments                                 --
---------------------------------------------------------------------------------------------------
-- variable received by a valid ID_DAT frame that concerns this station 
  var_o                  <= s_var;

-- number of bytes of the Control & Data fields of a produced RP_DAT frame
  prod_data_length_o     <= s_prod_data_length;

--
  tx_byte_ready_p_o      <= s_tx_byte_ready_p_d2;

-- Index of the byte being consumed or produced
  prod_cons_byte_index_o <= s_tx_byte_index when s_producing = '1' else s_rx_byte_index;

-- If the WF_rx_deserializer continues receiving bytes when the engine_control is idle, it has to
-- be reset. This happens when the number of bytes that have arrived exceed the expected (ID_DAT >8
-- bytes and consumed RP_DAT > 130 bytes) 
  rst_rx_unit_p_o        <= s_idle_state and rx_byte_ready_p_i; 

-- Production starts after the expiration of the silence time
  tx_start_prod_p_o      <= s_tx_start_prod_p;
---------------------------------------------------------------------------------------------------


end architecture rtl;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------