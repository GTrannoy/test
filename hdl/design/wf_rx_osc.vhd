--=================================================================================================
--! @file wf_rx_osc.vhd
--! @brief Recovers clock from the input serial line. 
--=================================================================================================
--! Standard library
library IEEE;
--! Standard packages
use IEEE.STD_LOGIC_1164.all; --! std_logic definitions
use IEEE.NUMERIC_STD.all;    --! conversion functions

---------------------------------------------------------------------------------------------------
--                                                                                               --
--                      wf_rx_osc //change name to wf_rx_tx_osc                                  --
--                                                                                               --
--                               CERN, BE/CO/HT                                                  --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
-- unit name: wf_rx_osc
--
--! @brief Generation the clock signals needed for the transmiter and receiver units. \n
--!
--!  Concerning the reception, even if the bit rate of the communication is known, jitter is
--!  expected to affect the arriving time of the incoming signal. The main idea of the wf_osc
--!  is to recalculate the expected arrival time of the next incoming bit,based on the arrival
--!  of the previous one,so that driftings are not accumulated.The clock recovery is based on
--!  the Manchester 2 coding which ensures that there is one transition for each bit. In this
--!  unit, we refer to a significant edge for an edge of a Manchester 2 encoded bit ( eg: bit
--!  0: _|-, bit 1: -|_) and to a transition between adjacacent bits for a transition that may
--!  or may not give an edge between adjacent bits (eg: a 0/1 followed by a 0/1 will give an
--!  edge _|-|_|-, but a 0/1 followed by a 1/0 will not _|--|_ ).
--!
--!
--!         Concerning the transmission...\n,
--!                    tx_clk_o
--!                    tx_clk_p_buff_o                      
--!                    s_tx_clk_p
--!
--!
--! @author	    Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)
--!             Evangelia Gousiou (Evangelia.Gousiou@cern.ch) 
--!
--! @date 07/2010
--
--! @version v0.03
--
--! @details 
--!
--! <b>Dependencies:</b>\n
--!            wf_tx_rx \n
--!            wf_rx    \n  
--!
--! <b>References:</b>\n
--! 
--! 
--!
--! <b>Modified by:</b>\n
--! Author:         Pablo Alvarez Sanchez
--!                 Evangelia Gousiou
---------------------------------------------------------------------------------------------------
--! \n\n<b>Last changes:</b>\n
--! 08/2009  v0.02  PAAS Entity Ports added, start of architecture content
--! 07/2010  v0.03  tx, rx counter changed from 20 bits signed, to 11 bits unsigned
--!                 rx clk generation depends on edges detection
--!                 code cleaned-up + commented                
---------------------------------------------------------------------------------------------------
--! @todo Define I/O signals \n
--!
---------------------------------------------------------------------------------------------------



--=================================================================================================
--! Entity declaration for wf_rx_osc
--=================================================================================================

entity wf_rx_osc is
  generic (C_COUNTER_LENGTH : integer := 11;  -- in the slowest bit rate (31.25kbps), the period is
                                              -- 32000ns and can be measured after 1280 uclk ticks.
                                              -- Therefore a counter of 11 bits is the max needed
                                              -- for counting transmission/reception periods. 
           C_QUARTZ_PERIOD : real := 24.8;    -- 40 MHz clock period
           C_CLKFCDLENTGTH :  natural := 3 
           );

  port (
  -- Inputs
    uclk_i :                  in std_logic; --! 40 MHz clock
    rate_i :                  in  std_logic_vector (1 downto 0); --! bit rate    
    rst_i :                   in std_logic; --! global reset

    -- signals from wf_tx_rx    
    d_edge_i :                in std_logic; --! indication of an edge on rx_data_i(buffered fd_rxd)
    rx_data_f_edge_i :        in std_logic; --! indication of a falling edge on rx_data_i

     --signal from wf_rx   
    wait_d_first_f_edge_i :   in std_logic; --! indication that wf_rx state machine is in idle,
                                            -- waiting for the 1st falling edge of rx_data_i

  -- Outputs  
    -- output signals needed in the reception
    rx_manch_clk_p_o :        out std_logic;-- signal with pulses 1-uclk period long
                                            -- 1) on a significant edge 
                                            -- 2) between adjacent bits
                                            -- ____|-|___|-|___|-|___
    rx_bit_clk_p_o :          out std_logic;-- signal with pulses 1-uclk period long
                                            -- between adjacent bits
                                            -- __________|-|_________

    rx_signif_edge_window_o : out std_logic;-- time window where a significant edge is expected
    
    rx_adjac_bits_window_o :  out std_logic;-- time window where a transition between adjacent
                                            --  bits is expected
    
    -- output signals needed in the transmission
    tx_clk_p_buff_o : out std_logic_vector(C_CLKFCDLENTGTH -1 downto 0);
    tx_clk_o :     out std_logic
    );

end entity wf_rx_osc;



---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
--! rtl architecture of wf_rx_osc
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
architecture rtl of wf_rx_osc is

  -- calculations of the number of uclk ticks equivalent to the reception/ transmission period
  constant c_uclk_ticks_31_25kbit:unsigned:= 
                                  to_unsigned((32000/ integer(C_QUARTZ_PERIOD)),C_COUNTER_LENGTH);
  constant c_uclk_ticks_1_mbit:unsigned:=
                                    to_unsigned((1000/ integer(C_QUARTZ_PERIOD)),C_COUNTER_LENGTH);
  constant c_uclk_ticks_2_5mbit:unsigned:=
                                     to_unsigned((400 /integer(C_QUARTZ_PERIOD)),C_COUNTER_LENGTH);

  -- formation of a table with the c_uclk_ticks info per bit rate
  type t_uclk_ticks is array (Natural range <>) of unsigned (C_COUNTER_LENGTH-1 downto 0);
  constant C_UCLK_TICKS : t_uclk_ticks(3 downto 0) := (0 => (c_uclk_ticks_31_25kbit),
                                                       1 => (c_uclk_ticks_1_mbit),
                                                       2 => (c_uclk_ticks_2_5mbit),
                                                       3 => (c_uclk_ticks_2_5mbit));

  
  -- auxiliary signals declarations
  signal s_counter_rx, s_counter_tx, s_period, s_jitter :   unsigned (C_COUNTER_LENGTH-1 downto 0);
  signal s_counter_full, s_one_forth_period, s_half_period :unsigned (C_COUNTER_LENGTH-1 downto 0);
  signal s_tx_clk_p_buff :                           std_logic_vector(C_CLKFCDLENTGTH -1 downto 0);
  signal s_tx_clk_d1, s_tx_clk, s_tx_clk_p :         std_logic;
  signal s_rx_bit_clk, s_rx_bit_clk_d1, s_rx_manch_clk, s_rx_manch_clk_d1 : std_logic;
  signal s_adjac_bits_edge_found, s_signif_edge_found :                     std_logic;
  signal s_rx_signif_edge_window, s_rx_adjac_bits_window :                  std_logic;

 

begin
 

  
  s_period <= C_UCLK_TICKS(to_integer(unsigned(rate_i)));  -- s_period: # uclock ticks for a period
  s_half_period <= (s_period srl 1);                       -- s_period shifted 1 bit
  s_one_forth_period <= s_period srl 2;                    -- s_period shifted 2 bits
  s_jitter <= s_period srl 3;                              -- jitter defined as 1/8 of the period
  s_counter_full <= s_period-1;


---------------------------------------------------------------------------------------------------
-- synchronous process periods_count:
-- Concerning the reception, the "periods_count" process is looking for the 1st falling edge of the
-- buffered serial input rxd(rx_data_i);this should be representing the 1st manchester encoded bit  
--'1'of the preamble.Starting from this edge,other falling or rising significant edges,are expected
-- around one period later. A time window around the expected arrival time is set and its length is
-- defined as 1/4th of the period (1/8th before and 1/8th after the expected time). When the actual
-- edge arrives, the counter resets.

-- Concerning the transmission, the "periods_count" process implements a counter that just counts
-- transmission periods.

  periods_count: process(uclk_i) 
  begin
    if rising_edge(uclk_i) then                                                  
      if rst_i = '1' then
        s_counter_tx <= (others => '0');
        s_counter_rx <= (others => '0');
        s_tx_clk_d1 <= '0';
        s_tx_clk_p_buff <= (others => '0');

      else 
      -- regarding transmission:   
        -- transmission counter:
        -- free counter measuring transmission periods
        if (s_counter_tx = s_counter_full) then                         
          s_counter_tx <= (others => '0');
        else
          s_counter_tx <= s_counter_tx + 1 ;                      
        end if;
     
        -- clk signals:
        s_tx_clk_d1 <= s_tx_clk;
        s_tx_clk_p_buff <= s_tx_clk_p_buff (s_tx_clk_p_buff'left -1 downto 0) & s_tx_clk_p; -- buffer


      -- regarding reception:         
        -- reception counter:
        -- counter initialized after the first falling edge of rx_data_i 
	    if (wait_d_first_f_edge_i = '1') then                 
          if rx_data_f_edge_i = '1' then           -- 1st falling edge of an id_dat received                                
             s_counter_rx <= (others => '0');      -- counter initialized
          else
            if (s_counter_rx=s_counter_full) then  -- measurement of the first period
              s_counter_rx <= (others => '0');              
            else
              s_counter_rx <= s_counter_rx + 1 ;
            end if; 
          end if;
        
        -- for the rest of the rxd
        else
         if (s_rx_signif_edge_window = '1') and (d_edge_i ='1') then 
           s_counter_rx <= (others => '0');        -- when an edge appears inside
                                                   --  the expected window, the   
                                                   --  counter is reinitialized

          elsif (s_counter_rx=s_counter_full) then -- otherwise, it continues counting
            s_counter_rx <= (others => '0');       -- complete nominal periods
          else
            s_counter_rx <= s_counter_rx + 1 ;  
  
         end if;
        end if;
       end if;
    end if;
  end process;


---------------------------------------------------------------------------------------------------
-- concurrent signal assignments concerning the receiver:
--creation of the windows where significant edges and adjacent bits transitions are expected on the
-- input signal
-- reminder:in principle, s_counter_rx is initialized after the detection of a significant edge and
-- it is counting a complete period, according to the bit rate. 
    
-- s_rx_signif_edge_window extends s_jitter uclk ticks before and s_jitter uclk ticks after the 
-- completion of a period, where significant edges are expected
-- s_rx_adjac_bits_window extends s_jitter uclk ticks before and s_jitter uclk ticks after the 
-- middle of a period, where transitions between adjacent bits are expected   

  s_rx_signif_edge_window <= '1' when ((s_counter_rx < s_jitter) or
                                       (s_counter_rx > s_counter_full - s_jitter-1))
                        else '0';

  s_rx_adjac_bits_window <= '1' when ((s_counter_rx >= s_half_period-s_jitter-1) and
                                      (s_counter_rx < s_half_period+s_jitter))

                        else '0';

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
        if (rst_i = '1') then
          s_rx_manch_clk <='0';
          s_rx_bit_clk <= '0';
          s_signif_edge_found <='0';
          s_adjac_bits_edge_found <='0';

        else
          -- regarding significant edges:
          if (s_rx_signif_edge_window='1') then   -- looking for a significant edge  
            if  (d_edge_i='1') then               -- inside the corresponding window
              s_rx_manch_clk <= not s_rx_manch_clk;
              s_signif_edge_found <= '1';         -- indication that the edge was found
              s_adjac_bits_edge_found <= '0';
            end if;

          elsif (s_signif_edge_found='0')and(s_counter_rx=s_jitter) then
            s_rx_manch_clk <= not s_rx_manch_clk; --if a significant edge is not found where               
                                                  -- expected (code violation), the
                                                  -- rx_manch_clk is inverted right after the
                                                  -- end of the signif_edge_window

            s_adjac_bits_edge_found <= '0';       -- re-initialization before the next cycle

          -- regarding edges between adjacent bits:
          elsif (s_rx_adjac_bits_window='1') then -- looking for an edge inside 
            if  (d_edge_i='1') then               -- the corresponding window
             s_rx_manch_clk <= not s_rx_manch_clk;-- inversion of rx_manch_clk
             s_rx_bit_clk <= not s_rx_bit_clk;    -- inversion of rx_bit_clk
             s_adjac_bits_edge_found <= '1';      -- indication that an edge was found

             s_signif_edge_found <= '0';          -- re-initialization before the next cycle
            end if;

          elsif (s_adjac_bits_edge_found='0')and(s_counter_rx=s_half_period+s_jitter) then 
            s_rx_manch_clk <= not s_rx_manch_clk; -- if no edge occurs inside the 
            s_rx_bit_clk <= not s_rx_bit_clk;     -- adjac_bits_edge_window, both clks are 
                                                  -- inverted right after the end of it.
           
           
            s_signif_edge_found <= '0';           -- re-initialization before the next cycle
         end if;

         s_rx_manch_clk_d1 <= s_rx_manch_clk;     -- s_rx_manch_clk:    ____|-----|_____|-----|____
                                                  -- s_rx_manch_clk_d1: ______|-----|_____|-----|__
                                                  -- rx_manch_clk_p_o:  ____|-|___|-|___|-|___|-|__

         s_rx_bit_clk_d1 <= s_rx_bit_clk;         -- s_rx_bit_clk:     ____|-----------|___________
                                                  -- s_rx_bit_clk_d1:  ______|-----------|_________
                                                  -- rx_bit_clk_p_o:   ____|-|_________|-|_________                           

        end if;
      end if;
    end process;  


---------------------------------------------------------------------------------------------------
-- Output signals construction:

  -- clocks needed for the receiver: 
   rx_manch_clk_p_o <= s_rx_manch_clk_d1 xor s_rx_manch_clk;   -- a pulse 1-uclk period long, after
                                                               -- 1) a significant edge 
                                                               -- 2) a new bit
                                                               -- ___|-|___|-|___|-|___

   rx_bit_clk_p_o  <= s_rx_bit_clk xor s_rx_bit_clk_d1;        -- a pulse 1-uclk period long, after
                                                               -- a new bit
                                                               -- _________|-|_________
  
 -- clocks needed for the transmitter:
  tx_clk_o <= s_tx_clk_d1;
  tx_clk_p_buff_o <= s_tx_clk_p_buff;                           

 
  -- output signals that have also been used in this unit's processes:
  rx_signif_edge_window_o <= s_rx_signif_edge_window;
  rx_adjac_bits_window_o <= s_rx_adjac_bits_window;


end architecture rtl;
---------------------------------------------------------------------------------------------------
--                          E N D   O F   F I L E
---------------------------------------------------------------------------------------------------
