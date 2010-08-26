--=================================================================================================
--! @file deglitcher.vhd
--=================================================================================================

--! Standard library
library IEEE;

--! Standard packages
use IEEE.STD_LOGIC_1164.all; --! std_logic definitions
use IEEE.NUMERIC_STD.all;    --! conversion functions


---------------------------------------------------------------------------------------------------
--                                                                                               --
--                                            deglitcher                                         --
--                                                                                               --
--                                          CERN, BE/CO/HT                                       --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
-- unit name   eglitcher
--
--! @brief     Glitch filter. 1 pulse adapted filter.
--
--
--! @author	   Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)
--!            Evangelia Gousiou (Evangelia.Gousiou@cern.ch) 
--
--
-- @date       08/2010
--
--
--! @version   v0.03
--
--
--! @details 
--
--!   \n<b>Dependencies:</b>\n
--!   wf_osc             \n
--!   reset_logic         \n
--
--
--!   \n<b>Modified by:</b>\n
--!   Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch) \n
--!   Evangelia Gousiou (Evangelia.Gousiou@cern.ch) 
--
---------------------------------------------------------------------------------------------------
--
--!   \n\n<b>Last changes:</b>\n
--!   07/08/2009  v0.02  PAS Entity Ports added, start of architecture content
--!   23/08/2010  v0.03  EG   Signal names changed, delayed signals changed, code cleaned-up
--
---------------------------------------------------------------------------------------------------
--
--! @todo 
--  more comments
---------------------------------------------------------------------------------------------------



--=================================================================================================
--!                             Entity declaration for wf_deglitcher
--=================================================================================================

entity deglitcher is
  generic (C_ACULENGTH : integer := 10);

  port( 
  -- INPUTS  
    -- User interface general signal   
    uclk_i :               in std_logic; --! 40 MHz clock

    -- Signal from the reset_logic unit  
    nFIP_rst_i :           in std_logic; --! internal reset

    -- FIELDRIVE input signal
    rx_data_i :            in std_logic; --! buffered fd_rxd

    -- Signals from the wf_osc unit
    sample_bit_p_i :       in std_logic; --! pulsed signal signaling a new bit
    sample_manch_bit_p_i : in std_logic; --! pulsed signal signaling a new manchestered bit 

  -- OUTPUTS  
    -- Output signals needed for the receiverwf_rx
    sample_bit_p_o :       out  std_logic;
    rx_data_filtered_o :   out  std_logic;
    sample_manch_bit_p_o : out  std_logic
      );
end deglitcher;



--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture Behavioral of deglitcher is

signal s_count_ones_c : signed(C_ACULENGTH - 1 downto 0);
signal s_rx_data_filtered: STD_LOGIC;
signal s_rx_data_filtered_d : std_logic;


--=================================================================================================
--                                      architecture begin
--=================================================================================================
begin


---------------------------------------------------------------------------------------------------
process(uclk_i)
  begin
  if rising_edge(uclk_i) then

    if nFIP_rst_i = '1' then
      s_count_ones_c <= (others =>'0');
    else

      if sample_manch_bit_p_i = '1' then -- arrival of a new manchester bit
        s_count_ones_c <= (others =>'0'); -- counter initialized

      elsif  rx_data_i = '1' then         -- counting the number of ones 
        s_count_ones_c <= s_count_ones_c - 1;
      else
        s_count_ones_c <= s_count_ones_c + 1;

      end if;
    end if;
  end if;
end process;

---------------------------------------------------------------------------------------------------
process(uclk_i)
  begin
  if rising_edge(uclk_i) then

    if nFIP_rst_i = '1' then
      s_rx_data_filtered <= '0';
      s_rx_data_filtered_d <= '0';
    else

	  if sample_manch_bit_p_i = '1' then 		
        s_rx_data_filtered <= s_count_ones_c (s_count_ones_c'left); -- if the ones are more than
                                                                      -- the zeros, the output is 1
                                                                      -- otherwise, 0	 
      end if;

      s_rx_data_filtered_d <= s_rx_data_filtered; 

    end if;
  end if;
end process;

      rx_data_filtered_o <= s_rx_data_filtered_d;
      sample_manch_bit_p_o <= sample_manch_bit_p_i;  
      sample_bit_p_o <= sample_bit_p_i;

end Behavioral;

--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------





























