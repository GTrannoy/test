--=================================================================================================
--! @file WF_reset_unit.vhd
--=================================================================================================

--! standard library
library IEEE;

--! standard packages
use IEEE.STD_LOGIC_1164.all;  --! std_logic definitions
use IEEE.NUMERIC_STD.all;     --! conversion functions

--! specific packages
use work.WF_PACKAGE.all;      --! definitions of supplemental types, subtypes, constants


---------------------------------------------------------------------------------------------------
--                                                                                               --
--                                        WF_reset_unit                                          --
--                                                                                               --
--                                        CERN, BE/CO/HT                                         --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
-- unit name: WF_reset_unit
--
--! @brief Reset logic. Manages the three nanoFIP reset signals: internal reset, FIELDRIVE reset
--! and user interface reset (RSTON)
--
--
--! @author Erik van der Bij (Erik.van.der.Bij@cern.ch)
--!         Pablo Alvarez Sanchez (pablo.alvarez.sanchez@cern.ch)
--!         Evangelia Gousiou (Evangelia.Gousiou@cern.ch)
--
--
--! @date 08/2010
--
--
--! @version v0.02
--
--
--! @details 
--
--!   \n<b>Dependencies:</b>\n
--!     WF_cons_bytes_from_rx\n
-- 
--
--!   \n<b>Modified by:</b>\n
--!     Pablo Alvarez Sanchez (pablo.alvarez.sanchez@cern.ch) \n
--!     Evangelia Gousiou (Evangelia.Gousiou@cern.ch)         \n
--
---------------------------------------------------------------------------------------------------
--
--!   \n\n<b>Last changes:</b>\n
--!     07/2009  v0.01  EB  First version \n
--!     08/2010  v0.02  EG  checking of bytes1 and2 of reset var added \n
--!                         fd_rstn_o, nFIP_rst_o enabled only if rstin has been active for > 16 uclk \n
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
    -- User Interface general signals (synchronized) (after synchronization)
    uclk_i :                in std_logic;                      --! 40 MHz clock
    urst_i :                in std_logic;                     --! initialisation control, active low
    urst_r_edge_i :         in std_logic;
    subs_i :                in std_logic_vector (7 downto 0); --! Subscriber number coding
    rate_i :                in std_logic_vector (1 downto 0);

    -- Signal from the central control unit WF_engine_control
    var_i :                 in t_var;                         --! variable type 
    rst_nFIP_and_FD_p_i : in std_logic;
    assert_RSTON_p_i :       in std_logic;


  -- OUTPUTS
    -- nanoFIP internal reset
    nFIP_rst_o :            out std_logic;                    --! nanoFIP internal reset, active high

    -- nanoFIP output to the User Interface 
    rston_o :               out std_logic;                    --! reset output, active low

    -- nanoFIP output to FIELDRIVE
    fd_rstn_o :             out std_logic                     --! FIELDRIVE reset, active low
       );
end entity WF_reset_unit;


--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of WF_reset_unit is

  signal s_intern_rst :          std_logic;
  signal s_urst_c_is_eight, s_reinit_counter, s_FD_rst :        std_logic;
  signal s_urst_c_is_full, s_urst_c_is_ten, s_incr_counter :          std_logic;
  signal s_urst_c_is_two, s_RSTON_counter_is_full :     std_logic;
  signal s_RSTON_counter :                            unsigned (1 downto 0);
  signal s_counter :                                  unsigned(C_PERIODS_COUNTER_LENGTH-1 downto 0)
                                                           := (others=>'0'); -- init for simulation

                                                      
  type rstin_st_t  is (idle, rstin_eval, intern_rst_ON_FD_rst_ON,intern_rst_OFF_FD_rst_ON);
  signal rstin_st, nx_rstin_st :                      rstin_st_t;

--=================================================================================================
--                                      architecture begin
--================================================================================================= 
  begin


---------------------------------------------------------------------------------------------------
--!@brief Synchronous process s_rst_creation: the process follows the input signal rstin 
--! and confirms that it stays active for more than 2^(C_RSTIN_C_LGTH-1) uclk cycles;
--! If so, it enables the signal s_intern_rst to follow it.

---------------------------------------------------------------------------------------------------

--!@brief synchronous process Receiver_FSM_Sync: storage of the current state of the FSM

   RSTIN_FSM_Sync: process(uclk_i)
    begin
      if rising_edge(uclk_i) then
  --      if urst_i = '0' then --has to be the PoR; otherwise i ll always be sent to idle (coundn t count the 40cycles for ex)---------
  --        rstin_st <= idle; 
  --      else
          rstin_st <= nx_rstin_st;
 --       end if;
      end if;
  end process;
 

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
--!@brief Combinatorial process RSTIN_FSM_Comb_State_Transitions:
--! definition of the state transitions of the FSM.
  
  RSTIN_FSM_Comb_State_Transitions: process (rstin_st,var_i,rst_nFIP_and_FD_p_i,urst_r_edge_i,
                                             s_urst_c_is_two,urst_i,s_urst_c_is_eight,
                                             s_urst_c_is_ten, s_urst_c_is_full)
  
  begin
  nx_rstin_st <= idle;
  
  case rstin_st is 

    when idle =>                                                        
                        if var_i = var_rst then 
                          if rst_nFIP_and_FD_p_i = '1' then
                              nx_rstin_st <= intern_rst_ON_FD_rst_ON;
                          else
                              nx_rstin_st <= idle;
                          end if;
              
                        else
                          if urst_r_edge_i = '1' then   -- rising edges of reset move the FSM to the next state,
                            nx_rstin_st   <= rstin_eval;-- so as not to be getting stuck if the reset is stuck
                          else
                            nx_rstin_st   <= idle;
                          end if;
                        end if;	
   
    when rstin_eval =>
                        if urst_i = '0' then
                          nx_rstin_st   <= idle;

                        else
                          if s_urst_c_is_eight = '1' then
                            nx_rstin_st <= intern_rst_ON_FD_rst_ON;
                          else 
                            nx_rstin_st <= rstin_eval;
                          end if;	
                        end if;  


    when intern_rst_ON_FD_rst_ON =>  
                        if var_i = var_rst then 
                          if s_urst_c_is_two ='1' then             
                             nx_rstin_st <= intern_rst_OFF_FD_rst_ON;
                          else
                             nx_rstin_st <= intern_rst_ON_FD_rst_ON;
                          end if;

                        else
                          if s_urst_c_is_ten ='1' then             
                            nx_rstin_st <= intern_rst_OFF_FD_rst_ON;
                          else
                            nx_rstin_st <= intern_rst_ON_FD_rst_ON;
                          end if;
                        end if;

    when intern_rst_OFF_FD_rst_ON =>  
                        if s_urst_c_is_full ='1' then             
                           nx_rstin_st <= idle;
                        else
                           nx_rstin_st <= intern_rst_OFF_FD_rst_ON;
                        end if;

                      
	
    when others => 
                        nx_rstin_st <= idle;
  end case;	
  end process;
  
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
--!@brief combinatorial process RSTIN_FSM_Comb_Output_Signals:
--! definition of the output signals of the FSM

  RSTIN_FSM_Comb_Output_Signals: process (rstin_st, urst_i)

  begin
  
    case rstin_st is 
  
    when idle =>           
                  s_reinit_counter <= '1';  -- counter initialized
                  s_intern_rst     <= '0'; 
                  s_FD_rst         <= '0';         
                  s_incr_counter   <= '0';
                                 
    when rstin_eval => 
                  s_reinit_counter <= '0';  -- counting (until 8)
                  s_intern_rst     <= '0';  -- the urst_i signal
                  s_FD_rst         <= '0';
                  s_incr_counter   <= urst_i; 

    when intern_rst_ON_FD_rst_ON =>
                  s_reinit_counter <= '0';  -- free counter continuing counting 2 uclk periods
                  s_intern_rst     <= '1';
                  s_FD_rst         <= '1'; 
                  s_incr_counter   <= '1';      

    when intern_rst_OFF_FD_rst_ON =>
                  s_reinit_counter <= '0';  -- free counter continuing counting (until counter full)
                  s_intern_rst     <= '0';
                  s_FD_rst         <= '1'; 
                  s_incr_counter   <= '1';      


    when others =>
                  s_reinit_counter <= '1';
                  s_intern_rst     <= '0';
                  s_FD_rst         <= '0'; 
                  s_incr_counter   <= '0';    

    end case;	
  end process;


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- used for the evaluation of the RSTIN signal, also for counting 2 clock cycles the internal rest,
-- & ...clock cycles the fieldrive reset.
counter: WF_incr_counter
  generic map (counter_length => C_PERIODS_COUNTER_LENGTH)
  port map(
    uclk_i            => uclk_i,        
    nFIP_urst_i       => '0' , --has to be the PoR--------------
    reinit_counter_i  => s_reinit_counter,
    incr_counter_i    => s_incr_counter,
    counter_o         => s_counter,
    counter_is_full_o => s_urst_c_is_full);

  s_urst_c_is_two  <= '1' when s_counter = to_unsigned(2, s_counter'length)
              else '0'; 
  s_urst_c_is_ten   <= '1' when s_counter = to_unsigned(10, s_counter'length)
              else '0'; 
  s_urst_c_is_eight  <= '1' when s_counter = to_unsigned(8, s_counter'length)
              else '0'; 
  s_urst_c_is_ten   <= '1' when s_counter = to_unsigned(10, s_counter'length)
              else '0'; 



---------------------------------------------------------------------------------------------------
--!@brief Synchronous process RSTON_generator: Generation of the RSTON signal that is enabled when
--! at the end of a valid consumed frame of a reset variable, where the 2nd data byte contains
--! the station's address. The signal stays enabled for four cycles.
---------------------------------------------------------------------------------------------------
   RSTON_generator: process(uclk_i)
    begin
      if rising_edge(uclk_i) then
        if s_intern_rst = '1' then
          rston_o   <= '1';
        else
          if assert_RSTON_p_i = '1' then         -- activation after the pulse that indicates that
            rston_o <= '0';                     -- a valid consumed frame has arrived with its 2nd 
          end if;                               -- data byte containing the station's address.

          if s_RSTON_counter_is_full = '1' then -- deactivation after 4 clock cycles
            rston_o <= '1';
          end if;
        end if;
      end if;
  end process;
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
RSTON_free_counter: WF_incr_counter
  generic map (counter_length => 2)
  port map(
    uclk_i           => uclk_i,        
    nFIP_urst_i      => s_intern_rst,
    reinit_counter_i => assert_RSTON_p_i,
    incr_counter_i   => '1',
    counter_o        => s_RSTON_counter,
    counter_is_full_o  => s_RSTON_counter_is_full
);
   
---------------------------------------------------------------------------------------------------
--! nFIP_rst_o: nanoFIP internal reset, active high;
--! fd_rstn_o : FIELDRIVE reset, active low;
--! They are both activated by the signals:

--! Signal                |Stays active for (Uclk cycles)           |Constraint
--!------------------------------------------------------------------------------------------------
--! PoR                   |full PoR duration                        |No
--! RSTIN                 |2                                        |RSTIN active > 8 uclk cycles
--! s_rst_nFIP_and_FD   |2                                        |No
 
  nFIP_and_FD_Resets: process (uclk_i)
  begin
    if rising_edge(uclk_i) then
      nFIP_rst_o <= s_intern_rst or s_intern_rst;         -- or PoR
      fd_rstn_o  <= not (s_intern_rst or s_FD_rst);   -- or PoR                                                    
 
   end if;
  end process;


end architecture rtl;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------