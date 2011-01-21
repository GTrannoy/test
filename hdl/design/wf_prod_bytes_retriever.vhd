--_________________________________________________________________________________________________
--                                                                                                |
--                                        |The nanoFIP|                                           |
--                                                                                                |
--                                        CERN,BE/CO-HT                                           |
--________________________________________________________________________________________________|
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--! @file WF_prod_bytes_retriever.vhd
---------------------------------------------------------------------------------------------------

--! standard library
library IEEE; 

--! standard packages
use IEEE.STD_LOGIC_1164.all;  --! std_logic definitions
use IEEE.NUMERIC_STD.all;     --! conversion functions

--! specific packages
use work.WF_PACKAGE.all;      --! definitions of types, constants, entities

---------------------------------------------------------------------------------------------------
--                                                                                               --
--                                      WF_prod_bytes_retriever                                  --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
--
--! @brief     After an ID_DAT frame requesting for a variable to be produced, the unit provides 
--!            to the WF_tx_serializer unit one by one, \n all the bytes of data needed for the  
--!            RP_DAT frame (apart from the  FSS, FCS and FES bytes). The coordination of the
--!            retreival is done through the WF_engine_control and the signal byte_index_i.
--!
--!            General structure of a produced RP_DAT frame :
--!    ___________ ______  _______ ______ _________________ _______ _______  ___________ _______
--!   |____FSS____|_Ctrl_||__PDU__|_LGTH_|_...User-Data..._|_nstat_|__MPS__||____FCS____|__FES__|
--!
--!            Data provided by the this unit (nstat & MPS, only if applicable) :
--!                ______  _______ ______ ________________________________________ _______ _______  
--!               |_Ctrl_||__PDU__|_LGTH_|_____________..User-Data..______________|_nstat_|__MPS__||
--!
--!            If the variable to be produced is the
--!              o presence       : the unit retreives the bytes from the WF_package.
--!                                 Note: No MPS & no nanoFIP status associated with this variable.
--!                ______  _______ ______ ______ ______ ______ ______ ______ 
--!               |_Ctrl_||__PDU__|__05__|__80__|__03__|__00__|__F0__|__00__||
--!
--!                               
--!              o identification : the unit retreives the Constructor & Model bytes from the
--!                                 WF_model_constr_decoder, and all the rest from the WF_package.
--!                                 Note: No MPS & no nanoFIP status associated with this variable.
--!                ______  _______ ______ ______ ______ ______ ______ _______ ______ ______ ______
--!               |_Ctrl_||__PDU__|__08__|__01__|__00__|__00__|_cons_|__mod__|__00__|__00__|__00__||
--!
--!
--!              o var_3          : if the operation is in stand-alone mode, the unit retreives the
--!                                 user-data bytes from the "nanoFIP User Interface, NON_WISHBONE"
--!                                 bus DAT_I.
--!                                 If the operation is in memory mode, it retreives them from the
--!                                 Produced RAM.
--!                                 The unit retreives the MPS and nanoFIP status bytes from the
--!                                 WF_status_bytes_gen, and the LGTH byte from the
--!                                 WF_prod_data_lgth_calc (in the WF_engine_control). The
--!                                 rest of the bytes (Ctrl & PDU) come from the WF_package.
--!                ______  _______ ______ ________________________________________ _______ _______  
--!               |_Ctrl_||__PDU__|_LGTH_|_____________..User-Data..______________|_nstat_|__MPS__||
--
--
--! @author    Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)
--!            Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)
--
--
--! @date      04/01/2011
--
--
--! @version   v0.05
--
--
--! @details \n  
--
--!   \n<b>Dependencies:</b>\n
--!            WF_reset_unit       \n
--!            WF_engine_control   \n
--!            WF_prod_permit      \n
--!            WF_status_bytes_gen \n
--!            WF_model_constr_dec \n
--
--------------------------------------------------------------------------------------------------- 
--
--!   \n<b>Modified by:</b>\n
--!     Evangelia Gousiou (Evangelia.Gousiou@cern.ch)
--
--
--!   \n\n<b>Last changes:</b>\n
--!     -> 06/2010  v0.02  EG  subs_i is not sent in the RP_DAT frames 
--!                            signal s_wb_we includes the wb_stb_r_edge_p_i
--!                            cleaner structure
--!     -> 06/2010  v0.03  EG  signal s_mem_byte was not in sensitivity list in v0.01! by adding it
--!                            changes were essential in the timing of the tx (WF_osc, WF_tx,
--!                            WF_engine_control and the configuration of the memory needed changes)
--!     -> 11/2010  v0.04  EG  for simplification, new unit Slone_Data_Sampler created
--!     -> 4/1/2011 v0.05  EG  unit renamed from WF_prod_bytes_to_tx to WF_prod_bytes_retriever;
--!                            input byte_being_sent_p_i added, so that the reseting of status bytes
--!                            does not pass from the engine; clening-up+commenting
--
--
---------------------------------------------------------------------------------------------------
--
--! @todo 
--! ->  
--
--------------------------------------------------------------------------------------------------- 

---/!\----------------------------/!\----------------------------/!\-------------------------/!\---
--                               Sunplify Premier D-2009.12 Warnings                             --
-- -- --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --
-- "W CL246  Input port bits 0, 1, 3, 4 of var_i(0 to 6) are unused"                             --
-- var_i is one-hot encoded and has 7 values.                                                    -- 
-- The unit is treating only the produced variables presence, identification and var_3.          --
---------------------------------------------------------------------------------------------------


--=================================================================================================
--!                           Entity declaration for WF_prod_bytes_retriever
--=================================================================================================

entity WF_prod_bytes_retriever is

  port (
  -- INPUTS 
    -- nanoFIP User Interface, General signals (synchronized with uclk) 
    uclk_i               : in std_logic;                     --! 40MHz clock
    nostat_i             : in std_logic;                     --! if negated, nFIP status is sent
    slone_i              : in std_logic;                     --! stand-alone mode 

    -- Signal from the WF_reset_unit
    nfip_rst_i           : in std_logic;                     --! nanoFIP internal reset
	
    -- nanoFIP User Interface, WISHBONE Slave
    wb_clk_i             : in std_logic;                     --! WISHBONE clock
    wb_adr_i             : in std_logic_vector(8 downto 0);  --! WISHBONE address to memory
    wb_data_i            : in std_logic_vector(7 downto 0);  --! WISHBONE data bus

    -- Signal from the WF_wb_controller
    wb_ack_prod_p_i      : in std_logic;                     --! WISHBONE acknowledge
                                                             --  latching moment of wb_data_i

    -- nanoFIP User Interface, NON WISHBONE (synchronized with uclk)
    slone_data_i         : in std_logic_vector(15 downto 0); --! input data bus for slone mode

    -- Signals from the WF_engine_control unit
    byte_index_i         : in std_logic_vector(7 downto 0);  --!index of the byte to be retrieved

    byte_being_sent_p_i  : in std_logic;                     --! indication that a byte is ready
                                                             --! to be delivered  

    data_length_i        : in std_logic_vector(7 downto 0);  --! # bytes of the Conrol&Data fields
                                                             -- of the RP_DAT frame; includes:
                                                             -- 1 byte RP_DAT.Control,
                                                             -- 1 byte RP_DAT.Data.PDU_type,
                                                             -- 1 byte RP_DAT.Data.LENGTH
                                                             -- 0-124 bytes of RP_DAT.Data,
                                                             -- 1 byte RP_DAT.Data.MPS_status &
                                                             -- optionally 1 byte for the 
                                                             -- RP_DAT.Data.nanoFIP_status 

                                                                 
    var_i                : in t_var;                         --!variable type that is being treated

    -- Signals from the WF_prod_permit	
    var3_rdy_i           : in std_logic;                     --! nanoFIP output VAR3_RDY  

    -- Signals from the WF_status_bytes_gen
    mps_status_byte_i    : in std_logic_vector(7 downto 0);  --! MPS status byte
    nFIP_status_byte_i   : in std_logic_vector(7 downto 0);  --! nanoFIP status byte

    -- Signals from the WF_model_constr_dec unit
    constr_id_dec_i      : in  std_logic_vector(7 downto 0); --! decoded constructor id settings
    model_id_dec_i       : in  std_logic_vector(7 downto 0); --! decoded model id settings


  -- OUTPUTS
    -- Signal to the WF_status_bytes_gen
    rst_status_bytes_p_o : out std_logic;                    --! reset for the nanoFIP&MPS status
                                                             --! status bytes.It is activated after
                                                             --! the delivery of the last one (MPS)

    -- Signal to the WF_tx_serializer
    byte_o               : out std_logic_vector(7 downto 0)  --! output byte to be serialized

      );
end entity WF_prod_bytes_retriever;


--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of WF_prod_bytes_retriever is

  signal s_base_addr, s_mem_addr_offset        : unsigned(8 downto 0);
  signal s_byte_index_aux                      : integer range 0 to 15;
  signal s_lgth_byte, s_mem_byte, s_slone_byte : std_logic_vector (7 downto 0);
  signal s_byte_index                          : std_logic_vector (7 downto 0);       
  signal s_mem_addr_A                          : std_logic_vector (8 downto 0);
  

--=================================================================================================
--                                      architecture begin
--=================================================================================================  
begin


---------------------------------------------------------------------------------------------------
--                                          Produced RAM                                         --
--                    Storage (by the user) & retreival (by the unit) of produced bytes          --
--------------------------------------------------------------------------------------------------- 
--!@brief Instantiation of a Produced Dual Port RAM

    Produced_Bytes_From_RAM:  WF_DualClkRAM_clka_rd_clkb_wr 
    generic map(
      c_RAM_DATA_LGTH => 8,                 -- 8 bits: length of data word
      c_RAM_ADDR_LGTH => 9)                 -- 2^9: depth of produced ram
                                            -- first 2 bits : identification of memory block
                                            -- remaining 7  : address of a byte inside the blck 
    -- port A corresponds to: nanoFIP that reads from the Produced ram & B to: WISHBONE that writes
    port map(
      clk_porta_i      => uclk_i,	            -- 40 MHz clock
      addr_porta_i     => s_mem_addr_A,         -- address of byte to be read from memory
      ------------------------------------------------------------------------------------
      data_porta_o     => s_mem_byte,           -- output byte read
      ------------------------------------------------------------------------------------
      clk_portb_i      => wb_clk_i,             -- WISHBONE clock
      addr_portb_i     => wb_adr_i (8 downto 0),-- address of byte to be written
      data_portb_i     => wb_data_i,            -- byte to be written
      write_en_portb_i => wb_ack_prod_p_i);     -- WISHBONE write enable
             


---------------------------------------------------------------------------------------------------
--                                   Produced bytes from DAT_I                                   --
---------------------------------------------------------------------------------------------------
--!@brief Instantiation of the unit that in stand-alone mode is responsible for the sampling of the
--! input data bus DAT_I(15:0). The sampling takes place on the 1st clock cycle after the VAR3_RDY
--! has been de-asserted.

    Produced_Bytes_From_DATI: WF_prod_bytes_from_dati
    port map(
      uclk_i       => uclk_i,
      nfip_rst_i   => nfip_rst_i,
      slone_data_i => slone_data_i,
      var3_rdy_i   => var3_rdy_i,
      byte_index_i => byte_index_i, 
      ------------------------------
      slone_byte_o => s_slone_byte);
      ------------------------------



---------------------------------------------------------------------------------------------------
--                                          Bytes Retreival                                      --
---------------------------------------------------------------------------------------------------
--!@brief Combinatorial process Bytes_Generation: Generation of bytes for the Control and Data
--! fields of an RP_DAT frame:\n If the variable requested in the ID_DAT is of "produced" type 
--! (identification/ presence/ var3) the process prepares accordingly, one by one, bytes of data
--! to be sent. \n The pointer "s_byte_index" (or "s_byte_index_aux") indicates which byte of the 
--! frame is to be sent. Some of the bytes are defined in the WF_package, the rest come either from 
--! the memory (if slone = 0) or from the the input bus data_i (if slone = 1) or from the
--! WF_status_bytes_gen or the WF_model_constr_decoder units.\n The output byte "byte_o" is sent to
--! the WF_tx_serializer unit for manchester encoding and serialization.
   
  Bytes_Generation: process (var_i, s_byte_index, data_length_i, constr_id_dec_i, model_id_dec_i, 
                             nFIP_status_byte_i, mps_status_byte_i, s_slone_byte, s_byte_index_aux,
                             s_mem_byte, s_byte_index_aux, nostat_i, byte_being_sent_p_i, 
                             s_lgth_byte, slone_i)
  
  begin
  
    --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --      
    -- generation of bytes according to the type of produced var:
    case var_i is

    
	-- case: presence variable 
    -- all the bytes for the RP_DAT.Control and RP_DAT.Data fields of the RP_DAT frame to be sent,
    -- are predefined in the c_VARS_ARRAY matrix.
    when var_presence =>

      byte_o         <= c_VARS_ARRAY(c_VAR_PRESENCE_INDEX).byte_array(s_byte_index_aux);
 
      s_base_addr    <= (others => '0');     
      rst_status_bytes_p_o  <= '0';                                                         

    --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --     

    
	-- case: identification variable
    -- The Constructor and Model bytes of the identification variable arrive from the
    -- WF_model_constr_decoder, wereas all the rest are predefined in the c_VARS_ARRAY matrix. 
    when var_identif =>

      if s_byte_index = c_CONSTR_BYTE_INDEX then       
        byte_o       <= constr_id_dec_i;       

      elsif s_byte_index = c_MODEL_BYTE_INDEX then      
        byte_o       <= model_id_dec_i;      

      else
        byte_o       <= c_VARS_ARRAY(c_VAR_IDENTIF_INDEX).byte_array(s_byte_index_aux);  	  
      end if;

      s_base_addr    <= (others => '0'); 
      rst_status_bytes_p_o  <= '0';

    --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 

   
    -- case: variable 3 (06h)
    -- For a var3 there is a separation according to the operational mode (stand-alone or memory)
    -- In general, few of the bytes are predefined in the c_VARS_ARRAY matrix, wereas the rest come
    -- either from the memory/ data_i bus or from status_generator unit (WF_status_gen). 
    when var_3 =>

      ---------------------------------------------------------------------------------------------
      -- In memory mode:
      if slone_i = '0' then

        -- retreival of base address info for the memory from the WF_package
        s_base_addr            <= c_VARS_ARRAY(c_VAR_3_INDEX).base_addr; 
                               

        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --         
        -- The first (Control) and second (PDU_TYPE) bytes to be sent 
        -- are predefined in the c_VARS_ARRAY matrix of the WF_package 

        if unsigned(s_byte_index) <= c_VARS_ARRAY(c_VAR_3_INDEX).array_length  then  -- less or eq                   
          byte_o               <= c_VARS_ARRAY(c_VAR_3_INDEX).byte_array(s_byte_index_aux);
          rst_status_bytes_p_o <= '0'; 
       
        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
        -- The c_LENGTH_BYTE_INDEX byte is the Length

        elsif s_byte_index = c_LENGTH_BYTE_INDEX then       
          byte_o               <= s_lgth_byte;                                              
          rst_status_bytes_p_o <= '0';

        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
        -- The one but last byte if the input nostat_i is negated is the nanoFIP status byte
        -- (if nostat_i is not negated, the "else" condition takes place) 

        elsif (unsigned(s_byte_index) = (unsigned(data_length_i)-1 )) and nostat_i = '0' then
          byte_o               <= nFIP_status_byte_i;                            
          rst_status_bytes_p_o <= '0'; 

        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
        -- The last byte is the MPS status
        elsif s_byte_index = (data_length_i)  then    
          byte_o               <= mps_status_byte_i;
          rst_status_bytes_p_o <= byte_being_sent_p_i; -- reset signal for both status bytes.
                                                       -- The reset arrives after having sent 
                                                       -- the MPS byte to the WF_tx_serializer
  
        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 		  
      -- The rest of the bytes come from the memory
        else
          byte_o               <= s_mem_byte;                                         
          rst_status_bytes_p_o <= '0'; 

        end if;

      --------------------------------------------------------------------------------------------- 
      -- In stand-alone mode:
      else

        s_base_addr            <= (others => '0');            -- no memory access needed

        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --      
        -- The first (Control) and second (PDU type) bytes to be sent 
        -- are predefined in the c_VARS_ARRAY matrix of the WF_package

        if unsigned(s_byte_index) <= c_VARS_ARRAY(c_VAR_3_INDEX).array_length then -- less or equal                             
          byte_o               <= c_VARS_ARRAY(c_VAR_3_INDEX).byte_array(s_byte_index_aux);
          rst_status_bytes_p_o <= '0'; 

        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
        -- The c_LENGTH_BYTE_INDEX byte is the Length

        elsif s_byte_index = c_LENGTH_BYTE_INDEX then       
          byte_o               <= s_lgth_byte;                                              
          rst_status_bytes_p_o <= '0';
       
        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
        -- The one but last byte if the input nostat_i is negated is the nanoFIP status byte
        -- (if nostat_i is not negated, the "else" condition takes place) 

        elsif unsigned(s_byte_index) = (unsigned(data_length_i)-1 ) and nostat_i = '0' then 
          byte_o               <= nFIP_status_byte_i;                            
          rst_status_bytes_p_o <= '0'; 

        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
        -- The last byte is the MPS status
        elsif s_byte_index = data_length_i then    
          byte_o               <= mps_status_byte_i;
          rst_status_bytes_p_o <= byte_being_sent_p_i; -- reset signal for both status bytes. 
                                                       -- The reset arrives after having sent the 
                                                       -- MPS byte to the WF_tx_serializer
    
        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 		  
        -- The rest of the bytes come from the input bus data_i(15:0)
        else
          byte_o               <= s_slone_byte;                                    
          rst_status_bytes_p_o <= '0';

        end if;
      end if;
    --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --


    when var_1 | var_2 | var_rst | var_whatever =>    
      rst_status_bytes_p_o     <= '0';
      byte_o                   <= (others => '0');                                   
      s_base_addr              <= (others => '0');    

    --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --


    when others =>    
      rst_status_bytes_p_o     <= '0';
      byte_o                   <= (others => '0');                                   
      s_base_addr              <= (others => '0');                           
                                     
    end case;		  
  end process;


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
--!@briedf Synchronous process Delay_byte_index_i: in the combinatorial process Bytes_Generation,
--! according to the value of the signal s_byte_index, a byte is retrieved either from the memory,
--! or from the WF_package or from the WF_status_bytes_gen or WF_model_constr_decoder units.
--! Since the memory needs one clock cycle to output its data (as opposed to the other units that
--! have them ready) the signal s_byte_index has to be a delayed version of the byte_index_i
--! (byte_index_i is the signal used as address for the mem; s_byte_index is the delayed one
--! used for the other units).

  Delay_byte_index_i: process (uclk_i) 
  begin
    if rising_edge (uclk_i) then
      if nfip_rst_i = '1' then
        s_byte_index <= (others => '0');          
      else  

        s_byte_index <= byte_index_i;   -- index of byte to be sent                
      end if;
    end if;
  end process;



---------------------------------------------------------------------------------------------------
--                                         Auxiliary signals                                     --
---------------------------------------------------------------------------------------------------

  s_mem_addr_A      <= std_logic_vector (s_base_addr + s_mem_addr_offset - 1);
  -- address of the byte to be read from memory: base_address(from WF_package) + byte_index_i - 1
  -- (the -1 is because the byte_index_i counts also the Control byte, that is not part of the
  -- memory (for example when byte_index_i is 3 which means that the Control, PDU_TYPE and Length
  -- bytes have preceeded and a byte from the memory is now requested, the byte from the memory cell
  -- 2 (00000010) has to be retrieved).
                                                                                  
  s_mem_addr_offset <= (resize((unsigned(byte_index_i)), s_mem_addr_offset'length));

  s_byte_index_aux  <= (to_integer(unsigned(s_byte_index(3 downto 0))));
                                                      -- index of byte to be sent(range restricted)
                                                      -- used to retreive bytes from the matrix
                                                      -- c_VARS_ARRAY.byte_array, with a predefined
                                                      -- width of 15 bytes
  
  s_lgth_byte      <= std_logic_vector (resize((unsigned(data_length_i)-2),byte_o'length));   
                                                      -- represents the RP_DAT.Data.LENGTH byte
                                                      -- it includes the # bytes of user-data
                                                      -- (P3_LGTH) plus 1 byte of MPS_status
                                                      -- plus 1 byte of nanoFIP_status, if
                                                      -- applicable. It does not include the
                                                      -- Control byte and itself.


end architecture rtl;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------