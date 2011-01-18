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
--!              o nanoFIP internal reset
--!                  after the activation of the "nanoFIP User Interface General signal" RSTIN, or
--!                  after the reception of a valid var_rst with its 1st data byte containing the
--!                  station's address. In those cases, the signal stays active for 2 uclk cycles.
--!                  After the activation of the "nanoFIP User Interface General signal" RSTPON.
--!                  In this case the signal stays active for as long as the RSTPON is active.
--!
--!              o FIELDRIVE reset (nanoFIP FIELDRIVE output FD_RSTN)
--!                  after the activation of the "nanoFIP User Interface General signal" RSTIN, or
--!                  after the reception of a valid var_rst with its 1st data byte containing the
--!                  station's address. The signal stays active for 4 FD_TXCK cycles.
--!
--!              o reset to the external logic (nanoFIP User Interface, General signal RSTON) 
--!                  after the reception of a valid var_rst with its 2nd data byte containing the
--!                  station's address. The signal stays active for 8 uclk cycles.
--!
--!            The input signal RSTIN is considered only if it has been active for > 8 uclk cycles.
--!            The input signals rst_nFIP_and_FD_p and assert_RSTON_p come from the
--!            WF_cons_outcome unit and are activated only after the sucessful validation of the
--!            frame structure and data-bytes of a var_rst; therefore in this unit they are used
--!            directly, without any handling.
--!            The Power On Reset signal is used directly, without any handling.
--!
--!            The unit implements 2 state machines: one for resets coming from RSTIN
--!                                                  and one for resets coming from a var_rst.
--!                       __________
--!               RSTIN  |          |       \ \
--!              ________|   FSM    |_______ \ \
--!                      |  RSTIN   |         \  \
--!                      |__________|          \  \
--!                       __________            |  \
--!   rst_nFIP_and_FD_p  |          |           |   |      nFIP_rst
--!              ________|   FSM    |________   |OR |  _______________ 
--!                      |  var_rst |           |   |
--!                      |__________|           |  /
--!                                            /  /
--!              RSTPON                       /  /
--!              __________________________  / /
--!                                         / / 
--!
--!
--!                       __________
--!               RSTIN  |          |       \ \
--!              ________|   FSM    |_______ \  \
--!                      |  RSTIN   |         \  \
--!                      |__________|          \   \
--!                                             |   \     FD_RSTN
--!                       __________            |   |  _______________    
--!   rst_nFIP_and_FD_p  |          |           |OR |     
--!              ________|   FSM    |________   |   |   
--!                      |  var_rst |          /   /
--!                      |__________|         /  /
--!                                          /  /
--!                                         / / 
--!
--!                       __________            
--!        assert_RSTON  |          |                       RSTON   
--!              ________|   FSM    |_________________________________   
--!                      |  var_rst |          
--!                      |__________| 
--!
--
--
--! @author    Erik van der Bij      (Erik.van.der.Bij@cern.ch)      \n
--!            Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch) \n
--!            Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)     \n
--
--
--! @date      18/01/2011
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
--
---------------------------------------------------------------------------------------------------
--
--! @todo 
--
---------------------------------------------------------------------------------------------------



--=================================================================================================
--!                           Entity declaration for WF_reset_unit
--=================================================================================================
entity WF_reset_unit is
  port (
  -- INPUTS
    -- nanoFIP User Interface General signals (synchronized with uclk)
    uclk_i              : in std_logic;     --! 40 MHz clock
    rstin_i             : in std_logic;     --! initialisation control, active low
    rstpon_i            : in std_logic;     --! Power On Reset, active low
    urst_r_edge_i       : in std_logic;     --! rising edge on RSTIN
    rate_i              : in  std_logic_vector (1 downto 0); --! WorldFIP bit rate 

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

    -- nanoFIP User Interface General signal output 
    rston_o             : out std_logic;    --! reset output, active low

    -- nanoFIP FIELDRIVE output
    fd_rstn_o           : out std_logic     --! FIELDRIVE reset, active low
       );
end entity WF_reset_unit;


--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of WF_reset_unit is

  signal s_counter_is_four, s_reinit_counter, s_rston, s_FD_rst_from_var_rst, s_por    : std_logic;
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

--=================================================================================================
--                                      architecture begin
--================================================================================================= 
begin

  s_por               <= not rstpon_i;

  s_transm_period     <= c_BIT_RATE_UCLK_TICKS(to_integer(unsigned(rate_i)));-- # uclk ticks of a
                                                                             -- transmission period

  s_txck_four_periods <= resize(s_transm_period, s_txck_four_periods'length) sll 1;-- # uclk ticks
                                                                                   -- of 2 transm.
                                                                                   -- periods = 4
                                                                                   -- FD_TXCK periods
  s_counter_full         <= '1' when s_c         = s_txck_four_periods else '0';                   
  s_var_rst_counter_full <= '1' when s_var_rst_c = s_txck_four_periods else '0';


---------------------------------------------------------------------------------------------------
--                                            RSTIN                                              --
---------------------------------------------------------------------------------------------------

--!@brief RSTIN FSM: the state machine is divided in three parts (a clocked process
--! to store the current state, a combinatorial process to manage state transitions and finally a
--! combinatorial process to manage the output signals), which are the three processes that follow.

--! The FSM is following the "User Interface, General signal" RSTIN (after synchronization) and
--! checks weather it stays active for more than 4 uclk cycles; if so, it enables the nanoFIP
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
        if s_por = '1' or rst_nFIP_and_FD_p_i = '1' then
          rstin_st <= idle; 
        else
          rstin_st <= nx_rstin_st;
        end if;
      end if;
  end process;
 

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
--!@brief Combinatorial process RSTIN_FSM_Comb_State_Transitions: definition of the state
--! transitions of the FSM.
  
  RSTIN_FSM_Comb_State_Transitions: process (rstin_st,urst_r_edge_i,
                                             s_counter_is_ten,rstin_i,s_counter_is_four,
                                             s_counter_is_full)
  
  begin
  
  case rstin_st is 

    when idle =>                                                        
                        if urst_r_edge_i = '1' then       -- rising edges of RSTIN move the FSM to
                          nx_rstin_st   <= rstin_eval;    -- the next state, so as not to be getting
                                                          -- stuck if the RSTIN is stuck
                        else 
                          nx_rstin_st   <= idle;
                        end if;
   
    when rstin_eval => 
                        if rstin_i = '0' then             -- RSTIN deactivated before the 8 cycles
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
--! the FSM. The process is managing the signals for the nanoFIP internal reset
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
                                                     -- if rstin_i is active
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
  port map(
    uclk_i            => uclk_i,        
    nfip_urst_i       => s_por, --or rst_nFIP_and_FD_p_i,
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

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  
--!@brief Synchronous process Resets_after_a_var_rst_synch: Storage of the current state of the FSM
--! The state machine can be reset by the Power On Reset and the nanoFIP internal reset from RSTIN.
   Resets_after_a_var_rst_synch: process (uclk_i)
    begin
      if rising_edge (uclk_i) then
        if s_por = '1' or s_intern_rst_from_RSTIN = '1' then
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
                                                             
                        if (var_i = var_rst) and (assert_RSTON_p_i = '1')      -- re-check of var_i
                                             and (rst_nFIP_and_FD_p_i = '1') then   -- just in case  
                          nx_after_a_var_rst_st   <= after_a_var_rst_nFIP_ON_fd_ON_rston_ON; 

                        elsif (var_i = var_rst) and (assert_RSTON_p_i = '1') then
                          nx_after_a_var_rst_st   <= after_a_var_rst_rston_ON;   

                        elsif (var_i = var_rst) and (rst_nFIP_and_FD_p_i = '1') then
                          nx_after_a_var_rst_st   <= after_a_var_rst_nFIP_ON_fd_ON;                            
                                                          
                        else 
                          nx_after_a_var_rst_st   <= after_a_var_rst_idle;
                        end if;

   
    when after_a_var_rst_rston_ON =>                              -- here for 8 uclk cycles

                        if s_var_rst_counter_is_eight = '1' then 
                          nx_after_a_var_rst_st   <= after_a_var_rst_idle;

                        else
                          nx_after_a_var_rst_st <= after_a_var_rst_rston_ON;
                        end if;  


    when after_a_var_rst_nFIP_ON_fd_ON_rston_ON =>                -- here for 2 uclk cycles
                             
                        if s_var_rst_counter_is_two = '1' then          
                          nx_after_a_var_rst_st <= after_a_var_rst_nFIP_OFF_fd_ON_rston_ON;
                                                                   
                        else
                          nx_after_a_var_rst_st <= after_a_var_rst_nFIP_ON_fd_ON_rston_ON;
                        end if;


    when after_a_var_rst_nFIP_OFF_fd_ON_rston_ON =>              -- here for 6 uclk cycles  
   
                        if s_var_rst_counter_is_eight = '1' then          
                          nx_after_a_var_rst_st <= after_a_var_rst_nFIP_OFF_fd_ON_rston_OFF;
                                                                   
                        else
                          nx_after_a_var_rst_st <= after_a_var_rst_nFIP_OFF_fd_ON_rston_ON;
                        end if;


    when after_a_var_rst_nFIP_ON_fd_ON =>                        -- here for 2 uclk cycles   
              
                        if s_var_rst_counter_is_two = '1' then          
                          nx_after_a_var_rst_st <= after_a_var_rst_nFIP_OFF_fd_ON_rston_OFF;
                                                                   
                        else
                          nx_after_a_var_rst_st <= after_a_var_rst_nFIP_ON_fd_ON;
                        end if;


    when after_a_var_rst_nFIP_OFF_fd_ON_rston_OFF =>             -- here for 4 fd_txck cycles 
                 
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
  port map(
    uclk_i            => uclk_i,        
    nfip_urst_i       => s_por,-- or s_intern_rst_from_RSTIN,
    reinit_counter_i  => s_var_rst_reinit_counter,
    incr_counter_i    => '1',
    counter_o         => s_var_rst_c,
    counter_is_full_o => open);

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
  s_var_rst_counter_is_eight <= '1' when s_var_rst_c = to_unsigned(8, s_var_rst_c'length)  else '0'; 
  s_var_rst_counter_is_two   <= '1' when s_var_rst_c = to_unsigned(10, s_var_rst_c'length) else '0'; 
  s_var_rst_counter_is_full  <= s_var_rst_counter_full;



---------------------------------------------------------------------------------------------------
--                                         Output Signals                                        --
---------------------------------------------------------------------------------------------------

  nFIP_rst_o <= s_intern_rst_from_RSTIN or s_intern_rst_from_var_rst or s_por;

  Outputs_Buffering: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if (s_por = '1') or (s_intern_rst_from_RSTIN = '1') or (s_intern_rst_from_var_rst = '1') then     
        fd_rstn_o  <= '1'; -- active low     
        rston_o    <= '1'; -- active low   

      else
        fd_rstn_o  <= (not s_FD_rst_from_RSTIN) or (not s_FD_rst_from_var_rst);      
        rston_o    <=  not s_rston; 
                                               
      end if;
    end if;
  end process;


end architecture rtl;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------