--===========================================================================
--! @file reset_logic.vhd
--! @brief Reset logic
--===========================================================================
--! Standard library
library IEEE;
--! Standard packages
use IEEE.STD_LOGIC_1164.all; --! std_logic definitions
use IEEE.NUMERIC_STD.all;    --! conversion functions
use work.wf_package.all;


-------------------------------------------------------------------------------
--                                                                           --
--                                 reset_logic                               --
--                                                                           --
--                               CERN, BE/CO/HT                              --
--                                                                           --
-------------------------------------------------------------------------------
--
-- unit name: reset_logic
--
--! @brief Reset logic.
--!
--! Used in the NanoFIP design. \n
--! The reset_logic implements the power-on reset and other resets (consumption
--! of the reset variable).
--!
--!
--! @author Erik van der Bij (Erik.van.der.Bij@cern.ch)
--
--! @date 07/07/2009
--
--! @version v0.01
--
--! @details 
--!
--! <b>Dependencies:</b>\n
--! wf_engine           \n
--!
--! <b>References:</b>\n
--! 
--! 
--!
--! <b>Modified by:</b>\n
--! Author:Pablo Alvarez Sanchez (pablo.alvarez.sanchez@cern.ch)
-------------------------------------------------------------------------------
--! \n\n<b>Last changes:</b>\n
--! 07/07/2009  v0.01  EB  First version \n
--!
-------------------------------------------------------------------------------
--! @todo Define I/O signals \n
--!
-------------------------------------------------------------------------------



--============================================================================
--! Entity declaration for reset_logic
--============================================================================
entity reset_logic is
  generic(c_reset_length : integer := 4); --! Reset counter length. 4==> 16 uclk_i ticks 

  port (
    uclk_i :   in std_logic;  --! 40MHz clock
    rstin_i :  in  std_logic; --! Initialisation control, active low
    var_i :    in t_var;      --! Received variable


    rston_o :  out std_logic; --! Reset output, active low.
                              --  Active when the reset variable is received 
                              --  and the second byte contains the station address.

    rst_o :    out std_logic;  --! Reset ouput active high

    fd_rst_o : out std_logic --! fieldrive reset, active low
                              -- Active when the reset variable is received 
                              --  and the first byte contains the station address.
    );

end entity reset_logic;
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--! ARCHITECTURE OF reset_logic
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
architecture rtl of reset_logic is

  signal s_rstin_buff : std_logic_vector(1 downto 0);
  signal s_rst_c, s_rstin_c : unsigned(4 downto 0);
  signal s_reload_rst_c, rst_o2, s_rstin_c_start, s_reset : std_logic;
  
  begin

    process(s_rstin_buff,var_i)
    begin
      if (var_i = c_var_array(c_reset_var_pos).var) then 
        s_reload_rst_c <= '1';
      else
        s_reload_rst_c <=   s_rstin_buff(s_rstin_buff'left);
      end if;
    end process;

  process(uclk_i)
  begin
    if rising_edge(uclk_i) then

        s_rstin_buff <= s_rstin_buff(0) & (not rstin_i);

        if (s_reload_rst_c = '1') then 
          s_rst_c <=  to_unsigned(0, s_rst_c'length);

        elsif  s_rst_c(s_rst_c'left) = '0' then
          s_rst_c <=  s_rst_c + 1;
        
        end if;

        rst_o <=  not s_rst_c(s_rst_c'left);
        rston_o <=  s_rst_c(s_rst_c'left);
        fd_rst_o <= s_rst_c(s_rst_c'left);
---------------------------------------------------------------------------------------------------
--        if (s_rstin_buff(0) = '1') and (s_rstin_buff(1) /= '1') then
--         s_rstin_c_start <= '1';
--          s_rstin_c <= to_unsigned(0, s_rstin_c'length); 
--        end if;   

--        if s_rstin_c_start = '1' then        
--          if rstin_i = '0' then
--            s_rstin_c <= s_rstin_c+1;
--          end if; 
--        end if;

--        if s_rstin_c(s_rstin_c'left) = '1' then
--          s_rstin_c_start <='0';
--          s_reset <= rstin_i;
--        else
--          s_reset <= '1';          
--        end if;

--        rst_o2 <= not (s_reset);


    end if;
  
end process;


end architecture rtl;
-------------------------------------------------------------------------------
--                          E N D   O F   F I L E
-------------------------------------------------------------------------------