--===========================================================================
--! @file wf_consumed_vars.vhd
--! @brief Nanofip control unit
--===========================================================================
--! Standard library
library IEEE;
--! Standard packages
use IEEE.STD_LOGIC_1164.all; --! std_logic definitions
use IEEE.NUMERIC_STD.all;    --! conversion functions

use work.wf_package.all;

-------------------------------------------------------------------------------
--                                                                           --
--                                 wf_consumed_vars                                 --
--                                                                           --
--                               CERN, BE/CO/HT                              --
--                                                                           --
-------------------------------------------------------------------------------
--
-- unit name: wf_consumed_vars
--
--! @brief Nanofip control unit. It accepts variable data and store them into block ram or in stand alone mode directly to the wf_wishbone. \n
--!
--! 
--!
--!
--!
--!
--!
--! @author Pablo Alvarez Sanchez (pablo.alvarez.sanchez@cern.ch)
--
--! @date 11/09/2009
--
--! @version v0.01
--
--! @details 
--!
--! <b>Dependencies:</b>\n
--! wf_package           \n
--!
--!
--! <b>References:</b>\n
--! 
--! 
--!
--! <b>Modified by:</b>\n
--! Author: 
-------------------------------------------------------------------------------
--! \n\n<b>Last changes:</b>\n
--! 11/09/2009  v0.01  EB  First version \n
--!
-------------------------------------------------------------------------------
--! @todo 
--!
-------------------------------------------------------------------------------



--============================================================================
--! Entity declaration for wf_consumed_vars
--============================================================================
entity wf_consumed_vars is

port (
   uclk_i    : in std_logic; --! User Clock
   rst_i     : in std_logic;

      --! Stand-alone mode
      --! If connected to Vcc, disables sending of NanoFIP status together with 
      --! the produced data.
   slone_i   : in  std_logic; --! Stand-alone mode

   byte_ready_p_i : in std_logic;
	var_i : in t_var;
--	append_status_i : in std_logic;
	add_offset_i : in std_logic_vector(6 downto 0);
--	data_length_i : in std_logic_vector(6 downto 0);
	byte_i : in std_logic_vector(7 downto 0);

-------------------------------------------------------------------------------
--!  USER INTERFACE. Data and address lines synchronized with uclk_i
-------------------------------------------------------------------------------

--   dat_i     : in  std_logic_vector (15 downto 0); --! 

   dat_o     : out std_logic_vector (15 downto 0); --! 
   adr_i     : in  std_logic_vector ( 9 downto 0) --! 
--   stb_p_i     : in  std_logic; --! Strobe
--   ack_p_o     : out std_logic; --! Acknowledge
--   we_p_i      : in  std_logic  --! Write enable

);

end entity wf_consumed_vars;




-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--! ARCHITECTURE OF wf_control
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
architecture rtl of wf_consumed_vars is


constant c_presence_pos : natural := 0;
constant c_identification_pos : natural := 1;
constant c_mem_pos : natural := 2;
constant c_last_pos : natural := 2;
signal base_add, add: std_logic_vector(9 downto 0);
signal s_dat_ram : std_logic_vector(7 downto 0);
signal we_ram_p : std_logic;
signal we_byte_p : std_logic_vector(1 downto 0);
signal s_dat : std_logic_vector(15 downto 0);
begin

 production_dpram : dpblockram 
 generic map(dl => 8, 		-- Length of the data word 
 			 al => 7,			-- Size of the addr map (10 = 1024 words)
			 nw => 2**7)    -- Number of words
			 									-- 'nw' has to be coherent with 'al'

 port map(clk  => uclk_i,			-- Global Clock
 	we  => we_ram_p, 				-- Write Enable
 	aw  => add(6 downto 0),  -- Write Address 
 	ar =>  adr_i(6 downto 0), -- Read Address
 	di =>  byte_i, -- Data input
 	dw  => open,  -- Data write, normaly open
 	do => s_dat_ram); 	 -- Data output

add <= std_logic_vector(unsigned(add_offset_i) + unsigned(base_add));

process(var_i, add_offset_i, slone_i, byte_ready_p_i)
begin
	we_ram_p <= '0';
	we_byte_p <= (others => '0');
   base_add <= (others => '0');

   for I in c_var_array'range loop
	   if (c_var_array(I).response = consume) then
      if c_var_array(I).var = var_i then
		   base_add <= c_var_array(I).base_add;
         if slone_i = '0' then
			   we_ram_p <= byte_ready_p_i;
         elsif slone_i = '1' and I = c_var_var1_pos   then
			   if unsigned(add_offset_i) = c_byte_0_add then
	            we_byte_p(0) <= byte_ready_p_i ;					
				end if;
	         if unsigned(add_offset_i) = c_byte_1_add then
	            we_byte_p(1) <= byte_ready_p_i ;		
				end if;
			end if;
         exit;
		  end if;
        end if;		
   end loop;
end process;

process(uclk_i)
begin
   if rising_edge(uclk_i) then
      if rst_i = '1' then
         s_dat <= (others => '0');
      else
         if we_byte_p(1) = '1' then
            s_dat(15 downto 8) <= byte_i;
         end if;
         if we_byte_p(0) = '1' then
            s_dat(7 downto 0) <= byte_i;
         end if;
      end if;
   end if;
end process;
process(s_dat, s_dat_ram, slone_i)
begin
   dat_o <= (others => '0');
      if slone_i = '1' then
         dat_o <= s_dat;
      else
         dat_o(7 downto 0) <= s_dat_ram;
      end if;
end process;

end architecture rtl;

-------------------------------------------------------------------------------
--                          E N D   O F   F I L E
-------------------------------------------------------------------------------
