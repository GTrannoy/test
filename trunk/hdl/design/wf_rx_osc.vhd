--===========================================================================
--! @file wf_rx_osc.vhd
--! @brief Recovers clock from the input serial line. 
--===========================================================================
--! Standard library
library IEEE;
--! Standard packages
use IEEE.STD_LOGIC_1164.all; --! std_logic definitions
use IEEE.NUMERIC_STD.all;    --! conversion functions


-------------------------------------------------------------------------------
--                                                                           --
--                                 wf_rx                                 --
--                                                                           --
--                               CERN, BE/CO/HT                              --
--                                                                           --
-------------------------------------------------------------------------------
--
-- unit name: wf_rx_osc
--
--! @brief Numeric oscillator that generates a clock locked to the carrier 
--!        encoded frequency. 
--!
--! Used in the NanoFIP design. \n
--! This unit serializes the data.
--!
--!
--! @author	    Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)
--!
--! @date 10/08/2009
--
--! @version v0.01
--
--! @details 
--!
--! <b>Dependencies:</b>\n
--! wf_engine           \n
--! tx_engine           \n
--! clk_gen             \n
--! reset_logic         \n
--! consumed_ram        \n
--!
--!
--! <b>References:</b>\n
--! 
--! 
--!
--! <b>Modified by:</b>\n
--! Author:         Pablo Alvarez Sanchez
-------------------------------------------------------------------------------
--! \n\n<b>Last changes:</b>\n
--! 07/08/2009  v0.02  PAAS Entity Ports added, start of architecture content
--!
-------------------------------------------------------------------------------
--! @todo Define I/O signals \n
--!
-------------------------------------------------------------------------------



--============================================================================
--! Entity declaration for wf_rx_osc
--============================================================================
entity wf_rx_osc is
  generic (C_OSC_LENGTH : integer := 20;
           C_QUARTZ_PERIOD : real := 25.0;
           C_CLKFCDLENTGTH :  natural := 3 
           );

  port (
    uclk_i    : in std_logic; --! User Clock
    rst_i     : in std_logic;

    d_edge_i : in std_logic;

    load_phase_i : in std_logic;	
    
    --! Bit rate         \n
    --! 00: 31.25 kbit/s => 62.5 KHz \n
    --! 01: 1 Mbit/s  => 2 MHz  \n
    --! 10: 2.5 Mbit/s  => 5 MHz  \n
    --! 11: reserved, do not use
    rate_i    : in  std_logic_vector (1 downto 0); --! Bit rate

    clk_fixed_carrier_p_o : out std_logic;
    clk_fixed_carrier_p_d_o : out std_logic_vector(C_CLKFCDLENTGTH -1 downto 0);
    clk_fixed_carrier_o : out std_logic;
    
    clk_carrier_p_o : out std_logic;
    clk_carrier_180_p_o : out std_logic;
    
    clk_bit_p_o  : out std_logic;
    clk_bit_90_p_o  : out std_logic;
    clk_bit_180_p_o  : out std_logic;
    clk_bit_270_p_o  : out std_logic;
    
    edge_window_o : out std_logic;
    edge_180_window_o : out std_logic;
    phase_o : out std_logic_vector(C_OSC_LENGTH -1  downto 0)
    );

end entity wf_rx_osc;



-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--! ARCHITECTURE OF wf_rx_osc
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
architecture rtl of wf_rx_osc is
  --! Bit rate         \n
  --! 31.25 kbit => 62.5 KHz carrier \n
  constant c_period_31_25kbit : real := (C_QUARTZ_PERIOD*real(2**C_OSC_LENGTH))/32000.0;
  --! 1 Mbit/s  => 2MHz  carrier  \n
  constant c_period_1_mbit : real := (C_QUARTZ_PERIOD*real(2**C_OSC_LENGTH))/1000.0;
  --! 2.5 Mbit/s  => 5MHz carrier \n
  constant c_period_2_5mbit : real := (C_QUARTZ_PERIOD*real(2**C_OSC_LENGTH))/400.0;

  type t_period is array (Natural range <>) of signed(C_OSC_LENGTH -1 downto 0);
  constant C_PERIOD : t_period(3 downto 0) := (0 => to_signed(integer(c_period_31_25kbit), C_OSC_LENGTH),
                                               1 => to_signed(integer(c_period_1_mbit), C_OSC_LENGTH),
                                               2 => to_signed(integer(c_period_2_5mbit), C_OSC_LENGTH),
                                               3 => to_signed(integer(c_period_2_5mbit), C_OSC_LENGTH));

  
  signal s_tag, s_phase, s_free_c :  signed(C_OSC_LENGTH -1 downto 0);
  signal s_period, s_period_by_4 : signed(C_OSC_LENGTH -1 downto 0);
  signal s_nx_clk_bit  : std_logic;
  signal s_nx_clk_bit_90  :  std_logic;
  signal s_nx_clk_bit_180  :  std_logic;
  signal s_nx_clk_bit_270  :  std_logic;
  signal s_clk_bit  :  std_logic;
  signal s_clk_bit_90  :  std_logic;
  signal s_clk_bit_180  :  std_logic;
  signal s_clk_bit_270  :  std_logic;
  signal s_clk_fixed_carrier, s_nx_clk_fixed_carrier, s_clk_fixed_carrier_p :  std_logic;
  signal s_clk_fixed_carrier_p_d : std_logic_vector(C_CLKFCDLENTGTH -1 downto 0);

begin

  s_period <= C_PERIOD(to_integer(unsigned(rate_i)));

  process(uclk_i)
  begin
    if rising_edge(uclk_i) then
      if rst_i = '1' then
        s_free_c <= to_signed(0, s_free_c'length);
        s_tag <= to_signed(0, s_free_c'length);
        s_clk_bit      <= '0';
        s_clk_bit_90   <= '0';
        s_clk_bit_180  <= '0';
        s_clk_bit_270  <= '0';
        s_clk_fixed_carrier <= '0';
        s_clk_fixed_carrier_p_d <= (others => '0');
      else
        s_free_c <= s_free_c + s_period;
        if load_phase_i = '1' and d_edge_i = '1' then
          s_tag <=  s_free_c; 
        end if;
        s_clk_bit      <= s_nx_clk_bit;
        s_clk_bit_90   <= s_nx_clk_bit_90;
        s_clk_bit_180  <= s_nx_clk_bit_180;
        s_clk_bit_270  <= s_nx_clk_bit_270;
        s_clk_fixed_carrier <= s_nx_clk_fixed_carrier;
        s_clk_fixed_carrier_p_d <=s_clk_fixed_carrier_p_d(s_clk_fixed_carrier_p_d'left -1 downto 0)&s_clk_fixed_carrier_p;
      end if;
    end if;
  end process;
    clk_fixed_carrier_o <= s_clk_fixed_carrier;
  clk_fixed_carrier_p_d_o <= s_clk_fixed_carrier_p_d;
                             
             clk_bit_p_o  <= s_nx_clk_bit and (not s_clk_bit); 
  clk_bit_90_p_o  <= s_nx_clk_bit_90 and (not s_clk_bit_90); 
  clk_bit_180_p_o  <= s_nx_clk_bit_180 and (not s_clk_bit_180); 
  clk_bit_270_p_o  <= s_nx_clk_bit_270 and (not s_clk_bit_270); 

  s_clk_fixed_carrier_p <= s_nx_clk_fixed_carrier and (not s_clk_fixed_carrier);
  clk_fixed_carrier_p_o <= s_clk_fixed_carrier_p; 

  clk_carrier_p_o  <= s_nx_clk_bit xor s_clk_bit; 
  clk_carrier_180_p_o <= s_nx_clk_bit_90 xor s_clk_bit_90; 


  s_phase <= s_tag - s_free_c;
  phase_o <= std_logic_vector(s_phase);
  
  s_period_by_4 <= resize(4*s_period,s_period_by_4'length);
  process( s_phase, s_period, s_free_c)
  variable v_mid_point, v_quad_point : signed(s_phase'range);

  begin
    edge_window_o <= '0';
    edge_180_window_o <= '1';
    s_nx_clk_bit <= '0';
    s_nx_clk_bit_90 <= '0';
    s_nx_clk_bit_180 <= '0';
    s_nx_clk_bit_270 <= '0'; 
    s_nx_clk_fixed_carrier <= '0';
    v_mid_point := to_signed(2**(s_phase'length-1), s_phase'length);
    v_quad_point := to_signed(2**(C_OSC_LENGTH-2), s_phase'length);
    if (signed(s_free_c(s_free_c'left -1 downto 0)) < 0) then
      s_nx_clk_fixed_carrier<= '1';
    else
      s_nx_clk_fixed_carrier <= '0';
    end if;	


    if (s_phase < s_period_by_4) and (s_phase > (-s_period_by_4)) then
      edge_window_o <= '1';
    else
      edge_window_o <= '0';
    end if;
    
    if ((s_phase - v_mid_point) < (s_period_by_4)) and ((s_phase - v_mid_point) > (-s_period_by_4)) then
      edge_180_window_o <= '1';
    else
      edge_180_window_o <= '0';
    end if;
    
    
    if (s_phase < 0) then
      s_nx_clk_bit <= '1';
      s_nx_clk_bit_180 <= '0';
    else
      s_nx_clk_bit <= '0';
      s_nx_clk_bit_180 <= '1';
    end if;	


    if ((s_phase - v_quad_point) < 0) then
      s_nx_clk_bit_90 <= '0';
      s_nx_clk_bit_270 <= '1';
    else
      s_nx_clk_bit_90 <= '1';
      s_nx_clk_bit_270 <= '0';
    end if;	


  end process;


end architecture rtl;
-------------------------------------------------------------------------------
--                          E N D   O F   F I L E
-------------------------------------------------------------------------------
