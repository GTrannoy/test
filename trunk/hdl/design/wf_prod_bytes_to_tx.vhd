---------------------------------------------------------------------------------------------------
--! @file WF_prod_bytes_to_tx.vhd
---------------------------------------------------------------------------------------------------

--! standard library
library IEEE; 

--! standard packages
use IEEE.STD_LOGIC_1164.all;  --! std_logic definitions
use IEEE.NUMERIC_STD.all;     --! conversion functions

--! specific packages
use work.WF_PACKAGE.all;      --! definitions of supplemental types, subtypes, constants

---------------------------------------------------------------------------------------------------
--                                                                                               --
--                                 WF_prod_bytes_to_tx                                           --
--                                                                                               --
--                                  CERN, BE/CO/HT                                               --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
--
--! @brief     After an id_dat frame requesting for a variable to be produced, this unit provides 
--!            to the transmitter (WF_tx) one by one, \n all the bytes of data needed for the  
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
--!     WF_status_bytes_gen \n
--
--
--!   \n<b>Modified by:</b>\n
--!     Evangelia Gousiou (Evangelia.Gousiou@cern.ch)
--
--------------------------------------------------------------------------------------------------- 
--
--!   \n\n<b>Last changes:</b>\n
--!     -> egousiou: subs_i is not sent in the rp_dat frames  \n
--!     -> egousiou: signal s_wb_we includes the wb_stb_r_edge_p_i     \n
--!     -> egousiou: signal s_mem_byte was not in sensitivity list in v0.01! by adding it,
--!                  changes were essential in the timing of the tx (WF_osc, WF_tx,
--!                  WF_engine_control and the configuration of the memory needed few changes)
--
--------------------------------------------------------------------------------------------------- 
--
--! @todo 
--!   
--
--------------------------------------------------------------------------------------------------- 


--=================================================================================================
--!                           Entity declaration for WF_prod_bytes_to_tx
--=================================================================================================

entity WF_prod_bytes_to_tx is

  port (
  -- INPUTS 
    -- User Interface general signals (synchronized) 
    uclk_i :          in std_logic;                      --! 40MHz clock
    slone_i :         in  std_logic;                     --! stand-alone mode 
    nostat_i :        in  std_logic;                     --! if negated, nFIP status is sent

    -- Signal from the WF_reset_unit unit
    nFIP_urst_i :      in std_logic;                      --! internal reset
	
    -- User Interface WISHBONE Slave

    wb_clk_i :        in std_logic;                      --! WISHBONE clock
                                                         -- note: may be indipendant of uclk

    wb_data_i :       in  std_logic_vector (7 downto 0); --! WISHBONE data bus

    wb_adr_i :        in  std_logic_vector (9 downto 0); --! WISHBONE address to memory
                                                         -- note: msb allways 0!

    wb_stb_r_edge_p_i : in  std_logic;                   --! WISHBONE strobe
                                                         -- (buffered once with wb_clk)
                                                         -- note: indication that the 
                                                         -- master is ready to transfer data
                                                      
    wb_we_p_i :       in  std_logic;                    --! WISHBONE write enable
                                                        -- note: indicates a write cycle of master

    wb_cyc_i :        in std_logic;                     --! WISHBONE cycle
                                                        -- note:indicates a valid cycle in progress


    -- User Interface Non WISHBONE
    slone_data_i :    in  std_logic_vector (15 downto 0);--! input data bus for slone mode
                                                         -- (buffered twice with uclk)   


   -- Signals from WF_engine_control
    var_i :           in t_var;                         --! variable received from id_dat   

    data_length_i:    in std_logic_vector (7 downto 0);  --! # bytes of Conrol&Data fields of rp_dat
                                                        -- includes 1 byte for the rp_dat.Control,
                                                        -- 1 byte for rp_dat.Data.PDU_type,
                                                        -- 1 byte for rp_dat.Data.LENGTH
                                                        -- 0-124 bytes of rp_dat.Data,
                                                        --1 byte for rp_dat.Data.MPS and optionally
                                                        -- 1 byte for rp_dat.Data.nanoFIP_status 

                                                                 
    byte_index_i :    in std_logic_vector (7 downto 0);  --! pointer to message bytes
                                                         -- includes rp_dat.Control and rp_dat.Data
    var3_rdy_i :      in std_logic;
	
   -- Signals from WF_status_bytes_gen
    nFIP_status_byte_i :   in std_logic_vector (7 downto 0);  --! nanoFIP status byte
    mps_status_byte_i :    in std_logic_vector (7 downto 0);  --! MPS status byte

    -- Signals from the WF_model_constr_decoder unit
    m_id_dec_i :      in  std_logic_vector (7 downto 0); --! model identification settings (decoded)
    c_id_dec_i :      in  std_logic_vector (7 downto 0); --! constructor id settings (decoded)


  -- OUTPUTS
    -- Signal to WF_status_bytes_gen
    sending_mps_o :   out std_logic;                    --!indication: mps byte being sent

    -- Signal to WF_tx
    byte_o :          out std_logic_vector (7 downto 0); --! output byte to be serialized and sent

    -- nanoFIP output
    wb_ack_prod_p_o : out std_logic                     --! WISHBONE acknowledge
                                                        -- response to master's strobe signal
      );
end entity WF_prod_bytes_to_tx;


--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of WF_prod_bytes_to_tx is

  signal s_wb_ack_prod_p :                   std_logic;
  signal s_base_addr, s_mem_addr_offset :    unsigned(8 downto 0);
  signal s_byte_index_aux :                  integer range 0 to 15;
  signal s_mem_wr_en_B_d3 :                  std_logic_vector (2 downto 0);
  signal s_length, s_mem_byte, s_slone_byte: std_logic_vector (7 downto 0);
  signal s_byte_index :                      std_logic_vector (7 downto 0);       
  signal s_mem_addr_A :                      std_logic_vector (8 downto 0);
  

--=================================================================================================
--                                      architecture begin
--=================================================================================================  
  begin

---------------------------------------------------------------------------------------------------
-- !@brief Instantiation of the Data Sampler unit for the sampling of the input data bus DAT(15:0)
--! on the stand-alone operation. The sampling takes place on the 1st clock cycle after the
--! VAR3_RDY has been deasserted.

  Slone_Data_Sampler:  WF_slone_DATI_bytes_sampler
    port map( uclk_i       => uclk_i,
              nFIP_urst_i   => nFIP_urst_i,
              slone_data_i => slone_data_i,
              var3_rdy_i   => var3_rdy_i,
              byte_index_i => byte_index_i, 
              slone_byte_o => s_slone_byte
            );

---------------------------------------------------------------------------------------------------  
-- !@brief Instantiation of a "Produced ram"

  production_dpram:  WF_DualClkRAM_clka_rd_clkb_wr 
  
    generic map (C_RAM_DATA_LGTH => 8,               -- 8 bits: length of data word
                 C_RAM_ADDR_LGTH => 9)               -- 2^9: depth of produced ram
                                                   -- first 2 bits: identification of memory block
                                                   --remaining 7: address of a byte inside the blck 
 
    -- port A corresponds to: nanoFIP that reads from the Produced ram & B to: WISHBONE that writes
    port map (clk_A_i     => uclk_i,	           -- 40 MHz clck
             addr_A_i     => s_mem_addr_A,         -- address of byte to be read from memory
             data_A_o     => s_mem_byte,           -- output byte read
             
             clk_B_i      => wb_clk_i,             -- WISHBONE clck
             addr_B_i     => wb_adr_i (8 downto 0),-- address of byte to be written
             data_B_i     => wb_data_i,            -- byte to be written
             write_en_B_i => s_mem_wr_en_B_d3(2)   -- WISHBONE write enable
             );
             

---------------------------------------------------------------------------------------------------
--!@brief Combinatorial process Bytes_Generation: Generation of bytes for the Control and Data
--!  fields of an rp_dat frame:\n If the variable requested in the id_dat is of "produced" type(id/ 
--! presence/ var3) the process prepares accordingly, one by one, bytes of data to be sent. \n The
--! pointer "byte_index_i" indicates which byte of the frame is to be sent. Some of the bytes are
--! defined in the WF_package, the rest come either from the memory (if slone=0) or from the the
--! input bus data_i or from the WF_status_gen or WF_model_constr_decoder units.\n
--! The output byte "byte_o" is sent to the transmitter(WF_tx)for serialization
   
  Bytes_Generation: process (var_i, s_byte_index, data_length_i, c_id_dec_i, m_id_dec_i,
                             nFIP_status_byte_i, mps_status_byte_i, s_slone_byte, s_length, 
                             s_mem_byte, slone_i, s_byte_index_aux, nostat_i, s_byte_index_aux)
  
  begin
  
    --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --      
    -- generation of bytes according to the type of produced var
    case var_i is

    
	-- case: presence variable 
    -- all the bytes for the rp_dat.Control and rp_dat.Data fields of the rp_dat frame to be sent,
    -- are predefined in the c_VARS_ARRAY(0).byte_array matrix
    when var_presence =>

      byte_o         <= c_VARS_ARRAY(c_VAR_PRESENCE_INDEX).byte_array(s_byte_index_aux);
 
      s_base_addr    <= (others => '0');     
      sending_mps_o  <= '0';                                                         

    --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --     

    
	--case: identification variable
    -- The Constructor and Model bytes of the identification variable arrive from the decoding unit
    -- (WF_model_constr_decoder), wereas all the rest are predefined in the c_VARS_ARRAY matrix 
  
    when var_identif =>

      if s_byte_index = c_CONSTR_BYTE_INDEX then       
        byte_o       <= c_id_dec_i;       

      elsif s_byte_index = c_MODEL_BYTE_INDEX then      
        byte_o       <= m_id_dec_i;      

      else
        byte_o       <= c_VARS_ARRAY(c_VAR_IDENTIF_INDEX).byte_array(s_byte_index_aux);  	  
      end if;

      s_base_addr    <= (others => '0'); 
      sending_mps_o  <= '0';

    --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 

   
    -- case: variable 3 (06h)
    -- For a var3 there is a separation according to the operational mode (stand-alone or memory)
    -- In general, few of the bytes are predefined in the c_VARS_ARRAY matrix, wereas the rest come
    -- either from the memory or from the data_i bus or from status_generator unit (WF_status_gen) 

    when var_3 =>

      ---------------------------------------------------------------------------------------------
      -- In memory mode:
      if slone_i = '0' then

        s_base_addr  <= c_VARS_ARRAY(c_VAR_3_INDEX).base_addr; --retreival of info for mem base address 

        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --         
        -- The first (rp_dat.Control) and second (PDU type) bytes to be sent 
        -- are predefined in the c_VARS_ARRAY matrix of the WF_package 

        if unsigned(s_byte_index) <= c_VARS_ARRAY(c_VAR_3_INDEX).array_length  then                    
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

        elsif (unsigned(s_byte_index) = (unsigned(data_length_i)-1 )) and nostat_i = '0' then
          byte_o        <= nFIP_status_byte_i;                            
          sending_mps_o <= '0'; 

        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
        -- The last byte is the MPS status
        elsif s_byte_index = (data_length_i)  then    
          byte_o        <= mps_status_byte_i;
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
        -- The first (rp_dat.Control) and second (PDU type) bytes to be sent 
        -- are predefined in the c_VARS_ARRAY matrix of the WF_package

        if unsigned(s_byte_index) <= c_VARS_ARRAY(c_VAR_3_INDEX).array_length then -- less equal than                             
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

        elsif unsigned(s_byte_index) = (unsigned(data_length_i)-1 ) and nostat_i = '0' then 
          byte_o        <= nFIP_status_byte_i;                            
          sending_mps_o <= '0'; 

        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
        -- The last byte is the MPS status
        elsif s_byte_index = data_length_i then    
          byte_o        <= mps_status_byte_i;
          sending_mps_o <= '1';                       -- indication: MPS byte is being sent
    
        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 		  
        -- The rest of the bytes come from the input bus data_i(15:0)

        else
          byte_o        <= s_slone_byte;                                    
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
--!@brief Generate_wb_ack_prod_p_o: Generation of the wb_ack_prod_p_o signal
--! (acknowledgement from WISHBONE slave of the write cycle, as a response to the master's storbe).
--! wb_ack_prod_p_o is asserted two wb_clk cycles after the assertion of the input strobe signal 
--! (reminder: stb_i is buffered once in the input stage), if the WISHBONE input address
--! corresponds to the Produced memory block and the WISHBONE write enable is asserted.
  
  Generate_wb_ack_prod_p_o: s_wb_ack_prod_p <= '1' when ((wb_stb_r_edge_p_i = '1')      and 
                                                         (wb_adr_i(9 downto 7) = "010") and
                                                         (wb_we_p_i = '1')              and 
                                                         (wb_cyc_i = '1'))
                                          else '0';

  wb_ack_prod_p_o <= s_wb_ack_prod_p;


--------------------------------------------------------------------------------------------------- 
-- auxiliary signals generation:

  -- address of the byte to be read from memory: base_address(from WF_package) + byte_index_i - 1
  -- (the -1 is because when byte_index_i is on the 4th byte (control, pdu and length have
  -- preceeded and a byte from the memory is now requested), the 3rd byte from the memory has to
  -- be retrieved (in cell 00000010) etc)
  s_mem_addr_A      <= std_logic_vector (s_base_addr + s_mem_addr_offset - 1);
                                                                                  
  s_mem_addr_offset <= (resize((unsigned(byte_index_i)), s_mem_addr_offset'length));

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  

  s_byte_index_aux <= (to_integer(unsigned(s_byte_index(3 downto 0))));
                                                      -- index of byte to be sent(range restricted)
                                                      -- used to retreive bytes from the matrix
                                                      -- c_VARS_ARRAY.byte_array, with a predefined
                                                      -- width of 15 bytes
  
  s_length         <= std_logic_vector (resize((unsigned(data_length_i)-2),byte_o'length));   
                                                      --signal used for the rp_dat.Data.LENGTH byte
                                                      -- it represents the # bytes of user-data
                                                      -- (P3_LGTH) plus 1 byte of rp_dat.Data.MPS
                                                      -- plus 1 byte of rp_dat.Data.nanoFIP_status,
                                                      -- if applicable  


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  

  --!synchronous process Delay_mem_wr_en_and_addr: since the input buses wb_data_i and 
  --! wb_addr_i are the triply buffered versions of the DAT_I and ADR_I, the signal wb_write_enable
  --! has to be delayed too.
  Delay_mem_wr_en_and_addr: process(wb_clk_i) 
  begin
    if rising_edge(wb_clk_i) then
      s_mem_wr_en_B_d3 <= s_mem_wr_en_B_d3(1 downto 0) & s_wb_ack_prod_p ;
    end if;
  end process;

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
  --! synchronous process Delay_index_offset_i: in the combinatorial process Bytes_Generation,
  --! according to the value of the signal s_byte_index, a byte is retrieved either from the memory,
  --! or from the WF_package or from the WF_status_bytes_gen or dec_m_ids units.
  --! Since the memory needs one clock cycle to output its data the signal s_byte_index has to be a
  --! delayed version of the byte_index_i (byte_index_i is the signal used as address for the mem)

  Delay_index_offset_i: process(uclk_i) 
  begin
    if rising_edge(uclk_i) then
      if nFIP_urst_i = '1' then
        s_byte_index <= (others=> '0');          
      else  

        s_byte_index <= byte_index_i;   -- index of byte to be sent                
      end if;
    end if;
  end process;
---------------------------------------------------------------------------------------------------

end architecture rtl;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------