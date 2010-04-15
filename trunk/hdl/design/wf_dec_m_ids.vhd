--===========================================================================
--! @file wf_produced_vars.vhd
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
--                                 wf_produced_vars                                 --
--                                                                           --
--                               CERN, BE/CO/HT                              --
--                                                                           --
-------------------------------------------------------------------------------
--
-- unit name: wf_produced_vars
--
--! @brief Nanofip control unit. It provides with a transparent interface between the wf_control state machine and the RAM and special \n
--!                              variable bytes not stored in RAM. wf_wishbone has write access and wf_control read access.\n
--!
--! @author Pablo Alvarez Sanchez (pablo.alvarez.sanchez@cern.ch)
--
--! @date 11/09/2009
--!
--! @version v0.01
--!
--! @details 
--!
--! <b>Dependencies:</b>\n
--! wf_package           \n
--!
--!
--! <b>References:</b>\n
--! 
--! 
--!
--! <b>Modified by:</b>\n
--! Author: Pablo Alvarez Sanchez (pablo.alvarez.sanchez@cern.ch)
-------------------------------------------------------------------------------
--! \n\n<b>Last changes:</b>\n
--! 11/09/2009  v0.01  EB  First version \n
--!
-------------------------------------------------------------------------------
--! @todo 
--!
-------------------------------------------------------------------------------



--============================================================================
--! Entity declaration for wf_dec_m_ids
--============================================================================
entity wf_dec_m_ids is

  port (
    uclk_i    : in std_logic; --! User Clock
    rst_i     : in std_logic;

    s_id_o : out std_logic_vector(1 downto 0);
    --! Identification variable settings. 
    m_id_dec_o    : out  std_logic_vector (7 downto 0); --! Model identification settings

    --! Constructor identification settings.
    c_id_dec_o    : out std_logic_vector (7 downto 0); --! Constructor identification setting

    
    --! Identification variable settings. 
    m_id_i    : in  std_logic_vector (3 downto 0); --! Model identification settings

    --! Constructor identification settings.
    c_id_i    : in  std_logic_vector (3 downto 0) --! Constructor identification settings


    );

end entity wf_dec_m_ids;




-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--! ARCHITECTURE OF wf_dec_m_ids
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
architecture rtl of wf_dec_m_ids is


  signal s_c, s_c_n : unsigned(8 downto 0);
  signal s_m_even, s_m_odd : std_logic_vector(3 downto 0);
  signal s_c_even, s_c_odd : std_logic_vector(3 downto 0);
  signal s_load_val : std_logic;

begin

  s_c_n <= s_c + 1;
  s_load_val <= s_c_n(s_c_n'left) and (not s_c(s_c'left));

  P_dec:process(uclk_i)
  begin
    if rising_edge(uclk_i) then
      if rst_i = '1' then
       s_m_even <= (others => '0');
        
       s_c_even <= (others => '0');
       s_c <= to_unsigned(0, s_c'length);
      else
       
       s_m_odd <= m_id_i;
       s_c_odd <= c_id_i;
       s_m_even <= s_m_odd; 
       s_c_even <= s_c_odd;
       s_c <= s_c_n;
       if s_load_val = '1' then
          for I in 0 to 3 loop
             m_id_dec_o(I*2) <= s_m_even(I);
             m_id_dec_o(I*2+1) <= s_m_odd(I);
             c_id_dec_o(I*2) <= s_c_even(I);
             c_id_dec_o(I*2+1) <= s_c_odd(I);
          end loop;
        end if;
      end if;
    end if;
  end process;

  s_id_o <= std_logic_vector(s_c((s_c'left - 1) downto (s_c'left - 2)));

end architecture rtl;
-------------------------------------------------------------------------------
--                          E N D   O F   F I L E
-------------------------------------------------------------------------------