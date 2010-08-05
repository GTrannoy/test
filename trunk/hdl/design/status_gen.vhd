--===========================================================================
--! @file status_gen.vhd
--! @brief NanoFIP status generator
--===========================================================================
--! Standard library
library IEEE;
--! Standard packages
use IEEE.STD_LOGIC_1164.all; --! std_logic definitions
use IEEE.NUMERIC_STD.all;    --! conversion functions

use work.wf_package.all;

-------------------------------------------------------------------------------
--                                                                           --
--                                 status_gen                                --
--                                                                           --
--                               CERN, BE/CO/HT                              --
--                                                                           --
-------------------------------------------------------------------------------
--
-- unit name: status_gen
--
--! @brief NanoFIP status generator.
--!
--! Used in the NanoFIP design.\n
--! Generates the NanoFIP status that may be sent with Produced variables. 
--! See Table 8 of the Functional Specification..
--!
--! @author Erik van der Bij (Erik.van.der.Bij@cern.ch)
--
--! @date 07/07/2009
--
--! @version v0.01
--
--! @details 
--!
--! <b>Dependencies:</b>\n
--! data_if             \n
--! tx_engine           \n
--! wf_tx_rx            \n
--! reset_logic         \n
--!
--! <b>References:</b>\n
--! 
--! 
--!
--! <b>Modified by:</b>\n
--! Author: Pablo Alvarez Sanchez (pablo.alvarez.sanchez@cern.ch)
-------------------------------------------------------------------------------
--! \n\n<b>Last changes:</b>\n
--! 07/07/2009  v0.01  EB  First version \n
--!
-------------------------------------------------------------------------------
--! @todo Define I/O signals \n
--!
-------------------------------------------------------------------------------



--============================================================================
-- Entity declaration for status_gen
--============================================================================
entity status_gen is

port (
   uclk_i :               in std_logic; --! User Clock
   rst_i :                in std_logic;


   fd_wdgn_i :            in  std_logic; --! Watchdog on transmitter
   fd_txer_i :            in  std_logic; --! Transmitter error

   code_violation_p_i :   in std_logic;
   crc_bad_p_i :          in std_logic;
   var1_rdy_i :           in std_logic; --! Variable 1 ready
   var2_rdy_i :           in std_logic; --! Variable 2 ready
   var3_rdy_i :           in std_logic; --! Variable 3 ready
   var1_access_a_i :      in std_logic; --! Variable 1 access
   var2_access_a_i :      in std_logic; --! Variable 2 access
   var3_access_a_i :      in std_logic; --! Variable 3 access
   reset_status_bytes_i : in std_logic;

   stat_o :               out std_logic_vector(7 downto 0); 
   mps_o :                out std_logic_vector(7 downto 0)

);

end entity status_gen;

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--! ARCHITECTURE OF STATUS_GEN
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
architecture rtl of status_gen is

signal s_stat : std_logic_vector(7 downto 0);
signal s_refreshment : std_logic;
signal s_var1_access:  std_logic_vector(1 downto 0); --! Variable 1 access
signal s_var2_access:  std_logic_vector(1 downto 0); --! Variable 2 access
signal s_var3_access:  std_logic_vector(1 downto 0); --! Variable 3 access

begin


  process(uclk_i) 
  begin
    if rising_edge(uclk_i) then
      s_var1_access(0) <= var1_access_a_i;
      s_var2_access(0) <= var2_access_a_i; 
      s_var3_access(0) <= var3_access_a_i;
      s_var1_access(1) <= s_var1_access(0);
      s_var2_access(1) <= s_var2_access(0);
      s_var3_access(1) <= s_var3_access(0);
    end if;
  end process;

  process(uclk_i) 
  begin

    if rising_edge(uclk_i) then
  
      if rst_i = '1' or reset_status_bytes_i = '1' then
        s_stat <= (others => '0');
	else -- value of s_var1_access on the previous clock tick should be 0
		if (var1_rdy_i = '0' and s_var1_access(1) = '1') or (var2_rdy_i = '0' and s_var2_access(1) = '1') then
			s_stat(c_u_cacer_pos) <= '1';
		end if;

		if ((var3_rdy_i = '0') and (s_var3_access(1) = '1')) then
			s_stat(c_u_pacer_pos) <= '1';
		end if;

		if code_violation_p_i = '1' then
			s_stat(c_r_bner_pos) <= '1';
		end if;

		if crc_bad_p_i = '1' then
			s_stat(c_r_fcser_pos) <= '1';
		end if;

		if fd_wdgn_i = '1' then
			s_stat(c_t_txer_pos) <= '1';
		end if;

		if fd_txer_i = '1' then
			s_stat(c_t_wder_pos) <= '1';
		end if;

	end if;

   if rst_i = '1' or reset_status_bytes_i = '1' then
			s_refreshment <= '0';
	else
		if (var3_access_a_i = '1') then
			s_refreshment <= '1';
		end if;
   end if;

	end if;
end process;

  process(s_refreshment)
  begin
    mps_o <= (others => '0'); 
    mps_o(c_refreshment_pos) <= s_refreshment; 
    mps_o(c_significance_pos) <= s_refreshment;
  end process;

  stat_o <= s_stat;

end architecture rtl;
-------------------------------------------------------------------------------
--                          E N D   O F   F I L E
-------------------------------------------------------------------------------