--=================================================================================================
--! @file wf_engine_control.vhd
--! @brief Nanofip control unit
--=================================================================================================
--! Standard library
library IEEE;
--! Standard packages
use IEEE.STD_LOGIC_1164.all; --! std_logic definitions
use IEEE.NUMERIC_STD.all;    --! conversion functions

use work.wf_package.all;


---------------------------------------------------------------------------------------------------  
--                                                                           --
--                                 wf_engine_control                                 --
--                                                                           --
--                               CERN, BE/CO/HT                              --
--                                                                           --
---------------------------------------------------------------------------------------------------
--
-- unit name: wf_control
--
--! @brief Nanofip control unit. It treats variable production and consuptions requests and manage timeouts. \n
--!
--! 
--!
--!
--!
--!
--!
--! @author Pablo Alvarez Sanchez (pablo.alvarez.sanchez@cern.ch)
--
--! @date 11/09/2009
--
--! @version v0.01
--
--! @details 
--!
--! <b>Dependencies:</b>\n
--! wf_engine           \n
--! tx_engine           \n
--! clk_gen             \n
--! reset_logic         \n
--! consumed_ram        \n
--!
--!
--! <b>References:</b>\n
--! 
--! 
--!
--! <b>Modified by:</b>\n
--! Author: Pablo Alvarez Sanchez (pablo.alvarez.sanchez@cern.ch)
---------------------------------------------------------------------------------------------------  
--! \n\n<b>Last changes:</b>\n
--! 11/09/2009  v0.01  EB  First version \n
--!
---------------------------------------------------------------------------------------------------  
--! @todo 
--!
---------------------------------------------------------------------------------------------------  



--=================================================================================================
--! Entity declaration for wf_engine_control
--=================================================================================================
entity wf_engine_control is
  generic( C_QUARTZ_PERIOD : real := 24.8);

  port (
    uclk_i :           in std_logic; --! 40MHz clock
    rst_i :            in std_logic; --! global reset

    -- Transmiter interface
    request_byte_p_i : in std_logic;

     -- Receiver interface
    fss_decoded_p_i :  in std_logic;   -- the receiver wf_rx has detected the start of a frame
    byte_ready_p_i :   in std_logic;   --  ouputs a new byte on byte_i
    byte_i :           in std_logic_vector(7 downto 0);  -- Decoded byte
    frame_ok_p_i :     in std_logic;     
    

    rate_i :           in std_logic_vector(1 downto 0);    -- Worldfip bit rate
    subs_i :           in  std_logic_vector (7 downto 0); --! Subscriber number coding.
    p3_lgth_i :        in  std_logic_vector (2 downto 0); --! Produced variable data length
    slone_i :          in  std_logic; --! Stand-alone mode
    nostat_i :         in  std_logic; --! No NanoFIP status transmission


    var1_rdy_o :       out std_logic; --! Variable 1 ready. signals new data is received and can safely be read (Consumed 
                               --! variable 05xyh). In stand-alone mode one may sample the data on the 
                               --! first clock edge VAR1_RDY is high.


    var2_rdy_o :       out std_logic; --! Variable 2 ready. Signals new data is received and can safely be read (Consumed 
                               --! broadcast variable 04xyh). In stand-alone mode one may sample the 
                               --! data on the first clock edge VAR1_RDY is high.

    var3_rdy_o :       out std_logic; --! Variable 3 ready. Signals that the variable can safely be written (Produced variable 
                               --! 06xyh). In stand-alone mode, data is sampled on the first clock after
                               --! VAR_RDY is deasserted.
    byte_ready_p_o :   out std_logic;
    last_byte_p_o :    out std_logic;
    start_produce_p_o :   out std_logic;
    var_o :            out t_var;
    append_status_o :  out std_logic;
    add_offset_o :     out std_logic_vector(6 downto 0);
    data_length_o :    out std_logic_vector(6 downto 0);
    cons_byte_we_p_o : out std_logic
    );

end entity wf_engine_control;



---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
--! ARCHITECTURE OF wf_control
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
architecture rtl of wf_engine_control is

--attribute syn_radhardlevel : string;
--attribute syn_radhardlevel of rtl: architecture is "tmr";


  type control_st_t  is (idle, id_dat_control_byte, id_dat_var_byte, id_dat_subs_byte, id_dat_frame_ok, 
                         produce_wait_respon_time, cont_w_cons_watchdog, consume, produce);


  signal control_st, nx_control_st : control_st_t;
  signal s_var_aux, s_var, s_var_aux_concurr : t_var;

  signal s_respon_silen_c, s_counter_top, s_response_time, s_silence_time  : signed(16 downto 0);
  signal s_counter_reset : std_logic;
  signal s_p3_length_decoded : unsigned(6 downto 0);
  signal s_data_length : unsigned(6 downto 0);
  signal s_reset_id_dat : std_logic;
  signal s_respon_silen_c_is_zero : std_logic;
  signal s_broadcast_var : std_logic;
  signal s_bytes_c : unsigned(7 downto 0);
  signal s_inc_bytes_c, s_reset_bytes_c : std_logic;
  signal s_produce_or_consume : std_logic_vector(1 downto 0);
  signal s_last_byte_p : std_logic;
  signal s_load_temp_var : std_logic;
  signal s_load_var : std_logic;
  signal data_length_match : std_logic;
  signal s_byte_ready_p : std_logic;
  signal s_append_status : std_logic;
  signal s_var1_received, s_var2_received : std_logic;
  signal s_start_produce_p, s_start_produce_p_d1 : std_logic;
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
      if rst_i = '1' then
        control_st <= idle;
      else
        control_st <= nx_control_st;
      end if;
    end if;
  end process;


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
--!@brief synchronous process Receiver_FSM_Sync: storage of the current state of the FSM 


  Central_Control_FSM_Comb_State_Transitions:process (control_st, fss_decoded_p_i, s_last_byte_p,
                                                     s_var_aux_concurr, byte_ready_p_i,byte_i, subs_i,
                                                     s_respon_silen_c_is_zero,s_produce_or_consume,
                                                     frame_ok_p_i, s_broadcast_var)
  begin
    nx_control_st <= idle;

    case control_st is

      when idle =>
        if fss_decoded_p_i = '1' then -- notification from the receiver that a correct FSS field has been received
          nx_control_st <= id_dat_control_byte;
        else
          nx_control_st <= idle;
        end if;

      when id_dat_control_byte =>
        if (byte_ready_p_i = '1') and (byte_i = c_id_dat) then
          nx_control_st <= id_dat_var_byte;
        elsif (byte_ready_p_i = '1') then
          nx_control_st <= idle;
        else
          nx_control_st <= id_dat_control_byte;
        end if;
        
      when id_dat_var_byte =>      
        if (byte_ready_p_i = '1') and (s_var_aux_concurr /= c_var_whatever) then
          nx_control_st <= id_dat_subs_byte;
        elsif  (byte_ready_p_i = '1') and (s_var_aux_concurr = c_var_whatever) then
          nx_control_st <= idle;
        else
          nx_control_st <= id_dat_var_byte;
        end if;

        
      when id_dat_subs_byte =>      
        if (byte_ready_p_i = '1') and (byte_i = subs_i) then
          nx_control_st <= id_dat_frame_ok;
        elsif (byte_ready_p_i = '1') and (s_broadcast_var = '1') then
          nx_control_st <= id_dat_frame_ok;
        elsif (byte_ready_p_i = '1') then
          nx_control_st <= idle;
        else
          nx_control_st <= id_dat_subs_byte;
        end if;
        
      when id_dat_frame_ok =>
        if (frame_ok_p_i = '1') and (s_produce_or_consume = "10") then
          nx_control_st <= produce_wait_respon_time;
        elsif (frame_ok_p_i = '1') and (s_produce_or_consume = "01") then
          nx_control_st <= consume;
        elsif (frame_ok_p_i = '1') then
          nx_control_st <= idle;
        elsif fss_decoded_p_i = '1' then
          nx_control_st <= id_dat_control_byte;
        else
          nx_control_st <= id_dat_frame_ok;
        end if;
        
      when produce_wait_respon_time =>
        if s_respon_silen_c_is_zero = '1' then
          nx_control_st <= produce;
        else
          nx_control_st <= produce_wait_respon_time;
        end if;

      when consume =>
        if frame_ok_p_i = '1' or s_respon_silen_c_is_zero = '1' then
          nx_control_st <= idle;
        else
          nx_control_st <= consume;
        end if;

      when produce =>
        if s_last_byte_p = '1' then
          nx_control_st <= idle;
        else
          nx_control_st <= produce;
        end if;

      when others =>
          nx_control_st <= idle;
    end case;                         
  end process;

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
--!@brief synchronous process Central_Control_FSM_Comb_Output_Signals: 

  Central_Control_FSM_Comb_Output_Signals: process (control_st, frame_ok_p_i, s_bytes_c, 
                                                    s_produce_or_consume, s_start_produce_p_d1,
                                                    request_byte_p_i, s_respon_silen_c_is_zero,
                                                    byte_ready_p_i,s_response_time, s_silence_time,
                                                    data_length_match)
  begin

    case control_st is

      when idle =>
                            s_load_temp_var <= '0';
                            s_counter_reset <= '1';
                            s_inc_bytes_c <= '0';
                            s_reset_bytes_c <= '1';
                            s_load_var <= '0';
                            s_counter_top <= s_silence_time;
                            cons_byte_we_p_o <= '0';
                            s_start_produce_p <= '0';
                            s_last_byte_p <= '0';
                            s_reset_id_dat <= '0';
                            s_byte_ready_p <= '0';
                            add_offset_o <= (others => '0');


      when id_dat_control_byte =>
                            s_load_temp_var <= '0';
                            s_counter_reset <= '1';
                            s_inc_bytes_c <= '0';
                            s_reset_bytes_c <= '1';
                            s_load_var <= '0';
                            s_counter_top <= s_silence_time;
                            cons_byte_we_p_o <= '0';
                            s_start_produce_p <= '0';
                            s_last_byte_p <= '0';
                            s_reset_id_dat <= '0';
                            s_byte_ready_p <= '0';
                            add_offset_o <= (others => '0');

      when id_dat_var_byte =>      
                            s_load_temp_var <= byte_ready_p_i;

                            s_counter_reset <= '1';
                            s_inc_bytes_c <= '0';
                            s_reset_bytes_c <= '1';
                            s_load_var <= '0';
                            s_counter_top <= s_silence_time;
                            cons_byte_we_p_o <= '0';
                            s_start_produce_p <= '0';
                            s_last_byte_p <= '0';
                            s_reset_id_dat <= '0';
                            s_byte_ready_p <= '0';
                            add_offset_o <= (others => '0');

      when id_dat_subs_byte =>
                            s_load_temp_var <= '0';
                            s_counter_reset <= '1';
                            s_inc_bytes_c <= '0';
                            s_reset_bytes_c <= '1';
                            s_load_var <= '0';
                            s_counter_top <= s_silence_time;
                            cons_byte_we_p_o <= '0';
                            s_start_produce_p <= '0';
                            s_last_byte_p <= '0';
                            s_reset_id_dat <= '0';
                            s_byte_ready_p <= '0';
                            add_offset_o <= (others => '0');



      when id_dat_frame_ok => 
                            s_load_var <= '0';

                            if s_produce_or_consume = "10" then
                              s_counter_top <= s_response_time;
                            else 
                              s_counter_top <= s_silence_time;
                            end if;

                            s_counter_reset <= '1';
                            s_inc_bytes_c <= '0';
                            s_reset_bytes_c <= '1';
                            cons_byte_we_p_o <= '0';
                            s_start_produce_p <= '0';
                            s_last_byte_p <= '0';
                            s_reset_id_dat <= '0';
                            s_byte_ready_p <= '0';
                            s_load_temp_var <= '0';
                            add_offset_o <= (others => '0');


      when produce_wait_respon_time =>  
                            s_start_produce_p <= s_respon_silen_c_is_zero;
                            s_counter_reset <= '0';

                            s_inc_bytes_c <= '0';
                            s_reset_bytes_c <= '1';
                            s_load_var <= '1';
                            s_counter_top <= s_silence_time;
                            cons_byte_we_p_o <= '0';
                            s_load_temp_var <= '0';
                            s_last_byte_p <= '0';
                            s_reset_id_dat <= '0';
                            s_byte_ready_p <= '0';
                            add_offset_o <= (others => '0'); 

	   
        
      when consume =>
                            if unsigned(s_bytes_c) > 1 then 
                              cons_byte_we_p_o <= byte_ready_p_i;
                            else
                              cons_byte_we_p_o <= '0';
                            end if;

                            s_reset_id_dat <= frame_ok_p_i or s_respon_silen_c_is_zero;
                            add_offset_o <= std_logic_vector(resize(s_bytes_c - 2,add_offset_o'length));
                            s_inc_bytes_c <= byte_ready_p_i;

                            s_reset_bytes_c <= '0';
                            s_counter_reset <= '0';
                            s_load_var <= '1';
                            s_counter_top <= s_silence_time;
                            s_start_produce_p <= '0';
                            s_last_byte_p <= '0';
                            s_load_temp_var <= '0';
                            s_byte_ready_p <= '0';



      when produce =>
                            s_last_byte_p <=  data_length_match and request_byte_p_i;
                            s_byte_ready_p <= request_byte_p_i or s_start_produce_p_d1;
                            s_inc_bytes_c <= request_byte_p_i;
                            s_reset_id_dat <= data_length_match and request_byte_p_i;
                            add_offset_o <= std_logic_vector(resize(s_bytes_c, add_offset_o'length));
                            s_counter_reset <= '0';

                            s_reset_bytes_c <= '0';
                            s_start_produce_p <= '0';
                            s_load_var <= '0';
                            s_counter_top <= s_silence_time;
                            cons_byte_we_p_o <= '0';
                            s_load_temp_var <= '0';

      when others =>   

    end case;                         
  end process;

---------------------------------------------------------------------------------------------------
--! The following two processes: id_dat_var_concurrent and id_dat_var_specific_moments manage the
--! signals s_var_aux_concurr, s_var_aux and s_var. All of them are used to keep the value of the
--! ID_DAT.Identifier.Variable byte of the incoming ID_DAT frame, but change their value on
--! different moments:
--! s_var_aux_concurr: is constantly following the incoming byte byte_i 
--! s_var_aux: locks to the value of s_var_aux_concurr when the ID_DAT.Identifier.Variable byte
--! is received (s_load_temp_var = 1)
--! s_var: locks to the value of s_var_aux at the end of the id_dat frame (s_load_var = 1) if the 
--! specified station address matches the SUBS configuration.
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
  
  id_dat_var_concurrent: process(byte_i)
  begin
    s_var_aux_concurr <= c_var_whatever;
    for I in c_var_array'range loop
      if byte_i = c_var_array(I).hexvalue then
        s_var_aux_concurr <= c_var_array(I).var;
        exit;
      end if;
    end loop;
  end process;
  
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
  id_dat_var_specific_moments: process(uclk_i)
  begin
    if rising_edge(uclk_i) then
      if rst_i = '1' then 
        s_var <= c_var_whatever;
        s_var_aux <= c_var_whatever;
      else
        
        if s_reset_id_dat = '1' then 
          s_var_aux <= c_var_whatever; 

        elsif s_load_temp_var = '1' then
          s_var_aux <= s_var_aux_concurr;
        end if;
        
        if s_reset_id_dat = '1' then 
          s_var <= c_var_whatever;

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

    for I in c_var_array'range loop

      if s_var_aux = c_var_array(I).var then

        if c_var_array(I).response = produce then
          s_produce_or_consume <= "10";
        else
          s_produce_or_consume <= "01";
        end if;
        exit;
      end if;
    end loop;

    if  s_var_aux = c_var_2 then
      s_broadcast_var <= '1';
    end if;

  end process;

---------------------------------------------------------------------------------------------------
--!@brief:Combinatorial process data_length_calcul_produce: calculation of the total amount of data
--! bytes that have to be transferreed when a variable is produced, including the rp_dat.Control as
--! well as the rp_dat.Data.mps and rp_dat.Data.nanoFIPstatus bytes. In the case of presence and
--! identification variables, the data length is predefined in the wf_package.
--! In the case of a var_3 the inputs slone, nostat and p3_lgth[] are accounted for the calculation 

  data_length_calcul_produce: process(s_var, s_p3_length_decoded, slone_i, nostat_i)
  variable v_nostat : std_logic_vector(1 downto 0);
  begin
    s_append_status <= not nostat_i;
    s_data_length <= to_unsigned(0,s_data_length'length);
    s_p3_length_decoded <= to_unsigned (c_p3_var_length_table (to_integer(unsigned(p3_lgth_i))), 
                                                                      s_p3_length_decoded'length);
    case s_var is

      when c_presence_var => 
        s_data_length<=to_unsigned(c_var_array(c_presence_var_pos).array_length-1,s_data_length'length);

      when c_identif_var => 
        s_data_length<=to_unsigned(c_var_array(c_identif_var_pos).array_length-1,s_data_length'length);

      when c_var_3 =>  
        if slone_i = '1' then
          s_data_length <= to_unsigned(3,s_data_length'length);
        
        else
          if s_append_status = '1' then
            s_data_length <= s_p3_length_decoded+1;
           else
            s_data_length <= s_p3_length_decoded; 
           end if;          
          end if;

      when c_var_1 => 

      when c_var_2 =>

      when c_reset_var =>  

      when others => 

    end case;
  end process;
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
  -- output signals that have been also used in the process
  append_status_o <= s_append_status;
  data_length_o <= std_logic_vector(s_data_length); 

 
--------------------------------------------------------------------------------------------------- 
--!@brief Synchronous process Bytes_Counter: Managment of the counter that counts the number of
--! produced or consumed bytes of data. 

  Bytes_Counter: process(uclk_i)
  begin
    if rising_edge(uclk_i) then
      if rst_i = '1' then
        s_bytes_c <= to_unsigned(0, s_bytes_c'length);
      elsif s_reset_bytes_c = '1' then
        s_bytes_c <= to_unsigned(0, s_bytes_c'length);
      elsif s_inc_bytes_c = '1' then
        s_bytes_c <= s_bytes_c + 1;
      end if;
    end if;
  end process;
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
  -- when s_data_length bytes have been counted, the signal data_length_match is activated 
  data_length_match <= '1' when s_bytes_c = s_data_length else '0'; 
--------------------------------------------------------------------------------------------------- 

-- retrieval of response and silence times information (in equivalent number of uclk ticks) from
-- the c_timeouts_table declared in the wf_package unit. 

  s_response_time <= to_signed((c_timeouts_table(to_integer(unsigned(rate_i))).response),
                                                                           s_response_time'length);
  s_silence_time <= to_signed((c_timeouts_table(to_integer(unsigned(rate_i))).silence),
                                                                           s_response_time'length);
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
--!@brief Synchronous process Response_and_Silence_Time_Counter: Managing the counter that counts
--! either response or silence times in uclk ticks. The same counter is used in both cases.
--! The signal s_counter_top initializes the counter to either the response or the silence time.

  Response_and_Silence_Time_Counter: process(uclk_i)
  begin
    if rising_edge(uclk_i) then
      if rst_i = '1' then
        s_respon_silen_c <= to_signed(-1, s_respon_silen_c'length);
      elsif s_counter_reset = '1' then
        s_respon_silen_c <= s_counter_top;
      else
        s_respon_silen_c <= s_respon_silen_c -1;
      end if;
    end if;
  end process;
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
  -- when the response or silence time is reached, the signal s_respon_silen_c_is_zero is activated 
  s_respon_silen_c_is_zero <= '1' when s_respon_silen_c = 0 else '0';


---------------------------------------------------------------------------------------------------
--!@brief:synchronous process VAR_RDY_Generation: managment of the nanoFIP output signals VAR1_RDY,
--! VAR2_RDY and VAR3_RDY. 

--! VAR1_RDY: signals that the user can safely read from the consumed variable memory. 

--! VAR2_RDY: signals that the user can safely read from the consumed broadcast variable memory.

--! VAR3_RDY: signals that the user can safely write to the produced variable memory.
--! it is deasserted right after the end of the reception of an id_dat that requests a produced var
--! and stays deasserted until the end of the transmission of the corresponding rp_dat from nanoFIP.
--! (in detail, it stays deasserted until the end of the transmission of the rp_dat.data field and
--! is enabled during the rp_dat.fcs and rp_dat.fes transmission.

  VAR_RDY_Generation: process(uclk_i) 
  begin
    if rising_edge(uclk_i) then
      if rst_i = '1' then
        var1_rdy_o <= '0';
        var2_rdy_o <= '0';
        var3_rdy_o <= '0';
        s_var1_received <= '0';
        s_var2_received <= '0';


      else
        if s_var = c_var_1 then 
          var1_rdy_o <= '0';
          s_var1_received <= '1';
        else
           var1_rdy_o <= s_var1_received; 
        end if;	 

        if s_var = c_var_2 then 
          var2_rdy_o <= '0';
          s_var2_received <= '1';
        else 
          var2_rdy_o <= s_var2_received; 
        end if;	 


        if s_var = c_var_3 then 
          var3_rdy_o <= '0';
        else 
          var3_rdy_o <= '1';
        end if;	 	 

      end if;
    end if;
  end process;


---------------------------------------------------------------------------------------------------
--!@brief: essential buffering of output signals last_byte_p_o, byte_ready_p_o, start_produce_p_o

  process(uclk_i)
  begin
    if rising_edge(uclk_i) then
      if rst_i = '1' then
        last_byte_p_o <= '0';
        byte_ready_p_o <= '0';
        s_start_produce_p_d1 <= '0';
      else
        last_byte_p_o <= s_last_byte_p;
        byte_ready_p_o <= s_byte_ready_p;
        s_start_produce_p_d1 <= s_start_produce_p;
      end if;
    end if;
  end process;
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --   
  start_produce_p_o <= s_start_produce_p_d1;

---------------------------------------------------------------------------------------------------

end architecture rtl;
---------------------------------------------------------------------------------------------------
--                          E N D   O F   F I L E
---------------------------------------------------------------------------------------------------