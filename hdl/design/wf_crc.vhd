--===========================================================================
--! @file wf_crc.vhd
--! @brief Calculates the crc of serialized data.
--===========================================================================
--! Standard library
library IEEE;
--! Standard packages
use IEEE.STD_LOGIC_1164.all; --! std_logic definitions
use IEEE.NUMERIC_STD.all;    --! conversion functions


-------------------------------------------------------------------------------
--                                                                           --
--                                 wf_crc                                 --
--                                                                           --
--                               CERN, BE/CO/HT                              --
--                                                                           --
-------------------------------------------------------------------------------
--
-- unit name: wf_crc
--
--! @brief Calculates the crc of serialized data. 
--!
--! Used in the NanoFIP design. \n
--!  Calculates the crc of serialized data.
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
--!
--!
--! <b>References:</b>\n
--! 
--! 
--!
--! <b>Modified by:</b>\n
--! Author: Pablo Alvarez Sanchez
-------------------------------------------------------------------------------
--! \n\n<b>Last changes:</b>\n
--! 07/08/2009  v0.02  PAAS Entity Ports added, start of architecture content
--!
-------------------------------------------------------------------------------
--! @todo Define I/O signals \n
--!
-------------------------------------------------------------------------------
--============================================================================
--! Entity declaration for wf_crc
--============================================================================
entity wf_crc is
generic( 
			c_poly_length :  natural := 16);
port (
   uclk_i    : in std_logic; --! User Clock
   rst_i     : in std_logic;
   
   start_p_i : in std_logic;
	d_i       : in std_logic;
	d_rdy_p_i     : in std_logic;
	data_fcs_sel_n : in std_logic;
	crc_o     : out  std_logic_vector(c_poly_length - 1 downto 0);
	crc_rdy_p_o : out std_logic;
	crc_ok_p : out std_logic

);

end entity wf_crc;



-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--! ARCHITECTURE OF wf_crc
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
architecture rtl of wf_crc is


--! shift register xor mask
constant c_poly :  std_logic_vector(c_poly_length - 1 downto 0)      := "0001110111001111"; 
--! crc check mask
constant c_check_mask : std_logic_vector(c_poly_length - 1 downto 0) := "0001110001101011";

signal s_q, s_q_nx  : std_logic_vector(c_poly_length - 1 downto 0);
signal s_crc_rdy_p : std_logic;
signal s_d : std_logic;
begin

s_d <= d_i;
G: for I in 0 to c_poly'left generate
   G0: if I = 0 generate
      s_q_nx(I) <= data_fcs_sel_n and (( s_d) xor s_q(s_q'left));
   end generate;
   G1: if I > 0 generate
      s_q_nx(I) <= s_q(I-1) xor (c_poly(I) and data_fcs_sel_n and (s_d xor s_q(s_q'left)));
   end generate;
end generate;

process(uclk_i)
begin
   if rising_edge(uclk_i) then
      if rst_i = '1' then
         s_q <= (others => '1');
      else
         if start_p_i = '1' then
            s_q <= (others => '1');
         elsif d_rdy_p_i = '1' then 
            s_q <= s_q_nx;
         end if;
         s_crc_rdy_p <= d_rdy_p_i; 
      end if;
   end if;
end process;

crc_o <= not s_q;
crc_rdy_p_o <= s_crc_rdy_p;

process(s_q, s_crc_rdy_p)
   variable v_q_check_mask : std_logic_vector(c_poly_length - 1 downto 0);
begin
   v_q_check_mask := s_q xor c_check_mask;
   crc_ok_p <= '0';
   if (unsigned(not v_q_check_mask)) = 0 then 
      crc_ok_p <= s_crc_rdy_p;
   end if;
end process;


end architecture rtl;
-------------------------------------------------------------------------------
--                          E N D   O F   F I L E
-------------------------------------------------------------------------------
