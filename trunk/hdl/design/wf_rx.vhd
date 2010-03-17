--===========================================================================
--! @file wf_rx.vhd
--! @brief Deserialises the WorldFIP data
--===========================================================================
--! Standard library
library IEEE;

--! Standard packages
use IEEE.STD_LOGIC_1164.all; --! std_logic definitions
use IEEE.NUMERIC_STD.all;    --! conversion functions

use work.wf_package.all;

-------------------------------------------------------------------------------
--                                                                           --
--                                 wf_rx                                 --
--                                                                           --
--                               CERN, BE/CO/HT                              --
--                                                                           --
-------------------------------------------------------------------------------
--
-- unit name: wf_rx
--
--! @brief Serialises and deserialises the WorldFIP data.
--!
--! Used in the NanoFIP design. \n
--! This unit serializes the data.
--!
--!
--! @author	    Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)
--!
--! @date 10/08/2009
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
--! Author: Erik van der Bij
--!         Pablo Alvarez Sanchez
-------------------------------------------------------------------------------
--! \n\n<b>Last changes:</b>\n
--! 07/08/2009  v0.02  PAAS Entity Ports added, start of architecture content
--!
-------------------------------------------------------------------------------
--! @todo Define I/O signals \n
--!
-------------------------------------------------------------------------------



--============================================================================
--! Entity declaration for wf_tx
--============================================================================
entity wf_rx is

port (
   uclk_i    : in std_logic; --! User Clock
   rst_i     : in std_logic;
   
	
	byte_ready_p_o : out std_logic;
	byte_o : out std_logic_vector(7 downto 0);
	last_byte_p_o : out std_logic;
	fss_decoded_p_o : out std_logic;
	code_violation_p_o : out std_logic;
	crc_bad_p_o : out std_logic;
	crc_ok_p_o : out std_logic;
	d_re_i : in std_logic;
	d_fe_i : in std_logic;
	d_filtered_i : in std_logic;
	s_d_ready_p_i : in std_logic;
   load_phase_o : out std_logic;	
	clk_bit_180_p_i  : in std_logic;
	edge_window_i : in std_logic;
   edge_180_window_i : in std_logic
		
);

end entity wf_rx;



-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--! ARCHITECTURE OF wf_tx_rx
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
architecture rtl of wf_rx is

constant ONE : std_logic_vector(1 downto 0) := "10";
constant ZERO : std_logic_vector(1 downto 0) := "01";
constant VP : std_logic_vector(1 downto 0) := "11";
constant VN : std_logic_vector(1 downto 0) := "00";

constant PREAMBLE : std_logic_vector(15 downto 0) := ONE&ZERO&ONE&ZERO&ONE&ZERO&ONE&ZERO;
constant FRAME_START : std_logic_vector(15 downto 0) := ONE&VP&VN&ONE&ZERO&VN&VP&ZERO;


--constant HEADER : std_logic_vector(31 downto 0) := PREAMBLE&FRAME_START;
constant QUEUE : std_logic_vector(15 downto 0) := ONE&VP&VN&VP&VN&ONE&ZERO&ONE;
--constant C_PATTERNS : std_logic_vector(45 downto 0) := HEADER&QUEUE;

--constant RP_DAT : std_logic_vector(11 downto 0) := ZERO&ONE&ZERO&ZERO&ZERO&ZERO;

type rx_st_t  is (w_1,w_2,w_3,w_4, w_frame_start, w_byte);

signal rx_st, nx_rx_st : rx_st_t;

signal pointer, s_start_pointer : unsigned(3 downto 0);
signal s_inc_pointer : std_logic;
signal s_re_edge_on_phase, s_fe_edge_on_phase, s_edge_not_on_phase: std_logic;
signal s_re_edge_180_on_phase : std_logic;
signal s_clk_bit_180_p_d : std_logic;

signal s_code_violation : std_logic;

signal s_frame_start_bit  : std_logic;
signal s_queue_bit  : std_logic;
signal s_good_header_bit  : std_logic;
--signal s_good_queue_bit  : std_logic;
signal s_bad_frame_start_bit  : std_logic;
signal s_bad_queue_bit  : std_logic;
signal s_last_frame_start_bit  : std_logic;
--signal s_last_queue_bit : std_logic;
signal s_pointer_is_zero  : std_logic;
--signal s_good_zero : std_logic;
signal s_load_pointer : std_logic;
signal s_byte_ok : std_logic;
signal s_write_bit_to_byte : std_logic;
--signal edge_window_i : std_logic;
signal s_d_filtered_d : std_logic;
signal s_byte : std_logic_vector(7 downto 0);
signal s_good_queue_detected_p, s_good_queue_detected : std_logic;
signal s_crc_ok_p, s_crc_ok,  s_start_crc_p : std_logic;
begin


uwf_crc : wf_crc 
generic map( 
			c_poly_length => 16)
port map(
   uclk_i => uclk_i, --! User Clock
   rst_i => rst_i,
   
   start_p_i => s_start_crc_p,
	d_i  => s_d_filtered_d,
	d_rdy_p_i  => s_write_bit_to_byte,
	data_fcs_sel_n => '1',
	crc_o  => open,
	crc_rdy_p_o => open,
	crc_ok_p => s_crc_ok_p
);


process(uclk_i)
   begin
      if rising_edge(uclk_i) then
         if rst_i = '1' then
            rx_st <= w_1;
			else
            rx_st <= nx_rx_st;
         end if;
      end if;
end process;

process(rx_st,d_fe_i, s_good_queue_detected_p, s_bad_queue_bit, s_bad_frame_start_bit,  s_bad_frame_start_bit, s_fe_edge_on_phase, s_re_edge_on_phase, s_re_edge_180_on_phase, s_edge_not_on_phase,  s_last_frame_start_bit,  s_code_violation)
begin
nx_rx_st <= w_1;
case rx_st is 


   --w_x states verify the unfiltered signal timing  
   when w_1 =>  -- I start detecting the first one, falling edge
                         if d_fe_i = '1' then
                            nx_rx_st <= w_2;
                         else
                            nx_rx_st <= w_1;
                         end if;	
   when w_2 =>  -- If there is a zero ,rising edge, then I jump to 3
                         if s_re_edge_on_phase = '1' then
                            nx_rx_st <= w_3;
                         elsif s_edge_not_on_phase = '1' then
                            nx_rx_st <= w_1;
                         else 
                            nx_rx_st <= w_2;
                         end if;	
   when w_3 =>  -- I wait for a one (falling edge)
                         if s_fe_edge_on_phase = '1' then
                            nx_rx_st <= w_4;
                         elsif s_edge_not_on_phase = '1' then
                            nx_rx_st <= w_1;
                         else 
                            nx_rx_st <= w_3;
                         end if;	
   when w_4 =>                          -- If the preamble is still being sent I will detect a zero, re,  and jump to w3
					-- If the start delimeter is received I will detect a one (fe) 
					-- Receiveing an edge not in phase means the header is going to be received next
					-- Eventually a glitch could be confused with such an event, but the header decoding
					-- and CRC should indicate that a bad frame has been decoded
                         if s_re_edge_180_on_phase = '1' then
                            nx_rx_st <= w_frame_start ;
                         elsif s_re_edge_on_phase = '1' then
                            nx_rx_st <= w_3;
                         elsif s_fe_edge_on_phase = '1' then
                            nx_rx_st <= w_1;				
                         elsif s_edge_not_on_phase = '1' then  -- In c
                            nx_rx_st <= w_1;
                         else 
                            nx_rx_st <= w_4;
                         end if;				
	-- w_header and w_byte use the filtered serial data
   when w_frame_start => 
                         if s_last_frame_start_bit = '1' then
                            nx_rx_st <= w_byte;
                         elsif s_bad_frame_start_bit = '1' then
                            nx_rx_st <= w_1;
                         else
                            nx_rx_st <= w_frame_start;			
                         end if;
   when w_byte =>
                         if s_good_queue_detected_p = '1' then
                            nx_rx_st <= w_1;
					-- Is there a code violation that does not correspond to the queue pattern?
                         elsif s_bad_queue_bit = '1' and s_code_violation = '1' then
                            nx_rx_st <= w_1;				
                         else
                            nx_rx_st <= w_byte;
                         end if;	
   when others => 
                         nx_rx_st <= w_1;
end case;	
end process;

process(rx_st, s_last_frame_start_bit, s_good_queue_detected_p, s_bad_queue_bit,  s_bad_queue_bit,  s_pointer_is_zero, s_re_edge_180_on_phase,  edge_window_i, s_d_ready_p_i, s_clk_bit_180_p_d, s_code_violation)
begin
   load_phase_o <= '0';
   s_inc_pointer <= '0';
   s_load_pointer <= '0';
   s_byte_ok <= '0';
   s_write_bit_to_byte <= '0';
   s_start_pointer <= to_unsigned(0,s_start_pointer'length);
   s_start_crc_p <= '0';
   fss_decoded_p_o <= '0';
   code_violation_p_o <= '0';
case rx_st is 
   when w_1 =>
      load_phase_o <= '1';
   when w_2 =>
      load_phase_o <= edge_window_i;
   when w_3 =>
      load_phase_o <= edge_window_i;
   when w_4 => 
      load_phase_o <= edge_window_i;
      s_start_pointer <= to_unsigned(FRAME_START'left-1,s_start_pointer'length);
      s_load_pointer <=  s_re_edge_180_on_phase;
   when w_frame_start =>
      load_phase_o <= edge_window_i;
      s_inc_pointer <= s_d_ready_p_i;
      s_start_pointer <= to_unsigned(QUEUE'left,s_start_pointer'length);
      s_load_pointer <=  s_pointer_is_zero and s_clk_bit_180_p_d;    
      s_start_crc_p <= '1';
      fss_decoded_p_o <= s_last_frame_start_bit;
      code_violation_p_o <= s_bad_queue_bit and s_code_violation;

   when w_byte =>
      load_phase_o <= edge_window_i;
      s_inc_pointer <= s_d_ready_p_i;
      s_write_bit_to_byte <= s_clk_bit_180_p_d;
      s_byte_ok <= s_pointer_is_zero and s_clk_bit_180_p_d and (not s_good_queue_detected_p) and (not s_code_violation);
      s_start_pointer <= to_unsigned(QUEUE'left,s_start_pointer'length);
      s_load_pointer <=  s_pointer_is_zero and s_clk_bit_180_p_d;
   when others => 
end case;	
end process;

s_re_edge_on_phase <= edge_window_i and d_re_i;
s_fe_edge_on_phase <= edge_window_i and d_fe_i;
s_re_edge_180_on_phase <= edge_180_window_i and ( d_re_i);
s_edge_not_on_phase <= (not edge_window_i)and (d_re_i or d_fe_i);

process(uclk_i)
   begin
      if rising_edge(uclk_i) then
         if s_d_ready_p_i = '1' then
            s_d_filtered_d <= d_filtered_i;
         end if;
         s_clk_bit_180_p_d <= clk_bit_180_p_i;
      end if;
end process;

s_code_violation <=  (not(s_d_filtered_d xor d_filtered_i)) and s_clk_bit_180_p_d;
s_frame_start_bit <= FRAME_START(to_integer(pointer));
s_queue_bit <= QUEUE(to_integer(resize(pointer,4)));
s_good_header_bit <= (s_frame_start_bit xnor  d_filtered_i )and s_d_ready_p_i;
s_bad_frame_start_bit <= (s_frame_start_bit xor  d_filtered_i )and s_d_ready_p_i;
s_bad_queue_bit <= (s_queue_bit xor  d_filtered_i) and s_d_ready_p_i;
s_last_frame_start_bit <= s_pointer_is_zero and s_good_header_bit and s_clk_bit_180_p_d;
s_good_queue_detected_p <= s_good_queue_detected and s_clk_bit_180_p_d and s_pointer_is_zero;

process(uclk_i)
   begin
      if rising_edge(uclk_i) then
         if rst_i = '1' then
            s_good_queue_detected <= '1';
         elsif s_clk_bit_180_p_d = '1' and s_pointer_is_zero = '1' then 
            s_good_queue_detected <= '1';
         elsif  s_bad_queue_bit = '1' then
            s_good_queue_detected <= '0';
         end if;
      end if;
end process;

s_pointer_is_zero <= '1' when pointer = 0 else '0';

process(uclk_i)
   begin
      if rising_edge(uclk_i) then
         if s_load_pointer = '1' then
            pointer <= s_start_pointer;
         elsif s_inc_pointer = '1' then
            pointer <= pointer - 1;
         end if;
      end if;
end process;


process(uclk_i)
   begin
      if rising_edge(uclk_i) then
         if s_write_bit_to_byte = '1' then
            s_byte <= s_byte(6 downto 0) & s_d_filtered_d;
         end if;
      end if;
end process;

process(uclk_i)
   begin
      if rising_edge(uclk_i) then
         if rst_i = '1' then
            s_crc_ok <= '0';		
         elsif s_byte_ok = '1' then
            s_crc_ok <= '0';
         elsif s_crc_ok_p = '1' then 
            s_crc_ok <= '1';
         end if;
      end if;
end process;


process(uclk_i)
   begin
      if rising_edge(uclk_i) then 
         if rst_i = '1' then
            byte_ready_p_o <= '0'; 
         else
            byte_ready_p_o <= s_byte_ok and (not s_good_queue_detected_p); 
         end if;
      end if;
end process; 

byte_o <= s_byte; 
last_byte_p_o <= s_good_queue_detected_p;
crc_ok_p_o <= s_good_queue_detected_p and s_crc_ok;
crc_bad_p_o <= s_good_queue_detected_p and (not s_crc_ok);

end architecture rtl;
-------------------------------------------------------------------------------
--                          E N D   O F   F I L E
-------------------------------------------------------------------------------