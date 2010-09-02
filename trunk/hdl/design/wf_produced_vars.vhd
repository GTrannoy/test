--=================================================================================================
--! @file wf_produced_vars.vhd
--=================================================================================================

--! standard library
library IEEE; 

--! standard packages
use IEEE.STD_LOGIC_1164.all;  --! std_logic definitions
use IEEE.NUMERIC_STD.all;     --! conversion functions

--! specific packages
use work.WF_PACKAGE.all;      --! definitions of supplemental types, subtypes, constants

---------------------------------------------------------------------------------------------------
--                                                                                               --
--                                 wf_produced_vars                                              --
--                                                                                               --
--                                  CERN, BE/CO/HT                                               --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
--
--! @brief     After an id_dat frame requesting for a variable to be produced, this unit provides 
--!            to the transmitter (wf_tx) one by one, \n all the bytes of data needed for the  
--!            rp_dat frame (apart from fss, fcs and fes bytes).
--
--
--! @author    Pablo Alvarez Sanchez (pablo.alvarez.sanchez@cern.ch)
--!            Evangelia Gousiou (evangelia.gousiou@cern.ch)
--
--
--! @date      06/2010
--
--
--! @version   v0.02
--
--
--! @details \n  
--
--!   \n<b>Dependencies:</b>\n
--!     status_gen \n
--
--
--!   \n<b>Modified by:</b>\n
--!     Evangelia Gousiou (Evangelia.Gousiou@cern.ch)
--
--------------------------------------------------------------------------------------------------- 
--
--!   \n\n<b>Last changes:</b>\n
--!     -> egousiou: subs_i is not sent in the rp_dat frames  \n
--!     -> egousiou: pdu_type & length bytes not sent in slone \n
--!     -> egousiou: signal s_wb_we includes the wb_stb_r_edge_p_i     \n
--!     -> egousiou: signal s_mem_byte was not in sensitivity list (pablo's varsion)! by adding it,
--!                  changes were essential in the timing of the tx (wf_osc, wf_tx, wf_engine_control
--!                  and the configuration of the memory needed few changes)
--
--------------------------------------------------------------------------------------------------- 
--
--! @todo 
--!   -> Confirm that specs for memory access (var3_rdy) are respected! \n
--
--------------------------------------------------------------------------------------------------- 


--=================================================================================================
--!                           Entity declaration for wf_produced_vars
--=================================================================================================

entity wf_produced_vars is

  port (
  -- INPUTS 
    -- User Interface general signals 
    uclk_i :          in std_logic;                      --! 40MHz clock
    slone_i :         in  std_logic;                     --! stand-alone mode 
    nostat_i :        in  std_logic;                     --! if negated, nFIP status is sent
	
    -- User Interface Wishbone Slave
    wb_rst_i :        in std_logic;                      --! wishbone reset

    wb_clk_i :        in std_logic;                      --! wishbone clock
                                                         -- note: may be indipendant of uclk

    data_i :       in  std_logic_vector (15 downto 0);   --! input data bus
                                                         -- (buffered once with wb_clk)    
                                                         -- in memory mode the 8 LSB are used
                                                         -- as part of the wishbone interface
                                                         -- in slone mode all the bits are used                       

    wb_adr_i :        in  std_logic_vector (9 downto 0);--! wishbone address to memory
                                                        -- (buffered once with wb_clk) 
                                                        -- note: msb allways 0!

    wb_stb_r_edge_p_i : in  std_logic;                    --! wishbone strobe
                                                        -- (buffered once with wb_clk)
                                                        -- note: indication that the 
                                                        -- master is ready to transfer data
                                                      
    wb_we_p_i :       in  std_logic;                    --! wishbone write enable
                                                        -- note: indicates a write cycle of master

    wb_cyc_i :        in std_logic;                     --! wishbone cycle
                                                        -- note:indicates a valid cycle in progress

   -- Signals from wf_engine_control
    var_i :           in t_var;                         --! variable received from id_dat   

    data_length_i:    in std_logic_vector(7 downto 0);  --! # bytes of Conrol&Data fields of rp_dat
                                                        -- includes 1 byte for the rp_dat.Control,
                                                        -- 1 byte for rp_dat.Data.PDU_type,
                                                        -- 1 byte for rp_dat.Data.LENGTH
                                                        -- 0-124 bytes of rp_dat.Data,
                                                        --1 byte for rp_dat.Data.MPS and optionally
                                                        -- 1 byte for rp_dat.Data.nanoFIP_status 

                                                                 
    index_offset_i :    in std_logic_vector(7 downto 0);  --! pointer to message bytes
                                                          -- including rp_dat.Control and rp_dat.Data
	
   -- Signals from status_gen
    nFIP_status_byte_i :   in std_logic_vector(7 downto 0);  --! nanoFIP status byte
    mps_byte_i :      in std_logic_vector(7 downto 0);  --! MPS status byte

    -- Signals from the wf_dec_m_ids unit
    m_id_dec_i :      in  std_logic_vector (7 downto 0); --! model identification settings (decoded)
    c_id_dec_i :      in  std_logic_vector (7 downto 0); --! constructor id settings (decoded)


  -- OUTPUTS
    -- Signal to status_gen
    sending_mps_o :   out std_logic;                    --!indication: mps byte being sent

    -- Signal to wf_tx
    byte_o :          out std_logic_vector(7 downto 0); --! output byte to be serialized and sent

    -- nanoFIP output
    wb_ack_prod_p_o : out std_logic                     --! wishbone acknowledge
                                                        -- response to master's strobe signal
      );
end entity wf_produced_vars;


--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of wf_produced_vars is

  constant c_ZERO : integer := 0;

  signal s_length, s_mem_byte, s_io_byte : std_logic_vector(7 downto 0);       
  signal s_mem_addr_A :                    std_logic_vector(8 downto 0); 
  signal s_index_offset_d1 :               std_logic_vector(7 downto 0);
  signal s_byte_index_aux :                integer range 0 to 15;
  signal s_base_addr, s_mem_addr_offset :  unsigned(8 downto 0);
  signal s_wb_ack_prod_p :                 std_logic;
  signal s_byte_index :                    integer; 

   

--=================================================================================================
--                                      architecture begin
--=================================================================================================  
  begin

---------------------------------------------------------------------------------------------------  
-- !@brief synchronous process production_dpram: Instanciation of a "Produced ram"

  production_dpram:  dpblockram_clka_rd_clkb_wr 
  
    generic map (c_data_length => 8,               -- 8 bits: length of data word
                 c_addr_length => 9)               -- 2^9: depth of produced ram
                                                   -- first 2 bits: identification of memory block
                                                   --remaining 7: address of a byte inside the blck 
 
    -- port A corresponds to: nanoFIP that reads from the Produced ram & B to: wishbone that writes
    port map (clk_A_i     => uclk_i,	           -- 40 MHz clck
             addr_A_i     => s_mem_addr_A,         -- address of byte to be read from memory
             data_A_o     => s_mem_byte,           -- output byte read
             
             clk_B_i      => wb_clk_i,              -- wishbone clck
             addr_B_i     => wb_adr_i(8 downto 0),  -- address of byte to be written
             data_B_i     => data_i(7 downto 0),    -- byte to be written
             write_en_B_i => s_wb_ack_prod_p        -- wishbone write enable ********************
             );
             
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  

    -- address of the byte to be read from memory: base_address(from wf_package) + index_offset_i - 1
    -- (the -1 is because when index_offset_i is on the 4th byte (control, pdu and length have
    -- preceeded and a byte from the memoryis now requested), the 3rd byte from the memory has to
    -- be retreived (in cell 00000010) etc)
    s_mem_addr_A <= std_logic_vector(s_base_addr + s_mem_addr_offset - 1);
                                                                                  
    s_mem_addr_offset <= (resize((unsigned(index_offset_i)), s_mem_addr_offset'length));

                                                                                        
--------------------------------------------------------------------------------------------------- 
--!@brief Generate_wb_ack_prod_p_o: Generation of the wb_ack_prod_p_o signal
--! (acknowledgement from wishbone slave of the write cycle, as a response to the master's storbe).
--! wb_ack_prod_p_o is asserted two wb_clk cycles after the assertion of the input strobe signal 
--! (reminder: stb_i is buffered once in the input stage), if the wishbone input address
--! corresponds to the Produced memory block and the wishbone write enable is asserted.
  
  Generate_wb_ack_prod_p_o: s_wb_ack_prod_p <= '1' when ((wb_stb_r_edge_p_i = '1')    and 
                                                         (wb_adr_i(9 downto 7) = "010") and
                                                         (wb_we_p_i = '1')              and 
                                                         (wb_cyc_i = '1'))
                                            else '0';

  wb_ack_prod_p_o <= s_wb_ack_prod_p;
 
--------------------------------------------------------------------------------------------------- 
--!@brief synchronous process Delay_index_offset_i: in the combinatorial process that follows
--! (Bytes_Generation), according to the value of the signal s_byte_index, a byte is retreived
--! either from the memory, or from the wf_package or from the status_gen or dec_m_ids units.
--! Since the memory needs one clock cycle to output its data the signal s_byte_index has to be a
--! delayed version of the index_offset_i, which is actually the signal used as address for the mem


  Delay_index_offset_i: process(uclk_i) 
  begin
    if rising_edge(uclk_i) then    
    s_index_offset_d1 <= index_offset_i;                    
    end if;
  end process;



---------------------------------------------------------------------------------------------------
--!@brief Combinatorial process Bytes_Generation: Generation of bytes for the Control and Data
--!  fields of an rp_dat frame:\n If the variable requested in the id_dat is of "produced" type(id/ 
--! presence/ var3) the process prepares accordingly, one by one, bytes of data to be sent. \n The
--! pointer "index_offset_i" indicates which byte of the frame is to be sent. Some of the bytes are
--! defined in the wf_package, the rest come either from the memory (if slone=0) or from the the
--! input bus data_i or from the wf_status_gen or wf_dec_m_ids units.\n
--! The output byte "byte_o" is sent to the transmitter(wf_tx)for serialization
   
  Bytes_Generation: process (var_i, s_index_offset_d1, s_byte_index, data_length_i, c_id_dec_i,
                             m_id_dec_i,nFIP_status_byte_i, mps_byte_i, s_io_byte, s_mem_byte,
                                                           slone_i, s_byte_index_aux, nostat_i)
  
  begin
  
    s_byte_index     <= to_integer(unsigned(s_index_offset_d1));
                                                      -- index of byte to be sent

    s_byte_index_aux <= (to_integer(unsigned(s_index_offset_d1(3 downto 0))));
                                                      -- index of byte to be sent(range restricted)
                                                      -- used to retreive bytes from the matrix
                                                      -- c_VARS_ARRAY.byte_array, with a predefined
                                                      -- width of 15 bytes
  
    s_length         <= std_logic_vector(resize((unsigned(data_length_i)-2),byte_o'length));   
                                                      --signal used for the rp_dat.Data.LENGTH byte
                                                      -- it represents the # bytes of "pure data"
                                                      -- (P3_LGTH) plus 1 byte of rp_dat.Data.MPS
                                                      -- plus 1 byte of rp_dat.Data.nanoFIP_status,
                                                      -- if applicable  


     	
    --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --      
    -- generation of bytes according to the type of produced var
    case var_i is

    
	-- case: presence variable 
    -- all the bytes for the rp_dat.Control and rp_dat.Data fields of the rp_dat frame to be sent,
    -- are predefined in the c_VARS_ARRAY(0).byte_array matrix
    when presence_var =>

      byte_o         <= c_VARS_ARRAY(c_PRESENCE_VAR_INDEX).byte_array(s_byte_index_aux);
 
      s_base_addr    <= (others => '0');     
      sending_mps_o  <= '0';                                                         

    --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --     

    
	--case: identification variable
    -- The Constructor and Model bytes of the identification variable arrive from the decoding unit
    -- (wf_dec_m_ids), wereas all the rest are predefined in the c_VARS_ARRAY matrix 
  
    when identif_var =>

      if s_byte_index = c_CONSTR_BYTE_INDEX then       
        byte_o       <= c_id_dec_i;       

      elsif s_byte_index = c_MODEL_BYTE_INDEX then      
        byte_o       <= m_id_dec_i;      

      else
        byte_o       <= c_VARS_ARRAY(c_IDENTIF_VAR_INDEX).byte_array(s_byte_index_aux);  	  
      end if;

      s_base_addr    <= (others => '0'); 
      sending_mps_o  <= '0';

    --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 

   
    -- case: variable 3 (06h)
    -- For a var3 there is a separation according to the operational mode (stand-alone or memory)
    -- In general, few of the bytes are predefined in the c_VARS_ARRAY matrix, wereas the rest come
    -- either from the memory or from the data_i bus or from status_generator unit (wf_status_gen) 

    when var_3 =>

      ---------------------------------------------------------------------------------------------
      -- In memory mode:
      if slone_i = '0' then

        s_base_addr  <= c_VARS_ARRAY(c_VAR_3_INDEX).base_add; --retreival of info for mem base address 

        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --         
        -- The first (rp_dat.Control) and second (PDU type) bytes to be sent 
        -- are predefined in the c_VARS_ARRAY matrix of the wf_package 

        if s_byte_index <= c_VARS_ARRAY(c_VAR_3_INDEX).array_length  then -- less than or equal to                         
          byte_o        <= c_VARS_ARRAY(c_VAR_3_INDEX).byte_array(s_byte_index_aux);
          sending_mps_o <= '0'; 
       
        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
        -- The c_LENGTH_BYTE_INDEX byte is the Length

        elsif s_byte_index = c_LENGTH_BYTE_INDEX then       
          byte_o        <= s_length;                                              
          sending_mps_o <= '0';

        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
        -- The one but last byte if the input nostat_i is negated is the nanoFIP status byte
        -- (if nostat_i is not negated, the "else" condition takes place) 

        elsif s_byte_index = (unsigned(data_length_i)-1 ) and nostat_i = '0' then 
          byte_o        <= nFIP_status_byte_i;                            
          sending_mps_o <= '0'; 

        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
        -- The last byte is the MPS status
        elsif s_byte_index = (unsigned(data_length_i))then    
          byte_o        <= mps_byte_i;
          sending_mps_o <= '1';                       -- indication: MPS byte is being sent
    
        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 		  
      -- The rest of the bytes come from the memory
        else
          byte_o        <= s_mem_byte;                                         
          sending_mps_o <= '0'; 

        end if;

      --------------------------------------------------------------------------------------------- 
      -- In standalone mode:
      else

        s_base_addr     <= (others => '0');            -- no access in memory needed

        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --      
        -- The first byte to be sent is the rp_dat.Control, which is
        -- predefined in the c_VARS_ARRAY matrix of the wf_package 

        if s_byte_index = 0  then                             
          byte_o        <= c_VARS_ARRAY(c_VAR_3_INDEX).byte_array(s_byte_index_aux);
          sending_mps_o <= '0'; 
       
        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
        -- The one but last byte if the input nostat_i is negated is the nanoFIP status byte
        -- (if nostat_i is not negated, the "else" condition takes place) 

        elsif s_byte_index = (unsigned(data_length_i)-1 ) and nostat_i = '0' then 
          byte_o        <= nFIP_status_byte_i;                            
          sending_mps_o <= '0'; 

        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
        -- The last byte is the MPS status
        elsif s_byte_index = (unsigned(data_length_i))then    
          byte_o        <= mps_byte_i;
          sending_mps_o <= '1';                       -- indication: MPS byte is being sent
    
        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 		  
        -- The rest of the bytes come from the input bus data_i(15:0)

        else
          byte_o        <= s_io_byte;                                    
          sending_mps_o <= '0';

        end if;
      end if;
    --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --

    when others =>    
      sending_mps_o     <= '0';
      byte_o            <= (others => '0');                                   
      s_base_addr       <= (others => '0');                           
                                     
    end case;		  
  end process;

---------------------------------------------------------------------------------------------------  
-- In stand-alone mode 2 bytes of "pure" data have to sent in total (other bytes to be sent: Control
-- mps and nFIP status bytes). The first data byte after the rp_dat.Control is retreived from the 
-- input bus data_i(7:0) and the second from the data_i(15:8)

  s_io_byte <= data_i(7 downto 0) when index_offset_i(0) = '1' else data_i(15 downto 8);  
                                                                         


end architecture rtl;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------