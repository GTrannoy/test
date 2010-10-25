--=================================================================================================
--! @file wf_rx_tx_osc.vhd
--=================================================================================================

--! Standard library
library IEEE;

--! Standard packages
use IEEE.STD_LOGIC_1164.all; --! std_logic definitions
use IEEE.NUMERIC_STD.all;    --! conversion functions

--! specific packages
use work.WF_PACKAGE.all;     --! definitions of supplemental types, subtypes, constants
---------------------------------------------------------------------------------------------------
--                                                                                               --
--                                          wf_rx_tx_osc                                         --
--                                                                                               --
--                                         CERN, BE/CO/HT                                        --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
-- unit name   wf_rx_tx_osc
--
--! @brief     Generation the clock signals needed for the receiver(wf_rx)and transmiter(wf_tx)\n
--!
--!            Concerning the reception, even if the bit rate of the communication is known, jitter
--!            is expected to affect the arriving time of the incoming signal. The main idea of the 
--!            unit is to recalculate the expected arrival time of the next incoming bit, based on
--!            the arrival of the previous one, so that drifts are not accumulated. The clock 
--!            recovery is based on the Manchester 2 coding which ensures that there is one edge
--!            (transition) for each bit. In this unit, we refer to a significant edge for an edge
--!            of a Manchester 2 encoded bit (eg: bit0: _|-, bit 1: -|_) and to a transition between
--!            adjacent bits for a transition that may or may not give an edge between adjacent 
--!            bits (e.g.: a 0/1 followed by a 0/1 will give an edge _|-|_|-, but a 0/1 followed by
--!            a 1/0 will not _|--|_ ).
--
--!            Concerning the transmission, the unit generates the nanoFIP output signal tx_clk
--!            (line driver half bit clock) and the nanoFIP internal signal tx_clk_p_buff:
--!            tx_clk:           ___|--------...--------|________...________|--------...--------|__
--!            tx_clk_p_buff (3):   |0|0|0|1                                |0|0|0|1
--!            tx_clk_p_buff (2):   |0|0|1|0                                |0|0|1|0
--!            tx_clk_p_buff (1):   |0|1|0|0                                |0|1|0|0
--!            tx_clk_p_buff (0):   |1|0|0|0                                |1|0|0|0
--!             
--
--
--! @author    Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)\n
--!            Evangelia Gousiou (Evangelia.Gousiou@cern.ch)         \n
--
--
--! @date      07/2010
--
--
--! @version   v0.02
--
--
--!   \n<b>Dependencies:</b>\n
--!     wf_reset_unit \n
--!     wf_synchronizer\n
--!     wf_rx           \n
--
--
--!   \n<b>Modified by:</b>\n
--!     Pablo Alvarez Sanchez\n
--!     Evangelia Gousiou     \n
--
---------------------------------------------------------------------------------------------------
--
--!   \n\n<b>Last changes:</b>\n
--!     -> 08/2009  v0.01  PS Entity Ports added, start of architecture content \n
--!     -> 07/2010  v0.02  EG  tx, rx counter changed from 20 bits signed, to 11 bits unsigned;
--!                         rx clk generation depends on edge detection; code cleaned-up+commented
--!                         C_TXCLKBUFFLENTGTH got 1 bit more\n 
--         
---------------------------------------------------------------------------------------------------
--
--! @todo --> better use of the preamble (in case 1st edge detected does not belong to preamble)/!\
--
---------------------------------------------------------------------------------------------------

---/!\----------------------------/!\----------------------------/!\--------------------------/!\--
--                                    Sunplify Premier Warnings                                  --
-- -- --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --
--                                         No Warnings                                           --
---------------------------------------------------------------------------------------------------


--=================================================================================================
--!                            Entity declaration for wf_rx_tx_osc
--=================================================================================================

entity wf_rx_tx_osc is
  generic (C_PERIODS_COUNTER_LENGTH : natural; 
           C_QUARTZ_PERIOD :          real;
           C_TXCLKBUFFLENTGTH :       natural);

  port (
  -- INPUTS
    uclk_i :                  in std_logic;                      --! 40 MHz clock
    rate_i :                  in  std_logic_vector (1 downto 0); --! bit rate  

    -- Signal from the wf_reset_unit unit  
    nFIP_u_rst_i :            in std_logic; --! nanoFIP internal reset

    -- Signals from the wf_synchronizer    
    rxd_edge_i :              in std_logic; --! indication of an edge on rxd_i
    rxd_f_edge_i :            in std_logic; --! indication of a falling edge on rxd_i

    -- Signal from wf_rx   
    wait_rxd_first_f_edge_i : in std_logic; --! indication that wf_rx state machine is in idle,
                                            --! waiting for the 1st falling edge of rxd_i

  -- OUTPUTS  
    -- Output signals needed in the reception
    -- Outputs to wf_rx and wf_rx_deglitcher
    rx_manch_clk_p_o :        out std_logic;  --! signal with uclk-wide pulses
                                              --! 1) on a significant edge 
                                              --! 2) between adjacent bits
                                              --! ____|-|___|-|___|-|___
    rx_bit_clk_p_o :          out std_logic;  --! signal with uclk-wide pulses
                                              --! between adjacent bits
                                              --! __________|-|_________

    rx_signif_edge_window_o : out std_logic;  --! time window where a significant edge is expected
    
    rx_adjac_bits_window_o :  out std_logic;  --! time window where a transition between adjacent
                                              --! bits is expected
    
    -- Output signals needed in the transmission
    -- nanoFIP output
    tx_clk_o :                out std_logic;  --! line driver half bit clock
    -- Output to the wf_tx
    tx_clk_p_buff_o :         out std_logic_vector (C_TXCLKBUFFLENTGTH -1 downto 0)
    );

end entity wf_rx_tx_osc;



--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of wf_rx_tx_osc is


  signal s_counter_rx, s_counter_tx :            unsigned (C_PERIODS_COUNTER_LENGTH-1 downto 0);
  signal s_period, s_jitter :                    unsigned (C_PERIODS_COUNTER_LENGTH-1 downto 0);
  signal s_counter_full, s_half_period :         unsigned (C_PERIODS_COUNTER_LENGTH-1 downto 0);
  signal s_one_forth_period :                    unsigned (C_PERIODS_COUNTER_LENGTH-1 downto 0);
  signal s_tx_clk_p_buff :                       std_logic_vector (C_TXCLKBUFFLENTGTH -1 downto 0);
  signal s_tx_clk_d1, s_tx_clk, s_tx_clk_p :     std_logic;
  signal s_rx_bit_clk, s_rx_manch_clk_d1 :       std_logic;
  signal s_rx_bit_clk_d1, s_rx_manch_clk :       std_logic;
  signal s_adjac_bits_edge_found :               std_logic;
  signal s_signif_edge_found :                   std_logic;
  signal s_rxd_signif_edge_window :              std_logic;
  signal s_rx_adjac_bits_window :                std_logic;

 
--=================================================================================================
--                                      architecture begin
--=================================================================================================
begin
  
  s_period           <= C_UCLK_TICKS(to_integer(unsigned(rate_i)));  -- # uclock ticks for a period
  s_half_period      <= (s_period srl 1);                            -- s_period shifted 1 bit
  s_one_forth_period <= s_period srl 2;                              -- s_period shifted 2 bits
  s_jitter           <= s_period srl 3;                              -- jitter defined as 1/8 of
                                                                     -- the period
  s_counter_full     <= s_period-1;


---------------------------------------------------------------------------------------------------
-- synchronous rx_process periods_count:
-- the process is looking for the 1st falling edge of the serial input rxd_i; this should be
-- representing the 1st Manchester (manch.) encoded bit '1'of the preamble. Starting from this
-- edge, other falling or rising significant edges, are expected around one period later.
-- A time window around the expected arrival time is set and its length is defined as 1/4th of
-- the period (1/8th before and 1/8th after the expected time). When the actual edge arrives,
-- the counter resets.

  rx_periods_count: process(uclk_i) 
  begin
    if rising_edge(uclk_i) then                                                  
      if nFIP_u_rst_i = '1' then
        s_counter_rx     <= (others => '0');

      else 
      ---------------------------------------------------------------------------------------------
        -- counter initialized after the first falling edge of a new frame
        if (wait_rxd_first_f_edge_i = '1' and rxd_f_edge_i = '1' ) then       

          s_counter_rx   <= (others => '0');        
        
        -- for the rest of the frame
        else

          if (s_rxd_signif_edge_window = '1') and (rxd_edge_i ='1') then 
            s_counter_rx <= (others => '0');     -- when an edge appears inside
                                                 -- the expected window, the   
                                                 -- counter is reinitialized

          elsif (s_counter_rx=s_counter_full) then -- otherwise, it continues counting
            s_counter_rx <= (others => '0');       -- complete nominal periods
          else
            s_counter_rx <= s_counter_rx + 1 ;  
  
          end if;
        end if;
      end if;
    end if;
  end process;

--------------------------------------------------------------------------------------------------
-- concurrent signal assignments concerning the receiver:
--creation of the windows where significant edges and adjacent bits transitions are expected on the
-- input signal
-- reminder:in principle, s_counter_rx is initialized after the detection of a significant edge and
-- it is counting a complete period, according to the bit rate. 
    
-- s_rxd_signif_edge_window extends s_jitter uclk ticks before and s_jitter uclk ticks after the 
-- completion of a period, where significant edges are expected
-- s_rx_adjac_bits_window extends s_jitter uclk ticks before and s_jitter uclk ticks after the 
-- middle of a period, where transitions between adjacent bits are expected   

  s_rxd_signif_edge_window <= '1' when ((s_counter_rx < s_jitter) or
                                       (s_counter_rx > s_counter_full - s_jitter-1))
                        else '0';

  s_rx_adjac_bits_window <= '1' when ((s_counter_rx >= s_half_period-s_jitter-1) and
                                      (s_counter_rx < s_half_period+s_jitter))

                        else '0';


---------------------------------------------------------------------------------------------------
-- synchronous process rx_clk:
    -- the process rx_clk is following the edges that appear on the input signal and constructs two
    -- clock signals: rx_manch_clk and rx_bit_clk.

    -- In detail, the process is looking for moments:
    -- 1) of significant edges 
    -- 2) between boundary bits
    
    -- the signal rx_manch_clk is inverted on each significant edge,as well as between adjacent bits
    -- the signal rx_bit_clk is inverted only between adjacent bits

    -- The significant edges are normally expected inside the signif_edge_window. In the cases of a
    -- code violation (V+ or V-) no edge will arrive in this window. In this situation rx_manch_clk
    -- is inverted right after the end of the signif_edge_window. 

    -- Edges between adjacent bits are expected inside the adjac_bits_window; if they do not arrive
    -- the rx_manch_clk and rx_bit_clk are inverted right after the end of the adjac_bits_window.


 rx_clk: process (uclk_i)
  
    begin
      if rising_edge(uclk_i) then
        -- initializations:  
        if (nFIP_u_rst_i = '1') then
          s_rx_manch_clk          <='0';
          s_rx_bit_clk            <='0';
          s_rx_bit_clk_d1         <='0';
          s_rx_manch_clk_d1       <='0';
          s_signif_edge_found     <='0';
          s_adjac_bits_edge_found <='0';


        else
          -- regarding significant edges:
          if (s_rxd_signif_edge_window='1') then   -- looking for a significant edge  
            if (rxd_edge_i='1') then               -- inside the corresponding window
              s_rx_manch_clk          <= not s_rx_manch_clk;
              s_signif_edge_found     <= '1';      -- indication that the edge was found
              s_adjac_bits_edge_found <= '0';
            end if;

          elsif (s_signif_edge_found='0')and(s_counter_rx=s_jitter) then
            s_rx_manch_clk            <= not s_rx_manch_clk; 
                                                  --if a significant edge is not found where               
                                                  -- expected (code violation), the
                                                  -- rx_manch_clk is inverted right after the
                                                  -- end of the signif_edge_window

            s_adjac_bits_edge_found   <= '0';     -- re-initialization before the next cycle

          -- regarding edges between adjacent bits:
          elsif (s_rx_adjac_bits_window='1') then           -- looking for an edge inside 
            if (rxd_edge_i='1') then                        -- the corresponding window
             s_rx_manch_clk           <= not s_rx_manch_clk;-- inversion of rx_manch_clk
             s_rx_bit_clk             <= not s_rx_bit_clk;  -- inversion of rx_bit_clk
             s_adjac_bits_edge_found  <= '1';               -- indication that an edge was found

             s_signif_edge_found      <= '0';               -- re-initialization before next cycle
            end if;

          elsif (s_adjac_bits_edge_found='0')and(s_counter_rx=s_half_period+s_jitter) then 
            s_rx_manch_clk            <= not s_rx_manch_clk; -- if no edge occurs inside the 
            s_rx_bit_clk              <= not s_rx_bit_clk;   --adjac_bits_edge_window,both clks are  
                                                             -- inverted right after the end of it
           
           
            s_signif_edge_found       <= '0';                -- re-initialization before next cycle
          end if;

        s_rx_manch_clk_d1             <= s_rx_manch_clk;    
                                                  -- s_rx_manch_clk:    ____|-----|_____|-----|____
                                                  -- s_rx_manch_clk_d1: ______|-----|_____|-----|__
                                                  -- rx_manch_clk_p_o:  ____|-|___|-|___|-|___|-|__

        s_rx_bit_clk_d1               <= s_rx_bit_clk;    
                                                  -- s_rx_bit_clk:     ____|-----------|___________
                                                  -- s_rx_bit_clk_d1:  ______|-----------|_________
                                                  -- rx_bit_clk_p_o:   ____|-|_________|-|_________                           

        end if;
      end if;
    end process;  

---------------------------------------------------------------------------------------------------
-- synchronous tx_process periods_count: implementation of a counter counting transmission periods.

 tx_periods_count: process(uclk_i) 
  begin
    if rising_edge(uclk_i) then                                                  
      if nFIP_u_rst_i = '1' then
        s_counter_tx    <= (others => '0');
        s_tx_clk_d1     <= '0';
        s_tx_clk_p_buff <= (others => '0');

      else 
        -- free counter measuring transmission periods
        if (s_counter_tx = s_counter_full) then                         
          s_counter_tx  <= (others => '0');
        else
          s_counter_tx  <= s_counter_tx + 1 ;                      
        end if;
     
        -- clk signals:
        s_tx_clk_d1     <= s_tx_clk;
        s_tx_clk_p_buff <= s_tx_clk_p_buff (s_tx_clk_p_buff'left -1 downto 0) & s_tx_clk_p; -- buffer
      end if;
    end if;
  end process;

---------------------------------------------------------------------------------------------------
-- concurrent signal assignments concerning the transmitter:

-- creation of the clock for the transmitter with period: 1/2 transmission period 
  s_tx_clk <= '1' when ((s_counter_tx < s_one_forth_period) or
               ((s_counter_tx > (2*s_one_forth_period)-1) and (s_counter_tx < 3*s_one_forth_period)))
         else '0';

-- creation of a pulse starting 1 uclk period before s_tx_clk_o (s_tx_clk_d1)
  s_tx_clk_p <= s_tx_clk and (not s_tx_clk_d1); 
                                                -- s_tx_clk:          __|-----|_____|-----|_____
                                                -- s_tx_clk_o:        ____|-----|_____|-----|___
                                                -- not s_tx_clk_d1:   ----|_____|-----|_____|---
                                                -- s_tx_clk_p:        __|-|___|-|___|-|___|-|___

---------------------------------------------------------------------------------------------------
-- Output signals construction:

  -- clocks needed for the receiver: 
  rx_manch_clk_p_o <= s_rx_manch_clk_d1 xor s_rx_manch_clk;    -- a pulse 1-uclk period long, after
                                                               -- 1) a significant edge 
                                                               -- 2) a new bit
                                                               -- ___|-|___|-|___|-|___

  rx_bit_clk_p_o   <= s_rx_bit_clk xor s_rx_bit_clk_d1;        -- a pulse 1-uclk period long, after
                                                               -- a new bit
                                                               -- _________|-|_________
  
  -- clocks needed for the transmitter:
  tx_clk_o          <= s_tx_clk_d1;
  tx_clk_p_buff_o   <= s_tx_clk_p_buff;                           

 
  -- output signals that have also been used in this unit's processes:
  rx_signif_edge_window_o <= s_rxd_signif_edge_window;
  rx_adjac_bits_window_o  <= s_rx_adjac_bits_window;


end architecture rtl;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------
