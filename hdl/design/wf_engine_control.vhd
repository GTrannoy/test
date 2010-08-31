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
--!     reset_logic         \n
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
    uclk_i :           in std_logic; --! 40MHz clock
    nFIP_rst_i :            in std_logic; --! internal reset

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
    add_offset_o :     out std_logic_vector(7 downto 0);
    data_length_o :    out std_logic_vector(7 downto 0);
    consume_byte_p_o : out std_logic
    );

end entity wf_engine_control;



--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of wf_engine_control is


  type control_st_t  is (idle, id_dat_control_byte, id_dat_var_byte, id_dat_subs_byte, consume, 
                         id_dat_frame_ok, produce_wait_respon_time, cont_w_cons_watchdog, produce);

  signal control_st, nx_control_st : control_st_t;
  signal s_var_aux, s_var, s_var_aux_concurr : t_var;


  signal s_load_var, s_load_temp_var, s_byte_ready_p_d, s_last_byte_p_d :      std_logic;
  signal s_counter_reset, s_reset_id_dat :                    std_logic;
  signal s_var1_received, s_var2_received :                   std_logic;
  signal s_start_produce_p, s_start_produce_p_d1 :            std_logic;
  signal s_respon_silen_c_is_zero, s_broadcast_var :          std_logic;
  signal s_inc_bytes_c, s_reset_bytes_c, s_last_byte_p :      std_logic;
  signal s_data_length_match, s_byte_ready_p :                std_logic;
  signal s_p3_length_decoded, s_data_length :                 unsigned(7 downto 0);
  signal s_bytes_c :                                          unsigned(7 downto 0);
  signal s_respon_silen_c, s_counter_top:                     signed(16 downto 0); 
  signal s_response_time, s_silence_time :                    signed(16 downto 0);
  signal s_produce_or_consume :                               std_logic_vector(1 downto 0);


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
        if (byte_ready_p_i = '1') and (byte_i = c_ID_DAT_CTRL_BYTE) then
          nx_control_st <= id_dat_var_byte;
        elsif (byte_ready_p_i = '1') then
          nx_control_st <= idle;
        else
          nx_control_st <= id_dat_control_byte;
        end if;
        
      when id_dat_var_byte =>      
        if (byte_ready_p_i = '1') and (s_var_aux_concurr /= var_whatever) then
          nx_control_st <= id_dat_subs_byte;
        elsif  (byte_ready_p_i = '1') and (s_var_aux_concurr = var_whatever) then
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
                                                    s_data_length_match)
  begin

    case control_st is

      when idle =>
                            s_load_temp_var   <= '0';
                            s_counter_reset   <= '1';
                            s_inc_bytes_c     <= '0';
                            s_reset_bytes_c   <= '1';
                            s_load_var        <= '0';
                            s_counter_top     <= s_silence_time;
                            consume_byte_p_o  <= '0';
                            s_start_produce_p <= '0';
                            s_last_byte_p     <= '0';
                            s_reset_id_dat    <= '0';
                            s_byte_ready_p    <= '0';
                            add_offset_o      <= (others => '0');


      when id_dat_control_byte =>
                            s_load_temp_var   <= '0';
                            s_counter_reset   <= '1';
                            s_inc_bytes_c     <= '0';
                            s_reset_bytes_c   <= '1';
                            s_load_var        <= '0';
                            s_counter_top     <= s_silence_time;
                            consume_byte_p_o  <= '0';
                            s_start_produce_p <= '0';
                            s_last_byte_p     <= '0';
                            s_reset_id_dat    <= '0';
                            s_byte_ready_p    <= '0';
                            add_offset_o      <= (others => '0');

      when id_dat_var_byte =>      
                            s_load_temp_var   <= byte_ready_p_i;

                            s_counter_reset   <= '1';
                            s_inc_bytes_c     <= '0';
                            s_reset_bytes_c   <= '1';
                            s_load_var        <= '0';
                            s_counter_top     <= s_silence_time;
                            consume_byte_p_o  <= '0';
                            s_start_produce_p <= '0';
                            s_last_byte_p     <= '0';
                            s_reset_id_dat    <= '0';
                            s_byte_ready_p    <= '0';
                            add_offset_o      <= (others => '0');

      when id_dat_subs_byte =>
                            s_load_temp_var   <= '0';
                            s_counter_reset   <= '1';
                            s_inc_bytes_c     <= '0';
                            s_reset_bytes_c   <= '1';
                            s_load_var        <= '0';
                            s_counter_top     <= s_silence_time;
                            consume_byte_p_o  <= '0';
                            s_start_produce_p <= '0';
                            s_last_byte_p     <= '0';
                            s_reset_id_dat    <= '0';
                            s_byte_ready_p    <= '0';
                            add_offset_o      <= (others => '0');



      when id_dat_frame_ok => 
                            s_load_var <= '0';

                            if s_produce_or_consume = "10" then
                              s_counter_top   <= s_response_time;
                            else 
                              s_counter_top   <= s_silence_time;
                            end if;

                            s_counter_reset   <= '1';
                            s_inc_bytes_c     <= '0';
                            s_reset_bytes_c   <= '1';
                            consume_byte_p_o  <= '0';
                            s_start_produce_p <= '0';
                            s_last_byte_p     <= '0';
                            s_reset_id_dat    <= '0';
                            s_byte_ready_p    <= '0';
                            s_load_temp_var   <= '0';
                            add_offset_o      <= (others => '0');


      when produce_wait_respon_time =>  
                            s_start_produce_p <= s_respon_silen_c_is_zero;
                            s_counter_reset   <= '0';

                            s_inc_bytes_c     <= '0';
                            s_reset_bytes_c   <= '1';
                            s_load_var        <= '1';
                            s_counter_top     <= s_silence_time;
                            consume_byte_p_o  <= '0';
                            s_load_temp_var   <= '0';
                            s_last_byte_p     <= '0';
                            s_reset_id_dat    <= '0';
                            s_byte_ready_p    <= '0';
                            add_offset_o      <= (others => '0'); 

	   
        
      when consume =>
                            --if unsigned(s_bytes_c) > 1 then -- 1st byte: control; not to be consumed--should be >0???
                            consume_byte_p_o  <= byte_ready_p_i;
                            --else
                            --  consume_byte_p_o <= '0';
                            --end if;

                            s_reset_id_dat    <= frame_ok_p_i or s_respon_silen_c_is_zero;
                            add_offset_o      <= std_logic_vector(resize(s_bytes_c,add_offset_o'length));
                            s_inc_bytes_c     <= byte_ready_p_i;

                            s_reset_bytes_c   <= '0';
                            s_counter_reset   <= '0';
                            s_load_var        <= '1';
                            s_counter_top     <= s_silence_time;
                            s_start_produce_p <= '0';
                            s_last_byte_p     <= '0';
                            s_load_temp_var   <= '0';
                            s_byte_ready_p    <= '0';



      when produce =>
                            s_last_byte_p     <=  s_data_length_match and request_byte_p_i;
                            s_byte_ready_p    <= request_byte_p_i or s_start_produce_p_d1;
                            s_inc_bytes_c     <= request_byte_p_i;
                            s_reset_id_dat    <= s_data_length_match and request_byte_p_i;
                            add_offset_o      <= std_logic_vector(resize(s_bytes_c, add_offset_o'length));
                            s_counter_reset   <= '0';

                            s_reset_bytes_c   <= '0';
                            s_start_produce_p <= '0';
                            s_load_var        <= '0';
                            s_counter_top     <= s_silence_time;
                            consume_byte_p_o  <= '0';
                            s_load_temp_var   <= '0';

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
    s_var_aux_concurr <= var_whatever;
    for I in c_VARS_ARRAY'range loop
      if byte_i = c_VARS_ARRAY(I).hexvalue then
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
        
        if s_reset_id_dat = '1' then 
          s_var_aux <= var_whatever; 

        elsif s_load_temp_var = '1' then
          s_var_aux <= s_var_aux_concurr;
        end if;
        
        if s_reset_id_dat = '1' then 
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
  variable v_nostat : std_logic_vector(1 downto 0);
  begin

    s_data_length <= (others => '0');
    s_p3_length_decoded <= c_P3_LGTH_TABLE (to_integer(unsigned(p3_lgth_i)));

    case s_var is


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -
      -- data length information retreival from the c_VARS_ARRAY matrix (wf_package) 
      when presence_var => 
        s_data_length<=to_unsigned(c_VARS_ARRAY(c_PRESENCE_VAR_INDEX).array_length,s_data_length'length);


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -
      -- data length information retreival from the c_VARS_ARRAY matrix (wf_package) 
      when identif_var => 
        s_data_length<=to_unsigned(c_VARS_ARRAY(c_IDENTIF_VAR_INDEX).array_length,s_data_length'length);


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -
      -- data length calculation according to the operational mode (memory or stand-alone)

      -- in slone mode                   2 bytes of "pure" data are produced
      -- to these there should be added: 1 byte rp_dat.Control
      --                                 1 byte MPS 
      --                      optionally 1 byte nFIP status
  
      -- in memory mode the signal      "s_p3_length_decoded" indicates the amount of "pure" data
      -- to these, there should be added 1 byte rp_dat.Control
      --                                 1 byte PDU
      --                                 1 byte Length
      --                                 1 byte MPS 
      --                      optionally 1 byte nFIP status  
    
      when var_3 =>  


        if slone_i = '1' then

          if nostat_i = '1' then
            s_data_length <= "00000011"; -- 4 bytes (counting starts from 0)

          else 
            s_data_length <= "00000100"; -- 5 bytes (counting starts from 0)
          end if;


        else
          if nostat_i = '0' then
            s_data_length <= s_p3_length_decoded + 4; -- (bytes counting starts from 0)

           else
            s_data_length <= s_p3_length_decoded + 3; -- (bytes counting starts from 0)
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
  data_length_o <= std_logic_vector(s_data_length);

 
--------------------------------------------------------------------------------------------------- 
--!@brief Synchronous process Bytes_Counter: Managment of the counter that counts the number of
--! produced or consumed bytes of data. 

  Bytes_Counter: process(uclk_i)
  begin
    if rising_edge(uclk_i) then
      if nFIP_rst_i = '1' then
        s_bytes_c <= to_unsigned(0, s_bytes_c'length);
      elsif s_reset_bytes_c = '1' then
        s_bytes_c <= to_unsigned(0, s_bytes_c'length);
      elsif s_inc_bytes_c = '1' then
        s_bytes_c <= s_bytes_c + 1;
      end if;
    end if;
  end process;
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
  -- when s_data_length bytes have been counted, the signal s_data_length_match is activated 
  s_data_length_match <= '1' when s_bytes_c = s_data_length else '0'; 
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
--! The signal s_counter_top initializes the counter to either the response or the silence time.

  Response_and_Silence_Time_Counter: process(uclk_i)
  begin
    if rising_edge(uclk_i) then
      if nFIP_rst_i = '1' then
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
--!@brief Synchronous process VAR_RDY_Generation: managment of the nanoFIP output signals VAR1_RDY,
--! VAR2_RDY and VAR3_RDY. 

--! VAR1_RDY (for consumed vars): signals that the user can safely read from the consumed variable
--! memory. The signal is asserted only after a consumed var has been received and there is data
--! in the memory to read.

--! VAR2_RDY (for broadcast consumed vars): signals that the user can safely read from the consumed
--! broadcast variable memory. The signal is asserted only after a consumed var has been received 
--! and there is data in the memory to read.

--! VAR3_RDY (for produced vars): signals that the user can safely write to the produced variable
--! memory. it is deasserted right after the end of the reception of an id_dat that requests a 
--! produced var and stays deasserted until the end of the transmission of the corresponding rp_dat
--! from nanoFIP (in detail, it stays deasserted until the end of the transmission of the
--! rp_dat.data field and is enabled during the rp_dat.fcs and rp_dat.fes transmission.

--! Note: the three memories (consumed, consumed broadcast, produced) are independant; therefore,
--! when a produced var is being sent, the user can read form the consumed memories. Similarly,
--! when a consumed variable is received the user can write to the produced momory.  


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
          var2_rdy_o <= s_var2_received;
          var3_rdy_o <= '1';

          s_var1_received <='0';
          var1_rdy_o <= '0';

          if frame_ok_p_i = '1' then 
            s_var1_received <= '1'; -- only if the crc of the received data is correct,
          end if;                   -- the nanoFIP signals the user to retreive data
                                    -- note: the signal s_var1_received stays asserted
                                    -- even after the end of the frame_ok_p_i pulse
      --  --  --  --  --  --  --  --
        elsif s_var = var_2 then 
          var1_rdy_o <= s_var1_received;
          var3_rdy_o <= '1';

          var2_rdy_o <= '0';

          if frame_ok_p_i = '1' then 
            s_var2_received <= '1'; -- only if the crc of the received data is correct,
          end if;                   -- the nanoFIP signals the user to retreive data
                                    -- note: the signal s_var1_received stays asserted
                                    -- even after the end of the frame_ok_p_i pulse

      --  --  --  --  --  --  --  --
        elsif s_var = var_3 then 
          var1_rdy_o <= s_var1_received;
          var2_rdy_o <= s_var2_received;
          var3_rdy_o <= '0';

      --  --  --  --  --  --  --  --
        else
          var1_rdy_o <= s_var1_received;
          var2_rdy_o <= s_var2_received;
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
      if nFIP_rst_i = '1' then
        last_byte_p_o <= '0';
        byte_ready_p_o <= '0';
        s_start_produce_p_d1 <= '0';
      else
        s_last_byte_p_d <= s_last_byte_p;
        last_byte_p_o <= s_last_byte_p_d;

        s_byte_ready_p_d <= s_byte_ready_p;
        byte_ready_p_o <= s_byte_ready_p_d;
        s_start_produce_p_d1 <= s_start_produce_p;
      end if;
    end if;
  end process;
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --   
  start_produce_p_o <= s_start_produce_p_d1;

---------------------------------------------------------------------------------------------------


end architecture rtl;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------