--_________________________________________________________________________________________________
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
--
--! @brief     The unit applies a glitch filter; it follows each manchester bit of the "nanoFIP
--!            FIELDRIVE" input signal fd_rxd (synchronized with uclk), counts the number of zeros
--!            and ones throughout its duration and finally outputs the majority. The output
--!            deglitched signal is one half-bit-clock period later than the input.
--!            Note: the term sample_manch_bit_p refers to the moments when a manch. encoded bit
--!            should be sampled (before and after a significant edge), whereas the 
--!            sample_bit_p includes only the sampling of the 1st part, before the transition. 
--!            Example:
--!                    bit                : 0 
--!                    manch. encoded     : _|-
--!                    sample_manch_bit_p : ^ ^
--!                    sample_bit_p       : ^    (this sampling will give the 0)
--
--
--! @author	   Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch) \n
--!            Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)     \n
--
--
-- @date       23/08/2010
--
--
--! @version   v0.02
--
--
--! @details 
--
--!   \n<b>Dependencies:</b>\n
--!     WF_tx-_rx_osc       \n
--!     WF_reset_unit       \n
--
--
--!   \n<b>Modified by:</b>\n
--!     Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch) \n
--!     Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)     \n 
--
---------------------------------------------------------------------------------------------------
--
--!   \n\n<b>Last changes:</b>\n
--!     -> 07/08/2009  v0.01  PAS Entity Ports added, start of architecture content
--!     -> 23/08/2010  v0.02  EG  code cleaned-up+commented
--
---------------------------------------------------------------------------------------------------
--
--! @todo 
--
---------------------------------------------------------------------------------------------------



--=================================================================================================
--!                             Entity declaration for WF_rx_deglitcher
--=================================================================================================

entity WF_rx_deglitcher is
  generic (c_DEGLITCH_LGTH : integer := 10);

  port( 
  -- INPUTS  
    -- nanoFIP User Interface general signal   
    uclk_i                  : in std_logic;  --! 40 MHz clock

    -- Signal from the WF_reset_unit  
    nfip_urst_i             : in std_logic;  --! nanoFIP internal reset

    -- nanoFIP FIELDRIVE (synchronized with uclk)
    rxd_i                   : in std_logic;  --!        ____|--------|________|--------|________

    -- Signals from the WF_tx_rx_osc unit
    sample_bit_p_i          : in std_logic;  --!        ____|-|_______________|-|_______________
    sample_manch_bit_p_i    : in std_logic;  --!        ____|-|______|-|______|-|______|-|______


  -- OUTPUTS  
    -- Signals to the WF_rx_deserializer unit
    rxd_filtered_o          : out std_logic; --! filtered output signal
    rxd_filtered_f_edge_p_o : out std_logic; --! indicates a falling edge on the filtered signal
    sample_bit_p_o          : out std_logic; --! same as sample_bit_p_i
    sample_manch_bit_p_o    : out std_logic  --! same as sample_manch_bit_p_i
      );
end WF_rx_deglitcher;



--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture Behavioral of WF_rx_deglitcher is

signal s_rxd_filtered      : std_logic;
signal s_rxd_filtered_d    : std_logic;
signal s_rxd_filtered_buff : std_logic_vector (1 downto 0);
signal s_zeros_and_ones_c  : signed (c_DEGLITCH_LGTH - 1 downto 0);


--=================================================================================================
--                                      architecture begin
--=================================================================================================
begin


---------------------------------------------------------------------------------------------------
--! Synchronous process: Zeros_and_Ones_counter: For each manchester bit (between two
--! sample_manch_bit_p_i pulses) at each uclk tick, the signed counter decreases by one if rxd is
--! one or increases by one if rxd is zero.

Zeros_and_Ones_counter: process (uclk_i)
  begin
  if rising_edge (uclk_i) then
    if nfip_urst_i = '1' then
      s_zeros_and_ones_c   <= (others =>'0');
    else

      if sample_manch_bit_p_i = '1' then      -- arrival of a new manchester bit
        s_zeros_and_ones_c <= (others =>'0'); -- counter initialized

      elsif  rxd_i = '1' then             
        s_zeros_and_ones_c <= s_zeros_and_ones_c - 1;
      else
        s_zeros_and_ones_c <= s_zeros_and_ones_c + 1;

      end if;
    end if;
  end if;
end process;

---------------------------------------------------------------------------------------------------
--! Synchronous process Filtering: On the arrival of a new manchester bit, if the number of ones 
--! that has been measured (for the bit that has already passed) is more than the number of zeros,
--! the filtered output signal is zero (until the new manchester bit), otherwise one. 
--! The filtered signal is one half-bit-clock cycle (+2 uclk cycles) late with respect to the
--! synchronized fd_rxd.

Filtering: process (uclk_i)
  begin
  if rising_edge (uclk_i) then
    if nfip_urst_i = '1' then
      s_rxd_filtered   <= '0';
      s_rxd_filtered_d <= '0';
    else

	  if sample_manch_bit_p_i = '1' then 		
        s_rxd_filtered <= s_zeros_and_ones_c (s_zeros_and_ones_c'left);-- if the ones are more than
                                                                       -- the zeros, the output is
      end if;                                                          -- 1 otherwise, 0	 

      s_rxd_filtered_d <= s_rxd_filtered;  -- 1 uclk period delay, so that the pulses sample_bit_p
                                           -- and sample_manch_bit_p arrive 2 uclk periods before
    end if;                                -- the rxd_filtered edges
  end if;
end process;

---------------------------------------------------------------------------------------------------
--!@brief synchronous process Detect_f_edge_rxd_filtered: detection of a falling edge on the 
--! deglitched input signal(rxd_filtered). A buffer is used to store the last 2 bits of the signal.

Detect_f_edge_rxd_filtered: process (uclk_i)
  begin
    if rising_edge (uclk_i) then 
      if nfip_urst_i = '1' then
        s_rxd_filtered_buff <= (others => '0');

      else
        -- buffer s_rxd_filtered_buff keeps the last 2 bits of s_rxd_filtered_d
        s_rxd_filtered_buff <= s_rxd_filtered_buff(0) & s_rxd_filtered_d;
      end if;
    end if;
  end process;

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  -- Concurrent signals assignments
  rxd_filtered_f_edge_p_o   <= s_rxd_filtered_buff(1) and (not s_rxd_filtered_buff(0));
  rxd_filtered_o            <= s_rxd_filtered_d;
  sample_bit_p_o            <= sample_bit_p_i;
  sample_manch_bit_p_o      <= sample_manch_bit_p_i;  


end Behavioral;

--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------