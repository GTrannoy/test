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

--! standard library
library IEEE;

--! standard packages
use IEEE.STD_LOGIC_1164.all;  --! std_logic definitions
use IEEE.NUMERIC_STD.all;     --! conversion functions

--! specific packages
use work.WF_PACKAGE.all;      --! definitions of types, constants, entities

---------------------------------------------------------------------------------------------------
--                                                                                               --
--                                          WF_rx_deglitcher                                     --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
--
--! @brief     The unit applies a glitch filter to the nanoFIP FIELDRIVE input FD_RXD.
--!            It is capable of cleaning glitches up to c_DEGLITCH_THRESHOLD uclk ticks long.
--
--
--! @author    Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)\n
--!            Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)    \n
--
--
-- @date       14/02/2011
--
--
--! @version   v0.03
--
--
--! @details
--
--!   \n<b>Dependencies:</b> \n
--!            WF_reset_unit \n
--
--
--!   \n<b>Modified by:</b>\n
--!            Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch) \n
--!            Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)     \n
--
---------------------------------------------------------------------------------------------------
--
--!   \n\n<b>Last changes:</b>\n
--!     -> 07/08/2009  v0.01  PAS Entity Ports added, start of architecture content
--!     -> 23/08/2010  v0.02  EG  code cleaned-up+commented
--!     -> 14/02/2011  v0.03  EG  changesd deglitcher philosophy, no dependency on osc;
--!                               fd_rxd deglitched right at reception
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

  port(
  -- INPUTS
    -- nanoFIP User Interface general signal
    uclk_i                     : in std_logic;  --! 40 MHz clock

    -- Signal from the WF_reset_unit
    nfip_rst_i                 : in std_logic;  --! nanoFIP internal reset

    -- nanoFIP FIELDRIVE (synchronized with uclk)
    fd_rxd_a_i                 : in std_logic;  --! receiver data


  -- OUTPUTS
    -- Signals to the WF_rx_deserializer unit
    fd_rxd_filtered_o          : out std_logic; --! filtered output signal
    fd_rxd_filtered_edge_p_o   : out std_logic; --! indicates an edge on the filtered signal
    fd_rxd_filtered_f_edge_p_o : out std_logic  --! indicates a falling edge on the filtered signal
      );
end WF_rx_deglitcher;



--=================================================================================================
--!                                    architecture declaration
--=================================================================================================
architecture Behavioral of WF_rx_deglitcher is

  signal s_rxd_filtered, s_rxd_filtered_d1      : std_logic;
  signal s_rxd_filtered_r_edge_p                : std_logic;
  signal s_rxd_filtered_f_edge_p                : std_logic;
  signal s_deglitch_c                           : unsigned (3 downto 0);
  signal s_fd_rxd_synch                         : std_logic_vector (1 downto 0);


--=================================================================================================
--!                                    architecture declaration
--=================================================================================================
begin

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -
--!@brief Synchronous process FD_RXD_synchronizer: Synchronization of the nanoFIP FIELDRIVE input
--! FD_RXD to the uclk, using a set of 2 registers.

  FD_RXD_synchronizer: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if nfip_rst_i = '1' then
       s_fd_rxd_synch   <= (others => '0');

      else
       s_fd_rxd_synch   <= s_fd_rxd_synch(0) & fd_rxd_a_i;
      end if;
    end if;
  end process;


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -
--!@brief Synchronous process FD_RXD_deglitcher: the output signal rxd_filtered is updated only
--! after the accumulation of a sufficient (c_DEGLITCH_THRESHOLD+1) amount of identical bits.
--! The signal is therefore cleaned of any glitches up to c_DEGLITCH_THRESHOLD uclk ticks long.

  FD_RXD_deglitcher: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if nfip_rst_i = '1' then
        s_deglitch_c       <= to_unsigned (c_DEGLITCH_THRESHOLD, s_deglitch_c'length) srl 1;-- middle value
        s_rxd_filtered     <= '0';
        s_rxd_filtered_d1  <= '0';
      else
        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
        if s_fd_rxd_synch(1) = '0' then         -- arrival of a '0'

          if s_deglitch_c /= 0 then             -- counter updated
            s_deglitch_c   <= s_deglitch_c - 1;

          else
            s_rxd_filtered <= '0';              -- output updated
          end if;                               -- if counter = 0

        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
        elsif s_fd_rxd_synch(1) = '1' then      -- arrival of a '1'

          if s_deglitch_c /= c_DEGLITCH_THRESHOLD then
            s_deglitch_c   <= s_deglitch_c + 1; -- counter updated

          else
            s_rxd_filtered <= '1';              -- output updated
          end if;                               -- if counter = c_DEGLITCH_THRESHOLD

        end if;
        s_rxd_filtered_d1  <= s_rxd_filtered;   -- used for the edges detection
      end if;
    end if;
  end process;



  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -
  -- Concurrent signal assignments

  s_rxd_filtered_r_edge_p    <= (not s_rxd_filtered_d1) and s_rxd_filtered; -- pulse upon detection
                                                                            -- of a falling edge

  s_rxd_filtered_f_edge_p    <= s_rxd_filtered_d1 and (not s_rxd_filtered); -- pulse upon detection
                                                                            -- of a rising edge

  fd_rxd_filtered_edge_p_o   <= s_rxd_filtered_f_edge_p or   s_rxd_filtered_r_edge_p;
  fd_rxd_filtered_f_edge_p_o <= s_rxd_filtered_f_edge_p;
  fd_rxd_filtered_o          <= s_rxd_filtered;

end Behavioral;

--=================================================================================================
--                                        architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------