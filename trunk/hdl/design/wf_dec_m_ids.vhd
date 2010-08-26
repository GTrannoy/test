--===========================================================================
--! @file wf_dec_m_ids.vhd
--===========================================================================

--! standard library
library IEEE;

--! standard packages
use IEEE.STD_LOGIC_1164.all;  --! std_logic definitions
use IEEE.NUMERIC_STD.all;     --! conversion functions

--! specific packages           -- not needed i t hink, confirm
--use work.WF_PACKAGE.all;      --! definitions of supplemental types, subtypes, constants

---------------------------------------------------------------------------------------------------
--                                                                                               --
--                                         wf_dec_m_ids                                          --
--                                                                                               --
--                                        CERN, BE/CO/HT                                         --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
-- unit name   wf_dec_m_ids
--
--
--! @brief     Decoding of the inputs S_ID and M_ID and construction of the nanoFIP output S_ID 
--!                                                                  (identification selection)
--
--
--! @author    Pablo Alvarez Sanchez (pablo.alvarez.sanchez@cern.ch)
--!            Evangelia Gousiou (evangelia.gousiou@cern.ch)
--
--! @date      08/2010
--
--
--! @version   v0.02
--
--
--! @details\n 
--
--!   \n<b>Dependencies:</b>\n
--
--
--!   \n<b>Modified by:</b>\n
--!     Pablo Alvarez Sanchez (pablo.alvarez.sanchez@cern.ch)
--!     Evangelia Gousiou (evangelia.gousiou@cern.ch)
--
---------------------------------------------------------------------------------------------------
--
--! \n\n<b>Last changes:</b>\n
--! -> 11/09/2009  v0.01  EB  First version \n
--! -> 20/08/2010  v0.02  EG  code cleaned-up \n
--
---------------------------------------------------------------------------------------------------
--
--! @todo 
--! -> understand whazz goin on!
--! -> chane name of the unit
--
---------------------------------------------------------------------------------------------------


--=================================================================================================
--!                             Entity declaration for wf_dec_m_ids
--=================================================================================================
entity wf_dec_m_ids is

  port (
  -- INPUTS 
    -- User Interface general signal
    uclk_i :     in std_logic; 

    -- Signal from the reset_logic unit
    nFIP_rst_i : in std_logic;

    -- WorldFIP settings
    m_id_i :     in  std_logic_vector (3 downto 0); --! Model identification settings
    c_id_i :     in  std_logic_vector (3 downto 0); --! Constructor identification settings


  -- OUTPUTS
    -- WorldFIP settings nanoFIP output
    s_id_o :     out std_logic_vector(1 downto 0);  --! Identification selection

    -- Output to wf_produced_vars
    m_id_dec_o : out  std_logic_vector (7 downto 0); --! Model identification decoded
    c_id_dec_o : out std_logic_vector (7 downto 0)  --! Constructor identification decoded
    );

end entity wf_dec_m_ids;




--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of wf_dec_m_ids is


  signal s_c, s_c_n : unsigned(8 downto 0);
  signal s_m_even, s_m_odd : std_logic_vector(3 downto 0);
  signal s_c_even, s_c_odd : std_logic_vector(3 downto 0);
  signal s_load_val : std_logic;


--=================================================================================================
--                                      architecture begin
--=================================================================================================
begin

  s_c_n <= s_c + 1;
  s_load_val <= s_c_n(s_c_n'left) and (not s_c(s_c'left));

  P_dec:process(uclk_i)
  begin
    if rising_edge(uclk_i) then
      if nFIP_rst_i = '1' then
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
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------