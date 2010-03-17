--===========================================================================
--! @file wf_produced_vars.vhd
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
--                                 wf_produced_vars                                 --
--                                                                           --
--                               CERN, BE/CO/HT                              --
--                                                                           --
-------------------------------------------------------------------------------
--
-- unit name: wf_produced_vars
--
--! @brief Nanofip control unit. It provides with a transparent interface between the wf_control state machine and the RAM and special \n
--!                              variable bytes not stored in RAM. wf_wishbone has write access and wf_control read access.\n
--!
--! @author Pablo Alvarez Sanchez (pablo.alvarez.sanchez@cern.ch)
--
--! @date 11/09/2009
--!
--! @version v0.01
--!
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
--! @todo I have removed var3_access_wb_clk_o and reset_var3_access_i because in the funtional
--!       specifications var3_access comes from an external pin. I leave the commented code in
--!       the spec is revised
--!
-------------------------------------------------------------------------------



--============================================================================
--! Entity declaration for wf_produced_vars
--============================================================================
entity wf_produced_vars is

  port (
    uclk_i    : in std_logic; --! User Clock
    rst_i     : in std_logic;

    

    

    --! Identification selection (see M_ID, C_ID)
--   s_id_o    : out std_logic_vector (1 downto 0); --! Identification selection

    --! Identification variable settings. 
    --! Connect the ID inputs either to Gnd, Vcc, S_ID[0] or S_ID[1] to 
    --! obtain different values for the Model data (i=0,1,2,3).\n
    --! M_ID[i] connected to: Gnd S_ID0 SID1 Vcc               \n
    --! Model [2*i]            0    1    0    1                \n
    --! Model [2*i+1]          0    0    1    1
    m_id_i    : in  std_logic_vector (3 downto 0); --! Model identification settings

    --! Constructor identification settings.
    --! Connect the ID inputs either to Gnd, Vcc, S_ID[0] or S_ID[1] to 
    --! obtain different values for the Model data (i=0,1,2,3).\n
    --! C_ID[i] connected to: Gnd S_ID0 SID1 Vcc               \n
    --! Constructor[2*i]       0    1    0    1                \n
    --! Constructor[2*i+1]     0    0    1    1
    c_id_i    : in  std_logic_vector (3 downto 0); --! Constructor identification settings

    subs_i    : in  std_logic_vector (7 downto 0); --! Subscriber number coding.

    --! Stand-alone mode
    --! If connected to Vcc, disables sending of NanoFIP status together with 
    --! the produced data.
    slone_i   : in  std_logic; --! Stand-alone mode


    --! No NanoFIP status transmission
    --! If connected to Vcc, disables sending of NanoFIP status together with 
    --! the produced data.
    nostat_i  : in  std_logic; --! No NanoFIP status transmission

    stat_i : in std_logic_vector(7 downto 0); --! NanoFIP status 
    mps_i : in std_logic_vector(7 downto 0);
    sending_stat_o : out std_logic; --! The status register is being adressed
    sending_mps_o : out std_logic; --! The status register is being adressed
    
 --   var3_access_wb_clk_o: out std_logic; --! Variable 2 access flag

 --   reset_var3_access_i: in std_logic; --! Reset Variable 1 access flag

--   prod_byte_i : in std_logic_vector(7 downto 0);
    var_i : in t_var;
    append_status_i : in std_logic;
    add_offset_i : in std_logic_vector(6 downto 0);  --! Pointer to message
                                                     --bytes, including rp_dat,
                                                     --and substation ID.
    data_length_i : in std_logic_vector(6 downto 0);
    byte_o : out std_logic_vector(7 downto 0);

-------------------------------------------------------------------------------
--!  USER INTERFACE. Data and address lines synchronized with uclk_i
-------------------------------------------------------------------------------

    wb_dat_i     : in  std_logic_vector (15 downto 0); --! 
    wb_clk_i     : in std_logic;
    wb_dat_o     : out std_logic_vector (15 downto 0); --! 
    wb_adr_i     : in  std_logic_vector (9 downto 0); --! 
    wb_stb_p_i     : in  std_logic; --! Strobe
    wb_ack_p_o     : out std_logic; --! Acknowledge
    wb_we_p_i      : in  std_logic  --! Write enable



    );

end entity wf_produced_vars;




-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--! ARCHITECTURE OF wf_produced_vars
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
architecture rtl of wf_produced_vars is


  constant c_presence_pos : natural := 0;
  constant c_identification_pos : natural := 1;
  constant c_mem_pos : natural := 2;
  constant c_last_pos : natural := 2;
  signal s_byte: std_logic_vector(7 downto 0);
  signal s_mem_byte : std_logic_vector(7 downto 0);
  signal s_io_byte : std_logic_vector(7 downto 0);
  signal base_add, add: std_logic_vector(9 downto 0);
  signal s_wb_we : std_logic;
--  signal s_reset_var3_access_clkb, s_var3_access_clkb : std_logic;
  signal s_add_to_ram : std_logic_vector(8 downto 0);  --! Pointer to RAM contents

begin



  production_dpram:  dpblockram_clka_rd_clkb_wr
    generic map(c_dl => 8, 		-- Length of the data word 
                c_al => 9)    -- Number of words
    -- 'nw' has to be coherent with 'c_al'

    port map(clka_i => uclk_i,			-- Global Clock
             aa_i => s_add_to_ram,
             da_o => s_mem_byte,
             
             clkb_i => wb_clk_i,
             ab_i => wb_adr_i(8 downto 0),
             db_i => wb_dat_i(7 downto 0),
             web_i => wb_we_p_i);
             
s_add_to_ram <= std_logic_vector(unsigned(add(s_add_to_ram'range)) - 2);
  s_wb_we <=  wb_stb_p_i and wb_we_p_i;


  --! P_wb_interface generates wb_ack and var3_access signal
  P_wb_interface:process(wb_clk_i)
  begin
    if rising_edge(wb_clk_i) then
      if wb_adr_i(9 downto 7) = "010" then
        wb_ack_p_o <= s_wb_we and  wb_stb_p_i;
      else
        wb_ack_p_o <= '0';
      end if;

--      if unsigned(wb_adr_i(9 downto 7)) = to_unsigned(2, 2) then
--        s_var3_access_clkb <= s_wb_we and  wb_stb_p_i;
--      elsif s_reset_var3_access_clkb = '1' then
--        s_var3_access_clkb <= '0' ;
--      end if;
 --     s_reset_var3_access_clkb <= reset_var3_access_i;

    end if;
  end process;
--  var3_access_wb_clk_o <= s_var3_access_clkb;

-- For the moment there is only one variable produced, but I think it is nice to have
-- defined an offset for every variable in case we produce more variables in the future

  add <= std_logic_vector(unsigned(add_offset_i) + unsigned(base_add));

  process(s_mem_byte, subs_i, mps_i, var_i, add_offset_i, s_io_byte, data_length_i, append_status_i, stat_i, slone_i, c_id_i, m_id_i)
  begin
    s_byte <= s_mem_byte;
    base_add <= (others => '0');
    sending_stat_o <= '0';
    sending_mps_o <= '0';
    for I in c_var_array'range loop
      if (c_var_array(I).response = produce) then
        if c_var_array(I).var = var_i then
          base_add <= c_var_array(I).base_add;

          --! I send c_rp_dat
          if unsigned(add_offset_i) = 0  then
             s_byte <= c_var_array(I).byte_array(to_integer(unsigned(add_offset_i(3 downto 0))));
             exit;
          end if;

          --! I send c_rp_dat
          if unsigned(add_offset_i) = 1  then
             s_byte <= subs_i;
             exit;
          end if;
          
          --! Next I check if the variable to be sent is of a predefined type:
          --! identification or presence
          if c_var_array(I).var = c_st_var_identification then
            if unsigned(add_offset_i) = c_cons_byte_add then
              s_byte(c_id_i'range) <= c_id_i;
              exit;
            elsif unsigned(add_offset_i) = c_model_byte_add then
              s_byte(m_id_i'range) <= m_id_i;
              exit;
            else
             s_byte <= c_var_array(I).byte_array(to_integer(unsigned(add_offset_i(3 downto 0))));
             exit;
            end if;
          end if;
          
          if c_var_array(I).var = c_st_var_presence then
            s_byte <= c_var_array(I).byte_array(to_integer(unsigned(add_offset_i(3 downto 0))));
            exit;
          end if;
         
          --! Normally the only variable left is var3. 
          if unsigned(add_offset_i) = c_pdu_byte_add then  --! Send PDU byte 
            s_byte <= c_var_array(I).byte_array(to_integer(unsigned(add_offset_i(3 downto 0))));
          elsif unsigned(add_offset_i) = c_var_length_add then
            s_byte(data_length_i'range) <= data_length_i;
          elsif (unsigned(add_offset_i) = (unsigned(data_length_i) - 1)) and append_status_i = '1' then
            s_byte <= stat_i;
            sending_stat_o <= '1';
          elsif (unsigned(add_offset_i) = unsigned(data_length_i)) then
            s_byte <= mps_i;
            sending_mps_o <= '1';
          elsif unsigned(add_offset_i) <  c_var_array(I).array_length then
            s_byte <= s_mem_byte;
          elsif slone_i = '1' then
            s_byte <= s_io_byte;
          else
            s_byte <= c_var_array(I).byte_array(to_integer(unsigned(add_offset_i(3 downto 0))));
          end if;
--            s_byte <= s_mem_byte;
          exit;
        end if;
      end if;
    end loop;
  end process;

  s_io_byte <= wb_dat_i(15 downto 8) when add_offset_i(0) = '1' else wb_dat_i(7 downto 0);
  byte_o <= s_byte;
end architecture rtl;
-------------------------------------------------------------------------------
--                          E N D   O F   F I L E
-------------------------------------------------------------------------------