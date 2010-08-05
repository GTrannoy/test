--=================================================================================================
--! @file wf_produced_vars.vhd
--=================================================================================================

-- standard library
library IEEE; 

-- standard packages
use IEEE.STD_LOGIC_1164.all;                                              --! std_logic definitions
use IEEE.NUMERIC_STD.all;                                                  --! conversion functions

use work.wf_package.all;                 --! definitions of supplemental types, subtypes, constants

---------------------------------------------------------------------------------------------------
--                                                                                               --
--                                 wf_produced_vars                                              --
--                                                                                               --
--                                  CERN, BE/CO/HT                                               --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
--
--! @brief After an id_dat frame requesting for a variable to be produced, this unit provides 
--! to the transmitter (wf_tx) one by one, \n all the bytes of data needed for the rp_dat frame
--! (apart from fss, fcs and fes bytes).
--!
--! @author Pablo Alvarez Sanchez (pablo.alvarez.sanchez@cern.ch)
--
--! @date 17/06/2010
--!
--! @version v0.02
--!
--! @details 
--!
--! <b>Dependencies:</b>\n
--! wf_package           \n
--! status_gen           \n
--!
--! <b>References:</b>\n
--!
--! <b>Modified by:</b>\n
--! Author: Evangelia Gousiou (Evangelia.Gousiou@cern.ch)

---------------------------------------------------------------------------------------------------
--! \n\n<b>Last changes:</b>\n
--! 11/09/2009  v0.01  EB  First version \n
--! 11/06/2010  v0.02  EB  Second version \n
--!                       -> egousiou: subs_i is not sent in the rp_dat frames
--!                                          (v0.01 lines 212-216 deleted) \n
--!                       -> egousiou: pdu_type & length bytes not sent in slone
--!                                           (v0.01 lines 239-254 modifid) \n
--!                       -> egousiou: signal s_wb_we includes the wb_stb_p_i
--!                                               (v0.01 line 142 modified) \n
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
--! @todo -> Confirm that specs for memory access (var3_rdy) are respected! \n
--!       -> Confirm cleaning up of rst_i, nostat_i, subs_i. \n
--!       -> Replace nested ifs (lines 170-231) with case structure to make code bit cleaner? \n                      
---------------------------------------------------------------------------------------------------

--=================================================================================================
--! Entity declaration for wf_produced_vars
--=================================================================================================

entity wf_produced_vars is

  port (
  -- Inputs 
    -- User Interface general signals 
    uclk_i :         in std_logic;                      --! 40MHz clock
    rst_i :          in std_logic;                      --! global reset
    slone_i :        in  std_logic;                     --! stand-alone mode 
    nostat_i :       in  std_logic;                     --! not used! to be cleaned-up!(confirm)
	
    -- WorldFIP settings
    m_id_dec_i :     in  std_logic_vector (7 downto 0); --! model identification settings (decoded)
    c_id_dec_i :     in  std_logic_vector (7 downto 0); --! constructor id settings (decoded)
    subs_i :         in  std_logic_vector (7 downto 0); --! bus not used!to be cleaned-up!(confirm)
   
   -- User Interface Wishbone Slave
    wb_data_i :      in  std_logic_vector (15 downto 0);--! wishbone input data bus

    wb_clk_i :       in std_logic;                      --! wishbone clock
                                                        -- note: may be indipendant of uclk

    wb_adr_i :       in  std_logic_vector (9 downto 0); --! wishbone address to memory
                                                        -- note: msb allways 0!

    wb_stb_p_i :     in  std_logic;                     --! wishbone strobe
                                                        --note:indicates a valid data transfer cycle
                                                      
    wb_we_p_i :      in  std_logic;                     --! wishbone write enable
                                                        -- note: indicates a write cycle of master
	
   -- signals from status_gen
    stat_i :         in std_logic_vector(7 downto 0); --! nanoFIP status byte
    mps_i :          in std_logic_vector(7 downto 0); --! MPS status byte

   -- signals from wf_engine_control
    var_i :          in t_var;                        --! variable received from id_dat   

    data_length_i:   in std_logic_vector(6 downto 0); --! # bytes of Conrol & Data fields of rp_dat
                                                      -- includes 1 byte of rp_dat.Control and
                                                      -- 0-128 bytes of rp_dat.Data
    append_status_i: in std_logic;                    --! acrive if nanoFIP status has to be sent
                                                                 
    add_offset_i :   in std_logic_vector(6 downto 0); --! pointer to message bytes
                                                      -- including rp_dat.Control and rp_dat.Data
   
  -- Outputs
    -- signal to status_gen
    sending_mps_o : out std_logic;                    --!indication: mps byte being sent

    -- signal to wf_tx
    byte_o :         out std_logic_vector(7 downto 0);--! output byte to be serialized and sent

    -- nanoFIP output
    wb_ack_p_o :     out std_logic                     --! wishbone acknowledge
                                                       -- response to master's strobe signal
      );
end entity wf_produced_vars;


--=================================================================================================
--! rtl architecture of wf_produced_vars
--=================================================================================================

architecture rtl of wf_produced_vars is
  constant c_zero : integer := 0;
  signal s_byte: std_logic_vector(7 downto 0);        -- byte to be read from memory
  signal s_mem_byte : std_logic_vector(7 downto 0);   -- byte to be read from memory
  signal s_io_byte : std_logic_vector(7 downto 0);    -- byte to be retreived from Dat_i input bus
  signal s_base_addr, s_addr_A_aux: std_logic_vector(9 downto 0);
  signal s_addr_A : std_logic_vector(8 downto 0); 
  signal s_wb_we : std_logic;
  signal s_byte_adr: integer; 
  signal s_byte_adr_aux: integer range 0 to 15;
   
  
  begin

---------------------------------------------------------------------------------------------------  
-- !@brief synchronous process production_dpram: Instanciation of a "Produced ram"

  production_dpram:  dpblockram_clka_rd_clkb_wr 
  
    generic map (c_data_length => 8,               -- 8 bits: length of data word
                c_addr_length => 9)                -- 2^9: depth of produced ram
                                                   -- first 2 bits: identification of memory block
                                                   --remaining 7: address of a byte inside the blck 
 
    -- port A corresponds to: nanoFIP that reads from the Produced ram & B to: wishbone that writes
    port map (clk_A_i     => uclk_i,	           -- 40 MHz clck
             addr_A_i     => s_addr_A,             -- address of byte to be read from memory
             data_A_o     => s_mem_byte,           -- output byte read
             
             clk_B_i      => wb_clk_i,             -- wishbone clck
             addr_B_i     => wb_adr_i(8 downto 0), -- address of byte to be written to memory
             data_B_i     => wb_data_i(7 downto 0),-- byte to be written
             write_en_B_i => wb_we_p_i             -- wishbone write enable
             );
             
	
    s_addr_A <= (s_addr_A_aux(s_addr_A'range));    -- address of the byte to be read
                                                                                     
    s_addr_A_aux<=std_logic_vector(unsigned(add_offset_i)+unsigned(s_base_addr));

    s_wb_we <=  wb_stb_p_i and wb_we_p_i;          -- write cycle identified & master
                                                   -- is ready to transfer data

  

--------------------------------------------------------------------------------------------------- 
--!@brief synchronous process Generate_wb_ack_p_o: Generation of wb_ack_p_o signal (acknowledgement
-- from wishbone slave of the write cycle)
  
  Generate_wb_ack_p_o: process(wb_clk_i) 
  begin
    if rising_edge(wb_clk_i) then         

      if rst_i = '1' then
        wb_ack_p_o <='0';

      else   

        if wb_adr_i(9 downto 7) = "010" then       -- checking of the 2 first bits of the address,
                                                   -- to confirm that the request to write is on
                                                   -- the "Produced" memory block 

          wb_ack_p_o <= s_wb_we;                   -- slave's indication: prepared to latch data 
 
        else
          wb_ack_p_o <= '0';
        end if;

      end if;
    end if;
  end process;



---------------------------------------------------------------------------------------------------
--!@brief synchronous process Bytes_Generation: Generation of bytes for the Control and Data fields
--! of an rp_dat frame:\n If the variable requested in the id_dat is of "produced" type (id/ 
--! presence/ var3) the process prepares accordingly, one by one, bytes of data to be sent. \n The
--! pointer "add_offset_i" indicates which byte of the frame is to be sent. Some of the bytes are
--! defined in the wf_package, the rest come either from the memory (if slone=0) or from the the
--! wishbone interface.\n The output byte"byte_o"is sent to the transmitter(wf_tx)for serialization
  
  Bytes_Generation: process ( mps_i, var_i, add_offset_i, s_io_byte, m_id_dec_i, s_byte_adr_aux,
                                         s_byte_adr, data_length_i, stat_i, slone_i, c_id_dec_i )
  
  begin
--------------------------------------------------------------------------------------------------- 
    -- signals initializations and essential castings 

    s_byte <= s_mem_byte;                                        -- byte to be sent (byte_o)
    
    s_byte_adr <= to_integer(unsigned(add_offset_i));            -- index of byte to be sent

    s_byte_adr_aux <= (to_integer(unsigned(add_offset_i(3 downto 0))));-- index of byte to be sent
                                                                 --will be used to retreive 
                                                                 -- bytes from the matrix
                                                                 -- c_var_array.byte_array
     	
    s_base_addr <= (others => '0');                              -- specifies the ram block
                                                                 -- corresponding to each variable 

    sending_mps_o <= '0';                                       -- indicates that mps status byte
                                                                -- is being sent


--------------------------------------------------------------------------------------------------- 	     
	-- generation of bytes according to the type of produced var
    case var_i is
    
	-- case: presence variable 
    when c_presence_var =>

      s_byte <= c_var_array(c_presence_var_pos).byte_array(s_byte_adr_aux); 
                                                      -- all the bytes for the rp_dat.Control
                                                      -- and rp_dat.Data fields of the rp_dat
                                                      -- frame to be sent, have been specified
                                                      -- in the c_var_array(0).byte_array matrix
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --      
    
	--case: identification variable  
    when c_identif_var =>

      if s_byte_adr = c_cons_byte_add then            -- moment for the Constructor byte to be sent 
        s_byte(c_id_dec_i'range) <= c_id_dec_i;       -- sending Const[7:0]

      elsif s_byte_adr = c_model_byte_add then        -- moment for the Model byte to be sent
        s_byte(m_id_dec_i'range) <= m_id_dec_i;       -- sending Model[7:0]

      else
        s_byte <= c_var_array(c_identif_var_pos).byte_array(s_byte_adr_aux); -- all the rest of the
                                                      -- bytes (ex. 1st (rp_dat.Control), 2nd (PDU)
                                                      -- etc) are pre-specified in the matrix
                                                      -- c_var_array(c_identif_var_pos).byte_array 	  
      end if;
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
   
    -- case: variable 3 (06h)
    when c_var_3 =>

      s_base_addr <= c_var_array(c_var_3_pos).base_add; --retreival of info for base address in mem 

      if s_byte_adr = 0  then                           -- 1st byte (rp_dat.Control) comes from the
                                                        -- matrix c_var_array
        s_byte <= c_var_array(c_var_3_pos).byte_array(s_byte_adr_aux);

      elsif s_byte_adr = (unsigned(data_length_i) - 1) and nostat_i = '0' then --one but last byte:
        s_byte <= stat_i;                              --nanoFIP status;only sent if nostat negated
 

      elsif s_byte_adr = (unsigned(data_length_i))then -- last byte: mps status 
        s_byte <= mps_i;
        sending_mps_o <= '1';                          -- indication that mps byte is being sent


      elsif slone_i='0' and s_byte_adr = c_pdu_byte_add then           -- in memory mode operation, 
        s_byte <= c_var_array(c_var_3_pos).byte_array(s_byte_adr_aux); -- PDU byte is being sent
                                                                       -- (specified in the matrix
                                                                       -- c_var_array)

      elsif slone_i='0' and s_byte_adr = c_var_length_add then         -- in memory mode operation,
        s_byte <= '0' & data_length_i;                                 -- Length byte is being sent 
                                                                       --(specified in c_var_array)  
 		  
      elsif slone_i='0' and s_byte_adr > c_var_array(c_var_3_pos).array_length then--in memory mode 
        s_byte <= s_mem_byte;                                          -- all the rest of the bytes
                                                                       -- arrive from the momory

      elsif slone_i='1' and s_byte_adr < c_var_array(c_var_3_pos).array_length then-- in standalone
        s_byte <=s_io_byte;                                            -- all the rest of the bytes
                                                                       -- (apart from 1st, nanoFIP/
                                                                       -- mps status) arrive from
                                                                       -- the dat_i(15:0) input bus
                                                                       --2bytes in total to be sent

      else    
        s_byte <= c_var_array(c_var_3_pos).byte_array(s_byte_adr_aux); -- default
      end if;  
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --

    when others =>                                                           

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    end case;		  
  end process;

---------------------------------------------------------------------------------------------------  


  s_io_byte <= wb_data_i(15 downto 8) when add_offset_i(0) = '1' else wb_data_i(7 downto 0);  
                                                                      -- lsb of add_offeset_i
                                                                      -- specifies which byte of
                                                                      --the input bus is to be sent
  
 
---------------------------------------------------------------------------------------------------
 byte_o <= s_byte;                                                    -- output byte

end architecture rtl;
---------------------------------------------------------------------------------------------------
--                                  E N D   O F   F I L E
---------------------------------------------------------------------------------------------------