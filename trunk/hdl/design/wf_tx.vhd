--===========================================================================
--! @file wf_tx.vhd
--! @brief Serialises and deserialises the WorldFIP data
--===========================================================================
--! Standard library
library IEEE;
--! Standard packages
use IEEE.STD_LOGIC_1164.all; --! std_logic definitions
use IEEE.NUMERIC_STD.all;    --! conversion functions

use work.wf_package.all;

-------------------------------------------------------------------------------
--                                                                           --
--                                 wf_tx                                 --
--                                                                           --
--                               CERN, BE/CO/HT                              --
--                                                                           --
-------------------------------------------------------------------------------
--
-- unit name: wf_tx
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
--! Entity declaration for wf_tx_rx
--============================================================================
entity wf_tx is
generic(
			C_CLKFCDLENTGTH :  natural := 3 );
port (
   uclk_i    : in std_logic; --! User Clock
   rst_i     : in std_logic;

   start_send_p_i  : in std_logic;
	request_byte_p_o : out std_logic;
	byte_ready_p_i : in std_logic; -- byte_ready_p_i is not used
	byte_i : in std_logic_vector(7 downto 0);
	last_byte_p_i : in std_logic;
	
--	 clk_fixed_carrier_p_d_i(0) : in std_logic;
    clk_fixed_carrier_p_d_i : in std_logic_vector(C_CLKFCDLENTGTH -1 downto 0);

	d_o : out std_logic;
	d_e_o : out std_logic
);

end entity wf_tx;



-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--! ARCHITECTURE OF wf_tx_rx
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
architecture rtl of wf_tx is

constant ONE : std_logic_vector(1 downto 0) := "10";
constant ZERO : std_logic_vector(1 downto 0) := "01";
constant VP : std_logic_vector(1 downto 0) := "11";
constant VN : std_logic_vector(1 downto 0) := "00";

constant PREAMBLE : std_logic_vector(15 downto 0) := ONE&ZERO&ONE&ZERO&ONE&ZERO&ONE&ZERO;
constant FRAME_START : std_logic_vector(15 downto 0) := ONE&VP&VN&ONE&ZERO&VN&VP&ZERO;

constant HEADER : std_logic_vector(31 downto 0) := PREAMBLE&FRAME_START;
constant QUEUE : std_logic_vector(15 downto 0) := ONE&VP&VN&VP&VN&ONE&ZERO&ONE;
--constant RP_DAT : std_logic_vector(11 downto 0) := ZERO&ONE&ZERO&ZERO&ZERO&ZERO;

type tx_st_t  is (tx_idle, tx_header, tx_byte, tx_last_byte, tx_crc_byte, tx_queue);

signal tx_st, nx_tx_st : tx_st_t;

signal s_pointer, s_top_pointer : unsigned(4 downto 0);
signal s_manchester_byte : std_logic_vector(15 downto 0);
signal s_reset_pointer, s_inc_pointer, s_pointer_is_zero, s_pointer_is_one : std_logic;
signal s_nx_data, s_nx_data_e : std_logic;
signal s_byte : std_logic_vector(7 downto 0);
signal s_d_to_crc_rdy_p : std_logic;
signal s_crc : std_logic_vector(15 downto 0);
signal s_manchester_crc : std_logic_vector(31 downto 0);
signal s_start_crc_p : std_logic;
signal s_calc_crc, s_nx_data_to_crc : std_logic;
begin

uwf_crc : wf_crc 
generic map( 
			c_poly_length => 16)
port map(
   uclk_i => uclk_i, --! User Clock
   rst_i => rst_i,
   
   start_p_i => s_start_crc_p,
	d_i  => s_nx_data_to_crc,
	d_rdy_p_i  => s_d_to_crc_rdy_p,

	data_fcs_sel_n => s_calc_crc,
	
	crc_o  => s_crc,
	crc_rdy_p_o => open,
	crc_ok_p => open
);

s_nx_data_to_crc <= s_calc_crc and s_nx_data;

process(uclk_i)
begin
   if rising_edge(uclk_i) then
      if byte_ready_p_i = '1' then
         s_byte <= byte_i;
      end if;
	end if;
end process;



process(uclk_i)
   begin
      if rising_edge(uclk_i) then
         if rst_i = '1' then
            tx_st <= tx_idle;
			else
            tx_st <= nx_tx_st;
         end if;
      end if;
end process;



process(tx_st, last_byte_p_i, s_pointer_is_zero, start_send_p_i,  clk_fixed_carrier_p_d_i)
begin
nx_tx_st <= tx_idle;

   case tx_st is 
      when tx_idle =>  if start_send_p_i = '1' then
                          nx_tx_st <= tx_header;
							  else
                          nx_tx_st <= tx_idle;
                       end if;
      when tx_header =>   if s_pointer_is_zero = '1'  and  clk_fixed_carrier_p_d_i(2) = '1' then
                             nx_tx_st <= tx_byte;
							     else
                             nx_tx_st <= tx_header;
                          end if;
      when tx_byte =>   if last_byte_p_i = '1' then
                             nx_tx_st <= tx_last_byte;
							     else
                             nx_tx_st <= tx_byte;
                        end if;
      when tx_last_byte => if s_pointer_is_zero = '1' and  clk_fixed_carrier_p_d_i(1) = '1' then
                             nx_tx_st <= tx_crc_byte;
							     else
                             nx_tx_st <= tx_last_byte;
                        end if;
      when tx_crc_byte => if s_pointer_is_zero = '1' and  clk_fixed_carrier_p_d_i(1) = '1' then
                             nx_tx_st <= tx_queue;
							     else
                             nx_tx_st <= tx_crc_byte;
                        end if;
		when tx_queue =>  if s_pointer_is_zero = '1' and  clk_fixed_carrier_p_d_i(1) = '1' then
                             nx_tx_st <= tx_idle;
							     else
                             nx_tx_st <= tx_queue;
                        end if;		
      when others =>
                        nx_tx_st <= tx_idle;
   end case;
end process;


process(tx_st, s_pointer_is_zero, s_pointer, s_manchester_crc,  clk_fixed_carrier_p_d_i, s_manchester_byte)
begin
   s_top_pointer <= to_unsigned(0,s_pointer'length);
	s_reset_pointer <= '0';
	s_inc_pointer <= '0';
	s_nx_data <= '0';
	s_nx_data_e <= '0';
	request_byte_p_o <= '0';
	s_d_to_crc_rdy_p <= '0';
	s_start_crc_p <= '0';
	s_calc_crc <= '0';
   case tx_st is 
      when tx_idle =>            
                         s_top_pointer <= to_unsigned(HEADER'length-1,s_pointer'length);
	                      s_reset_pointer <= '1';
      when tx_header =>
	                      s_reset_pointer <= s_pointer_is_zero and  clk_fixed_carrier_p_d_i(2);
								 s_inc_pointer <=  clk_fixed_carrier_p_d_i(2);
								 
								 s_nx_data <= HEADER(to_integer(s_pointer));
	                      s_nx_data_e <= '1';
                         s_top_pointer <= to_unsigned(15,s_pointer'length);
								 s_start_crc_p <= s_pointer_is_zero and  clk_fixed_carrier_p_d_i(2);
      when tx_byte  => 
								 request_byte_p_o <= s_pointer_is_zero and  clk_fixed_carrier_p_d_i(0);
								 s_inc_pointer <=  clk_fixed_carrier_p_d_i(2);
								 s_nx_data <= s_manchester_byte(to_integer(resize(s_pointer,4)));
	                      s_nx_data_e <= '1';
								 s_d_to_crc_rdy_p <= clk_fixed_carrier_p_d_i(2) and s_pointer(0);
                         s_top_pointer <= to_unsigned(QUEUE'length-1,s_pointer'length);	
	                      s_reset_pointer <= s_pointer_is_zero and  clk_fixed_carrier_p_d_i(2);
								 s_calc_crc <= '1';
      when tx_last_byte => 
								 request_byte_p_o <= s_pointer_is_zero and  clk_fixed_carrier_p_d_i(0);
								 s_inc_pointer <=  clk_fixed_carrier_p_d_i(2);
								 s_nx_data <= s_manchester_byte(to_integer(resize(s_pointer,4)));
	                      s_nx_data_e <= '1';
								 s_d_to_crc_rdy_p <= clk_fixed_carrier_p_d_i(2) and s_pointer(0);
	                      s_reset_pointer <= s_pointer_is_zero and  clk_fixed_carrier_p_d_i(2);
                         s_top_pointer <= to_unsigned(QUEUE'length-1,s_pointer'length);
								 s_calc_crc <= '1';

      when tx_crc_byte =>
                         -- I enable the crc shift register at the bit boundaries by 
                         -- inverting s_pointer(0)								 
 --                        s_d_to_crc_rdy_p <= clk_fixed_carrier_p_d_i(2) and (not s_pointer(0));
								 
								 s_inc_pointer <=  clk_fixed_carrier_p_d_i(2);
								 
								 s_nx_data <= s_manchester_crc(to_integer(resize(s_pointer,4)));

--								 s_nx_data <= (not s_crc(s_crc'left)) xor ( s_pointer(0)); -- s_crc(s_crc'left) is xored with s_pointer(0) to mimic
								                                                  -- a manchester encoder
	                      s_nx_data_e <= '1';
	                      s_reset_pointer <= s_pointer_is_zero and  clk_fixed_carrier_p_d_i(2);
                         s_top_pointer <= to_unsigned(s_manchester_crc'length-1,s_pointer'length);	
								 
		when tx_queue =>
                         s_top_pointer <= to_unsigned(QUEUE'length-1,s_pointer'length);	
	                      s_reset_pointer <= s_pointer_is_zero and  clk_fixed_carrier_p_d_i(2);
								 s_inc_pointer <=  clk_fixed_carrier_p_d_i(2);
							    s_nx_data <= QUEUE(to_integer(resize(s_pointer,4)));							 
	                      s_nx_data_e <= '1';								 
      when others => 
   end case;
end process;

process(s_byte)
begin
   for I in byte_i'range loop
	   s_manchester_byte(I*2) <= not s_byte(I);
      s_manchester_byte(I*2+1) <=  s_byte(I);
   end loop;
end process;

process(s_crc)
begin
   for I in s_crc'range loop
	   s_manchester_crc(I*2) <= not s_crc(I);
      s_manchester_crc(I*2+1) <=  s_crc(I);
   end loop;
end process;

process(uclk_i)
   begin
      if rising_edge(uclk_i) then
		  if  clk_fixed_carrier_p_d_i(0) = '1' then
            d_o <= s_nx_data;
		  end if;
				d_e_o <= s_nx_data_e;
      end if;
end process;

process(uclk_i)
   begin
      if rising_edge(uclk_i) then
		   if s_reset_pointer = '1' then
		      s_pointer <= s_top_pointer;
		   elsif s_inc_pointer = '1' then
		      s_pointer <= s_pointer - 1;
			end if;
      end if;
end process;

s_pointer_is_zero <= '1' when s_pointer = to_unsigned(0,s_pointer'length) else '0';
s_pointer_is_one <= '1' when s_pointer = to_unsigned(1,s_pointer'length) else '0';

end architecture rtl;
-------------------------------------------------------------------------------
--                          E N D   O F   F I L E
-------------------------------------------------------------------------------
