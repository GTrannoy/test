--________________________________________________________________________________________________|
--                                                                                                |
--                                        |The nanoFIP|                                           |
--                                                                                                |
--                                        CERN,BE/CO-HT                                           |
--________________________________________________________________________________________________|
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--! @file WF_rx_deglitcher.vhd                                                                    |
---------------------------------------------------------------------------------------------------

--! Standard library
library IEEE;

--! Standard packages
use IEEE.STD_LOGIC_1164.all; --! std_logic definitions
use IEEE.NUMERIC_STD.all;    --! conversion functions


---------------------------------------------------------------------------------------------------
--                                                                                               --
--                                          WF_rx_deglitcher                                     --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
-- unit name   eglitcher
--
--! @brief     Glitch filter. 1 pulse adapted filter.
--
--
--! @author	   Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)
--!            Evangelia Gousiou     (Evangelia.Gousiou@cern.ch) 
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
--!   WF_osc             \n
--!   WF_reset_unit         \n
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
--!                             Entity declaration for WF_deglitcher
--=================================================================================================

entity WF_rx_deglitcher is
  generic (C_ACULENGTH : integer := 10);

  port( 
  -- INPUTS  
    -- User interface general signal   
    uclk_i :                  in std_logic; --! 40 MHz clock

    -- Signal from the WF_reset_unit unit  
    nFIP_urst_i :              in std_logic; --! internal reset

    -- FIELDRIVE input signal
    rxd_i :                   in std_logic; --! buffered fd_rxd

    -- Signals from the WF_osc unit
    sample_bit_p_i :          in std_logic; --! pulsed signal signaling a new bit
    sample_manch_bit_p_i :    in std_logic; --! pulsed signal signaling a new manchestered bit 

  -- OUTPUTS  
    -- Output signals needed for the receiverWF_rx
    sample_bit_p_o :          out std_logic;
    rxd_filtered_o :          out std_logic;
    rxd_filtered_f_edge_p_o : out std_logic;
    sample_manch_bit_p_o :    out std_logic
      );
end WF_rx_deglitcher;



--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture Behavioral of WF_rx_deglitcher is

signal s_count_ones_c :      signed(C_ACULENGTH - 1 downto 0);
signal s_rxd_filtered    :   std_logic;
signal s_rxd_filtered_d  :   std_logic;
signal s_rxd_filtered_buff : std_logic_vector (1 downto 0);



--=================================================================================================
--                                      architecture begin
--=================================================================================================
begin


---------------------------------------------------------------------------------------------------
process(uclk_i)
  begin
  if rising_edge(uclk_i) then

    if nFIP_urst_i = '1' then
      s_count_ones_c <= (others =>'0');
    else

      if sample_manch_bit_p_i = '1' then  -- arrival of a new manchester bit
        s_count_ones_c <= (others =>'0'); -- counter initialized

      elsif  rxd_i = '1' then             -- counting the number of ones 
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

    if nFIP_urst_i = '1' then
      s_rxd_filtered <= '0';
      s_rxd_filtered_d <= '0';
    else

	  if sample_manch_bit_p_i = '1' then 		
        s_rxd_filtered <= s_count_ones_c (s_count_ones_c'left); -- if the ones are more than
                                                                -- the zeros, the output is 1
                                                                -- otherwise, 0	 
      end if;

      s_rxd_filtered_d <= s_rxd_filtered; 

    end if;
  end if;
end process;

---------------------------------------------------------------------------------------------------
--!@brief synchronous process Detect_f_edge_rx_data_filtered: detection of a falling edge on the 
--! deglitched input signal (rx_data_filtered). A buffer is used to store the last 2 bits of the 
--! signal. A falling edge is detected if the last bit of the buffer (new bit) is a zero and the 
--! first (old) is a one. 

  Detect_f_edge_rx_data_filtered: process(uclk_i)
    begin
      if rising_edge(uclk_i) then 
        if nFIP_urst_i = '1' then
          s_rxd_filtered_buff <= (others => '0');
          rxd_filtered_f_edge_p_o <= '0';
        else

          -- buffer s_rxd_filtered_buff keeps the last 2 bits of s_rxd_filtered_d
          s_rxd_filtered_buff <= s_rxd_filtered_buff(0) & s_rxd_filtered_d;
          -- falling edge detected if last bit is a 0 and previous was a 1
          rxd_filtered_f_edge_p_o <= s_rxd_filtered_buff(1)and(not s_rxd_filtered_buff(0));
        end if;
      end if;
end process;


---------------------------------------------------------------------------------------------------

  rxd_filtered_o <= s_rxd_filtered_d;
  sample_manch_bit_p_o <= sample_manch_bit_p_i;  
  sample_bit_p_o <= sample_bit_p_i;

end Behavioral;

--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------
