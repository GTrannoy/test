-------------------------------------------------------------------------------
--! @file dpblockram.vhd
-------------------------------------------------------------------------------
--! Standard library
library IEEE;
--! Standard packages
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

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

 entity dpblockram is
 generic (dl : integer := 42; 		-- Length of the data word 
 			 al : integer := 10;			-- Size of the addr map (10 = 1024 words)
			 nw : integer := 1024);    -- Number of words
			 									-- 'nw' has to be coherent with 'al'

 port (clk  : in std_logic; 			-- Global Clock
 	we   : in std_logic; 				-- Write Enable
 	aw    : in std_logic_vector(al - 1 downto 0); -- Write Address 
 	ar : in std_logic_vector(al - 1 downto 0); 	 -- Read Address
 	di   : in std_logic_vector(dl - 1 downto 0);  -- Data input
 	dw  : out std_logic_vector(dl - 1 downto 0);  -- Data write, normaly open
 	do  : out std_logic_vector(dl - 1 downto 0)); 	 -- Data output
 end dpblockram; 
 												
--library synplify;
--use synplify.attributes.all;
 architecture syn of dpblockram is 
 
 type ram_type is array (nw - 1 downto 0) of std_logic_vector (dl - 1 downto 0); 
 signal RAM : ram_type; 
 signal read_a : std_logic_vector(al - 1 downto 0); 
 signal read_ar : std_logic_vector(al - 1 downto 0); 
--attribute syn_ramstyle of RAM : signal is "select_ram"; 
--attribute syn_ramstyle of RAM : signal is "area "; 
begin 

 process (clk) 
 begin 
 	if (clk'event and clk = '1') then  
 		if (we = '1') then 
 			RAM(conv_integer(aw)) <= di; 
 		end if; 
 		read_a <=aw ; 
 		read_ar <=ar ; 

 	end if; 
 end process; 
 


 dw <= RAM(conv_integer(read_a)); 
 do <= RAM(conv_integer(read_ar)); -- Notice that the Data Output is not registered


 end syn;

 
