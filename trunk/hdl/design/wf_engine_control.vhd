--=================================================================================================
--! @file wf_engine_control.vhd
--=================================================================================================

--! Standard library
library IEEE;

--! Standard packages
use IEEE.STD_LOGIC_1164.all; --! std_logic definitions
use IEEE.NUMERIC_STD.all;    --! conversion functions

use work.WF_PACKAGE.all;


---------------------------------------------------------------------------------------------------  
--                                                                                               --
--                                        wf_engine_control                                      --
--                                                                                               --
--                                         CERN, BE/CO/HT                                        --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
-- unit name   wf_control
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
--!     wf_engine           \n
--!     tx_engine           \n
--!     clk_gen             \n
--!     wf_reset_unit         \n
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
--!                         PDU,length,ctrl bytes of rp_dat checked bf var1_rdy/ var_2_rdy assertion
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
--!                          Entity declaration for wf_engine_control
--=================================================================================================
entity wf_engine_control is

  generic( C_QUARTZ_PERIOD : real := 24.8);

  port (
  -- INPUTS 
    -- User Interface general signals 
    uclk_i :               in std_logic;                    --! 40MHz clock
    slone_i :              in std_logic;                    --! Stand-alone mode
    nostat_i :             in std_logic;                    --! no NanoFIP status transmission
    rate_i :               in std_logic_vector (1 downto 0); --! Worldfip bit rate
    subs_i :               in std_logic_vector (7 downto 0); --! Subscriber number coding.
    p3_lgth_i :            in std_logic_vector (2 downto 0); --! Produced variable data length

    -- Signal from the wf_reset_unit unit
    nFIP_rst_i :           in std_logic;                    --! internal reset

    -- Signal from the wf_tx unit
    tx_request_byte_p_i :  in std_logic;                    --!

    -- Signals from the wf_rx unit
    rx_fss_decoded_p_i :   in std_logic;                    --! correct FSS detected by wf_rx 
    rx_byte_ready_p_i :    in std_logic;                    --! new byte from the receiver on rx_byte_i
    rx_byte_i :            in std_logic_vector (7 downto 0);  -- Decoded byte
    rx_CRC_FES_ok_p_i :      in std_logic;   

    -- Signal from the wf_produced_vars 
    tx_sending_mps_i :     in std_logic;
 
    rx_Ctrl_byte_i :   in std_logic_vector (7 downto 0);
    rx_PDU_byte_i :    in std_logic_vector (7 downto 0);           
    rx_Length_byte_i : in std_logic_vector (7 downto 0);    


  -- OUTPUTS
    -- User interface, non-WISHBONE nanoFIP outputs
    var1_rdy_o :           out std_logic; --! signals new data received and can safely be read
    var2_rdy_o :           out std_logic; --! signals new data received and can safely be read
    var3_rdy_o :           out std_logic; --! signals that data can safely be written in the memory

    -- Outputs to the wf_tx unit
    tx_last_byte_p_o :     out std_logic;
    tx_start_produce_p_o : out std_logic;

    -- Output to wf_rx
    reset_rx_unit_p_o :    out std_logic; --! if an FES has not arrived after 8 bytes of an id_dat,
                                          --! or after 134 bytes of an rp_dat, the state machine
                                          --! of the wf_rx unit returns to idle state 

    -- Output to wf_concumed_vars and wf_produced_vars 
    var_o :                out t_var;
    tx_rx_byte_index_o :   out std_logic_vector (7 downto 0);

    -- Output to wf_produced_vars
    tx_data_length_o :     out std_logic_vector (7 downto 0);

    -- Output to wf_tx
    tx_byte_ready_p_o :    out std_logic;

    -- output to wf_consumed_vars
    rx_byte_ready_p_o :  out std_logic;

    -- output to the wf_reset_unit
    reset_status_bytes_o : out std_logic

    );
end entity wf_engine_control;



--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of wf_engine_control is


  type control_st_t  is (idle, id_dat_control_byte, id_dat_var_byte, id_dat_subs_byte, consume, consume_wait_FSS,
                         id_dat_frame_ok, produce_wait_respon_time, cont_w_cons_watchdog, produce);

  signal control_st, nx_control_st : control_st_t;
  signal s_var_aux, s_var, s_var_aux_concurr : t_var;


  signal s_load_var, s_load_temp_var, s_tx_byte_ready_p_d1 :           std_logic;
  signal s_rst_time_c, s_tx_byte_ready_p_d2 :        std_logic;
  signal s_var1_received, s_var2_received, s_tx_last_byte_p_d :        std_logic;
  signal s_tx_start_produce_p, s_tx_start_produce_p_d1 :               std_logic;
  signal s_time_c_is_zero, s_broadcast_var :                           std_logic;
  signal s_inc_tx_rx_bytes_counter, s_rst_tx_rx_bytes_counter, s_tx_last_byte_p :std_logic;
  signal s_tx_data_length_match, s_tx_byte_ready_p, s_cons_frame_ok_p :std_logic;
  signal s_rx_ctrl_byte_ok, s_rx_PDU_byte_ok, s_rx_length_byte_ok :    std_logic;        
  signal s_p3_length_decoded, s_tx_data_length, s_tx_rx_bytes_c :      unsigned(7 downto 0);
  signal s_time_c, s_time_counter_top:                                 signed(14 downto 0); 
  signal s_response_time, s_silence_time :                             signed(14 downto 0);
  signal s_produce_or_consume :                                        std_logic_vector (1 downto 0);
  signal s_enble_load_temp_var, s_reset_rx_unit : std_logic;
  signal s_enble_bytes_counter, s_start_producing, s_enble_tx, s_enble_rx :                                  std_logic;


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
      if nFIP_rst_i = '1' then
        control_st <= idle;
      else
        control_st <= nx_control_st;
      end if;
    end if;
  end process;


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
--!@brief synchronous process Receiver_FSM_Sync: storage of the current state of the FSM 


  Central_Control_FSM_Comb_State_Transitions:process (control_st, rx_fss_decoded_p_i, s_tx_last_byte_p,
                                                     s_var_aux_concurr, rx_byte_ready_p_i,rx_byte_i, subs_i,
                                                     s_time_c_is_zero,s_produce_or_consume, slone_i,
                                                     rx_CRC_FES_ok_p_i, s_broadcast_var, s_tx_rx_bytes_c)
  begin


    case control_st is

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
      when idle =>

        if rx_fss_decoded_p_i = '1' then -- notification from the receiver that a correct FSS field has been received
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
  
        if (rx_byte_ready_p_i = '1') and (s_var_aux_concurr /= var_whatever) then
          nx_control_st <= id_dat_subs_byte;

        elsif  (rx_byte_ready_p_i = '1') and (s_var_aux_concurr = var_whatever) then
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

        elsif (rx_CRC_FES_ok_p_i = '1') and (s_tx_rx_bytes_c > 2)  then
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

        if rx_fss_decoded_p_i = '1' then
          nx_control_st <= consume;
 
        elsif s_time_c_is_zero = '1' then
          nx_control_st <= idle;
 
        else
          nx_control_st <= consume_wait_FSS;  
        end if;      


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
      when consume =>

        if (rx_CRC_FES_ok_p_i = '1')  or                   -- if the rp_dat frame finishes as 
           (s_tx_rx_bytes_c > 130 and slone_i = '0') or    -- expected with a FES, or if no rp_dat 
           (s_tx_rx_bytes_c > 4   and slone_i = '1') then  -- arrives after the silence_time, or
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

  Central_Control_FSM_Comb_Output_Signals: process (control_st, s_silence_time, s_response_time)
  begin

    case control_st is

      when idle =>
                  s_reset_rx_unit           <= '1';
                  s_rst_time_c              <= '1';
                  s_time_counter_top        <= s_silence_time;
                  s_enble_bytes_counter     <= '0';
                  s_rst_tx_rx_bytes_counter <= '1';
                  s_enble_load_temp_var     <= '0';
                  s_load_var                <= '0';
                  s_start_producing         <= '0';
                  s_enble_rx                <= '0';
                  s_enble_tx                <= '0';


      when id_dat_control_byte =>
                  s_reset_rx_unit           <= '0';
                  s_rst_time_c              <= '1';
                  s_time_counter_top        <= s_silence_time;
                  s_enble_bytes_counter     <= '0';
                  s_rst_tx_rx_bytes_counter <= '1';
                  s_enble_load_temp_var     <= '0';
                  s_load_var                <= '0';
                  s_start_producing         <= '0';
                  s_enble_rx                <= '0';
                  s_enble_tx                <= '0';


      when id_dat_var_byte =>      
                  s_reset_rx_unit           <= '0';
                  s_rst_time_c              <= '1';
                  s_time_counter_top        <= s_silence_time;
                  s_enble_bytes_counter     <= '0';
                  s_rst_tx_rx_bytes_counter <= '1';
                  s_enble_load_temp_var     <= '1';
                  s_load_var                <= '0';
                  s_start_producing         <= '0';
                  s_enble_rx                <= '0';
                  s_enble_tx                <= '0';


      when id_dat_subs_byte =>
                  s_reset_rx_unit           <= '0';
                  s_rst_time_c              <= '1';
                  s_time_counter_top        <= s_silence_time;
                  s_enble_bytes_counter     <= '0';
                  s_rst_tx_rx_bytes_counter <= '1';
                  s_enble_load_temp_var     <= '0';
                  s_load_var                <= '0';
                  s_start_producing         <= '0';
                  s_enble_rx                <= '0';
                  s_enble_tx                <= '0';


      when id_dat_frame_ok => 
                  s_reset_rx_unit           <= '0';
                  s_rst_time_c              <= '1';
                  s_time_counter_top        <= s_silence_time;
                  s_enble_bytes_counter     <= '1';
                  s_rst_tx_rx_bytes_counter <= '0';
                  s_enble_load_temp_var     <= '0';
                  s_load_var                <= '0';
                  s_start_producing         <= '0';
                  s_enble_rx                <= '0';
                  s_enble_tx                <= '0';


      when produce_wait_respon_time =>  
                  s_reset_rx_unit           <= '0';
                  s_rst_time_c              <= '0';
                  s_time_counter_top        <= s_response_time;
                  s_enble_bytes_counter     <= '0';
                  s_rst_tx_rx_bytes_counter <= '1';
                  s_enble_load_temp_var     <= '0';
                  s_load_var                <= '1';
                  s_start_producing         <= '1';
                  s_enble_rx                <= '0';
                  s_enble_tx                <= '0';



      when consume_wait_FSS =>
                  s_reset_rx_unit           <= '0';
                  s_rst_time_c              <= '0';
                  s_time_counter_top        <= s_silence_time;
                  s_enble_bytes_counter     <= '0';
                  s_rst_tx_rx_bytes_counter <= '1';
                  s_enble_load_temp_var     <= '0';
                  s_load_var                <= '0';
                  s_start_producing         <= '0';
                  s_enble_rx                <= '0';
                  s_enble_tx                <= '0';

	   
        
      when consume =>
                  s_reset_rx_unit           <= '0';
                  s_rst_time_c              <= '1';
                  s_time_counter_top        <= s_silence_time;
                  s_enble_bytes_counter     <= '1';
                  s_rst_tx_rx_bytes_counter <= '0';
                  s_enble_load_temp_var     <= '0';
                  s_load_var                <= '1';
                  s_start_producing         <= '0';
                  s_enble_rx                <= '1';
                  s_enble_tx                <= '0';



      when produce =>
                  s_reset_rx_unit           <= '0';
                  s_rst_time_c              <= '0';
                  s_time_counter_top        <= s_silence_time;
                  s_enble_bytes_counter     <= '1';
                  s_rst_tx_rx_bytes_counter <= '0';
                  s_enble_load_temp_var     <= '0';
                  s_load_var                <= '0';
                  s_start_producing         <= '0';
                  s_enble_rx                <= '0';
                  s_enble_tx                <= '1';


      when others =>   
                  s_reset_rx_unit           <= '0';
                  s_rst_time_c              <= '0';
                  s_time_counter_top        <= s_silence_time;
                  s_enble_bytes_counter     <= '0';
                  s_rst_tx_rx_bytes_counter <= '0';
                  s_enble_load_temp_var     <= '0';
                  s_load_var                <= '0';
                  s_start_producing         <= '0';
                  s_enble_rx                <= '0';
                  s_enble_tx                <= '0';

    end case;                         
  end process;


  reset_rx_unit_p_o          <= s_reset_rx_unit and rx_byte_ready_p_i;
  s_load_temp_var            <= s_enble_load_temp_var and rx_byte_ready_p_i;
  rx_byte_ready_p_o          <= s_enble_rx and rx_byte_ready_p_i;
  s_tx_last_byte_p           <= s_enble_tx and s_tx_data_length_match and tx_request_byte_p_i;
  reset_status_bytes_o       <= s_enble_tx and s_tx_byte_ready_p_d2 and tx_sending_mps_i;
  s_inc_tx_rx_bytes_counter  <= s_enble_bytes_counter and (tx_request_byte_p_i or rx_byte_ready_p_i);
  s_tx_byte_ready_p          <= s_enble_tx and (tx_request_byte_p_i or s_tx_start_produce_p_d1);
  tx_rx_byte_index_o         <= std_logic_vector (resize(s_tx_rx_bytes_c, tx_rx_byte_index_o'length))
                                                  when s_enble_tx ='1' or s_enble_rx = '1'
                                                  else (others => '0');

  s_tx_start_produce_p <= s_start_producing and s_time_c_is_zero;



--------------------------------------------------------------------------------------------------
--! The following two processes: id_dat_var_concurrent and id_dat_var_specific_moments manage the
--! signals s_var_aux_concurr, s_var_aux and s_var. All of them are used to keep the value of the
--! ID_DAT.Identifier.Variable byte of the incoming ID_DAT frame, but change their value on
--! different moments:
--! s_var_aux_concurr: is constantly following the incoming byte rx_byte_i 
--! s_var_aux: locks to the value of s_var_aux_concurr when the ID_DAT.Identifier.Variable byte
--! is received (s_load_temp_var = 1)
--! s_var: locks to the value of s_var_aux at the end of the id_dat frame (s_load_var = 1) if the 
--! specified station address matches the SUBS configuration.
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
  
  id_dat_var_concurrent: process(rx_byte_i)
  begin
    s_var_aux_concurr <= var_whatever;
    for I in c_VARS_ARRAY'range loop
      if rx_byte_i = c_VARS_ARRAY(I).hexvalue then
        s_var_aux_concurr <= c_VARS_ARRAY(I).var;
        exit;
      end if;
    end loop;
  end process;
  
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
  id_dat_var_specific_moments: process(uclk_i)
  begin
    if rising_edge(uclk_i) then
      if nFIP_rst_i = '1' then 
        s_var <= var_whatever;
        s_var_aux <= var_whatever;
      else
        
        if s_reset_rx_unit = '1' then 
          s_var_aux <= var_whatever; 

        elsif s_load_temp_var = '1' then
          s_var_aux <= s_var_aux_concurr;
        end if;
        
        if s_reset_rx_unit = '1' then 
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

    if  ((s_var_aux = var_2) or (s_var_aux = reset_var)) then
      s_broadcast_var <= '1';
    end if;

  end process;

---------------------------------------------------------------------------------------------------
--!@brief:Combinatorial process data_length_calcul_produce: calculation of the total amount of data
--! bytes that have to be transferreed when a variable is produced, including the rp_dat.Control as
--! well as the rp_dat.Data.mps and rp_dat.Data.nanoFIPstatus bytes. In the case of the presence 
--! and the identification variables, the data length is predefined in the wf_package.
--! In the case of a var_3 the inputs slone, nostat and p3_lgth[] are accounted for the calculation 

  data_length_calcul_produce: process ( s_var, s_p3_length_decoded, slone_i, nostat_i, p3_lgth_i )
  variable v_nostat : std_logic_vector (1 downto 0);
  begin

    s_tx_data_length <= (others => '0');
    s_p3_length_decoded <= c_P3_LGTH_TABLE (to_integer(unsigned(p3_lgth_i)));

    case s_var is


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -
      -- data length information retreival from the c_VARS_ARRAY matrix (wf_package) 
      when presence_var => 
        s_tx_data_length <= c_VARS_ARRAY(c_PRESENCE_VAR_INDEX).array_length;


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -
      -- data length information retreival from the c_VARS_ARRAY matrix (wf_package) 
      when identif_var => 
        s_tx_data_length <= c_VARS_ARRAY(c_IDENTIF_VAR_INDEX).array_length;


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -
      -- data length calculation according to the operational mode (memory or stand-alone)

      -- in slone mode                   2 bytes of user-data are produced
      -- to these there should be added: 1 byte rp_dat.Control
      --                                 1 byte MPS 
      --                      optionally 1 byte nFIP status
  
      -- in memory mode the signal      "s_p3_length_decoded" indicates the amount of user-data
      -- to these, there should be added 1 byte rp_dat.Control
      --                                 1 byte PDU
      --                                 1 byte Length
      --                                 1 byte MPS 
      --                      optionally 1 byte nFIP status  
    
      when var_3 =>  


        if slone_i = '1' then

          if nostat_i = '1' then
            s_tx_data_length <= "00000011"; -- 4 bytes (counting starts from 0)

          else 
            s_tx_data_length <= "00000100"; -- 5 bytes (counting starts from 0)
          end if;


        else
          if nostat_i = '0' then
            s_tx_data_length <= s_p3_length_decoded + 4; -- (bytes counting starts from 0)

           else
            s_tx_data_length <= s_p3_length_decoded + 3; -- (bytes counting starts from 0)
           end if;          
          end if;

      when var_1 => 

      when var_2 =>

      when reset_var =>  

      when others => 

    end case;
  end process;
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
  -- output signals that have been also used in the process
  tx_data_length_o <= std_logic_vector (s_tx_data_length);

 
--------------------------------------------------------------------------------------------------- 
--!@brief Synchronous process Bytes_Counter: Managment of the counter that counts the number of
--! produced or consumed bytes of data. 

  Bytes_Counter: process(uclk_i)
  begin
    if rising_edge(uclk_i) then
      if nFIP_rst_i = '1' then
        s_tx_rx_bytes_c <= (others => '0');

      elsif s_rst_tx_rx_bytes_counter = '1' then
        s_tx_rx_bytes_c <= (others => '0');

      elsif s_inc_tx_rx_bytes_counter = '1' then
        s_tx_rx_bytes_c <= s_tx_rx_bytes_c + 1;

      end if;
    end if;
  end process;
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
  -- when s_tx_data_length bytes have been counted, the signal s_tx_data_length_match is activated 
  s_tx_data_length_match <= '1' when s_tx_rx_bytes_c = s_tx_data_length else '0'; 
--------------------------------------------------------------------------------------------------- 

-- retrieval of response and silence times information (in equivalent number of uclk ticks) from
-- the c_TIMEOUTS_TABLE declared in the wf_package unit. 

  s_response_time <= to_signed((c_TIMEOUTS_TABLE(to_integer(unsigned(rate_i))).response),
                                                                           s_response_time'length);
  s_silence_time <= to_signed((c_TIMEOUTS_TABLE(to_integer(unsigned(rate_i))).silence),
                                                                           s_response_time'length);
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
--!@brief Synchronous process Response_and_Silence_Time_Counter: Managing the counter that counts
--! either response or silence times in uclk ticks. The same counter is used in both cases.
--! The signal s_time_counter_top initializes the counter to either the response or the silence time.

  Response_and_Silence_Time_Counter: process(uclk_i)
  begin
    if rising_edge(uclk_i) then
      if nFIP_rst_i = '1' then
        s_time_c <= to_signed(-1, s_time_c'length);

      elsif s_rst_time_c = '1' then
        s_time_c <= s_time_counter_top;
      else
        s_time_c <= s_time_c -1;
      end if;
    end if;
  end process;
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
  -- when the response or silence time is reached, the signal s_time_c_is_zero is activated 
  s_time_c_is_zero <= '1' when s_time_c = 0 else '0';



--------------------------------------------------------------------------------------------------- 
--!@brief Combinatorial process rx_Ctrl_PDU_Length_bytes_Verification: Checking the correctness of 
--! the Ctrl, PDU and Length bytes of an rp_dat. At the end of the rp_dat frame, the signal
--! s_cons_frame_ok_p indicates if those bytes, along with the CRC and the FES were correct and enables
--! the signals var1_rdy or var2_rdy (VAR_RDY_Generation process) 
 process(uclk_i)
  begin
    if rising_edge(uclk_i) then

      if s_var = var_1 or s_var = var_2 then

    --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
        if rx_Ctrl_byte_i = c_RP_DAT_CTRL_BYTE then              -- comparison with the expected
          s_rx_ctrl_byte_ok <= '1';                              -- RP_DAt_CTRL byte
        else
          s_rx_ctrl_byte_ok <= '0';
        end if; 

    --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
        if rx_PDU_byte_i = c_PROD_CONS_PDU_TYPE_BYTE then        -- comparison with the expected
          s_rx_PDU_byte_ok <= '1';                               -- PDU_TYPE byte
        else 
          s_rx_PDU_byte_ok <= '0' ;
        end if;

    --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
        if rx_CRC_FES_ok_p_i = '1' then                          -- checking the rp_dat.Data.Length
                                                                 -- byte, when the end of frame
                                                                 -- arrives correctly
          if s_tx_rx_bytes_c = (unsigned(rx_Length_byte_i) + 5) then 
            s_rx_length_byte_ok <= '1';                          -- s_tx_rx_bytes_c starts counting
                                                                 -- from 0 and apart from the user-data
           else                                                  -- bytes, also counts ctrl, PDU,
             s_rx_length_byte_ok <= '0';                         -- Length, 2 crc and FES bytes 
          end if;                                                          

        else 
          s_rx_length_byte_ok <= '0';
        end if;   

    --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --

      else
        s_rx_ctrl_byte_ok   <= '0';
        s_rx_PDU_byte_ok    <= '0';
        s_rx_length_byte_ok <= '0';
      end if;
    end if;
end process;            

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- -- -
s_cons_frame_ok_p <= s_rx_length_byte_ok and s_rx_ctrl_byte_ok and s_rx_PDU_byte_ok;



---------------------------------------------------------------------------------------------------
--!@brief Synchronous process VAR_RDY_Generation: managment of the nanoFIP output signals VAR1_RDY,
--! VAR2_RDY and VAR3_RDY. 

--! VAR1_RDY (for consumed vars): signals that the user can safely read from the consumed variable
--! memory or retreive data from the dat_o bus. The signal is asserted only after a consumed var
--! that has been received correctly.

--! VAR2_RDY (for broadcast consumed vars): signals that the user can safely read from the consumed
--! broadcast variable memory. The signal is asserted only after a consumed var has been received 
--! and there is data in the memory to read. In slone mode, the var2_rdy remains deasserted.

--! VAR3_RDY (for produced vars): signals that the user can safely write to the produced variable
--! memory. it is deasserted right after the end of the reception of an id_dat that requests a
--! produced var and stays deasserted until the end of the transmission of the corresponding
--! rp_dat from nanoFIP (in detail, it stays deasserted until the end of the transmission of the
--! rp_dat.data field and is enabled during the rp_dat.fcs and rp_dat.fes transmission.

--! Note: in memory mode, since the three memories (consumed, consumed broadcast, produced) are
--! independant, when a produced var is being sent, the user can read form the consumed memories;
--! similarly, when a consumed variable is received the user can write to the produced momory.
--! In stand-alone mode, since the DAT_O bus is the same for consumed and consumed broadcast
--! variables, only one of the VAR1_RDY and VAR2_RDY can be enabled at a time.
--! VAR3_RDY remains independant.  


  VAR_RDY_Generation: process(uclk_i) 
  begin
    if rising_edge(uclk_i) then
      if nFIP_rst_i = '1' then
        var1_rdy_o <= '0';
        var2_rdy_o <= '0';
        var3_rdy_o <= '0';
        s_var1_received <= '0';
        s_var2_received <= '0';

      else
      --  --  --  --  --  --  --  --
        if s_var = var_1 then
 
          var2_rdy_o        <= s_var2_received; -- var 2 retains its previous value
          var3_rdy_o        <= '1';             -- the user can write in the produced memory

          s_var1_received   <= '0';
          var1_rdy_o        <= '0';

          if s_cons_frame_ok_p = '1' then 
            s_var1_received <= '1'; -- only if the received rp_dat frame is correct,
                                    -- the nanoFIP signals the user to retreive data
                                    -- note: the signal s_var1_received stays asserted
                                    -- even after the end of the rx_CRC_FES_ok_p_i pulse
     --       if slone_i = '0' then
     --         s_var2_received <='0';
     --       end if;

          end if; 
      --  --  --  --  --  --  --  --
        elsif s_var = var_2 then 

            var1_rdy_o        <= s_var1_received; -- var 1 retains its previous value
            var3_rdy_o        <= '1';             -- the user can write in the produced memory

            var2_rdy_o        <= '0';

          if slone_i = '0' then       -- slone mode does not support broadcast variables

            if s_cons_frame_ok_p = '1' then 
              s_var2_received <= '1'; -- only if the received rp_dat frame is correct,
            end if;                   -- the nanoFIP signals the user to retreive data
                                      -- note: the signal s_var1_received stays asserted
                                      -- even after the end of the rx_CRC_FES_ok_p_i pulse
          else
              s_var2_received <= '0';
          end if;

      --  --  --  --  --  --  --  --
        elsif s_var = var_3 then 

          var1_rdy_o          <= s_var1_received; -- var 1 and 2 retain their previous values
          var2_rdy_o          <= s_var2_received;

          var3_rdy_o          <= '0';             -- when nanoFIP is producing data, accessing
                                                  -- the produced memory is not allowed

      --  --  --  --  --  --  --  --
        else
          var1_rdy_o          <= s_var1_received; -- var 1 and 2 retain their previous values
          var2_rdy_o          <= s_var2_received; 
          var3_rdy_o          <= '1';             -- the user can write in the produced memory
      
        end if;	 	 
      end if;
    end if;
  end process;


---------------------------------------------------------------------------------------------------
--!@brief: essential buffering of output signals tx_last_byte_p_o, tx_byte_ready_p_o, tx_start_produce_p_o

  process(uclk_i)
  begin
    if rising_edge(uclk_i) then
      if nFIP_rst_i = '1' then
        tx_last_byte_p_o        <= '0';
        s_tx_last_byte_p_d      <= '0';
        s_tx_byte_ready_p_d1    <= '0';
        s_tx_byte_ready_p_d2    <= '0';
        s_tx_start_produce_p_d1 <= '0';

      else
        s_tx_last_byte_p_d      <= s_tx_last_byte_p;
        tx_last_byte_p_o        <= s_tx_last_byte_p_d;
        s_tx_byte_ready_p_d1    <= s_tx_byte_ready_p;
        s_tx_byte_ready_p_d2    <= s_tx_byte_ready_p_d1;
        s_tx_start_produce_p_d1 <= s_tx_start_produce_p;
      end if;
    end if;
  end process;
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --   
  tx_byte_ready_p_o    <= s_tx_byte_ready_p_d2;
  tx_start_produce_p_o <= s_tx_start_produce_p_d1;

---------------------------------------------------------------------------------------------------


end architecture rtl;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------