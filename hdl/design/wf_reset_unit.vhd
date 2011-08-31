--_________________________________________________________________________________________________
--                                                                                                |
--                                        |The nanoFIP|                                           |
--                                                                                                |
--                                        CERN,BE/CO-HT                                           |
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--                                                                                               --
--                                        WF_reset_unit                                          --
--                                                                                               --
---------------------------------------------------------------------------------------------------
-- File         WF_reset_unit.vhd
--
-- Description  The unit is responsible for the generation of the:
--
--                o nanoFIP internal reset: that resets all nanoFIP's logic, apart from the WISHBONE
--                  It is asserted after a proper assertion of the "nanoFIP User Interface General
--                  signal" RSTIN (synchronized to the uclk), or
--                  after the reception of a valid var_rst with its 1st application-data byte
--                  containing the station's address. In those cases, the signal stays active for
--                  2 uclk cycles.
--                  It is also asserted during the activation of the "nanoFIP User Interface
--                  General signal" RSTPON. In this case it stays active for as long as the
--                  RSTPON is active.
--                                          __________
--                                  RSTIN  |          |       \ \
--                                 ________|   FSM    |_______ \ \
--                                         |  RSTIN   |         \  \
--                                         |__________|          \  \
--                                          __________            |  \
--                      rst_nFIP_and_FD_p  |          |           |   |      nFIP_rst
--                                 ________|   FSM    |________   |OR |  _______________
--                                         |  var_rst |           |   |
--                                         |__________|           |  /
--                                                               /  /
--                                 RSTPON                       /  /
--                                 __________________________  / /
--                                                            / /
--
--
--                o FIELDRIVE reset: nanoFIP FIELDRIVE output FD_RSTN
--                  Same as the nanoFIP internal reset, it can be activated by the RSTIN,
--                  a var_rst or the RSTPON. Regarding the activation time, for the first
--                  two cases (RSTIN, var_rst) it stays asserted for 4 FD_TXCK cycles whereas in
--                  the case of the RSTPON, it stays active for as long as the RSTPON is active.
--
--                                          __________
--                                  RSTIN  |          |       \ \
--                                 ________|   FSM    |_______ \ \
--                                         |  RSTIN   |         \  \
--                                         |__________|          \  \
--                                          __________            |  \
--                      rst_nFIP_and_FD_p  |          |           |   |      FD_RSTN
--                                 ________|   FSM    |________   |OR |  _______________
--                                         |  var_rst |           |   |
--                                         |__________|           |  /
--                                                               /  /
--                                 RSTPON                       /  /
--                                 __________________________  / /
--                                                            / /
--
--                o reset to the external logic: nanoFIP User Interface, General signal RSTON
--                  It is asserted after the reception of a valid var_rst with its 2nd data byte
--                  containing the station's address. It stays active for 8 uclk cycles.
--                                          _________
--                         assert_RSTON_p  |          |                       RSTON
--                                 ________|   FSM    |_________________________________
--                                         |  var_rst |
--                                         |__________|
--
--
--                o nanoFIP internal reset for the WISHBONE logic:
--                  It is asserted after the assertion of the "nanoFIP User Interface, WISHBONE
--                  Slave" input RST_I (not synchronized, to comply with with WISHBONE rule 3.15)
--                  or of the "nanoFIP User Interface General signal" RSTPON.
--                  It stays asserted for as long as the RST_I or RSTPON stay asserted.
--
--                                 RSTPON
--                                 __________________________ \ \
--                                                             \  \           wb_rst
--                                 RST_I                        |OR|____________________
--                                 __________________________  /  /
--                                                            / /
--
--
--              o The input signal RSTIN is considered only if it has been active for >8 uclk cycles
--              o The pulses rst_nFIP_and_FD_p and assert_RSTON_p come from the WF_cons_outcome unit
--                only after the sucessful validation of the frame structure and of the application-
--                data bytes of a var_rst; in this unit they are used here directly,
--                without any handling.
--              o The Power On Reset signal is used directly, without any handling.
--                --->>Still missing the synchronization with the uclk and wb_clk of the falling edge
--                     of RSTPON
--
--              The unit implements 2 state machines: one for resets coming from RSTIN
--                                                    and one for resets coming from a var_rst.
--
--
-- Authors      Erik van der Bij      (Erik.van.der.Bij@cern.ch)
--              Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)
--              Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)
-- Date         21/01/2011
-- Version      v0.03
-- Depends on   WF_cons_bytes_processor
----------------
-- Last changes
--     07/2009  v0.01  EB  First version
--     08/2010  v0.02  EG  checking of bytes1 and 2 of reset var added
--                         fd_rstn_o, nFIP_rst_o enabled only if rstin has been active for>4 uclk
--     01/2011  v0.03  EG  PoR added; signals assert_RSTON_p_i & rst_nFIP_and_FD_p_i are inputs
--                         treated in the wf_cons_outcome; 2 state machines created; clean-up
--                         PoR also for internal WISHBONE resets
--     02/2011  v0.031  EG state nfip_off_fd_off added
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
--                               GNU LESSER GENERAL PUBLIC LICENSE                                |
--                              ------------------------------------                              |
-- This source file is free software; you can redistribute it and/or modify it under the terms of |
-- the GNU Lesser General Public License as published by the Free Software Foundation; either     |
-- version 2.1 of the License, or (at your option) any later version.                             |
-- This source is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;       |
-- without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.      |
-- See the GNU Lesser General Public License for more details.                                    |
-- You should have received a copy of the GNU Lesser General Public License along with this       |
-- source; if not, download it from http://www.gnu.org/licenses/lgpl-2.1.html                     |
---------------------------------------------------------------------------------------------------



--=================================================================================================
--                                      Libraries & Packages
--=================================================================================================

-- Standard library
library IEEE;
use IEEE.STD_LOGIC_1164.all; -- std_logic definitions
use IEEE.NUMERIC_STD.all;    -- conversion functions
-- Specific library
library work;
use work.WF_PACKAGE.all;     -- definitions of types, constants, entities


--=================================================================================================
--                           Entity declaration for WF_reset_unit
--=================================================================================================
entity WF_reset_unit is
  port (
  -- INPUTS
    -- nanoFIP User Interface General signals
    uclk_i                                : in std_logic;    -- 40 MHz clock
    rstin_a_i           : in std_logic;     -- initialization control, active low
    rstpon_a_i          : in std_logic;     -- Power On Reset, active low
    rate_i              : in  std_logic_vector (1 downto 0); -- WorldFIP bit rate

    -- nanoFIP User Interface WISHBONE Slave
    rst_i               : in std_logic;     -- WISHBONE reset
    wb_clk_i            : in std_logic;     -- WISHBONE clock

    -- Signal from the WF_consumption unit
    rst_nFIP_and_FD_p_i : in std_logic;     -- indicates that a var_rst with its 1st byte
                                            -- containing the station's address has been
                                            -- correctly received

    assert_RSTON_p_i    : in std_logic;     -- indicates that a var_rst with its 2nd byte
                                            -- containing the station's address has been
                                            -- correctly received


  -- OUTPUTS
    -- nanoFIP internal reset, to all the units
    nFIP_rst_o          : out std_logic;    -- nanoFIP internal reset, active high
                                            -- resets all nanoFIP logic, apart from the WISHBONE

    -- Signal to the WF_wb_controller
    wb_rst_o            : out std_logic;    -- reset of the WISHBONE logic

    -- nanoFIP User Interface General signal output
    rston_o             : out std_logic;    -- reset output, active low

    -- nanoFIP FIELDRIVE output
    fd_rstn_o           : out std_logic     -- FIELDRIVE reset, active low
       );
end entity WF_reset_unit;


--=================================================================================================
--                                    architecture declaration
--=================================================================================================
architecture rtl of WF_reset_unit is

  type rstin_st_t   is (idle, rstin_eval, nfip_on_fd_on, nfip_off_fd_on, nfip_off_fd_off);
  type var_rst_st_t is (var_rst_idle, var_rst_rston_on, var_rst_nfip_on_fd_on_rston_on,
                        var_rst_nfip_off_fd_on_rston_on, var_rst_nfip_on_fd_on,
                        var_rst_nfip_off_fd_on_rston_off);

  signal var_rst_st, nx_var_rst_st                    : var_rst_st_t;
  signal rstin_st, nx_rstin_st                        : rstin_st_t;
  signal s_rstin_c, s_var_rst_c                       : unsigned (c_2_PERIODS_COUNTER_LGTH-1 downto 0);
  signal s_rstin_c_reinit, s_rstin_c_is_four, s_rstin_c_is_ten, s_rstin_c_is_full          : std_logic;
  signal s_var_rst_c_reinit, s_var_rst_c_is_two, s_var_rst_c_is_eight, s_var_rst_c_is_full : std_logic;
  signal s_rstin_nfip, s_rstin_fd, s_var_rst_fd, s_var_rst_nfip, s_rston                   : std_logic;
  signal s_transm_period                              : unsigned (c_PERIODS_COUNTER_LGTH - 1 downto 0);
  signal s_txck_four_periods                          : unsigned (c_2_PERIODS_COUNTER_LGTH-1 downto 0);
  signal s_u_por_ff1, s_u_por, s_wb_por_ff1, s_wb_por : std_logic;
  signal s_rsti_synch                                 : std_logic_vector (2 downto 0);

--=================================================================================================
--                                       architecture begin
--=================================================================================================
begin


  s_transm_period     <= c_BIT_RATE_UCLK_TICKS(to_integer(unsigned(rate_i)));-- # uclk ticks of a
                                                                             -- transmission period

  s_txck_four_periods <= resize(s_transm_period, s_txck_four_periods'length) sll 1;-- # uclk ticks
                                                                                   -- of 2 transm.
                                                                                   -- periods = 4
                                                                                   -- FD_TXCK periods


---------------------------------------------------------------------------------------------------
--                                  Power On Reset Synchronizers                                 --
---------------------------------------------------------------------------------------------------

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Synchronization of the de-assertion of the Power On reset, with the wb_clk.
-- The second flip-flop is used to remove metastabilities.

  PoR_wb_clk_Synchronizer: process (wb_clk_i, rstpon_a_i)
    begin
      if rstpon_a_i = '0' then
        s_wb_por_ff1 <= '1';
        s_wb_por     <= '1';
      elsif rising_edge (wb_clk_i) then
        s_wb_por_ff1 <= '0';
        s_wb_por     <= s_wb_por_ff1;
      end if;
    end process;


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Synchronization of the de-assertion of the Power On reset, with the uclk.
-- The second flip-flop is used to remove metastabilities.

  PoR_uclk_Synchronizer: process (uclk_i, rstpon_a_i)
    begin
      if rstpon_a_i = '0' then
        s_u_por_ff1 <= '1';
        s_u_por     <= '1';
      elsif rising_edge (uclk_i) then
        s_u_por_ff1 <= '0';
        s_u_por     <= s_u_por_ff1;
      end if;
    end process;



---------------------------------------------------------------------------------------------------
--                                             RSTIN                                             --
---------------------------------------------------------------------------------------------------

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- RSTIN synchronization with a set of 3 registers.

  RSTIN_uclk_Synchronizer: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      s_rsti_synch <= s_rsti_synch (1 downto 0) &  not rstin_a_i;
    end if;
  end process;


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- RSTIN FSM: the state machine is divided in three parts (a clocked process
-- to store the current state, a combinatorial process to manage state transitions and finally a
-- combinatorial process to manage the output signals), which are the three processes that follow.
-- The FSM is following the "User Interface, General signal" RSTIN (after synchronization) and
-- checks whether it stays active for more than 4 uclk cycles; if so, it enables the nanoFIP
-- internal reset (s_rstin_nfip) and the FIELDRIVE reset (s_rstin_fd). The
-- nanoFIP internal reset stays active for 2 uclk cycles and the  FIELDRIVE for 4 FD_TXCK cycles.
-- The same counter is used for the evaluation of the RSTIN (if it is > 4 uclk) and for the
-- generation of the two reset signals.

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Synchronous process RSTIN_FSM_Sync: Storage of the current state of the FSM.
-- The state machine can be reset by the Power On Reset and the variable reset.
  RSTIN_FSM_Sync: process (uclk_i)
    begin
      if rising_edge (uclk_i) then
        if s_u_por = '1' or rst_nFIP_and_FD_p_i = '1' then
          rstin_st <= idle;
        else
          rstin_st <= nx_rstin_st;
        end if;
      end if;
    end process;


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Combinatorial process RSTIN_FSM_Comb_State_Transitions: definition of the state
-- transitions of the FSM.

  RSTIN_FSM_Comb_State_Transitions: process (rstin_st, s_rsti_synch(2), s_rstin_c_is_four,
                                             s_rstin_c_is_ten, s_rstin_c_is_full)

  begin

  case rstin_st is

    when idle =>
                        if s_rsti_synch(2) = '1' then      -- RSTIN active
                          nx_rstin_st   <= rstin_eval;

                        else
                          nx_rstin_st   <= idle;
                        end if;


    when rstin_eval =>
                        if s_rsti_synch(2) = '0' then      -- RSTIN deactivated
                          nx_rstin_st   <= idle;

                        else
                          if s_rstin_c_is_four = '1' then  -- counting the uclk cycles that
                            nx_rstin_st <= nfip_on_fd_on;  -- RSTIN is active

                          else
                            nx_rstin_st <= rstin_eval;
                          end if;
                        end if;


    when nfip_on_fd_on =>

                        if s_rstin_c_is_ten = '1' then     -- nanoFIP internal reset and
                          nx_rstin_st   <= nfip_off_fd_on; -- FIELDRIVE reset active for
                                                           -- 2 uclk cycles

                        else
                          nx_rstin_st   <= nfip_on_fd_on;
                        end if;


    when nfip_off_fd_on =>
                                                           -- nanoFIP internal reset deactivated
                        if s_rstin_c_is_full = '1' then    -- FIELDRIVE reset continues being active
                          nx_rstin_st   <= nfip_off_fd_off;-- unitl 4 FD_TXCK cycles have passed

                        else
                          nx_rstin_st   <= nfip_off_fd_on;
                        end if;


    when nfip_off_fd_off =>

                        if s_rsti_synch(2) = '1' then      -- RSTIN still active
                          nx_rstin_st   <= nfip_off_fd_off;
                        else
                          nx_rstin_st   <= idle;
                        end if;


    when others =>
                        nx_rstin_st   <= idle;
  end case;
  end process;

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Combinatorial process RSTIN_FSM_Comb_Output_Signals: definition of the output signals of
-- the FSM. The process is handling the signals for the nanoFIP internal reset (s_rstin_nfip)
-- and the FIELDRIVE reset (s_rstin_fd), as well as the inputs of the RSTIN_free_counter.

  RSTIN_FSM_Comb_Output_Signals: process (rstin_st)

  begin

    case rstin_st is

    when idle =>
                  s_rstin_c_reinit <= '1';    -- counter initialized

                  s_rstin_nfip     <= '0';
                  s_rstin_fd       <= '0';


    when rstin_eval =>
                  s_rstin_c_reinit <= '0';    -- counting until 4
                                              -- if RSTIN is active
                  s_rstin_nfip     <= '0';
                  s_rstin_fd       <= '0';


    when nfip_on_fd_on =>
                  s_rstin_c_reinit <= '0';    -- free counter counting 2 uclk cycles

                 -------------------------------------
                  s_rstin_fd       <= '1';    -- FIELDRIVE     active
                  s_rstin_nfip     <= '1';    -- nFIP internal active
                 -------------------------------------


    when nfip_off_fd_on =>
                  s_rstin_c_reinit <= '0';    -- free counter counting 4 FD_TXCK cycles

                  s_rstin_nfip     <= '0';
                 -------------------------------------
                  s_rstin_fd       <= '1';    -- FIELDRIVE     active
                 -------------------------------------


    when nfip_off_fd_off =>
                  s_rstin_c_reinit <= '1';    -- no counting

                  s_rstin_nfip     <= '0';
                  s_rstin_fd       <= '0';


    when others =>
                  s_rstin_c_reinit <= '1';    -- no counting

                  s_rstin_fd       <= '0';
                  s_rstin_nfip     <= '0';


    end case;
  end process;


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Instantiation of a WF_incr_counter: the counter counts from 0 to 4 FD_TXCK.

RSTIN_free_counter: WF_incr_counter
  generic map (g_counter_lgth => c_2_PERIODS_COUNTER_LGTH)
  port map (
    uclk_i            => uclk_i,
    reinit_counter_i  => s_rstin_c_reinit,
    incr_counter_i    => '1',
    counter_is_full_o => open,
   ----------------------------------------
    counter_o         => s_rstin_c);
   ----------------------------------------

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  s_rstin_c_is_four  <= '1' when s_rstin_c = to_unsigned(4, s_rstin_c'length)  else '0';
  s_rstin_c_is_ten   <= '1' when s_rstin_c = to_unsigned(10, s_rstin_c'length) else '0';
  s_rstin_c_is_full  <= '1' when s_rstin_c = s_txck_four_periods               else '0';



---------------------------------------------------------------------------------------------------
--                                            var_rst                                            --
---------------------------------------------------------------------------------------------------
-- Resets_after_a_var_rst FSM: the state machine is divided in three parts (a clocked process
-- to store the current state, a combinatorial process to manage state transitions and finally a
-- combinatorial process to manage the output signals), which are the three processes that follow.
-- If after the reception of a var_rst the signal assert_RSTON_p_i is asserted, the FSM
-- asserts the "nanoFIP user Interface General signal" RSTON for 8 uclk cycles.
-- If after the reception of a var_rst the signal rst_nFIP_and_FD_p_i is asserted, the FSM
-- asserts the nanoFIP internal reset (s_var_rst_nfip) for 2 uclk cycles and the
-- "nanoFIP FIELDRIVE" output (s_var_rst_fd) for 4 FD_TXCK cycles.
-- If after the reception of a var_rst both assert_RSTON_p_i and rst_nFIP_and_FD_p_i
-- are asserted, the FSM asserts the s_var_rst_nfip for 2 uclk cycles, the RSTON for 8
-- uclk cycles and the s_var_rst_fd for 4 FD_TXCK cycles.
-- The same counter is used for all the countings!

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Synchronous process Resets_after_a_var_rst_synch: Storage of the current state of the FSM
-- The state machine can be reset by the Power On Reset and the nanoFIP internal reset from RSTIN.
   Resets_after_a_var_rst_synch: process (uclk_i)
    begin
      if rising_edge (uclk_i) then
        if s_u_por = '1' or s_rstin_nfip = '1' then
          var_rst_st <= var_rst_idle;
        else
          var_rst_st <= nx_var_rst_st;
        end if;
      end if;
  end process;


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Combinatorial process Resets_after_a_var_rst_Comb_State_Transitions: definition of the
-- state transitions of the FSM.

  Resets_after_a_var_rst_Comb_State_Transitions: process (var_rst_st, rst_nFIP_and_FD_p_i,
                                                          assert_RSTON_p_i, s_var_rst_c_is_two,
                                                          s_var_rst_c_is_eight,
                                                          s_var_rst_c_is_full)

  begin

  case var_rst_st is

    when var_rst_idle =>

                        if assert_RSTON_p_i = '1' and rst_nFIP_and_FD_p_i = '1' then
                          nx_var_rst_st   <= var_rst_nfip_on_fd_on_rston_on;

                        elsif assert_RSTON_p_i = '1' then
                          nx_var_rst_st   <= var_rst_rston_on;

                        elsif rst_nFIP_and_FD_p_i = '1' then
                          nx_var_rst_st   <= var_rst_nfip_on_fd_on;

                        else
                          nx_var_rst_st   <= var_rst_idle;
                        end if;


    when var_rst_rston_on =>                              -- for 8 uclk cycles

                        if s_var_rst_c_is_eight = '1' then
                          nx_var_rst_st   <= var_rst_idle;

                        else
                          nx_var_rst_st <= var_rst_rston_on;
                        end if;


    when var_rst_nfip_on_fd_on_rston_on =>                -- for 2 uclk cycles

                        if s_var_rst_c_is_two = '1' then
                          nx_var_rst_st <= var_rst_nfip_off_fd_on_rston_on;

                        else
                          nx_var_rst_st <= var_rst_nfip_on_fd_on_rston_on;
                        end if;


    when var_rst_nfip_off_fd_on_rston_on =>              -- for 6 uclk cycles

                        if s_var_rst_c_is_eight = '1' then
                          nx_var_rst_st <= var_rst_nfip_off_fd_on_rston_off;

                        else
                          nx_var_rst_st <= var_rst_nfip_off_fd_on_rston_on;
                        end if;


    when var_rst_nfip_on_fd_on =>                        -- for 2 uclk cycles

                        if s_var_rst_c_is_two = '1' then
                          nx_var_rst_st <= var_rst_nfip_off_fd_on_rston_off;

                        else
                          nx_var_rst_st <= var_rst_nfip_on_fd_on;
                        end if;


    when var_rst_nfip_off_fd_on_rston_off =>             -- until the filling-up of the counter

                        if s_var_rst_c_is_full = '1' then
                           nx_var_rst_st <= var_rst_idle;

                        else
                           nx_var_rst_st <= var_rst_nfip_off_fd_on_rston_off;
                        end if;


    when others =>
                        nx_var_rst_st <= var_rst_idle;
  end case;
  end process;

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Combinatorial process RSTIN_FSM_Comb_Output_Signals: definition of the output signals of
-- the FSM. The process is managing the signals for the nanoFIP internal reset and the FIELDRIVE
-- reset, as well as the arguments of the counter.

  rst_var_FSM_Comb_Output_Signals: process (var_rst_st)

  begin

    case var_rst_st is

    when var_rst_idle =>
                                     s_var_rst_c_reinit <= '1';    -- counter initialized

                                     s_rston            <= '0';
                                     s_var_rst_nfip     <= '0';
                                     s_var_rst_fd       <= '0';


    when var_rst_rston_on =>
                                     s_var_rst_c_reinit <= '0';    -- counting 8 uclk cycles

                                    -------------------------------------
                                     s_rston            <= '1';    -- RSTON         active
                                    -------------------------------------
                                     s_var_rst_nfip     <= '0';
                                     s_var_rst_fd       <= '0';


    when var_rst_nfip_on_fd_on_rston_on =>
                                     s_var_rst_c_reinit <= '0';    -- counting 2 uclk cycles

                                    -------------------------------------
                                     s_rston            <= '1';    -- RSTON         active
                                     s_var_rst_nfip     <= '1';    -- nFIP internal active
                                     s_var_rst_fd       <= '1';    -- FIELDRIVE     active
                                    -------------------------------------


    when var_rst_nfip_off_fd_on_rston_on =>
                                     s_var_rst_c_reinit <= '0';    -- counting 6 uclk cycles

                                     s_var_rst_nfip     <= '0';
                                    -------------------------------------
                                     s_rston            <= '1';    -- RSTON         active
                                     s_var_rst_fd       <= '1';    -- FIELDRIVE     active
                                    -------------------------------------


    when var_rst_nfip_on_fd_on =>
                                     s_var_rst_c_reinit <= '0';    -- counting 2 uclk cycles

                                     s_rston            <= '0';
                                    -------------------------------------
                                     s_var_rst_nfip     <= '1';    -- nFIP internal active
                                     s_var_rst_fd       <= '1';    -- FIELDRIVE     active
                                    -------------------------------------


    when var_rst_nfip_off_fd_on_rston_off =>
                                     s_var_rst_c_reinit <= '0';    -- counting 4 FD_TXCK cycles

                                     s_rston            <= '0';
                                     s_var_rst_nfip     <= '0';
                                    -------------------------------------
                                    s_var_rst_fd        <= '1';    -- FIELDRIVE     active
                                    -------------------------------------


    when others =>
                                     s_var_rst_c_reinit <= '1';    -- no counting

                                     s_rston            <= '0';
                                     s_var_rst_nfip     <= '0';
                                     s_var_rst_fd       <= '0';


    end case;
  end process;



--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Instantiation of a WF_incr_counter:
-- the counter counts from 0 to 8, if only assert_RSTON_p has been activated, or
--                    from 0 to 4 * FD_TXCK, if rst_nFIP_and_FD_p has been activated.

free_counter: WF_incr_counter
  generic map (g_counter_lgth => c_2_PERIODS_COUNTER_LGTH)
  port map (
    uclk_i            => uclk_i,
    reinit_counter_i  => s_var_rst_c_reinit,
    incr_counter_i    => '1',
    counter_is_full_o => open,
   ----------------------------------------
    counter_o         => s_var_rst_c);
   ----------------------------------------

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  s_var_rst_c_is_eight <= '1' when s_var_rst_c= to_unsigned(8, s_var_rst_c'length) else '0';
  s_var_rst_c_is_two   <= '1' when s_var_rst_c= to_unsigned(2, s_var_rst_c'length) else '0';
  s_var_rst_c_is_full  <= '1' when s_var_rst_c= s_txck_four_periods                else '0';



---------------------------------------------------------------------------------------------------
--                                         Output Signals                                        --
---------------------------------------------------------------------------------------------------

  wb_rst_o      <= rst_i or s_wb_por;
  nFIP_rst_o    <= s_rstin_nfip or s_var_rst_nfip or s_u_por;

  -- Flip-flop with asynchronous reset to be sure that whenever nanoFIP is reset the user is not
  RSTON_Buffering: process (uclk_i, s_u_por, s_rstin_nfip, s_var_rst_nfip)
  begin
    if s_rstin_nfip = '1' or s_var_rst_nfip = '1' or s_u_por = '1' then
      rston_o   <=  '1';
    elsif rising_edge (uclk_i) then
      rston_o   <= not s_rston;
    end if;
  end process;


  FD_RST_Buffering: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      fd_rstn_o <= not (s_rstin_fd or s_var_rst_fd or s_u_por);
    end if;
  end process;

end architecture rtl;
--=================================================================================================
--                                        architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------