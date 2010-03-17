-------------------------------------------------------------------------------
--! @file dpblockram.vhd
-------------------------------------------------------------------------------
--! Standard library
library IEEE;
--! Standard packages
use IEEE.STD_LOGIC_1164.all; --! std_logic definitions
use IEEE.NUMERIC_STD.all;    --! conversion functions


----------------------------------------------------------------------------
----------------------------------------------------------------------------
-- --
-- CERN, BE  --
-- --
-------------------------------------------------------------------------------
--
-- unit name: dpblockram.vhd
--
--! @brief The dpblockram implements a template for a true dual port ram clocked on both ports by the same clock.
--! 
--! @author <Pablo Alvarez(pablo.alvarez.sanchez@cern.ch)>
--
--! @date 24\01\2009
--
--! @version 1
--
--! @details
--!
--! <b>Dependencies:</b>\n
--! 
--!
--! <b>References:</b>\n
--! <reference one> \n
--! <reference two>
--!
--! <b>Modified by:</b>\n
--! Author: <name>
-------------------------------------------------------------------------------
--! \n\n<b>Last changes:</b>\n
--! 24\01\2009 paas header included\n
--! <extended description>
-------------------------------------------------------------------------------
--! @todo Adapt vhdl sintax to ohr standard\n
--! <another thing to do> \n
--
-------------------------------------------------------------------------------

entity dpblockram_clka_rd_clkb_wr is
  generic (c_dl : integer := 42; 		-- Length of the data word 
           c_al : integer := 10);    -- Number of words
                                       -- 'nw' has to be coherent with 'c_al'

  port (clka_i  : in std_logic; 			-- Global Clock
        aa_i : in std_logic_vector(c_al - 1 downto 0);
        da_o : out std_logic_vector(c_dl -1 downto 0);
        
        clkb_i : in std_logic;
        ab_i : in std_logic_vector(c_al - 1 downto 0);
        db_i : in std_logic_vector(c_dl - 1 downto 0);
        web_i : in std_logic);
end dpblockram_clka_rd_clkb_wr; 

--library synplify;
--use synplify.attributes.all;
architecture beh of dpblockram_clka_rd_clkb_wr is 
 
 
  
  type t_ram is array (2**c_al - 1 downto 0) of std_logic_vector (c_dl - 1 downto 0); 
  shared variable s_ram : t_ram := (others => (others => '0')); 
  
 --attribute syn_ramstyle : string;
--attribute syn_ramstyle of s_ram : variable is "block_ram";
--attribute syn_ramstyle of RAM : signal is "select_ram"; 
--attribute syn_ramstyle of RAM : signal is "area "; 
begin 

  process (clkb_i)
  begin
    if (clkb_i'event and clkb_i = '1') then
      if (web_i = '1') then
        s_ram(to_integer(unsigned(ab_i))) := db_i; 
      end if;
    end if;
  end process;

  process (clka_i)
  begin
    if (clka_i'event and clka_i = '1') then
      da_o <= s_ram(to_integer(unsigned(aa_i))); 
    end if;
  end process;

end syn;