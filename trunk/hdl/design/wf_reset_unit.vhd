--_________________________________________________________________________________________________
--                                                                                                |
--                                        |The nanoFIP|                                           |
--                                                                                                |
--                                        CERN,BE/CO-HT                                           |
--________________________________________________________________________________________________|
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--! @file WF_reset_unit.vhd                                                                       |
---------------------------------------------------------------------------------------------------

--! Standard library
library IEEE;

--! Standard packages
use IEEE.STD_LOGIC_1164.all; --! std_logic definitions
use IEEE.NUMERIC_STD.all;    --! conversion functions

use work.WF_PACKAGE.all;     --! definitions of types, constants, entities


---------------------------------------------------------------------------------------------------
--                                                                                               --
--                                        WF_reset_unit                                          --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
--
--! @brief     The unit is responsible for the generation of the:
--!
--!              o nanoFIP internal reset: that resets all nanoFIP's logic, apart from the WISHBONE
--!                  It is asserted after a proper assertion of the "nanoFIP User Interface General
--!                  signal" RSTIN (synchronized to the uclk), or
--!                  after the reception of a valid var_rst with its 1st application-data byte
--!                  containing the station's address. In those cases, the signal stays active for
--!                  2 uclk cycles.
--!                  It is also asserted during the activation of the "nanoFIP User Interface
--!                  General signal" RSTPON. In this case it stays active for as long as the
--!                  RSTPON is active.
--!                                          __________
--!                                  RSTIN  |          |       \ \
--!                                 ________|   FSM    |_______ \ \
--!                                         |  RSTIN   |         \  \
--!                                         |__________|          \  \
--!                                          __________            |  \
--!                      rst_nFIP_and_FD_p  |          |           |   |      nFIP_rst
--!                                 ________|   FSM    |________   |OR |  _______________ 
--!                                         |  var_rst |           |   |
--!                                         |__________|           |  /
--!                                                               /  /
--!                                 RSTPON                       /  /
--!                                 __________________________  / /
--!                                                            / / 
--!
--!
--!              o FIELDRIVE reset: nanoFIP FIELDRIVE output FD_RSTN
--!                  Same as the nanoFIP internal reset, it can be activated by the RSTIN,
--!                  a var_rst or the RSTPON. Regarding the activation time, for the first
--!                  two cases (RSTIN, var_rst) it stays asserted for 4 FD_TXCK cycles whereas in
--!                  the case of the RSTPON, it stays active for as long as the RSTPON is active.
--!
--!                                          __________
--!                                  RSTIN  |          |       \ \
--!                                 ________|   FSM    |_______ \ \
--!                                         |  RSTIN   |         \  \
--!                                         |__________|          \  \
--!                                          __________            |  \
--!                      rst_nFIP_and_FD_p  |          |           |   |      FD_RSTN
--!                                 ________|   FSM    |________   |OR |  _______________ 
--!                                         |  var_rst |           |   |
--!                                         |__________|           |  /
--!                                                               /  /
--!                                 RSTPON                       /  /
--!                                 __________________________  / /
--!                                                            / / 
--!
--!
--!              o reset to the external logic: nanoFIP User Interface, General signal RSTON 
--!                  It is asserted after the reception of a valid var_rst with its 2nd data byte
--!                  containing the station's address. It stays active for 8 uclk cycles.
--!                                          __________            
--!                           assert_RSTON  |          |                       RSTON   
--!                                 ________|   FSM    |_________________________________   
--!                                         |  var_rst |          
--!                                         |__________| 
--! 
--!
--!              o nanoFIP internal reset for the WISHBONE logic: 
--!                  It is asserted after the assertion of the "nanoFIP User Interface, WISHBONE
--!                  Slave" input RST_I (not synchronized, to comply with with WISHBONE rule 3.15)
--!                  or of the "nanoFIP User Interface General signal" RSTPON.
--!                  It stays asserted for as long as the RST_I or RSTPON stay asserted.
--!    
--!                                 RSTPON                       
--!                                 __________________________ \ \
--!                                                             \  \           wb_rst
--!                                 RST_I                        |OR|____________________
--!                                 __________________________  /  /
--!                                                            / /
--!
--!
--!            o The input signal RSTIN is considered only if it has been active for >8 uclk cycles
--!            o The pulses rst_nFIP_and_FD_p and assert_RSTON_p come from the WF_cons_outcome unit
--!              only after the sucessful validation of the frame structure and of the application-
--!              data bytes of a var_rst; in this unit they are used here directly,
--!              without any handling.
--!            o The Power On Reset signal is used directly, without any handling. 
--!              --->>Still missing the synchronization with the uclk and wb_clk of the falling edge
--                    of RSTPON
--!
--!            The unit implements 2 state machines: one for resets coming from RSTIN
--!                                                  and one for resets coming from a var_rst.

--!
--!

--!

--
--
--! @author    Erik van der Bij      (Erik.van.der.Bij@cern.ch)      \n
--!            Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch) \n
--!            Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)     \n
--
--
--! @date      21/01/2011
--
--
--! @version   v0.03
--
--
--! @details 
--
--!   \n<b>Dependencies:</b>           \n
--!            WF_cons_bytes_processor \n
-- 
--
--!   \n<b>Modified by:</b>          \n
--!            Pablo Alvarez Sanchez \n
--!            Evangelia Gousiou     \n
--
---------------------------------------------------------------------------------------------------
--
--!   \n\n<b>Last changes:</b>\n
--!     07/2009  v0.01  EB  First version \n
--!     08/2010  v0.02  EG  checking of bytes1 and 2 of reset var added \n
--!                         fd_rstn_o, nFIP_rst_o enabled only if rstin has been active for>4 uclk
--!     01/2011  v0.03  EG  PoR added; signals assert_RSTON_p_i & rst_nFIP_and_FD_p_i are inputs
--!                         treated in the wf_cons_outcome; 2 state machines created; clean-up
--!                         PoR also for internal WISHBONE resets 
--
---------------------------------------------------------------------------------------------------
--
--! @todo -> synchronize falling edge (@ deactivation) of asynchronous RSTPON to uclk and wb_clk
--!          here for the moment we just use rstpon_i for both worlds
--
---------------------------------------------------------------------------------------------------



--=================================================================================================
--!                           Entity declaration for WF_reset_unit
--=================================================================================================
entity WF_reset_unit is
  port (
  -- INPUTS
    -- nanoFIP User Interface General signals 
    uclk_i              : in std_logic;     --! 40 MHz clock
    rstin_a_i           : in std_logic;     --! initialisation control, active low (synch/ed with uclk)
    rstpon_i            : in std_logic;     --! Power On Reset, active low
    rate_i              : in  std_logic_vector (1 downto 0); --! WorldFIP bit rate (synch/ed with uclk)


    wb_clk_i            : in std_logic;

    -- nanoFIP User Interface WISHBONE Slave
    rst_i               : in std_logic;     --! WISHBONE reset

    -- Signal from the WF_engine_control unit
    var_i               : in t_var;         --! variable type that is being treated

    -- Signal from the WF_consumption unit
    rst_nFIP_and_FD_p_i : in std_logic;     --! indicates that a var_rst with its 1st byte
                                            --! containing the station's address has been
                                            --! correctly received

    assert_RSTON_p_i    : in std_logic;     --! indicates that a var_rst with its 2nd byte
                                            --! containing the station's address has been
                                            --! correctly received


  -- OUTPUTS
    -- nanoFIP internal reset, to all the units
    nFIP_rst_o          : out std_logic;    --! nanoFIP internal reset, active high
                                            --! resets all nanoFIP logic, apart from the WISHBONE

    -- Signal to the WF_wb_controller
    wb_rst_o            : out std_logic;    --! reset of the WISHBONE logic

    -- nanoFIP User Interface General signal output 
    rston_o             : out std_logic;    --! reset output, active low

    -- nanoFIP FIELDRIVE output
    fd_rstn_o           : out std_logic     --! FIELDRIVE reset, active low
       );
end entity WF_reset_unit;


--=================================================================================================
--!                                    architecture declaration
--=================================================================================================
architecture rtl of WF_reset_unit is

  signal s_counter_is_four, s_reinit_counter, s_rston, s_FD_rst_from_var_rst           : std_logic;
  signal s_u_por_ff1, s_u_por, s_wb_por_ff1, s_wb_por                          : std_logic;
  signal s_intern_rst_from_RSTIN, s_intern_rst_from_var_rst, s_fd_rst_from_RSTIN       : std_logic;
  signal s_counter_is_ten, s_counter_is_full, s_counter_full                           : std_logic;
  signal s_var_rst_counter_is_eight, s_var_rst_counter_is_two                          : std_logic;
  signal s_var_rst_reinit_counter, s_var_rst_counter_is_full, s_var_rst_counter_full   : std_logic;
  signal s_transm_period                        : unsigned   (c_PERIODS_COUNTER_LENGTH-1 downto 0);
  signal s_c, s_var_rst_c, s_txck_four_periods  : unsigned (c_2_PERIODS_COUNTER_LENGTH-1 downto 0);

  type rstin_st_t        is (idle, rstin_eval, intern_rst_ON_FD_rst_ON,intern_rst_OFF_FD_rst_ON);
  type after_a_var_rst_t is (after_a_var_rst_idle, after_a_var_rst_rston_ON,
                             after_a_var_rst_nFIP_ON_fd_ON_rston_ON,
                             after_a_var_rst_nFIP_OFF_fd_ON_rston_ON,
                             after_a_var_rst_nFIP_ON_fd_ON,
                             after_a_var_rst_nFIP_OFF_fd_ON_rston_OFF);

  signal after_a_var_rst_st, nx_after_a_var_rst_st : after_a_var_rst_t;
  signal rstin_st, nx_rstin_st                     : rstin_st_t;
  signal s_rsti_synch : std_logic_vector (2 downto 0);

--=================================================================================================
--                                        architecture begin
--================================================================================================= 
begin

  s_transm_period     <= c_BIT_RATE_UCLK_TICKS(to_integer(unsigned(rate_i)));-- # uclk ticks of a
                                                                             -- transmission period

  s_txck_four_periods <= resize(s_transm_period, s_txck_four_periods'length) sll 1;-- # uclk ticks
                                                                                   -- of 2 transm.
                                                                                   -- periods = 4
                                                                                   -- FD_TXCK periods
  s_counter_full         <= '1' when s_c         = s_txck_four_periods else '0';                   
  s_var_rst_counter_full <= '1' when s_var_rst_c = s_txck_four_periods else '0';




---------------------------------------------------------------------------------------------------
--                                  Power On Reset Synchronizers                                 --
---------------------------------------------------------------------------------------------------

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
--!@brief Synchronization of the de-assertion of the Power On reset, with the wb_clk.
--! The second flip-flop is used to remove metastabilities. 

  PoR_wb_clk_Synchronizer: process (wb_clk_i, rstpon_i)
    begin
      if rstpon_i = '0' then
        s_wb_por_ff1 <= '1';
        s_wb_por     <= '1';
      elsif rising_edge (wb_clk_i) then
        s_wb_por_ff1 <= '0';
        s_wb_por     <= s_wb_por_ff1;
      end if;
    end process;


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
--!@brief Synchronization of the de-assertion of the Power On reset, with the uclk.
--! The second flip-flop is used to remove metastabilities. 

  PoR_uclk_Synchronizer: process (uclk_i, rstpon_i)
    begin
      if rstpon_i = '0' then
        s_u_por_ff1 <= '1';
        s_u_por     <= '1';
      elsif rising_edge (uclk_i) then
        s_u_por_ff1 <= '0';
        s_u_por     <= s_u_por_ff1;
      end if;
    end process;



---------------------------------------------------------------------------------------------------
--                                            RSTIN                                              --
---------------------------------------------------------------------------------------------------

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
--!@brief RSTIN synchronization with a set of 3 registers.

  RSTIN_uclk_Synchronizer: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      s_rsti_synch <= s_rsti_synch (1 downto 0) &  not rstin_a_i;
    end if;
  end process;


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
--!@brief RSTIN FSM: the state machine is divided in three parts (a clocked process
--! to store the current state, a combinatorial process to manage state transitions and finally a
--! combinatorial process to manage the output signals), which are the three processes that follow.
--! The FSM is following the "User Interface, General signal" RSTIN (after synchronization) and
--! checks whether it stays active for more than 4 uclk cycles; if so, it enables the nanoFIP
--! internal reset (s_intern_rst_from_RSTIN) and the FIELDRIVE reset (s_FD_rst_from_RSTIN). The
--! nanoFIP internal reset stays active for 2 uclk cycles and the  FIELDRIVE for 4 FD_TXCK cycles.
--! The same counter is used for the evaluation of the RSTIN (if it is > 4 uclk) and for the
--! generation of the two reset signals.

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  
--!@brief synchronous process RSTIN_FSM_Sync: Storage of the current state of the FSM.
--! The state machine can be reset by the Power On Reset and the variable reset.
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
--!@brief Combinatorial process RSTIN_FSM_Comb_State_Transitions: definition of the state
--! transitions of the FSM.
  
  RSTIN_FSM_Comb_State_Transitions: process (rstin_st, s_rsti_synch(2), s_counter_is_four,
                                             s_counter_is_ten, s_counter_is_full)
  
  begin
  
  case rstin_st is 

    when idle =>                                                        
                        if s_rsti_synch(2) = '1' then              -- RSTIN active
                          nx_rstin_st   <= rstin_eval;  

                        else 
                          nx_rstin_st   <= idle;
                        end if;
 
  
    when rstin_eval => 
                        if s_rsti_synch(2) = '0' then              -- RSTIN deactivated
                          nx_rstin_st   <= idle;

                        else
                          if s_counter_is_four = '1' then          -- counting the uclk cycles that 
                            nx_rstin_st <= intern_rst_ON_fd_rst_ON;-- RSTIN is active 

                          else 
                            nx_rstin_st <= rstin_eval;
                          end if;	
                        end if;  


    when intern_rst_ON_fd_rst_ON =>                   

                        if s_counter_is_ten = '1' then             -- nanoFIP internal reset and             
                          nx_rstin_st <= intern_rst_OFF_fd_rst_ON; -- FIELDRIVE reset active for
                                                                   -- 2 uclk cycles

                        else
                          nx_rstin_st <= intern_rst_ON_fd_rst_ON;
                        end if;


    when intern_rst_OFF_fd_rst_ON =>                              
                                                          -- nanoFIP internal reset deactivated
                        if s_counter_is_full = '1' then   -- FIELDRIVE reset continues being active
                           nx_rstin_st <= idle;           -- unitl 4 FD_TXCK cycles have passed

                        else
                           nx_rstin_st <= intern_rst_OFF_FD_rst_ON;
                        end if;

                      
    when others => 
                        nx_rstin_st <= idle;
  end case;	
  end process;
  
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
--!@brief combinatorial process RSTIN_FSM_Comb_Output_Signals: definition of the output signals of
--! the FSM. The process is handling the signals for the nanoFIP internal reset
--! (s_intern_rst_from_RSTIN) and the FIELDRIVE reset (s_FD_rst_from_RSTIN), as well as the inputs
--! of the RSTIN_free_counter.

  RSTIN_FSM_Comb_Output_Signals: process (rstin_st)

  begin
  
    case rstin_st is 
  
    when idle =>           
                  s_reinit_counter        <= '1';    -- counter initialized 

                  s_intern_rst_from_RSTIN <= '0'; 
                  s_FD_rst_from_RSTIN     <= '0';  
 
                                
    when rstin_eval => 
                  s_reinit_counter        <= '0';    -- counting until 4 
                                                     -- if RSTIN is active
                  s_intern_rst_from_RSTIN <= '0';  
                  s_FD_rst_from_RSTIN     <= '0';


    when intern_rst_ON_fd_rst_ON =>
                  s_reinit_counter        <= '0';    -- free counter counting 2 uclk cycles

                 ------------------------------------- 
                  s_FD_rst_from_RSTIN     <= '1';    -- FIELDRIVE     active 
                  s_intern_rst_from_RSTIN <= '1';    -- nFIP internal active  
                 ------------------------------------- 


    when intern_rst_OFF_fd_rst_ON =>
                  s_reinit_counter        <= '0';    -- free counter counting 4 FD_TXCK cycles

                  s_intern_rst_from_RSTIN <= '0';
                 ------------------------------------- 
                  s_FD_rst_from_RSTIN     <= '1';    -- FIELDRIVE     active 
                 ------------------------------------- 


    when others =>
                  s_reinit_counter        <= '1';    -- no counting

                  s_FD_rst_from_RSTIN     <= '0'; 
                  s_intern_rst_from_RSTIN <= '0';
 

    end case;	
  end process;


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
--!@brief Instantiation of a WF_incr_counter: the counter counts from 0 to 4 FD_TXCK.

RSTIN_free_counter: WF_incr_counter
  generic map (g_counter_lgth => c_2_PERIODS_COUNTER_LENGTH)
  port map (
    uclk_i            => uclk_i,        
    reinit_counter_i  => s_reinit_counter,
    incr_counter_i    => '1',
    counter_o         => s_c,
    counter_is_full_o => open);

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
  s_counter_is_four  <= '1' when s_c = to_unsigned(4, s_c'length)  else '0'; 
  s_counter_is_ten   <= '1' when s_c = to_unsigned(10, s_c'length) else '0'; 
  s_counter_is_full  <= s_counter_full;
  


---------------------------------------------------------------------------------------------------
--                                              var_rst                                          --
---------------------------------------------------------------------------------------------------
--!@brief Resets_after_a_var_rst FSM: the state machine is divided in three parts (a clocked process
--! to store the current state, a combinatorial process to manage state transitions and finally a
--! combinatorial process to manage the output signals), which are the three processes that follow.
--! If after the reception or a var_rst the signal assert_RSTON_p_i is asserted, the FSM
--! asserts the "nanoFIP user Interface General signal" RSTON for 8 uclk cycles.
--! If after the reception or a var_rst the signal rst_nFIP_and_FD_p_i is asserted, the FSM
--! asserts the nanoFIP internal reset (s_intern_rst_from_var_rst) for 2 uclk cycles and the
--! "nanoFIP FIELDRIVE" output (s_FD_rst_from_var_rst) for 4 FD_TXCK cycles.
--! If after the reception or a var_rst both assert_RSTON_p_i and rst_nFIP_and_FD_p_i
--! are asserted, the FSM asserts the s_intern_rst_from_var_rst for 2 uclk cycles, the RSTON for 8
--! uclk cycles and the s_FD_rst_from_var_rst for 4 FD_TXCK cycles.
--! The same counter is used for all the countings!

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  
--!@brief Synchronous process Resets_after_a_var_rst_synch: Storage of the current state of the FSM
--! The state machine can be reset by the Power On Reset and the nanoFIP internal reset from RSTIN.
   Resets_after_a_var_rst_synch: process (uclk_i)
    begin
      if rising_edge (uclk_i) then
        if s_u_por = '1' or s_intern_rst_from_RSTIN = '1' then
          after_a_var_rst_st <= after_a_var_rst_idle; 
        else
          after_a_var_rst_st <= nx_after_a_var_rst_st;
        end if;
      end if;
  end process;


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
--!@brief Combinatorial process Resets_after_a_var_rst_Comb_State_Transitions: definition of the 
--! state transitions of the FSM.
  
  Resets_after_a_var_rst_Comb_State_Transitions: process (after_a_var_rst_st,var_i,rst_nFIP_and_FD_p_i,
                                                          assert_RSTON_p_i, s_var_rst_counter_is_two,
                                                          s_var_rst_counter_is_eight,
                                                          s_var_rst_counter_is_full)
  
  begin
  
  case after_a_var_rst_st is 

    when after_a_var_rst_idle =>      
                                                             
                        if (var_i = var_rst) and (assert_RSTON_p_i = '1')     
                                             and (rst_nFIP_and_FD_p_i = '1') then
                          nx_after_a_var_rst_st   <= after_a_var_rst_nFIP_ON_fd_ON_rston_ON; 

                        elsif (var_i = var_rst) and (assert_RSTON_p_i = '1') then
                          nx_after_a_var_rst_st   <= after_a_var_rst_rston_ON;   

                        elsif (var_i = var_rst) and (rst_nFIP_and_FD_p_i = '1') then
                          nx_after_a_var_rst_st   <= after_a_var_rst_nFIP_ON_fd_ON;                            
                                                          
                        else 
                          nx_after_a_var_rst_st   <= after_a_var_rst_idle;
                        end if;

   
    when after_a_var_rst_rston_ON =>                              -- for 8 uclk cycles

                        if s_var_rst_counter_is_eight = '1' then 
                          nx_after_a_var_rst_st   <= after_a_var_rst_idle;

                        else
                          nx_after_a_var_rst_st <= after_a_var_rst_rston_ON;
                        end if;  


    when after_a_var_rst_nFIP_ON_fd_ON_rston_ON =>                -- for 2 uclk cycles
                             
                        if s_var_rst_counter_is_two = '1' then          
                          nx_after_a_var_rst_st <= after_a_var_rst_nFIP_OFF_fd_ON_rston_ON;
                                                                   
                        else
                          nx_after_a_var_rst_st <= after_a_var_rst_nFIP_ON_fd_ON_rston_ON;
                        end if;


    when after_a_var_rst_nFIP_OFF_fd_ON_rston_ON =>              -- for 6 uclk cycles  
   
                        if s_var_rst_counter_is_eight = '1' then          
                          nx_after_a_var_rst_st <= after_a_var_rst_nFIP_OFF_fd_ON_rston_OFF;
                                                                   
                        else
                          nx_after_a_var_rst_st <= after_a_var_rst_nFIP_OFF_fd_ON_rston_ON;
                        end if;


    when after_a_var_rst_nFIP_ON_fd_ON =>                        -- for 2 uclk cycles   
              
                        if s_var_rst_counter_is_two = '1' then          
                          nx_after_a_var_rst_st <= after_a_var_rst_nFIP_OFF_fd_ON_rston_OFF;
                                                                   
                        else
                          nx_after_a_var_rst_st <= after_a_var_rst_nFIP_ON_fd_ON;
                        end if;


    when after_a_var_rst_nFIP_OFF_fd_ON_rston_OFF =>             -- until the filling-up of the counter 
                 
                        if s_var_rst_counter_is_full = '1' then  
                           nx_after_a_var_rst_st <= after_a_var_rst_idle;

                        else
                           nx_after_a_var_rst_st <= after_a_var_rst_nFIP_OFF_fd_ON_rston_OFF;
                        end if;

	
    when others => 
                        nx_after_a_var_rst_st <= after_a_var_rst_idle;
  end case;	
  end process;

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
--!@brief combinatorial process RSTIN_FSM_Comb_Output_Signals: definition of the output signals of
--! the FSM. The process is managing the signals for the nanoFIP internal reset and the FIELDRIVE
--! reset, as well as the arguments of the counter.

  rst_var_FSM_Comb_Output_Signals: process (after_a_var_rst_st)

  begin
  
    case after_a_var_rst_st is 
  
    when after_a_var_rst_idle =>  
                                     s_var_rst_reinit_counter  <= '1';    -- counter initialized

                                     s_rston                   <= '0';
                                     s_intern_rst_from_var_rst <= '0'; 
                                     s_FD_rst_from_var_rst     <= '0';  

                                 
    when after_a_var_rst_rston_ON => 
                                     s_var_rst_reinit_counter  <= '0';    -- counting 8 uclk cycles

                                    -------------------------------------
                                     s_rston                   <= '1';    -- RSTON         active
                                    -------------------------------------
                                     s_intern_rst_from_var_rst <= '0';  
                                     s_FD_rst_from_var_rst     <= '0';


    when after_a_var_rst_nFIP_ON_fd_ON_rston_ON =>
                                     s_var_rst_reinit_counter  <= '0';    -- counting 2 uclk cycles

                                    -------------------------------------
                                     s_rston                   <= '1';    -- RSTON         active
                                     s_intern_rst_from_var_rst <= '1';    -- nFIP internal active
                                     s_FD_rst_from_var_rst     <= '1';    -- FIELDRIVE     active
                                    -------------------------------------


    when after_a_var_rst_nFIP_OFF_fd_ON_rston_ON =>
                                     s_var_rst_reinit_counter  <= '0';    -- counting 6 uclk cycles

                                     s_intern_rst_from_var_rst <= '0'; 
                                    -------------------------------------
                                     s_rston                   <= '1';    -- RSTON         active
                                     s_FD_rst_from_var_rst     <= '1';    -- FIELDRIVE     active
                                    -------------------------------------


    when after_a_var_rst_nFIP_ON_fd_ON =>
                                     s_var_rst_reinit_counter  <= '0';    -- counting 2 uclk cycles 

                                     s_rston                   <= '0';
                                    ------------------------------------- 
                                     s_intern_rst_from_var_rst <= '1';    -- nFIP internal active
                                     s_FD_rst_from_var_rst     <= '1';    -- FIELDRIVE     active
                                    ------------------------------------- 


    when after_a_var_rst_nFIP_OFF_fd_ON_rston_OFF =>
                                     s_var_rst_reinit_counter  <= '0';    -- counting 4 FD_TXCK cycles
 
                                     s_rston                   <= '0';   
                                     s_intern_rst_from_var_rst <= '0';
                                    -------------------------------------  
                                    s_FD_rst_from_var_rst      <= '1';    -- FIELDRIVE     active
                                    -------------------------------------    


    when others =>
                                     s_var_rst_reinit_counter  <= '1';    -- no counting

                                     s_rston                   <= '0';   
                                     s_intern_rst_from_var_rst <= '0'; 
                                     s_FD_rst_from_var_rst     <= '0';   
 

    end case;	
  end process;



--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
--!@brief Instantiation of a WF_incr_counter:
--! the counter counts from 0 to 8, if only assert_RSTON_p has been activated, or
--!                    from 0 to 4 * FD_TXCK, if rst_nFIP_and_FD_p has been activated.

free_counter: WF_incr_counter
  generic map (g_counter_lgth => c_2_PERIODS_COUNTER_LENGTH)
  port map (
    uclk_i            => uclk_i,        
    reinit_counter_i  => s_var_rst_reinit_counter,
    incr_counter_i    => '1',
    counter_o         => s_var_rst_c,
    counter_is_full_o => open);

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
  s_var_rst_counter_is_eight <= '1' when s_var_rst_c= to_unsigned(8, s_var_rst_c'length)  else '0'; 
  s_var_rst_counter_is_two   <= '1' when s_var_rst_c= to_unsigned(10, s_var_rst_c'length) else '0'; 
  s_var_rst_counter_is_full  <= s_var_rst_counter_full;



---------------------------------------------------------------------------------------------------
--                                         Output Signals                                        --
---------------------------------------------------------------------------------------------------

  wb_rst_o      <= rst_i or s_wb_por;
  nFIP_rst_o    <= s_intern_rst_from_RSTIN or s_intern_rst_from_var_rst or s_u_por;

  -- Flip-flop with asynchronous reset to be sure that whenever nanoFIP is reset the user is not
  RSTON_Buffering: process (uclk_i, s_u_por, s_intern_rst_from_RSTIN, s_intern_rst_from_var_rst)
  begin
    if s_intern_rst_from_RSTIN = '1' or s_intern_rst_from_var_rst = '1' or s_u_por = '1' then
      rston_o   <=  '1'; 
    elsif rising_edge (uclk_i) then
      rston_o   <= not s_rston; 
    end if;
  end process;


  FD_RST_Buffering: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      fd_rstn_o <= not (s_FD_rst_from_RSTIN or s_FD_rst_from_var_rst or s_u_por); 
    end if;
  end process;

end architecture rtl;
--=================================================================================================
--                                        architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------