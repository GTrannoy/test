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
--! @author    Pablo Alvarez Sanchez (pablo.alvarez.sanchez@cern.ch)
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
--!                         PDU,length,ctrl bytes of rp_dat checked bf VAR1_RDY/ var_2_rdy assertion
--!                         if id_dat>8 bytes or rp_dat>134 (bf reception of a FES) go to idle 
--!                         state consume_wait_FSS, for the correct use of the silence time(time not
--!                         counting when an rp_dat frame has started)
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

  generic( C_QUARTZ_PERIOD : real);

  port (
  -- INPUTS 
    -- User Interface general signals (synchronized) 
    uclk_i :                 in std_logic;                    --! 40MHz clock
    slone_i :                in std_logic;                    --! Stand-alone mode
    nostat_i :               in std_logic;                    --! no NanoFIP status transmission
    rate_i :                 in std_logic_vector (1 downto 0); --! Worldfip bit rate
    subs_i :                 in std_logic_vector (7 downto 0); --! Subscriber number coding.
    p3_lgth_i :              in std_logic_vector (2 downto 0); --! Produced variable data length

    -- Signal from the WF_reset_unit unit
    nFIP_urst_i :            in std_logic;                    --! internal reset

    -- Signal from the WF_tx unit
    tx_request_byte_p_i :    in std_logic;                    --!

    -- Signals from the WF_rx unit
    rx_FSS_received_p_i :    in std_logic;                      --! correct FSS detected by WF_rx 
    rx_byte_ready_p_i :      in std_logic;                      --! new byte from the receiver on rx_byte_i
    rx_byte_i :              in std_logic_vector (7 downto 0);  -- Decoded byte
    rx_CRC_FES_ok_p_i :      in std_logic;   

    -- Signal from the WF_prod_bytes_to_tx 
    tx_sending_mps_i :       in std_logic;

    -- Signal from the WF_prod_bytes_to_tx  
    rx_Ctrl_byte_i :        in std_logic_vector (7 downto 0);
    rx_PDU_byte_i :         in std_logic_vector (7 downto 0);           
    rx_Length_byte_i :      in std_logic_vector (7 downto 0);    
    rx_var_rst_byte_1_i :   in std_logic_vector (7 downto 0);
    rx_var_rst_byte_2_i :   in std_logic_vector (7 downto 0);

  -- OUTPUTS
    -- User interface, non-WISHBONE nanoFIP outputs
    var1_rdy_o :            out std_logic; --! signals new data received and can safely be read
    var2_rdy_o :            out std_logic; --! signals new data received and can safely be read
    var3_rdy_o :            out std_logic; --! signals that data can safely be written in the memory

    -- Outputs to the WF_tx unit
    tx_last_byte_p_o :      out std_logic;
    tx_start_produce_p_o :  out std_logic;

    -- Output to WF_rx
    rst_rx_unit_p_o :     out std_logic;--! if an FES has not arrived after 8 bytes of an id_dat,
                                          --! or after 134 bytes of an rp_dat, the state machine
                                          --! of the WF_rx unit returns to idle state 

    -- Output to WF_concumed_vars and WF_prod_bytes_to_tx 
    var_o :                 out t_var;
    tx_rx_byte_index_o :    out std_logic_vector (7 downto 0);

    -- Output to WF_prod_bytes_to_tx
    tx_data_length_o :      out std_logic_vector (7 downto 0);

    -- Output to WF_tx
    tx_byte_ready_p_o :     out std_logic;

    -- output to WF_cons_bytes_from_rx
    rx_byte_ready_p_o :     out std_logic;

    -- Output to WF_reset_unit
    assert_RSTON_p_o :       out std_logic;
    rst_nFIP_and_FD_p_o : out std_logic;

    -- output to the WF_status_bytes_gen
    rst_status_bytes_o :  out std_logic

    );
end entity WF_engine_control;



--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of WF_engine_control is


  type control_st_t  is (idle, id_dat_control_byte, id_dat_var_byte, id_dat_subs_byte, consume, consume_wait_FSS,
                         id_dat_frame_ok, produce_wait_respon_time, cont_w_cons_watchdog, produce);

  signal control_st, nx_control_st : control_st_t;
  signal s_var_aux, s_var, s_var_id : t_var;


  signal s_load_var, s_load_var_aux, s_tx_byte_ready_p_d1 :           std_logic;
  signal s_load_time_c, s_tx_byte_ready_p_d2 :        std_logic;
  signal s_tx_start_prod_p :               std_logic;
  signal s_time_c_is_zero, s_broadcast_var :                           std_logic;
  signal s_inc_rx_bytes_counter, s_tx_last_byte_p :std_logic;
  signal s_tx_data_length_match, s_tx_byte_ready_p, s_cons_frame_ok_p :std_logic;
  signal s_rx_bytes_c, s_tx_bytes_c :  unsigned(7 downto 0);
  signal s_tx_data_length :      std_logic_vector(7 downto 0);
  signal s_time_counter_top, s_time_c:                                 unsigned(14 downto 0); 
  signal s_response_time, s_silence_time :                             unsigned(14 downto 0);
  signal s_produce_or_consume :                                        std_logic_vector (1 downto 0);
  signal s_id_dat_subs_byte, s_id_dat_frame_ok : std_logic;
  signal s_idle_state, s_id_dat_ctrl_byte, s_id_dat_var_byte, s_cons_wait_FSS: std_logic;
  signal s_prod_wait_resp_time, s_producing, s_consuming :                                  std_logic;
  signal s_rst_tx_bytes_counter, s_inc_tx_bytes_counter : std_logic;
  signal s_rst_rx_bytes_counter, s_tx_last_byte_p_d: std_logic;
  signal s_tx_byte_index, s_rx_byte_index :        std_logic_vector (7 downto 0);



--=================================================================================================
--                                      architecture begin
--=================================================================================================
begin

---------------------------------------------------------------------------------------------------
--!@brief central control FSM: the state machine is divided in three parts (a clocked process
--! to store the current state, a combinatorial process to manage state transitions and finally a
--! combinatorial process to manage the output signals), which are the three processes that follow.
--! The unit, is 


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
--!@brief synchronous process Receiver_FSM_Sync: storage of the current state of the FSM 
  
  Central_Control_FSM_Sync: process(uclk_i)
  begin
    if rising_edge(uclk_i) then
      if nFIP_urst_i = '1' then
        control_st <= idle;
      else
        control_st <= nx_control_st;
      end if;
    end if;
  end process;


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
--!@brief synchronous process Receiver_FSM_Sync: storage of the current state of the FSM 


  Central_Control_FSM_Comb_State_Transitions:process (control_st, rx_FSS_received_p_i, s_tx_last_byte_p,
                                                     s_var_id, rx_byte_ready_p_i,rx_byte_i, subs_i,
                                                     s_time_c_is_zero,s_produce_or_consume, slone_i,
                                                     rx_CRC_FES_ok_p_i, s_broadcast_var, s_rx_bytes_c)
  begin


    case control_st is

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
      when idle =>

        if rx_FSS_received_p_i = '1' then -- notification from the receiver that a correct FSS field has been received
          nx_control_st <= id_dat_control_byte;

        else
          nx_control_st <= idle;
        end if;

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
      when id_dat_control_byte => 
        if (rx_byte_ready_p_i = '1') and (rx_byte_i = c_ID_DAT_CTRL_BYTE) then
          nx_control_st <= id_dat_var_byte;

        elsif (rx_byte_ready_p_i = '1') then
          nx_control_st <= idle;

        else
          nx_control_st <= id_dat_control_byte;
        end if;
        
      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
      when id_dat_var_byte =>    
  
        if (rx_byte_ready_p_i = '1') and (s_var_id /= var_whatever) then
          nx_control_st <= id_dat_subs_byte;

        elsif  (rx_byte_ready_p_i = '1') then
          nx_control_st <= idle;

        else
          nx_control_st <= id_dat_var_byte;
        end if;

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --         
      when id_dat_subs_byte =>    
  
        if (rx_byte_ready_p_i = '1') and (rx_byte_i = subs_i) then
          nx_control_st <= id_dat_frame_ok;

        elsif (rx_byte_ready_p_i = '1') and (s_broadcast_var = '1') then
          nx_control_st <= id_dat_frame_ok;

        elsif (rx_byte_ready_p_i = '1') then
          nx_control_st <= idle;

        else
          nx_control_st <= id_dat_subs_byte;
        end if;
        
      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
      when id_dat_frame_ok =>

        if (rx_CRC_FES_ok_p_i = '1') and (s_produce_or_consume = "10") then
          nx_control_st <= produce_wait_respon_time;

        elsif (rx_CRC_FES_ok_p_i = '1') and (s_produce_or_consume = "01") then
          nx_control_st <= consume_wait_FSS;

        elsif (rx_CRC_FES_ok_p_i = '1') and (s_rx_bytes_c > 2)  then
          nx_control_st <= idle;

        else
          nx_control_st <= id_dat_frame_ok;
        end if;


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
      when produce_wait_respon_time =>

        if s_time_c_is_zero = '1' then
          nx_control_st <= produce;

        else
          nx_control_st <= produce_wait_respon_time;
        end if;


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
      when consume_wait_FSS =>

        if rx_FSS_received_p_i = '1' then
          nx_control_st <= consume;
 
        elsif s_time_c_is_zero = '1' then
          nx_control_st <= idle;
 
        else
          nx_control_st <= consume_wait_FSS;  
        end if;      


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
      when consume =>

        if (rx_CRC_FES_ok_p_i = '1')  or                   -- if the rp_dat frame finishes as 
           (s_rx_bytes_c > 130 and slone_i = '0') or    -- expected with a FES, or if no rp_dat 
           (s_rx_bytes_c > 4   and slone_i = '1') then  -- arrives after the silence_time, or
                                                           -- if no FES has arrived after the max
                                                           -- number of bytes expected, the engine
          nx_control_st <= idle;                           -- goes back to idle state

        else
          nx_control_st <= consume;
        end if;

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
      when produce =>

        if s_tx_last_byte_p = '1' then
          nx_control_st <= idle;

        else
          nx_control_st <= produce;
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
                  s_idle_state          <= '1';
                  s_id_dat_ctrl_byte    <= '0';
                  s_id_dat_var_byte     <= '0';
                  s_id_dat_subs_byte    <= '0';
                  s_id_dat_frame_ok     <= '0';
                  s_prod_wait_resp_time <= '0';
                  s_cons_wait_FSS       <= '0';
                  s_consuming           <= '0';
                  s_producing           <= '0';


      when id_dat_control_byte =>
                  s_idle_state          <= '0';
                  s_id_dat_ctrl_byte    <= '1';
                  s_id_dat_var_byte     <= '0';
                  s_id_dat_subs_byte    <= '0';
                  s_id_dat_frame_ok     <= '0';
                  s_prod_wait_resp_time <= '0';
                  s_cons_wait_FSS       <= '0';
                  s_consuming           <= '0';
                  s_producing           <= '0';

      when id_dat_var_byte => 
                  s_idle_state          <= '0';
                  s_id_dat_ctrl_byte    <= '0';
                  s_id_dat_var_byte     <= '1';
                  s_id_dat_subs_byte    <= '0';
                  s_id_dat_frame_ok     <= '0';
                  s_prod_wait_resp_time <= '0';
                  s_cons_wait_FSS       <= '0';
                  s_consuming           <= '0';
                  s_producing           <= '0';

      when id_dat_subs_byte =>
                  s_idle_state          <= '0';
                  s_id_dat_ctrl_byte    <= '0';
                  s_id_dat_var_byte     <= '0';
                  s_id_dat_subs_byte    <= '1';
                  s_id_dat_frame_ok     <= '0';
                  s_prod_wait_resp_time <= '0';
                  s_cons_wait_FSS       <= '0';
                  s_consuming           <= '0';
                  s_producing           <= '0';

      when id_dat_frame_ok => 
                  s_idle_state          <= '0';
                  s_id_dat_ctrl_byte    <= '0';
                  s_id_dat_var_byte     <= '0';
                  s_id_dat_subs_byte    <= '0';
                  s_id_dat_frame_ok     <= '1';
                  s_prod_wait_resp_time <= '0';
                  s_cons_wait_FSS       <= '0';
                  s_consuming           <= '0';
                  s_producing           <= '0';

      when produce_wait_respon_time =>  
                  s_idle_state          <= '0';
                  s_id_dat_ctrl_byte    <= '0';
                  s_id_dat_var_byte     <= '0';
                  s_id_dat_subs_byte    <= '0';
                  s_id_dat_frame_ok     <= '0';
                  s_prod_wait_resp_time <= '1';
                  s_cons_wait_FSS       <= '0';
                  s_consuming           <= '0';
                  s_producing           <= '0';

      when consume_wait_FSS =>
                  s_idle_state          <= '0';
                  s_id_dat_ctrl_byte    <= '0';
                  s_id_dat_var_byte     <= '0';
                  s_id_dat_subs_byte    <= '0';
                  s_id_dat_frame_ok     <= '0';
                  s_prod_wait_resp_time <= '0';
                  s_cons_wait_FSS       <= '1';
                  s_consuming           <= '0';
                  s_producing           <= '0';

      when consume =>
                  s_idle_state          <= '0';
                  s_id_dat_ctrl_byte    <= '0';
                  s_id_dat_var_byte     <= '0';
                  s_id_dat_subs_byte    <= '0';
                  s_id_dat_frame_ok     <= '0';
                  s_prod_wait_resp_time <= '0';
                  s_cons_wait_FSS       <= '0';
                  s_consuming           <= '1';
                  s_producing           <= '0';

      when produce =>
                  s_idle_state          <= '0';
                  s_id_dat_ctrl_byte    <= '0';
                  s_id_dat_var_byte     <= '0';
                  s_id_dat_subs_byte    <= '0';
                  s_id_dat_frame_ok     <= '0';
                  s_prod_wait_resp_time <= '0';
                  s_cons_wait_FSS       <= '0';
                  s_consuming           <= '0';
                  s_producing           <= '1';


      when others =>  
                  s_idle_state          <= '0';
                  s_id_dat_ctrl_byte    <= '0';
                  s_id_dat_var_byte     <= '0';
                  s_id_dat_subs_byte    <= '0';
                  s_id_dat_frame_ok     <= '0';
                  s_prod_wait_resp_time <= '0';
                  s_cons_wait_FSS       <= '0';
                  s_consuming           <= '0';
                  s_producing           <= '0';

    end case;                         
  end process;


---------------------------------------------------------------------------------------------------
  Prod_Data_Length_Calculator: WF_prod_data_lgth_calc
  port map(
    slone_i          => slone_i,             
    nostat_i         => nostat_i,
    p3_lgth_i        => p3_lgth_i,
    var_i            => s_var,
    ------------------------------------
    tx_data_length_o => s_tx_data_length
    ------------------------------------ 
      );
  tx_data_length_o <= s_tx_data_length;

--------------------------------------------------------------------------------------------------- 
  Cons_Frame_Validator: WF_cons_frame_validator
  port map(
    rx_Ctrl_byte_i         => rx_Ctrl_byte_i, 
    rx_PDU_byte_i          => rx_PDU_byte_i,    
    rx_Length_byte_i       => rx_Length_byte_i,
    rx_FSS_CRC_FES_viol_ok_p_i => rx_CRC_FES_ok_p_i,
    var_i                  => s_var,
    rx_byte_index_i        => s_rx_bytes_c,
    -------------------------------------------
    cons_frame_ok_p_o      => s_cons_frame_ok_p
    -------------------------------------------
      );

---------------------------------------------------------------------------------------------------
 VAR_RDY_Signals_Generation: WF_VAR_RDY_generator
  port map (
    uclk_i                => uclk_i,
    slone_i               => slone_i,
    subs_i                => subs_i,
    nFIP_urst_i           => nFIP_urst_i, 
    cons_frame_ok_p_i     => s_cons_frame_ok_p,
    var_i                 => s_var,
    rx_var_rst_byte_1_i      => rx_var_rst_byte_1_i,
    rx_var_rst_byte_2_i      => rx_var_rst_byte_2_i,
    ---------------------------------------
    var1_rdy_o            => var1_rdy_o,
    var2_rdy_o            => var2_rdy_o,
    var3_rdy_o            => var3_rdy_o,
    assert_RSTON_p_o       => assert_RSTON_p_o,
    rst_nFIP_and_FD_p_o => rst_nFIP_and_FD_p_o
    ---------------------------------------
      );

--------------------------------------------------------------------------------------------------- 
--!@brief Counter that counts the number of produced or consumed bytes of data. 
 Rx_Bytes_Counter: WF_incr_counter
  generic map(counter_length => 8)
  port map(
    uclk_i            => uclk_i,
    nFIP_urst_i       => nFIP_urst_i,
    reinit_counter_i  => s_rst_rx_bytes_counter,
    incr_counter_i    => s_inc_rx_bytes_counter,
    ---------------------------------------------
    counter_o         => s_rx_bytes_c,
    counter_is_full_o => open
    ---------------------------------------------
      );

--------------------------------------------------------------------------------------------------- 
--!@brief Counter that counts the number of produced or consumed bytes of data. 
 Tx_Bytes_Counter: WF_incr_counter
  generic map(counter_length => 8)
  port map(
    uclk_i          => uclk_i,
    nFIP_urst_i     => nFIP_urst_i,
    reinit_counter_i => s_rst_tx_bytes_counter,
    incr_counter_i  => s_inc_tx_bytes_counter,
    ---------------------------------------------
    counter_o       => s_tx_bytes_c  
    ---------------------------------------------
      );
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
  -- when s_tx_data_length bytes have been counted, the signal s_tx_data_length_match is activated 
  s_tx_data_length_match <= '1' when s_tx_bytes_c = unsigned(s_tx_data_length) else '0'; 

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  Rx_Tx_Bytes_Counters_Arg: process (s_id_dat_frame_ok, s_consuming, tx_request_byte_p_i,
                                     s_producing, rx_byte_ready_p_i, s_rx_bytes_c, s_tx_bytes_c)
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
      s_inc_tx_bytes_counter  <= tx_request_byte_p_i;
      s_tx_byte_index  <= std_logic_vector (resize(s_tx_bytes_c, s_tx_byte_index'length));

      s_rst_rx_bytes_counter <= '1';
      s_inc_rx_bytes_counter <= '0';
      s_rx_byte_index        <= (others => '0'); 

    else
      s_rst_rx_bytes_counter <= '1';
      s_inc_rx_bytes_counter <= '0';
      s_rx_byte_index        <= (others => '0'); 
      s_rst_tx_bytes_counter <= '1';
      s_inc_tx_bytes_counter <= '0';
      s_tx_byte_index  <= (others => '0');
    end if;
  end process;

  tx_rx_byte_index_o <= s_tx_byte_index when s_producing = '1'
                   else s_rx_byte_index;

---------------------------------------------------------------------------------------------------
-- Managing the counter that counts either response or silence times in uclk ticks.
-- The same counter is used in both cases. The signal s_time_counter_top initializes the counter
-- to either the response or the silence time.
Response_and_Silence_Time_Counter: WF_decr_counter
  generic map(counter_length => 15)
  port map(
    uclk_i            => uclk_i,
    nFIP_urst_i        => nFIP_urst_i,
    counter_top       => s_time_counter_top,
    counter_load_i    => s_load_time_c,
    counter_decr_p_i  => '1',
    counter_o         => s_time_c,
    ---------------------------------------
    counter_is_zero_o => s_time_c_is_zero
    ---------------------------------------
      );

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
-- retrieval of response and silence times information (in equivalent number of uclk ticks) from
-- the c_TIMEOUTS_TABLE declared in the WF_package unit. 

  s_response_time <= to_unsigned((c_TIMEOUTS_TABLE(to_integer(unsigned(rate_i))).response),
                                                                           s_response_time'length);
  s_silence_time <= to_unsigned((c_TIMEOUTS_TABLE(to_integer(unsigned(rate_i))).silence),
                                                                           s_response_time'length);

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
  Response_and_Silence_Time_Counter_Arg: process(s_prod_wait_resp_time, s_response_time, s_cons_wait_FSS,
                                                 s_silence_time, s_id_dat_frame_ok, s_produce_or_consume)
  begin

    if s_id_dat_frame_ok = '1'  and s_produce_or_consume = "10" then
      s_load_time_c      <= '1'; -- counter loads
      s_time_counter_top <= s_response_time;

    elsif s_id_dat_frame_ok = '1'  and s_produce_or_consume = "01" then
      s_load_time_c      <= '1'; -- counter loads
      s_time_counter_top <= s_silence_time;

    elsif s_prod_wait_resp_time = '1' then
      s_load_time_c      <= '0'; -- counter counts
      s_time_counter_top <= s_silence_time;

    elsif s_cons_wait_FSS = '1' then
      s_load_time_c      <= '0';  -- counter counts
      s_time_counter_top <= s_silence_time;

    else
      s_load_time_c      <= '1';
      s_time_counter_top <= s_silence_time;

    end if;
  end process;

--------------------------------------------------------------------------------------------------
--! The following two processes: id_dat_var_identifier and id_dat_var manage the
--! signals s_var_id, s_var_aux and s_var. All of them are used to keep the value of the
--! ID_DAT.Identifier.Variable byte of the incoming ID_DAT frame, but change their value on
--! different moments:
--! s_var_id: is constantly following the incoming byte rx_byte_i 
--! s_var_aux: locks to the value of s_var_id when the ID_DAT.Identifier.Variable byte
--! is received (s_load_var_aux = 1)
--! s_var: locks to the value of s_var_aux at the end of the id_dat frame (s_load_var = 1) if the 
--! specified station address matches the SUBS configuration.
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
  
  id_dat_var_identifier: process(rx_byte_i)
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
  s_load_var     <= s_prod_wait_resp_time or s_consuming;
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 

  id_dat_var: process(uclk_i)
  begin
    if rising_edge(uclk_i) then
      if nFIP_urst_i = '1' then 
        s_var <= var_whatever;
        s_var_aux <= var_whatever;
      else
        
        if s_idle_state = '1' then 
          s_var_aux <= var_whatever; 

        elsif s_load_var_aux = '1' then
          s_var_aux <= s_var_id;
        end if;
        
        if s_idle_state = '1' then 
          s_var <= var_whatever;

        elsif s_load_var = '1' then
          s_var <= s_var_aux;
        end if;
      end if;
    end if;
  end process;

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 

  var_o <= s_var; -- var_o takes a value at the end of the id_dat

---------------------------------------------------------------------------------------------------
--!@brief: Combinatorial process Var_Characteristics: managment of the signals
--! s_produce_or_consume and s_broadcast_var, accroding to the value of s_var_aux.

  Var_Characteristics: process(s_var_aux)
  begin
    s_produce_or_consume <= "00";
    s_broadcast_var <= '0';

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
      s_broadcast_var <= '1';
    end if;

  end process;



---------------------------------------------------------------------------------------------------
--!@brief: essential buffering of output signals tx_last_byte_p_o, tx_byte_ready_p_o, tx_start_produce_p_o

  process(uclk_i)
  begin
    if rising_edge(uclk_i) then
      if nFIP_urst_i = '1' then
        tx_last_byte_p_o        <= '0';
        s_tx_last_byte_p_d      <= '0';
        s_tx_byte_ready_p_d1    <= '0';
        s_tx_byte_ready_p_d2    <= '0';
        s_tx_start_prod_p <= '0';

      else
        s_tx_last_byte_p_d      <= s_tx_last_byte_p;
        tx_last_byte_p_o        <= s_tx_last_byte_p_d;
        s_tx_byte_ready_p_d1    <= s_tx_byte_ready_p;
        s_tx_byte_ready_p_d2    <= s_tx_byte_ready_p_d1;
        s_tx_start_prod_p    <= (s_prod_wait_resp_time and s_time_c_is_zero);
      end if;
    end if;
  end process;
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --   


  tx_start_produce_p_o <= s_tx_start_prod_p;

  s_tx_byte_ready_p    <= s_producing and (tx_request_byte_p_i or s_tx_start_prod_p);

  tx_byte_ready_p_o    <= s_tx_byte_ready_p_d2;

  s_tx_last_byte_p           <= s_producing and s_tx_data_length_match and tx_request_byte_p_i;
  rst_status_bytes_o       <= s_producing and s_tx_byte_ready_p_d2 and tx_sending_mps_i;

  rx_byte_ready_p_o          <= s_consuming and rx_byte_ready_p_i;

  rst_rx_unit_p_o          <= s_idle_state and rx_byte_ready_p_i;
---------------------------------------------------------------------------------------------------


end architecture rtl;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------