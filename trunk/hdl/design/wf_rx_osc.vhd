--_________________________________________________________________________________________________
--                                                                                                |
--                                        |The nanoFIP|                                           |
--                                                                                                |
--                                        CERN,BE/CO-HT                                           |
--________________________________________________________________________________________________|
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--! @file WF_rx_osc.vhd                                                                           |
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
--                                           WF_rx_osc                                           --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
--! @brief     Generation of the clock signals needed for the reception (WF_rx_deserializer).
--!
--!            Even if the bit rate of the communication is known, jitter is expected to affect the
--!            arriving time of the incoming signal. The main idea of the unit is to recalculate
--!            the expected arrival time of the next incoming bit, based on the arrival of the
--!            previous one, so that drifts are not accumulated. The clock recovery is based on the
--!            Manchester 2 coding which ensures that there is one edge (transition) for each bit.
--!
--!            In this unit, we refer to
--!              o a significant edge : for the edge of a manch. encoded bit (bit 0: _|-, bit 1: -|_)
--!              o a transition	      : for the moment in between two adjacent bits, that may or
--!                may not result in an edge (eg. a 0 followed by a 0 will give an edge _|-|_|-,
--!                but a 0 followed by a 1 will not _|--|_ ).
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
--!   \n<b>Dependencies:</b>      \n
--!            WF_reset_unit      \n
--!            WF_deglitcher      \n
--!            WF_rx_deserializer \n
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
--!     -> 07/2010  v0.02  EG  rx counter changed from 20 bits signed, to 11 bits unsigned;
--!                            rx clk generation depends on edge detection;code cleanedup+commented
--!                            rst_rx_osc signal clearified
--!     -> 12/2010  v0.03  EG  code cleaned-up   
--!     -> 01/2011  v0.031 EG  rxd_edge_i became fd_rxd_edge_p_i; small correctiond on comments
--!     -> 02/2011  v0.04  EG  2 units WF_rx_osc and WF_tx_osc; process replaced by WF_incr_counter
--         
---------------------------------------------------------------------------------------------------
--
--! @todo --> 
--
---------------------------------------------------------------------------------------------------



--=================================================================================================
--!                            Entity declaration for WF_rx_osc
--=================================================================================================

entity WF_rx_osc is
  port (
  -- INPUTS
    -- nanoFIP User Interface, General signals
    uclk_i                  : in std_logic;                      --! 40 MHz clock
    rate_i                  : in  std_logic_vector (1 downto 0); --! WorldFIP bit rate 

    -- Signal from the WF_reset_unit  
    nfip_rst_i              : in std_logic;   --! nanoFIP internal reset

    -- Signal from the WF_deglitcher unit    
    fd_rxd_edge_p_i         : in std_logic;   --! indication of an edge on fd_rxd

    -- Signal from WF_rx_deserializer unit  
    rx_osc_rst_i            : in std_logic;   --! resets the clock recovery procedure of the rx_osc


  -- OUTPUTS  
    -- Signals to the WF_rx_deserializer
    rx_manch_clk_p_o        : out std_logic;  --! signal with uclk-wide pulses
                                              --!  o  on a significant edge 
                                              --!  o  between adjacent bits
                                              --!  ____|-|___|-|___|-|___

    rx_bit_clk_p_o          : out std_logic;  --! signal with uclk-wide pulses
                                              --!  o between adjacent bits
                                              --!  __________|-|_________

    rx_signif_edge_window_o : out std_logic;  --! time window where a significant edge is expected
    
    rx_adjac_bits_window_o  : out std_logic   --! time window where a transition between adjacent
                                              --! bits is expected
    );

end entity WF_rx_osc;



--=================================================================================================
--!                                    architecture declaration
--=================================================================================================
architecture rtl of WF_rx_osc is

  signal s_period_c, s_period, s_jitter           : unsigned (c_PERIODS_COUNTER_LGTH-1 downto 0);
  signal s_half_period, s_one_forth_period        : unsigned (c_PERIODS_COUNTER_LGTH-1 downto 0);
  signal s_reinit_counter, s_counter_is_full                                           : std_logic;
  signal s_adjac_bits_window, s_signif_edge_window                                     : std_logic;
  signal s_adjac_bits_edge_found, s_signif_edge_found                                  : std_logic;
  signal s_bit_clk, s_bit_clk_d1, s_manch_clk, s_manch_clk_d1                          : std_logic;


 --=================================================================================================
--                                        architecture begin
--=================================================================================================
begin

                     -- # uclock ticks for a bit period, defined by the WorldFIP bit rate 
  s_period           <= c_BIT_RATE_UCLK_TICKS(to_integer(unsigned(rate_i))); 

  s_counter_is_full  <= '1' when s_period_c = s_period -1 else '0'; -- counter full indicator
  s_half_period      <= s_period srl 1;                             -- 1/2 s_period
  s_one_forth_period <= s_period srl 2;                             -- 1/4 s_period
  s_jitter           <= s_period srl 3;                             -- jitter defined as 1/8 s_period


---------------------------------------------------------------------------------------------------
--!@brief Instantiation of a WF_incr_counter unit : the rx_counter starts counting after the
--! release of the reset signal rx_osc_rst_i. This takes place after a falling edge on the
--! deglitched FD_RXD; this edge should be representing the 1st Manchester (manch.) encoded bit '1'
--! of the PREamble. Starting from this edge, other falling or rising significant edges, are
--! expected around one period (s_period) later. A time window around the expected arrival time is
--! set and its length is defined as 1/4th of the period (1/8th before and 1/8th after the expected
--! time). When the actual edge arrives, the counter is reset.
--! If that first falling edge of FD_RXD is finally proven not to belong to a valid PRE (the
--! state machine of the WF_rx_deserializer unit is checking that and generating the rx_osc_rst_i),
--! the counter is reinitialialized.

  rx_periods_count: WF_incr_counter
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
    -- counter reinitialized : if nfip_rst_i is active                       or
    --                         if the rx_osc_rst_i is active                 or
    --                         if an edge is detected in the expected window or
    --                         if it fills up
    s_reinit_counter <= nfip_rst_i or rx_osc_rst_i or (s_signif_edge_window and fd_rxd_edge_p_i) or s_counter_is_full;



---------------------------------------------------------------------------------------------------
--!@brief Synchronous process rx_clks: the process rx_clk is following the edges that appear on the
--! nanoFIP FIELDRIVE input fd_rxd and constructs two clock signals: rx_manch_clk & rx_bit_clk.

-- In detail, the process is looking for moments :
  -- o of significant edges 
  -- o between boundary bits
    
  -- the signal rx_manch_clk: is inverted on each significant edge,as well as between adjacent bits
  -- the signal rx_bit_clk  : is inverted only between adjacent bits

  -- The significant edges are normally expected inside the signif_edge_window. In the cases of a
  -- code violation (V+ or V-) no edge will arrive in this window. In this situation rx_manch_clk
  -- is inverted right after the end of the signif_edge_window. 

  -- Edges between adjacent bits are expected inside the adjac_bits_window; if they do not arrive
  -- the rx_manch_clk and rx_bit_clk are inverted right after the end of the adjac_bits_window.

  rx_clks: process (uclk_i)
  
  begin
    if rising_edge (uclk_i) then
      if (nfip_rst_i = '1') then
        s_manch_clk                 <='0';
        s_bit_clk                   <='0';
        s_bit_clk_d1                <='0';
        s_manch_clk_d1              <='0';
        s_signif_edge_found         <='0';
        s_adjac_bits_edge_found     <='0';


      else
        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -
        -- regarding significant edges:

        -- looking for a significant edge inside the corresponding window 
        if (s_signif_edge_window = '1') and (fd_rxd_edge_p_i = '1') and (s_signif_edge_found = '0') then
                                                   
            s_manch_clk             <= not s_manch_clk; -- inversion of rx_manch_clk 
            s_signif_edge_found     <= '1';             -- indication that the edge was found
            s_adjac_bits_edge_found <= '0';

        -- if a significant edge is not found where expected (code violation), the rx_manch_clk
        -- is inverted right after the end of the signif_edge_window.
        elsif (s_signif_edge_found = '0') and (s_period_c = s_jitter) then

          s_manch_clk               <= not s_manch_clk; 
          s_adjac_bits_edge_found   <= '0';             -- re-initialization before the
                                                        -- next cycle


        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -
        -- regarding edges between adjacent bits:

        -- looking for an edge inside the corresponding window
        elsif (s_adjac_bits_window = '1') and (fd_rxd_edge_p_i = '1') then 

           s_manch_clk              <= not s_manch_clk; -- inversion of rx_manch_clk
           s_bit_clk                <= not s_bit_clk;   -- inversion of rx_bit_clk
           s_adjac_bits_edge_found  <= '1';             -- indication that an edge was found

           s_signif_edge_found      <= '0';             -- re-initialization before next cycle


        -- if no edge is detected inside the adjac_bits_edge_window, both clks are inverted right
        -- after the end of it
        elsif (s_adjac_bits_edge_found = '0') and (s_period_c = s_half_period + s_jitter) then 

          s_manch_clk               <= not s_manch_clk;
          s_bit_clk                 <= not s_bit_clk;        
           
          s_signif_edge_found       <= '0';             -- re-initialization before next cycle
        end if;

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      s_manch_clk_d1                <= s_manch_clk;    
                                                -- s_manch_clk:      ____|-----|_____|-----|____
                                                -- s_manch_clk_d1:   ______|-----|_____|-----|__
                                                -- rx_manch_clk_p_o: ____|-|___|-|___|-|___|-|__

      s_bit_clk_d1                  <= s_bit_clk;    
                                                -- s_bit_clk:        ____|-----------|___________
                                                -- s_bit_clk_d1:     ______|-----------|_________
                                                -- rx_bit_clk_p_o:   ____|-|_________|-|_________                           

      end if;
    end if;
  end process;  



---------------------------------------------------------------------------------------------------
--!@brief Concurrent signal assignments: creation of the windows where
--! "significant edges" and "adjacent bits transitions" are expected on the input signal.
--! o s_signif_edge_window : extends s_jitter uclk ticks before and s_jitter uclk ticks after  
--!   the completion of a period, where significant edges are expected.
--! o s_adjac_bits_window      : extends s_jitter uclk ticks before and s_jitter uclk ticks after 
--!   the middle of a period, where transitions between adjacent bits are expected.   

  s_signif_edge_window <= '1' when ((s_period_c < s_jitter) or
                                        (s_period_c  > s_period-1 - s_jitter-1))
                         else '0';

  s_adjac_bits_window      <= '1' when ((s_period_c >= s_half_period-s_jitter-1) and
                                        (s_period_c <  s_half_period+s_jitter))

                         else '0';


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Output signals concurrent assignments

  rx_manch_clk_p_o         <= s_manch_clk_d1 xor s_manch_clk; -- a 1 uclk-wide pulse, after
                                                              --  o a significant edge 
                                                              --  o a new bit
                                                              -- ___|-|___|-|___|-|___

  rx_bit_clk_p_o           <= s_bit_clk xor s_bit_clk_d1;     -- a 1 uclk-wide pulse, after
                                                              --  o a new bit
                                                              -- _________|-|_________

  rx_signif_edge_window_o  <= s_signif_edge_window;

  rx_adjac_bits_window_o   <= s_adjac_bits_window;



end architecture rtl;
--=================================================================================================
--                                        architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------