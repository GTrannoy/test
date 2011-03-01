--_________________________________________________________________________________________________
--                                                                                                |
--                                        |The nanoFIP|                                           |
--                                                                                                |
--                                        CERN,BE/CO-HT                                           |
--________________________________________________________________________________________________|
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--! @file WF_tx_osc.vhd                                                                           |
---------------------------------------------------------------------------------------------------

--! Standard library
library IEEE;

--! Standard packages
use IEEE.STD_LOGIC_1164.all; --! std_logic definitions
use IEEE.NUMERIC_STD.all;    --! conversion functions

--! specific packages
use work.WF_PACKAGE.all;     --! definitions of types, constants, entities
---------------------------------------------------------------------------------------------------
--                                                                                               --
--                                            WF_tx_osc                                          --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
--! @brief     Generation of the clock signals needed for the transmission (WF_tx_serializer)\n
--!
--!            The unit generates the nanoFIP FIELDRIVE output FD_TXCK (line driver half bit clock)
--!            and the nanoFIP internal signal tx_clk_p_buff:
--!
--!            uclk             :  _|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|
--!            FD_TXCK          :  _____|--------...--------|________...________|--------...--------|__
--!            tx_clk_p_buff(3) :   0   0   0   1                           0   0   0   1
--!            tx_clk_p_buff(2) :   0   0   1   0                           0   0   1   0
--!            tx_clk_p_buff(1) :   0   1   0   0                           0   1   0   0
--!            tx_clk_p_buff(0) :   1   0   0   0                           1   0   0   0
--!
--
--
--! @author    Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)\n
--!            Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)    \n
--
--
--! @date      14/02/2011
--
--
--! @version   v0.04
--
--
--!   \n<b>Dependencies:</b>     \n
--!            WF_reset_unit     \n
--!            WF_engine_control \n
--
--
--!   \n<b>Modified by:</b>\n
--!            Pablo Alvarez Sanchez\n
--!            Evangelia Gousiou    \n
--
---------------------------------------------------------------------------------------------------
--
--!   \n\n<b>Last changes:</b>\n
--!     -> 08/2009  v0.01  PS  Entity Ports added, start of architecture content \n
--!     -> 07/2010  v0.02  EG  tx counter changed from 20 bits signed, to 11 bits unsigned;
--!                            c_TX_CLK_BUFF_LGTH got 1 bit more\n
--!     -> 12/2010  v0.03  EG  code cleaned-up
--!     -> 01/2011  v0.04  EG  WF_tx_osc as different unit; use of WF_incr_counter;added tx_osc_rst_p_i
--
---------------------------------------------------------------------------------------------------
--
--! @todo -->
--
---------------------------------------------------------------------------------------------------



--=================================================================================================
--!                            Entity declaration for WF_tx_osc
--=================================================================================================

entity WF_tx_osc is
  port (
  -- INPUTS
    -- nanoFIP User Interface, General signals
    uclk_i          : in std_logic;                     --! 40 MHz clock
    rate_i          : in std_logic_vector (1 downto 0); --! WorldFIP bit rate

    -- Signal from the WF_reset_unit
    nfip_rst_i      : in std_logic;                     --! nanoFIP internal reset

    -- Signals from the WF_engine_control
    tx_osc_rst_p_i  : in std_logic;                     --! transmitter timeout


  -- OUTPUTS
    -- nanoFIP FIELDRIVE output
    tx_clk_o        : out std_logic;                    --! line driver half bit clock

    -- Signal to the WF_tx_serializer unit
    tx_clk_p_buff_o : out std_logic_vector (c_TX_CLK_BUFF_LGTH -1 downto 0)
                                                        --! buffer keeping the last values of tx_clk_o
    );

end entity WF_tx_osc;



--=================================================================================================
--!                                    architecture declaration
--=================================================================================================
architecture rtl of WF_tx_osc is

  signal s_period_c, s_period                   : unsigned  (c_PERIODS_COUNTER_LGTH -1 downto 0);
  signal s_one_forth_period                     : unsigned  (c_PERIODS_COUNTER_LGTH -1 downto 0);
  signal s_tx_clk_p_buff                        : std_logic_vector (c_TX_CLK_BUFF_LGTH-1 downto 0);
  signal s_tx_clk_d1, s_tx_clk, s_tx_clk_p, s_counter_is_full, s_reinit_counter        : std_logic;


--=================================================================================================
--                                        architecture begin
--=================================================================================================
begin

  s_period           <= c_BIT_RATE_UCLK_TICKS(to_integer(unsigned(rate_i)));-- # uclock ticks for a
                                                                            -- transmission period
  s_one_forth_period <= s_period srl 2;                                     -- 1/4 s_period
  s_counter_is_full  <= '1' when s_period_c = s_period -1 else '0';         -- counter full



--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
--!@brief Instantiation of a WF_incr_counter counting transmission periods.

  tx_periods_count: WF_incr_counter
  generic map (g_counter_lgth => c_PERIODS_COUNTER_LGTH)
  port map (
    uclk_i            => uclk_i,
    reinit_counter_i  => s_reinit_counter,
    incr_counter_i    => '1',
    counter_is_full_o => open,
    ------------------------------------------
    counter_o         => s_period_c);
    ------------------------------------------

    --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- counter reinitialized : if the nfip_rst_i is active or
    --                         if the tx_osc_rst_p_i is active or
    --                         if it fills up
    s_reinit_counter <= nfip_rst_i or tx_osc_rst_p_i or s_counter_is_full;



--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
--!@brief Clocks Constraction: Concurrent signals assignments and a synchronous process that use
--! the s_period_c to construct the tx_clk_o clock and the buffer of pulses tx_clk_p_buff_o.

  -- Creation of the clock for the transmitter with period: 1/2 transmission period
  s_tx_clk        <= '1' when ((s_period_c < s_one_forth_period) or
                                ((s_period_c > (2*s_one_forth_period)-1) and
                                 (s_period_c < 3*s_one_forth_period)))
                else '0';
                                            -- transm. period        : _|----------|__________|--
                                            -- tx_counter            :  0   1/4   1/2   3/4   1
                                            -- s_tx_clk              : _|----|_____|----|_____|--


  -- Creation of a pulse starting 1 uclk period before tx_clk_o
  s_tx_clk_p      <= s_tx_clk and (not s_tx_clk_d1);
                                            -- s_tx_clk              : __|-----|_____|-----|_____
                                            -- tx_clk_o/ s_tx_clk_d1 : ____|-----|_____|-----|___
                                            -- not s_tx_clk_d1       : ----|_____|-----|_____|---
                                            -- s_tx_clk_p            : __|-|___|-|___|-|___|-|___


  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  clk_Signals_Construction: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if (nfip_rst_i = '1') or (tx_osc_rst_p_i = '1') then
        s_tx_clk_p_buff <= (others => '0');
        s_tx_clk_d1     <= '0';
      else

        s_tx_clk_d1     <= s_tx_clk;
        s_tx_clk_p_buff <= s_tx_clk_p_buff (s_tx_clk_p_buff'left-1 downto 0) & s_tx_clk_p;
                                                    -- buffering of the s_tx_clk_p pulses
      end if;
    end if;
  end process;



--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
--!@brief Output signals assignments

  tx_clk_o        <= s_tx_clk_d1;
  tx_clk_p_buff_o <= s_tx_clk_p_buff;



end architecture rtl;
--=================================================================================================
--                                        architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------