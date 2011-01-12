---------------------------------------------------------------------------------------------------
--! @file WF_engine_control.vhd                                                                  
---------------------------------------------------------------------------------------------------

--! Standard library
library IEEE;

--! Standard packages
use IEEE.STD_LOGIC_1164.all; --! std_logic definitions
use IEEE.NUMERIC_STD.all;    --! conversion functions

use work.WF_PACKAGE.all;


---------------------------------------------------------------------------------------------------  
--                                                                                               --
--                                        WF_engine_control                                      --
--                                                                                               --
--                                         CERN, BE/CO/HT                                        --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
-- unit name   WF_control
--
--
--! @brief     Nanofip control unit. It treats variable production and consuptions requests and manage timeouts. \n
--!
--
--
--! @author    Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)
--!            Evangelia Gousiou (Evangelia.Gousiou@cern.ch)
--
--
--! @date 11/09/2009
--
--
--! @version v0.02
--
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
--!     Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)
--!     Evangelia Gousiou (Evangelia.Gousiou@cern.ch)
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
--!     01/2011  v0.03  EG  signals named according to their origin
--
---------------------------------------------------------------------------------------------------  
--
--! @todo 
--!
---------------------------------------------------------------------------------------------------  


--=================================================================================================
--!                          Entity declaration for WF_engine_control
--=================================================================================================
entity WF_engine_control is

  generic (c_QUARTZ_PERIOD : real);

  port (
  -- INPUTS 
    -- nanoFIP User Interface, General signals (synchronized with uclk) 
    uclk_i                  : in std_logic;                     --! 40MHz clock
    slone_i                 : in std_logic;                     --! stand-alone mode
    nostat_i                : in std_logic;                     --! no NanoFIP status transmission
    rate_i                  : in std_logic_vector (1 downto 0); --! WorldFIP bit rate
    subs_i                  : in std_logic_vector (7 downto 0); --! subscriber number coding
    p3_lgth_i               : in std_logic_vector (2 downto 0); --! produced variable data length

    -- Signal from the WF_reset_unit
    nfip_urst_i             : in std_logic;                     --! nanoFIP internal reset

    -- Signal from the wf_tx_serializer unit
    tx_request_byte_p_i     : in std_logic;                     --! 

    -- Signal from the wf_prod_bytes_retriever 
    prod_sending_mps_i      : in std_logic; --! indication than the MPS byte is being sent

    -- Signals from the wf_rx_deserializer unit
    rx_FSS_received_p_i     : in std_logic; --! correct FSS detected
    rx_byte_ready_p_i       : in std_logic; --! indication of a new byte on rx_byte_i 
    rx_byte_i               : in std_logic_vector (7 downto 0); --! deserialized byte
    rx_crc_fes_viol_ok_p_i  : in std_logic; --! indication of a correct CRC and FES reception
    rx_crc_wrong_p_i        : in std_logic; --! indication of a wrong CRC reception

    -- Signal from the wf_cons_bytes_processor  
    cons_ctrl_byte_i        : in std_logic_vector (7 downto 0); --! received Control byte
    cons_pdu_byte_i         : in std_logic_vector (7 downto 0); --! received PDU_TYPE byte          
    cons_lgth_byte_i        : in std_logic_vector (7 downto 0); --! received Length byte   
    cons_var_rst_byte_1_i   : in std_logic_vector (7 downto 0); --! 1st data byte of a received var_rst
    cons_var_rst_byte_2_i   : in std_logic_vector (7 downto 0); --! 2nd data byte of a received var_rst


  -- OUTPUTS
    -- nanoFIP User Interface, NON-WISHBONE nanoFIP outputs
    var1_rdy_o              : out std_logic;--! signals new data is received and can safely be read
    var2_rdy_o              : out std_logic;--! signals new data is received and can safely be read
    var3_rdy_o              : out std_logic;--! signals that data can safely be written

    -- Signal to the wf_tx_serializer unit
    tx_last_byte_p_o        : out std_logic;--! indication that it is the last data-byte
    tx_start_prod_p_o       : out std_logic;--! launches the transmitters's FSM 
    tx_byte_ready_p_o       : out std_logic;--! 

    -- Signal to the wf_rx_deserializer
    rst_rx_unit_p_o         : out std_logic;--!if an FES has not arrived after 8 bytes of an ID_DAT
                                            --! or after 134 bytes of an RP_DAT, the state machine
                                            --! of the wf_rx_deserializer unit returns to idle state 

    -- Signal to the wf_cons_bytes_processor, wf_prod_bytes_retriever, wf_reset_unit,
    -- wf_var_rdy_generator, wf_prod_data_lgth_calc, wf_cons_frame_validator 
    var_o                   : out t_var;

    -- Signal to the wf_cons_bytes_processor, wf_prod_bytes_retriever
    prod_cons_byte_index_o  : out std_logic_vector (7 downto 0);

    -- Signal to the wf_prod_bytes_retriever
    prod_data_length_o      : out std_logic_vector (7 downto 0); --! # bytes of the Conrol & Data
                                                                 --! fields of a prod RP_DAT frame


    -- Signal to the wf_cons_bytes_processor
    cons_byte_ready_p_o     : out std_logic;

    -- Signal to the WF_reset_unit
    assert_rston_p_o        : out std_logic; --! indicates that a var_rst with its 2nd data-byte
                                             --! containing the station's address has been
                                             --! correctly received

    rst_nfip_and_fd_p_o     : out std_logic; --! indicates that a var_rst with its 1st data-byte
                                             --! containing the station's address has been
                                             --! correctly received

    -- Signal to the WF_status_bytes_gen
    rst_status_bytes_o      : out std_logic; --! resets the nanoFIP and MPS status bytes 
    nfip_status_r_fcser_p_o : out std_logic; --! nanoFIP status byte, bit 5
    nfip_status_r_tler_o    : out std_logic  --! nanoFIP status byte, bit 4

    );
end entity WF_engine_control;



--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of WF_engine_control is


  type control_st_t  is (idle, id_dat_control_byte, id_dat_var_byte, id_dat_subs_byte,
                         id_dat_frame_ok, consume, consume_wait_FSS, produce_wait_turnar_time,
                         produce);

  signal control_st, nx_control_st  : control_st_t;
  signal s_var_aux, s_var, s_var_id : t_var;


  signal s_load_var, s_load_var_aux, s_tx_byte_ready_p_d1 :           std_logic;
  signal s_load_time_counter, s_tx_byte_ready_p_d2 :        std_logic;
  signal s_tx_start_prod_p :               std_logic;
  signal s_time_c_is_zero, s_broadcast_var :                           std_logic;
  signal s_inc_rx_bytes_counter, s_tx_last_byte_p :std_logic;
  signal s_prod_data_length_match, s_tx_byte_ready_p, s_cons_frame_ok_p :std_logic;
  signal s_rx_bytes_c, s_prod_bytes_c :  unsigned(7 downto 0);
  signal s_prod_data_length :      std_logic_vector(7 downto 0);
  signal s_time_counter_top, s_time_c:                                 unsigned(14 downto 0); 
  signal s_turnaround_time, s_silence_time :                             unsigned(14 downto 0);
  signal s_produce_or_consume :                                        std_logic_vector (1 downto 0);
  signal s_id_dat_subs_byte, s_id_dat_frame_ok : std_logic;
  signal s_idle_state, s_id_dat_ctrl_byte, s_id_dat_var_byte, s_cons_wait_FSS: std_logic;
  signal s_prod_wait_turnar_time, s_producing, s_consuming :                                  std_logic;
  signal s_rst_tx_bytes_counter, s_inc_tx_bytes_counter : std_logic;
  signal s_rst_rx_bytes_counter, s_tx_last_byte_p_d: std_logic;
  signal s_tx_byte_index, s_rx_byte_index :        std_logic_vector (7 downto 0);



--=================================================================================================
--                                      architecture begin
--=================================================================================================
begin

---------------------------------------------------------------------------------------------------
--                                      engine_control_FSM                                       --
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
--!@brief central control FSM: the state machine is divided in three parts (a clocked process
--! to store the current state, a combinatorial process to manage state transitions and finally a
--! combinatorial process to manage the output signals), which are the three processes that follow.
--! The unit, is 


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
--!@brief synchronous process Receiver_FSM_Sync: storage of the current state of the FSM 
  
  Central_Control_FSM_Sync: process (uclk_i)
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
--!@brief synchronous process Receiver_FSM_Sync: storage of the current state of the FSM 


  Central_Control_FSM_Comb_State_Transitions:process (control_st, rx_FSS_received_p_i, s_tx_last_byte_p,
                                                     s_var_id, rx_byte_ready_p_i,rx_byte_i, s_rx_bytes_c,
                                                     s_time_c_is_zero,s_produce_or_consume,subs_i, 
                                                     rx_crc_fes_viol_ok_p_i, s_broadcast_var)
  begin


    case control_st is

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
      when idle =>

        if rx_FSS_received_p_i = '1' then      -- correct FSS arrived
          nx_control_st <= id_dat_control_byte;

        else
          nx_control_st <= idle;
        end if;

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
      when id_dat_control_byte => 
        if (rx_byte_ready_p_i = '1') and (rx_byte_i = c_ID_DAT_CTRL_BYTE) then 
          nx_control_st <= id_dat_var_byte;    -- check of ID_DAT Control byte

        elsif (rx_byte_ready_p_i = '1') then
          nx_control_st <= idle;               -- byte different than the expected ID_DAT Control

        else
          nx_control_st <= id_dat_control_byte;-- byte being arriving
        end if;
        
      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
      when id_dat_var_byte =>    
  
        if (rx_byte_ready_p_i = '1') and (s_var_id /= var_whatever) then
          nx_control_st <= id_dat_subs_byte; -- check of the ID_DAT variable

        elsif  (rx_byte_ready_p_i = '1') then
          nx_control_st <= idle;             -- byte not corresponding to an expected variable

        else
          nx_control_st <= id_dat_var_byte;  -- byte being arriving
        end if;

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --         
      when id_dat_subs_byte =>    
  
        if (rx_byte_ready_p_i = '1') and (rx_byte_i = subs_i) then
          nx_control_st <= id_dat_frame_ok;  -- check of the ID_DAT subscriber

        elsif (rx_byte_ready_p_i = '1') and (s_broadcast_var = '1') then-- at this moment we do not
          nx_control_st <= id_dat_frame_ok;                             -- check if slone=1, as the
                                                                        -- rst var which is broad-
                                                                        -- cast is treaded in slone
        elsif (rx_byte_ready_p_i = '1') then -- not the station's address, neither a broadcast
          nx_control_st <= idle;

        else
          nx_control_st <= id_dat_subs_byte; -- byte being arriving
        end if;
        
      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
      when id_dat_frame_ok =>

        if (rx_crc_fes_viol_ok_p_i = '1') and (s_produce_or_consume = "10") then
          nx_control_st <= produce_wait_turnar_time; -- CRC & FES check ok! station has to produce 

        elsif (rx_crc_fes_viol_ok_p_i = '1') and (s_produce_or_consume = "01") then
          nx_control_st <= consume_wait_FSS;         -- CRC & FES check ok! station has to consume

        elsif (s_rx_bytes_c > 2)  then               -- 3 bytes after the arrival of the subscriber
          nx_control_st <= idle;                     -- byte, there has not been detected a FES
                                                     -- s_rx_bytes_c: starts counting at this state

        else
          nx_control_st <= id_dat_frame_ok;          -- bytes being arriving (CRC & FES)
        end if;


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
      when produce_wait_turnar_time =>

        if s_time_c_is_zero = '1' then              -- turnaround time passed
          nx_control_st <= produce;           

        else
          nx_control_st <= produce_wait_turnar_time;-- waiting for turnaround time to pass
        end if;


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
      when consume_wait_FSS =>

        if rx_FSS_received_p_i = '1' then    -- FSS of the consumed RP_DAT arrived
          nx_control_st <= consume;
 
        elsif s_time_c_is_zero = '1' then    -- if no consumed RP_DAT frame arrives after the 
          nx_control_st <= idle;             -- silence time, the engine goes back to idle
 
        else
          nx_control_st <= consume_wait_FSS; -- counting silence time  
        end if;      


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
      when consume =>

        if (rx_crc_fes_viol_ok_p_i = '1') or -- if the RP_DAT frame finishes as 
           (s_rx_bytes_c > 130) then         -- expected with a FES,
                                             -- or if no FES has arrived after the max
                                             -- number of bytes expected, the engine
          nx_control_st <= idle;             -- goes back to idle

        else
          nx_control_st <= consume;        -- consuming bytes
        end if;

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
      when produce =>

        if s_tx_last_byte_p = '1' then     -- last byte to be produced
          nx_control_st <= idle;

        else
          nx_control_st <= produce;        -- producing bytes
        end if;

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
      when others =>
          nx_control_st <= idle;
    end case;                         
  end process;

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
--!@brief synchronous process Central_Control_FSM_Comb_Output_Signals: 

  Central_Control_FSM_Comb_Output_Signals: process (control_st)
  begin

    case control_st is

      when idle =>
                  s_idle_state            <= '1';
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
                  s_id_dat_ctrl_byte      <= '1';
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
                  s_id_dat_var_byte       <= '1';
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
                  s_id_dat_subs_byte      <= '1';
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
                  s_id_dat_frame_ok       <= '1';
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
                  s_prod_wait_turnar_time <= '1';
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
                  s_cons_wait_FSS         <= '1';
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
                  s_consuming             <= '1';
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
                  s_producing             <= '1';


      when others =>  
                  s_idle_state            <= '1';
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
--              Validation of a consumed RP_DAT frame (FSS, Control, PDU_TYPE, Length,           --
--                     CRC, FES, Code Violations) and Generation of the signals                  -- 
--                                    VAR_RDY, R_TLER, R_FCSER                                   --
---------------------------------------------------------------------------------------------------

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
  Consumed_Frame_Validator: WF_cons_frame_validator
  port map(
    cons_ctrl_byte_i           => cons_ctrl_byte_i, 
    cons_pdu_byte_i            => cons_pdu_byte_i,    
    cons_lgth_byte_i           => cons_lgth_byte_i,
    rx_fss_crc_fes_viol_ok_p_i => rx_crc_fes_viol_ok_p_i,
    rx_crc_wrong_p_i           => rx_crc_wrong_p_i,
    var_i                      => s_var,
    rx_byte_index_i            => s_rx_bytes_c,
    ----------------------------------------------------
    nfip_status_r_fcser_p_o    => nfip_status_r_fcser_p_o,
    nfip_status_r_tler_o       => nfip_status_r_tler_o, 
    cons_frame_ok_p_o          => s_cons_frame_ok_p);
    ----------------------------------------------------

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
 VAR_RDY_Signals_Generation: WF_var_rdy_generator
  port map (
    uclk_i                => uclk_i,
    slone_i               => slone_i,
    subs_i                => subs_i,
    nfip_urst_i           => nfip_urst_i, 
    cons_frame_ok_p_i     => s_cons_frame_ok_p,
    var_i                 => s_var,
    cons_var_rst_byte_1_i => cons_var_rst_byte_1_i,
    cons_var_rst_byte_2_i => cons_var_rst_byte_2_i,
    --------------------------------------------
    var1_rdy_o            => var1_rdy_o,
    var2_rdy_o            => var2_rdy_o,
    var3_rdy_o            => var3_rdy_o,
    assert_rston_p_o      => assert_rston_p_o,
    rst_nfip_and_fd_p_o   => rst_nfip_and_fd_p_o
    ---------------------------------------
      );



---------------------------------------------------------------------------------------------------
--                       Counters for the number of bytes being received or produced             --
---------------------------------------------------------------------------------------------------

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
  Produced_Data_Length_Calculator: WF_prod_data_lgth_calc
  port map(
    slone_i            => slone_i,             
    nostat_i           => nostat_i,
    p3_lgth_i          => p3_lgth_i,
    var_i              => s_var,
    ------------------------------------
    prod_data_length_o => s_prod_data_length
    ------------------------------------ 
      ); 

  --  --  --  --  --  --  --  --  --  --  -- 
  prod_data_length_o   <= s_prod_data_length;


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
--!@brief Counter that counts the number of produced bytes 
  Produced_Bytes_Counter: WF_incr_counter
  generic map(g_counter_lgth => 8)
  port map(
    uclk_i            => uclk_i,
    nfip_urst_i       => nfip_urst_i,
    reinit_counter_i  => s_rst_tx_bytes_counter,
    incr_counter_i    => s_inc_tx_bytes_counter,
    ---------------------------------------------
    counter_o         => s_prod_bytes_c,
    counter_is_full_o => open  
    ---------------------------------------------
      );

  --  --  --  --  --  --  --  --  --  --  -- 
  -- when s_prod_data_length bytes have been counted,the signal s_prod_data_length_match is activated
  s_prod_data_length_match <= '1' when s_prod_bytes_c = unsigned (s_prod_data_length) else '0';


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  
--!@brief Counter that counts the number of bytes being received by the wf_rx_deserializer unit.
--! The same counter is used for the bytes of an ID_DAT frame or a consumed RP_DAT frame
--! (that is why the name of the counter is s_rx_bytes_c and not s_cons_bytes_c).
  Rx_Bytes_Counter: WF_incr_counter
  generic map(g_counter_lgth => 8)
  port map(
    uclk_i            => uclk_i,
    nfip_urst_i       => nfip_urst_i,
    reinit_counter_i  => s_rst_rx_bytes_counter,
    incr_counter_i    => s_inc_rx_bytes_counter,
    ---------------------------------------------
    counter_o         => s_rx_bytes_c,
    counter_is_full_o => open
    ---------------------------------------------
      );


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  Arguments_For_Both_Bytes_Counters: process (s_id_dat_frame_ok, s_consuming, tx_request_byte_p_i,
                                     s_producing, rx_byte_ready_p_i, s_rx_bytes_c, s_prod_bytes_c)
  begin

    if s_id_dat_frame_ok = '1' then
      s_rst_rx_bytes_counter <= '0';
      s_inc_rx_bytes_counter <= rx_byte_ready_p_i;
      s_rx_byte_index        <= (others => '0');  

      s_rst_tx_bytes_counter <= '1';
      s_inc_tx_bytes_counter <= '0';
      s_tx_byte_index        <= (others => '0');
  

    elsif s_consuming = '1' then
      s_rst_rx_bytes_counter <= '0';
      s_inc_rx_bytes_counter <= rx_byte_ready_p_i;
      s_rx_byte_index        <= std_logic_vector (resize(s_rx_bytes_c,s_rx_byte_index'length));

      s_rst_tx_bytes_counter <= '1';
      s_inc_tx_bytes_counter <= '0';
      s_tx_byte_index        <= (others => '0');

    elsif s_producing = '1' then
      s_rst_tx_bytes_counter <= '0';
      s_inc_tx_bytes_counter <= tx_request_byte_p_i;
      s_tx_byte_index        <= std_logic_vector (resize(s_prod_bytes_c, s_tx_byte_index'length));

      s_rst_rx_bytes_counter <= '1';
      s_inc_rx_bytes_counter <= '0';
      s_rx_byte_index        <= (others => '0'); 

    else
      s_rst_rx_bytes_counter <= '1';
      s_inc_rx_bytes_counter <= '0';
      s_rx_byte_index        <= (others => '0'); 
      s_rst_tx_bytes_counter <= '1';
      s_inc_tx_bytes_counter <= '0';
      s_tx_byte_index        <= (others => '0');
    end if;
  end process;

  prod_cons_byte_index_o     <= s_tx_byte_index when s_producing = '1'
                           else s_rx_byte_index;



---------------------------------------------------------------------------------------------------
--                                    Turnaround & Silence times                                 --
---------------------------------------------------------------------------------------------------

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Managing the counter that counts either turnaround or silence times in uclk ticks.
-- The same counter is used in both cases. The signal s_time_counter_top initializes the counter
-- to either the turnaround or the silence time.
  Turnaround_and_Silence_Time_Counter: WF_decr_counter
  generic map(g_counter_lgth => 15)
  port map(
    uclk_i            => uclk_i,
    nfip_urst_i       => nfip_urst_i,
    counter_top       => s_time_counter_top,
    counter_load_i    => s_load_time_counter,
    counter_decr_p_i  => '1',
    counter_o         => s_time_c,
    ---------------------------------------
    counter_is_zero_o => s_time_c_is_zero
    ---------------------------------------
      );

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
-- retrieval of the turnaround and silence times (in equivalent number of uclk ticks) from the
-- c_TIMEOUTS_TABLE declared in the WF_package unit. 

  s_turnaround_time <= to_unsigned((c_TIMEOUTS_TABLE(to_integer(unsigned(rate_i))).turnaround),
                                                                           s_turnaround_time'length);
  s_silence_time <= to_unsigned((c_TIMEOUTS_TABLE(to_integer(unsigned(rate_i))).silence),
                                                                           s_turnaround_time'length);

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
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
--                    Recognition of the Identifier field of a received ID_DAT frame             --
---------------------------------------------------------------------------------------------------
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
--! The following two processes: id_dat_var_identifier and id_dat_var manage the
--! signals s_var_id, s_var_aux and s_var. All of them are used to keep the value of the
--! ID_DAT.Identifier.Variable byte of the incoming ID_DAT frame, but change their value on
--! different moments:
--! s_var_id  : is constantly following the incoming byte rx_byte_i 
--! s_var_aux : locks to the value of s_var_id when the ID_DAT.Identifier.Variable byte
--! is received (s_load_var_aux = 1)
--! s_var     : locks to the value of s_var_aux at the end of the ID_DAT frame (s_load_var = 1) if 
--! the specified station address matches the SUBS configuration.
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
  
  id_dat_var_identifier: process (rx_byte_i)
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
  s_load_var_aux <= s_id_dat_var_byte and rx_byte_ready_p_i;  
  s_load_var     <= s_prod_wait_turnar_time or s_consuming;
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 

  id_dat_var: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if nfip_urst_i = '1' then 
        s_var       <= var_whatever;
        s_var_aux   <= var_whatever;
      else
        
        if s_idle_state = '1' then 
          s_var_aux <= var_whatever; 

        elsif s_load_var_aux = '1' then
          s_var_aux <= s_var_id;
        end if;
        
        if s_idle_state = '1' then 
          s_var     <= var_whatever;

        elsif s_load_var = '1' then
          s_var     <= s_var_aux;
        end if;
      end if;
    end if;
  end process;

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 

  var_o <= s_var; -- var_o takes a value at the end of the ID_DAT


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
--!@brief: Combinatorial process Var_Characteristics: managment of the signals
--! s_produce_or_consume and s_broadcast_var, accroding to the value of s_var_aux.

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
--                                          Introducing delays                                   --
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
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --   
   
  tx_start_prod_p_o       <= s_tx_start_prod_p;

  s_tx_byte_ready_p       <= s_producing and (tx_request_byte_p_i or s_tx_start_prod_p);

  tx_byte_ready_p_o       <= s_tx_byte_ready_p_d2;

  s_tx_last_byte_p        <= s_producing and s_prod_data_length_match and tx_request_byte_p_i;
  rst_status_bytes_o      <= s_producing and s_tx_byte_ready_p_d2 and prod_sending_mps_i;

  cons_byte_ready_p_o     <= s_consuming and rx_byte_ready_p_i;

  rst_rx_unit_p_o         <= s_idle_state and rx_byte_ready_p_i;
---------------------------------------------------------------------------------------------------


end architecture rtl;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------