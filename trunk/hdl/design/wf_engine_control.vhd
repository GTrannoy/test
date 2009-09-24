--===========================================================================
--! @file wf_engine_control.vhd
--! @brief Nanofip control unit
--===========================================================================
--! Standard library
library IEEE;
--! Standard packages
use IEEE.STD_LOGIC_1164.all; --! std_logic definitions
use IEEE.NUMERIC_STD.all;    --! conversion functions

use work.wf_package.all;

-------------------------------------------------------------------------------
--                                                                           --
--                                 wf_engine_control                                 --
--                                                                           --
--                               CERN, BE/CO/HT                              --
--                                                                           --
-------------------------------------------------------------------------------
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
--! Author: 
-------------------------------------------------------------------------------
--! \n\n<b>Last changes:</b>\n
--! 11/09/2009  v0.01  EB  First version \n
--!
-------------------------------------------------------------------------------
--! @todo 
--!
-------------------------------------------------------------------------------



--============================================================================
--! Entity declaration for wf_engine_control
--============================================================================
entity wf_engine_control is
generic( C_QUARTZ_PERIOD : real := 25.0);

port (
   uclk_i    : in std_logic; --! User Clock
   rst_i     : in std_logic;

   -- Transmiter interface
   start_send_p_o  : out std_logic;
	request_byte_p_i : in std_logic;
	byte_ready_p_o : out std_logic;
-- 	byte_o : out std_logic_vector(7 downto 0);
	last_byte_p_o : out std_logic;
 

   -- Receiver interface
	fss_decoded_p_i : in std_logic;  -- The frame decoder has detected the start of a frame
	byte_ready_p_i : in std_logic;   -- The frame docoder ouputs a new byte on byte_i
	byte_i : in std_logic_vector(7 downto 0);  -- Decoded byte
	frame_ok_p_i : in std_logic;     
	
	-- Worldfip bit rate
	rate_i    : in std_logic_vector(1 downto 0);
	
   subs_i    : in  std_logic_vector (7 downto 0); --! Subscriber number coding.


      --! Produced variable data length \n
      --! 000: 2 Bytes                  \n
      --! 001: 8 Bytes                  \n
      --! 010: 16 Bytes                 \n
      --! 011: 32 Bytes                 \n
      --! 100: 64 Bytes                 \n
      --! 101: 124 Bytes                \n
      --! 110: reserved, do not use     \n
      --! 111: reserved, do not use     \n
      --! Actual size: +1 NanoFIP Status byte +1 MPS Status byte (last transmitted) 
      --! Note: when SLONE=Vcc, p3_lgth_i should be set to 000.
   p3_lgth_i : in  std_logic_vector (2 downto 0); --! Produced variable data length

      --! Stand-alone mode
      --! If connected to Vcc, disables sending of NanoFIP status together with 
      --! the produced data.
   slone_i   : in  std_logic; --! Stand-alone mode


      --! No NanoFIP status transmission
      --! If connected to Vcc, disables sending of NanoFIP status together with 
      --! the produced data.
   nostat_i  : in  std_logic; --! No NanoFIP status transmission

-------------------------------------------------------------------------------
--  USER INTERFACE, non WISHBONE
-------------------------------------------------------------------------------

      --! Signals new data is received and can safely be read (Consumed 
      --! variable 05xyh). In stand-alone mode one may sample the data on the 
      --! first clock edge VAR1_RDY is high.
   var1_rdy_o: out std_logic; --! Variable 1 ready

      --! Signals new data is received and can safely be read (Consumed 
      --! broadcast variable 04xyh). In stand-alone mode one may sample the 
      --! data on the first clock edge VAR1_RDY is high.
   var2_rdy_o: out std_logic; --! Variable 2 ready


      --! Signals that the variable can safely be written (Produced variable 
      --! 06xyh). In stand-alone mode, data is sampled on the first clock after
      --! VAR_RDY is deasserted.
   var3_rdy_o: out std_logic; --! Variable 3 ready



--   prod_byte_i : in std_logic_vector(7 downto 0);
	var_o : out t_var;
	append_status_o : out std_logic;
	add_offset_o : out std_logic_vector(6 downto 0);
	data_length_o : out std_logic_vector(6 downto 0);
	cons_byte_we_p_o : out std_logic
);

end entity wf_engine_control;



-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--! ARCHITECTURE OF wf_control
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
architecture rtl of wf_engine_control is



type control_st_t  is (cont_idle, cont_w_id_dat_control, cont_w_id_dat_subs, cont_w_id_dat_var, cont_w_id_dat_frame_ok, 
cont_w_prod_watchdog, cont_w_cons_watchdog, cont_cons_var, cont_prod_var);


signal control_st, nx_control_st : control_st_t;
signal temp_var, var, nx_temp_var : t_var;

signal s_watchdog_c, s_watchdog_top, s_response_time, s_silence_time  : signed(16 downto 0);
signal s_reset_watchdog_c : std_logic;
signal s_p3_length_decoded : unsigned(6 downto 0);
--signal produce, consume : std_logic;
signal data_length : unsigned(6 downto 0);
signal s_reset_id_data : std_logic;
signal s_watchdog_is_zero : std_logic;
signal s_broadcast : std_logic;
signal s_byte_c : unsigned(6 downto 0);
signal s_inc_bytes_c, s_reset_bytes_c : std_logic;
signal s_prodcons : std_logic_vector(1 downto 0);
signal nx_last_byte_p : std_logic;
signal s_load_temp_var : std_logic;
signal s_load_var : std_logic;
signal data_length_match : std_logic;
signal  nx_byte_ready_p : std_logic;
signal s_append_status : std_logic;
signal var1_was_received, var2_was_received : std_logic;
begin

	
	
process(uclk_i)
   begin
      if rising_edge(uclk_i) then
         if rst_i = '1' then
            control_st <= cont_idle;
			else
            control_st <= nx_control_st;
         end if;
      end if;
end process;




process(control_st, fss_decoded_p_i, nx_last_byte_p, nx_temp_var, byte_ready_p_i, byte_i, subs_i, s_prodcons, frame_ok_p_i, s_broadcast, nx_temp_var, s_watchdog_is_zero)
   begin
	nx_control_st <= cont_idle;
   case control_st is
      when cont_idle => if fss_decoded_p_i = '1' then
		                           nx_control_st <= cont_w_id_dat_control;
								else
		                           nx_control_st <= cont_idle;
								end if;
	   when cont_w_id_dat_control =>   if (byte_ready_p_i = '1') and (byte_i =  c_id_dat) then
		                                   nx_control_st <= cont_w_id_dat_subs;
											     elsif (byte_ready_p_i = '1') then
		                                   nx_control_st <= cont_idle;
 												  else
		                                   nx_control_st <= cont_w_id_dat_control;
											     end if;
												  
	   when cont_w_id_dat_subs =>      
		                                   if (byte_ready_p_i = '1') and (byte_i = subs_i) then
		                                      nx_control_st <= cont_w_id_dat_var;
											        elsif (byte_ready_p_i = '1') and (s_broadcast = '1') then
		                                      nx_control_st <= cont_w_id_dat_var;
											        elsif (byte_ready_p_i = '1') then
		                                      nx_control_st <= cont_idle;
												     else
		                                      nx_control_st <= cont_w_id_dat_subs;
											        end if;
	   when cont_w_id_dat_var =>      
		                                   if (byte_ready_p_i = '1') and (nx_temp_var /= c_st_var_whatever) then
		                                      nx_control_st <= cont_w_id_dat_frame_ok;
											        elsif  (byte_ready_p_i = '1') and (nx_temp_var = c_st_var_whatever) then
		                                      nx_control_st <= cont_idle;
											        else
		                                      nx_control_st <= cont_w_id_dat_var;
											        end if;


	   when cont_w_id_dat_frame_ok =>   if (frame_ok_p_i = '1') and (s_prodcons = "10") then
		                                   nx_control_st <= cont_w_prod_watchdog;
											     elsif (frame_ok_p_i = '1') and (s_prodcons = "01") then
		                                   nx_control_st <= cont_w_cons_watchdog;
											     elsif (frame_ok_p_i = '1') then
		                                   nx_control_st <= cont_idle;
											     elsif fss_decoded_p_i = '1' then
		                                   nx_control_st <= cont_w_id_dat_control;
												  else
		                                   nx_control_st <= cont_w_id_dat_frame_ok;
											     end if;
												  
	   when cont_w_prod_watchdog =>   if s_watchdog_is_zero = '1' then
		                           nx_control_st <= cont_prod_var;
										else
	                              nx_control_st <= cont_w_prod_watchdog;
                              end if;
--	   when cont_w_cons_watchdog =>   if s_watchdog_is_zero = '1' then
--		                           nx_control_st <= cont_cons_var;
--										else
--	                              nx_control_st <= cont_w_cons_watchdog;
--                              end if;

	   when cont_cons_var =>   if frame_ok_p_i = '1' or s_watchdog_is_zero = '1' then
		                           nx_control_st <= cont_idle;
										else
	                              nx_control_st <= cont_cons_var;
                              end if;
	   when cont_prod_var =>   if nx_last_byte_p = '1' then
		                           nx_control_st <= cont_idle;
										else
	                              nx_control_st <= cont_prod_var;
                              end if;
	   when others =>          nx_control_st <= cont_idle;
    end case;                         
end process;


process(control_st, frame_ok_p_i,  s_prodcons, s_response_time, s_silence_time, request_byte_p_i,  s_watchdog_is_zero, byte_ready_p_i, data_length_match)
   begin
	s_reset_watchdog_c <= '1';
	s_inc_bytes_c <= '0';
	s_reset_bytes_c <= '1';
	s_load_temp_var <= '0';
	s_load_var <= '0';
	s_watchdog_top <= s_silence_time;
	cons_byte_we_p_o <= '0';
	start_send_p_o <= '0';
	nx_last_byte_p <= '0';
	s_reset_id_data <= '0';
	nx_byte_ready_p <= '0';
   case control_st is
	   when cont_w_id_dat_var => 
		     s_load_temp_var <= byte_ready_p_i;
	   when cont_w_id_dat_frame_ok => 
		     if s_prodcons = "10" then
	            s_watchdog_top <= s_response_time;
			  else 
	            s_watchdog_top <= s_silence_time;
			  end if;
			  	s_reset_watchdog_c <= '1';
			  s_load_var <= '1';

	   when cont_w_prod_watchdog =>  
				start_send_p_o <= s_watchdog_is_zero;
	         s_reset_watchdog_c <= '0';	   
				
	   when cont_cons_var =>
			  	s_reset_watchdog_c <= '0';
		      s_inc_bytes_c <= byte_ready_p_i;
		      cons_byte_we_p_o <= byte_ready_p_i;
				s_reset_id_data <= frame_ok_p_i or s_watchdog_is_zero;
	   when cont_prod_var =>
			  	s_reset_watchdog_c <= '0';	
		      nx_last_byte_p <=  data_length_match and request_byte_p_i;
				nx_byte_ready_p <= request_byte_p_i;
		      s_inc_bytes_c <= request_byte_p_i;
	         s_reset_bytes_c <= '0';
				s_reset_id_data <= nx_last_byte_p;
	   when others =>   
    end case;                         
end process;
   

	
--	
--process(byte_i)
--begin
--nx_temp_var <= c_st_var_whatever;
--case byte_i is
--   when c_var_presence =>  nx_temp_var <= c_st_var_presence;
--	
--   when c_var_identification =>  nx_temp_var <= c_st_var_identification;
--   when c_var_1 =>  nx_temp_var <= c_st_var_1;
--   when c_var_2 =>  nx_temp_var <= c_st_var_2;
--   when c_var_3 =>  nx_temp_var <= c_st_var_3;
--   when c_var_reset =>  nx_temp_var <= c_st_var_reset;
--   when others =>  nx_temp_var <= c_st_var_whatever;
--end case;
--end process;

process(byte_i)
begin
 nx_temp_var <= c_st_var_whatever;
for I in c_var_array'range loop
if byte_i = c_var_array(I).hexvalue then
nx_temp_var <= c_var_array(I).var;
exit;
end if;
end loop;
end process;


process(uclk_i)
begin
if rising_edge(uclk_i) then
 if rst_i = '1' then 
       var <= c_st_var_whatever;
 else
 
    if s_reset_id_data = '1' then 
       temp_var <= c_st_var_whatever;
    elsif s_load_temp_var = '1' then
       temp_var <= nx_temp_var;
    end if;
	 
    if s_reset_id_data = '1' then 
       var <= c_st_var_whatever;
    elsif s_load_var = '1' then
       var <= temp_var;
    end if;
 end if;
 end if;
end process;



process(temp_var)
begin
s_prodcons <= "00";
for I in c_var_array'range loop
if temp_var = c_var_array(I).var then
if c_var_array(I).response = produce then
s_prodcons <= "10";
else
s_prodcons <= "01";
end if;
exit;
end if;
end loop;
end process;

process(temp_var)
begin
      s_broadcast <= '0';
   if  temp_var = c_st_var_2 then
      s_broadcast <= '1';
   end if;
end process;


process(var, s_p3_length_decoded, nostat_i)
variable v_nostat : std_logic_vector(1 downto 0);
begin
v_nostat := ('0'& ((not nostat_i) and (not slone_i)));
s_append_status <= '0';
data_length <= to_unsigned(0,data_length'length);
case var is
   when c_st_var_presence =>
      data_length <= to_unsigned(6,data_length'length);
   when c_st_var_identification => 
      data_length <= to_unsigned(9,data_length'length);
   when c_st_var_1 => 
   when c_st_var_2 =>
   when c_st_var_3 =>  
      s_append_status <= not nostat_i;
		if nostat_i = '1' then
         data_length <= to_unsigned(3,data_length'length);
		else
         data_length <= s_p3_length_decoded + unsigned(v_nostat) ;
		end if;
   when c_st_var_reset =>  
   when others => 
end case;
end process;

append_status_o <= s_append_status;
data_length_o <= std_logic_vector(data_length); 

--process(p3_lgth_i)
--begin
-- s_p3_length_decoded <= to_unsigned(0, s_p3_length_decoded'length);
--case p3_lgth_i is 
--   when "000" =>  s_p3_length_decoded <= to_unsigned(2, s_p3_length_decoded'length);
--   when "001" =>  s_p3_length_decoded <= to_unsigned(8, s_p3_length_decoded'length);
--   when "010" =>  s_p3_length_decoded <= to_unsigned(16, s_p3_length_decoded'length);
--   when "011" =>  s_p3_length_decoded <= to_unsigned(32, s_p3_length_decoded'length);
--   when "100" =>  s_p3_length_decoded <= to_unsigned(64, s_p3_length_decoded'length);
--   when "101" =>  s_p3_length_decoded <= to_unsigned(124, s_p3_length_decoded'length);
--   when "110" =>  s_p3_length_decoded <= to_unsigned(0, s_p3_length_decoded'length);
--   when "111" =>  s_p3_length_decoded <= to_unsigned(0, s_p3_length_decoded'length);
--	when others => s_p3_length_decoded <= to_unsigned(0, s_p3_length_decoded'length);
--end case;
--end process;

s_p3_length_decoded <= to_unsigned(c_p3_var_length_table(to_integer(unsigned(p3_lgth_i))), s_p3_length_decoded'length);

--process(rate_i)
--begin
--   s_response_time <= to_signed(integer(c_response_time_31k25/C_QUARTZ_PERIOD), s_response_time'length);
--   s_silence_time <= to_signed(integer(c_silence_time_31k25/C_QUARTZ_PERIOD), s_silence_time'length);
--case rate_i is 
--   when "00" =>  s_response_time <= to_signed(integer(c_response_time_31k25/C_QUARTZ_PERIOD), s_response_time'length);
--                 s_silence_time <= to_signed(integer(c_silence_time_31k25/C_QUARTZ_PERIOD), s_silence_time'length);
--
--   when "01" =>   s_response_time <= to_signed(integer(c_response_time_1M/C_QUARTZ_PERIOD), s_response_time'length);
--                 s_silence_time <= to_signed(integer(c_silence_time_1M/C_QUARTZ_PERIOD), s_silence_time'length);
--   when "10" =>   s_response_time <= to_signed(integer(c_response_time_2M5/C_QUARTZ_PERIOD), s_response_time'length);
--                 s_silence_time <= to_signed(integer(c_silence_time_2M5/C_QUARTZ_PERIOD), s_silence_time'length);
--
--	when others =>
--   s_response_time <= to_signed(integer(c_response_time_31k25/C_QUARTZ_PERIOD), s_response_time'length);
--   s_silence_time <= to_signed(integer(c_silence_time_31k25/C_QUARTZ_PERIOD), s_silence_time'length);
--
--end case;
--end process;

s_response_time <= to_signed((c_timeouts_table(to_integer(unsigned(rate_i))).response), s_response_time'length);
s_silence_time <= to_signed((c_timeouts_table(to_integer(unsigned(rate_i))).silence), s_response_time'length);
		  
process(uclk_i)
begin
if rising_edge(uclk_i) then
   if rst_i = '1' then
	 s_byte_c <= to_unsigned(0, s_byte_c'length);
	elsif s_reset_bytes_c = '1' then
	 s_byte_c <= to_unsigned(0, s_byte_c'length);
	elsif s_inc_bytes_c = '1' then
	 s_byte_c <= s_byte_c + 1;
	end if;
end if;
end process;

add_offset_o <= std_logic_vector(s_byte_c);
data_length_match <= '1' when s_byte_c = data_length else '0'; 

process(uclk_i)
begin
if rising_edge(uclk_i) then
   if rst_i = '1' then
	 s_watchdog_c <= to_signed(-1, s_watchdog_c'length);
	elsif s_reset_watchdog_c = '1' then
	 s_watchdog_c <= s_watchdog_top;
	else
	 s_watchdog_c <= s_watchdog_c -1;
	end if;
end if;
end process;
s_watchdog_is_zero <= '1' when s_watchdog_c = 0 else '0';

process(uclk_i)
begin
if rising_edge(uclk_i) then
   if rst_i = '1' then
	 last_byte_p_o <= '0';
	 byte_ready_p_o <= '0';
	else
	 last_byte_p_o <= nx_last_byte_p;
	 byte_ready_p_o <= nx_byte_ready_p;
	end if;
end if;
end process;


process(uclk_i)
begin
if rising_edge(uclk_i) then
   if rst_i = '1' then
	 var1_rdy_o<= '0';
	 var1_was_received <= '0';
	elsif var = c_st_var_1 then 
	 var1_rdy_o <= '0';
	 var1_was_received <= '1'; -- After a reset var1_rdy must not be asserted
	else
	 var1_rdy_o <= var1_was_received; -- After a reset var1_rdy must not be asserted
   end if;	 

   if rst_i = '1' then
	 var2_rdy_o<= '0';
	 var2_was_received <= '0';
	elsif var = c_st_var_2 then 
	 var2_rdy_o <= '0';
	 var2_was_received <= '1';
	else 
	 var2_rdy_o <= var2_was_received; -- After a reset var2_rdy must not be asserted
   end if;	 

   if rst_i = '1' then
	 var3_rdy_o<= '0';
	elsif var = c_st_var_3 then 
	 var3_rdy_o <= '1';
	else 
	 var3_rdy_o <= '0';
   end if;	 	 

end if;
end process;

var_o <= var;
end architecture rtl;
-------------------------------------------------------------------------------
--                          E N D   O F   F I L E
-------------------------------------------------------------------------------
