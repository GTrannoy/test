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
--! Author: Pablo Alvarez Sanchez (pablo.alvarez.sanchez@cern.ch)
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
  generic (c_dl : integer := 8; 		-- Length of the data word 
           c_al : integer := 9);        -- Number of words
                                        -- 'nw' has to be coherent with 'c_al'

  port (
        clka_i  : in std_logic; 			-- Global Clock
        aa_i : in std_logic_vector(c_al - 1 downto 0);
        da_o : out std_logic_vector(c_dl -1 downto 0);
        
        clkb_i : in std_logic;
        ab_i : in std_logic_vector(c_al - 1 downto 0);
        db_i : in std_logic_vector(c_dl - 1 downto 0);
        web_i : in std_logic);
end dpblockram_clka_rd_clkb_wr; 

--library synplify;
--use synplify.attributes.all;
architecture syn of dpblockram_clka_rd_clkb_wr is 

component DualClkRam is 
    port( DINA : in std_logic_vector(7 downto 0); DOUTA : out 
        std_logic_vector(7 downto 0); DINB : in std_logic_vector(
        7 downto 0); DOUTB : out std_logic_vector(7 downto 0); 
        ADDRA : in std_logic_vector(8 downto 0); ADDRB : in 
        std_logic_vector(8 downto 0);RWA, RWB, BLKA, BLKB, CLKA, 
        CLKB, RESET : in std_logic) ;
end component DualClkRam;

signal s_zeros_da : std_logic_vector(7 downto 0);
signal zero : std_logic;
signal one : std_logic;
signal s_rw : std_logic;
begin 

s_zeros_da <= (others => '0');
zero <= '0';
one <= '1';
s_rw <= not web_i;
UDualClkRam : DualClkRam  
    port map ( DINA => s_zeros_da,
     DOUTA => da_o,
     DINB => db_i,
     DOUTB  => open,
     ADDRA  => aa_i,
     ADDRB  => ab_i, 
     RWA  => one, 
     RWB  => s_rw, 
     BLKA  => zero, 
     BLKB  => zero, 
     CLKA  => clka_i, 
     CLKB  => clkb_i, 
     RESET  => one) ;


end syn;