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
--! Author: Pablo Alvarez Sanchez (pablo.alvarez.sanchez@cern.ch)
---------------------------------------------------------------------------------------------------
--! \n\n<b>Last changes:</b>\n
--! 11/09/2009  v0.01  EB  First version \n
--!
---------------------------------------------------------------------------------------------------
--! @todo 
--!
---------------------------------------------------------------------------------------------------



--============================================================================
--! Entity declaration for wf_consumed_vars
--============================================================================
entity wf_consumed_vars is

port (
  -- Inputs 
    -- User Interface general signals 
    uclk_i :         in std_logic;                                                  --! 40MHz clock
    rst_i :          in std_logic;                        --! global reset
    slone_i :        in  std_logic;                              --! stand-alone mode (active high)

    byte_ready_p_i : in std_logic;
	add_offset_i :   in std_logic_vector(6 downto 0);
	var_i :          in t_var;
	byte_i :         in std_logic_vector(7 downto 0);

    wb_clk_i :        in std_logic;

    wb_adr_i :        in  std_logic_vector (9 downto 0); --! 
    wb_stb_p_i :      in  std_logic; --! Strobe
    wb_we_p_i :       in  std_logic;  --! Write enable

  -- Outputs
    wb_data_o :        out std_logic_vector (15 downto 0); --! 
    wb_ack_p_o :      out std_logic --! Acknowledge

);

end entity wf_consumed_vars;




---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
--! rtl architecture of wf_consumed_vars
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
architecture rtl of wf_consumed_vars is

constant c_presence_pos : natural := 0;
constant c_identification_pos : natural := 1;
constant c_mem_pos : natural := 2;
constant c_last_pos : natural := 2;

signal s_base_addr, s_addr: std_logic_vector(9 downto 0);
signal s_mem_data_out : std_logic_vector(7 downto 0);
signal s_slone_write_byte : std_logic_vector(1 downto 0);
signal s_slone_data_out : std_logic_vector(15 downto 0);
signal s_write_en_p : std_logic;

begin

---------------------------------------------------------------------------------------------------  
-- !@brief synchronous process consumtion_dpram: Instanciation of a "Consumed ram"

  consumtion_dpram:  dpblockram_clka_rd_clkb_wr

    generic map(c_data_length => 8,         -- 8 bits: length of data word
 			    c_addr_length => 9)         -- 2^9: depth of consumed ram
                                            -- first 2 bits: identification of the memory block
                                            -- remaining 7 bits: address of a byte inside the block 


   -- port A corresponds to: wishbone that reads from the Consumed ram & B to: nanoFIP that writes
    port map (clk_A_i     => wb_clk_i,	           -- wishbone clck
             addr_A_i     => wb_adr_i(8 downto 0), -- address of byte to be read from memory
             data_A_o     => s_mem_data_out,       -- output byte read
             
             clk_B_i      => uclk_i,               -- 40 MHz clck 
             addr_B_i     => s_addr(8 downto 0),   -- address of byte to be written to memory
             data_B_i     => byte_i,               -- byte to be written
             write_en_B_i => s_write_en_p          -- wishbone write enable
             );

---------------------------------------------------------------------------------------------------
process(wb_clk_i)
begin
if rising_edge(wb_clk_i) then
   if unsigned(wb_adr_i(9 downto 8)) = to_unsigned(0, 2) then
      wb_ack_p_o <= wb_stb_p_i ;
   else
      wb_ack_p_o <= '0';
   end if;

-- The access flags can be generated inside the wishbone interface
-- I comment these lines because they do not follow the funtional spec,
-- but I think it is a more accurate way of signaling a race condition

--   if unsigned(wb_adr_i(9 downto 7)) = to_unsigned(0, 2) then
--     s_var1_access_clkb <= wb_stb_p_i ;
--   elsif s_reset_var1_access_clkb = '1' then
--      s_var1_access_clkb <= '0' ;
--   end if;

--   if unsigned(wb_adr_i(9 downto 7)) = to_unsigned(1, 2) then
--      s_var2_access_clkb <= wb_stb_p_i ;
--   elsif s_reset_var2_access_clkb = '1' then
--      s_var2_access_clkb <= '0' ;
--   end if;
	
--	s_reset_var1_access_clkb <= reset_var1_access_i;
--	s_reset_var2_access_clkb <= reset_var2_access_i;
end if;
end process;
--  var1_access_wb_clk_o <= s_var1_access_clkb;
--  var2_access_wb_clk_o <= s_var2_access_clkb;

s_addr <= std_logic_vector(unsigned(add_offset_i) + unsigned(s_base_addr));

---------------------------------------------------------------------------------------------------
process(var_i, add_offset_i, slone_i, byte_ready_p_i)
  begin
   s_write_en_p <= '0';
   s_slone_write_byte <= (others => '0');
   s_base_addr <= (others => '0');

    case var_i is


    when c_var_1 =>
            s_base_addr <= c_var_array(3).base_add;

            if slone_i = '0' then
               s_write_en_p <= byte_ready_p_i;

            elsif slone_i = '1' then
               if unsigned(add_offset_i) = c_byte_0_add then -- 1st byte
                  s_slone_write_byte(0) <= byte_ready_p_i ;					
               end if;

               if unsigned(add_offset_i) = c_byte_1_add then -- 2nd byte
                  s_slone_write_byte(1) <= byte_ready_p_i ;		
               end if;
            end if;


    when c_var_2 =>
            s_base_addr <= c_var_array(4).base_add;

            if slone_i = '0' then
               s_write_en_p <= byte_ready_p_i;
            end if;

    when others =>

  end case;
 
end process;

---------------------------------------------------------------------------------------------------
process(uclk_i)
begin
   if rising_edge(uclk_i) then
      if rst_i = '1' then
         s_slone_data_out <= (others => '0');
      else

         if s_slone_write_byte(0) = '1' then
            s_slone_data_out(7 downto 0) <= byte_i;
         end if;

         if s_slone_write_byte(1) = '1' then
            s_slone_data_out(15 downto 8) <= byte_i;
         end if;

      end if;
   end if;
end process;

---------------------------------------------------------------------------------------------------
process(s_slone_data_out, s_mem_data_out, slone_i)
begin
   wb_data_o <= (others => '0');
   if slone_i = '1' then
     wb_data_o <= s_slone_data_out;
   else
     wb_data_o(7 downto 0) <= s_mem_data_out;
   end if;
end process;

end architecture rtl;

---------------------------------------------------------------------------------------------------
--                          E N D   O F   F I L E
---------------------------------------------------------------------------------------------------