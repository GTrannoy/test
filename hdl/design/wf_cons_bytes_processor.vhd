--_________________________________________________________________________________________________
--                                                                                                |
--                                        |The nanoFIP|                                           |
--                                                                                                |
--                                        CERN,BE/CO-HT                                           |
--________________________________________________________________________________________________|
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--! @file WF_cons_bytes_processor.vhd                                                             |
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
--                                     WF_cons_bytes_processor                                   --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
-- unit name:  WF_cons_bytes_processor
--
--! @brief     The unit is consuming the data bytes that are arriving from the WF_rx_deserializer,
--!            according to the following:
--!
--!            o If the consumed variable had been a var_1 or a var_2:
--!
--!                o If the operation is in memory mode    : the unit is registering the pure-data
--!                  bytes along with the PDU_TYPE, Length and MPS bytes in the Consumed memories
--!
--!                o If the operation is in standalone mode: the unit is transferring the 2 
--!                  pure-data bytes to the "nanoFIP User Interface, NON_WISHBONE" data bus DAT_O.
--!
--!            o If the consumed variable had been a var_rst, the 2 pure-data bytes are just
--!              identified and sent to the WF_reset_unit.
--!
--!            ------------------------------------------------------------------------------------
--!            Reminder:
--!
--!            Consumed RP_DAT frame structure :
--!             ___________ ______  _______ ________ ________________ _______  ___________ _______
--!            |____FSS____|_Ctrl_||__PDU__|__LGTH__|__..PureData..__|__MPS__||____FCS____|__FES__|
--!
--!                                                 |-------LGTH bytes-------|
--!                                |--------write to Consumed memory---------|
--!                                                 |----to DAT_O----|
--!                                                 |--to ResetUnit--|
--!
--!            ------------------------------------------------------------------------------------
--
--
--! @author    Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)\n
--!            Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)    \n
--        
--
--! @date 15/12/2010
--
--
--! @version v0.03
--
--
--! @details\n 
--
--!   \n<b>Dependencies:</b>    \n
--!          WF_reset_unit      \n
--!          WF_rx_deserializer \n
--!          WF_engine_control  \n
--
--
--!   \n<b>Modified by:</b>\n
--!     Pablo Alvarez Sanchez \n
--!     Evangelia Gousiou     \n
--
--
--!   \n\n<b>Last changes:</b>\n
--!     -> 11/09/2009  v0.01  EB  First version \n
--!     ->    09/2010  v0.02  EG  Treatment of reset variable added; Bytes_Transfer_To_DATO unit
--!                               creation for simplification; Signals renamed;
--!                               Ctrl, PDU_TYPE, Length bytes registered;
--!                               Code cleaned-up & commented.\n
--!     -> 15/12/2010  v0.03  EG  Unit renamed from WF_cons_bytes_from_rx to WF_cons_bytes_processor
--!                               byte_ready_p comes from the rx_deserializer (no need to pass from
--!                               the engine) Code cleaned-up & commented (more!) \n
--
---------------------------------------------------------------------------------------------------
--
--! @todo 
--!   --> separate unit for the wb_ack treatment
--!   --> two constant!
--
---------------------------------------------------------------------------------------------------

---/!\----------------------------/!\----------------------------/!\-------------------------/!\---
--                                    Synplify Premier Warnings                                  --
-- -- --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --
--                                         No Warnings                                           --
---------------------------------------------------------------------------------------------------


--=================================================================================================
--!                            Entity declaration for WF_cons_bytes_processor
--=================================================================================================
entity WF_cons_bytes_processor is

port (
  -- INPUTS 
    -- nanoFIP User Interface, General signals (synchronized with uclk) 
    uclk_i                : in std_logic;                      --! 40MHz clock
    slone_i               : in  std_logic;                     --! stand-alone mode (active high)

    -- Signal from the WF_reset_unit
    nfip_urst_i           : in std_logic;                      --! nanoFIP internal reset

    -- nanoFIP User Interface, WISHBONE Slave (synchronized with wb_clk)
    wb_clk_i              : in std_logic;                      --! WISHBONE clock
    wb_adr_i              : in  std_logic_vector (9 downto 0); --! WISHBONE address to memory
    wb_cyc_i              : in std_logic;                      --! WISHBONE cycle
    wb_stb_r_edge_p_i     : in  std_logic;                     --! pulse on the rising edge of stb_i

    -- Signals from the WF_rx_deserializer unit
    byte_i                : in std_logic_vector (7 downto 0);  --! input byte
    byte_ready_p_i        : in std_logic;                      --! indication of a new input byte

    -- Signals from the WF_engine_control unit
    byte_index_i          : in std_logic_vector (7 downto 0);  --! index of a byte inside the frame
                                                               -- starting from 0, it counts all the
                                                               -- bytes after the FSS&before the FES

    var_i                 : in t_var;                          --! variable type that is being treated           


  -- OUTPUTS
    -- nanoFIP User Interface, WISHBONE Slave outputs
    data_o                : out std_logic_vector (15 downto 0);--! data out bus 
    wb_ack_cons_p_o       : out std_logic;                     --! WISHBONE acknowledge

    -- Signals to the WF_cons_frame_validator unit
    cons_ctrl_byte_o      : out std_logic_vector (7 downto 0); --! received RP_DAT Control byte
    cons_lgth_byte_o      : out std_logic_vector (7 downto 0); --! received RP_DAT Length byte
    cons_pdu_byte_o       : out std_logic_vector (7 downto 0); --! received RP_DAT PDY_TYPE byte  

    -- Signals to the WF_cons_outcome unit
    cons_var_rst_byte_1_o : out std_logic_vector (7 downto 0); --! content of the 1st data byte of
                                                               --! a reset variable

    cons_var_rst_byte_2_o : out std_logic_vector (7 downto 0)  --! content of the 2nd data byte of
                                                               --! a reset variable
);

end entity WF_cons_bytes_processor;


--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of WF_cons_bytes_processor is

signal s_slone_data                     : std_logic_vector (15 downto 0);
signal s_addr                           : std_logic_vector (8 downto 0);
signal s_mem_data_out, s_cons_lgth_byte : std_logic_vector (7 downto 0);
signal s_slone_write_byte_p             : std_logic_vector (1 downto 0);
signal two                              : unsigned(7 downto 0);
signal s_base_addr                      : unsigned(8 downto 0);
signal s_write_byte_to_mem_p            : std_logic;

--=================================================================================================
--                                      architecture begin
--=================================================================================================
begin

  two    <= to_unsigned (2, two'length);

---------------------------------------------------------------------------------------------------
--                                  Consumed & Consumed Broadcast RAM                            --
--                    Storage (by the unit) & retreival (by the user) of consumed bytes          --
--------------------------------------------------------------------------------------------------- 
-- !@brief Instantiation of a Dual Port Consumed RAM
--! (for both the consumed and consumed broadcast variables)

    Consumed_Bytes_To_RAM:  WF_DualClkRAM_clka_rd_clkb_wr
    generic map(
      c_RAM_DATA_LGTH => 8,     -- 8 bits: length of data word
      c_RAM_ADDR_LGTH => 9)     -- 2^9: depth of consumed RAM
                                -- first 2 bits: identification of the memory block
                                -- remaining 7 bits: address of a byte inside the block 
    -- port A: WISHBONE that reads from the Consumed RAM; port B: nanoFIP that writes
    port map(
      clk_porta_i      => wb_clk_i,	               -- WISHBONE clock
      addr_porta_i     => wb_adr_i(8 downto 0),    -- address of byte to be read
      -----------------------------------------------------------------------------
      data_porta_o     => s_mem_data_out,          -- output byte read
      -----------------------------------------------------------------------------          
      clk_portb_i      => uclk_i,                  -- 40 MHz clock 
      addr_portb_i     => s_addr(8 downto 0),      -- address of byte to be written
      data_portb_i     => byte_i,                  -- byte to be written
      write_en_portb_i => s_write_byte_to_mem_p ); -- write enable
            
--------------------------------------------------------------------------------------------------- 
--!@brief Generate_wb_ack_cons_p_o:  Generation of the wb_ack_cons_p_o signal
--! (acknowledgement from WISHBONE Slave of the read cycle, as a response to the master's strobe).
--! wb_ack_cons_p_o is 1 wclk-wide pulse asserted 3 wclk cycles after the assertion of the 
--! asynchronous strobe signal, if the wb_cyc is asserted and the WISHBONE input address 
--! corresponds to an address in the Consumed memory block.

  Generate_wb_ack_cons_p_o: wb_ack_cons_p_o <= '1' when ((wb_stb_r_edge_p_i = '1')    and 
                                                        (wb_adr_i(9 downto 8) = "00") and
                                                        (wb_cyc_i = '1'))
                                          else '0';



---------------------------------------------------------------------------------------------------
--                                      Consumed bytes to DAT_O                                  --
---------------------------------------------------------------------------------------------------
--! @brief Instantiation of the unit responsible for the transfering of 2 de-serialized data bytes
--! to DAT_O;

  Consumed_Bytes_To_DATO: WF_cons_bytes_to_dato
  port map(
    uclk_i            => uclk_i, 
    nfip_urst_i       => nfip_urst_i, 
    transfer_byte_p_i => s_slone_write_byte_p,
    byte_i            => byte_i,
    ------------------------------------------
    slone_data_o      => s_slone_data);
    ------------------------------------------

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- -- -- --
  -- In stand-alone mode the 16 bits DAT_O fills up with the output of the WF_cons_bytes_to_dato
  -- unit.In memory mode,the lsb of DAT_O contains the output of the reading of the consumed memory
 
   data_o <= s_slone_data when slone_i = '1'
        else "00000000" & s_mem_data_out;  



---------------------------------------------------------------------------------------------------
--                                        Bytes Processing                                       --
---------------------------------------------------------------------------------------------------
--!@brief Combinatorial process Bytes_Processing: Data bytes are consumed according to the
--! variable type (var_1, var_2, var_rst) they belong.

--! In memory mode the treatment of a var_1 is identical to the one of a var2; only the base address
--! of the memory differs.
 
--! Bytes are consumed even if any of the Control, PDU_TYPE, Length, CRC & FES byte or the manch.
--! encoding of the consumed frame are incorrect.
--! It is the VAR_RDY signal that signals the user for the validity of the consumed data.

--! In memory mode, the incoming bytes (byte_i) after the Control byte and before the CRC bytes,
--! are written in the memory one by one as they arrive, on the moments when the signal
--! byte_ready_p_i is active.
--! The signals byte_index_i and Length (s_cons_lgth_byte) are used to distinguish the Control and
--! CRC bytes from hte rest:
--!   o the Control byte arrives when byte_index_i = 0
--!   o the CRC bytes arrive $Length bytes after the Length byte
--! The byte_index_i signal is counting each byte after the FSS and before the FES.
--! The Length byte (s_cons_lgth_byte) is received from the WF_rx_deserializer when byte_index_i is
--! equal to 3 and indicates the amount of bytes in the frame after the Control, PDU_TYPE and itself and
--! before the CRC.

--! In stand-alone mode, in total two bytes of data have to be transferred to the data out bus. The
--! process manages the signal slone_write_byte_p which indicates on which one of the bytes of the
--! bus (msb: 15 downto 8 or lsb: 7 downto 0) the new incoming byte has to be written.

--! If the consumed variable is the reset one the process latches the first and second data bytes.

Bytes_Processing: process (var_i, byte_index_i, slone_i, byte_i, two,
                            byte_ready_p_i, s_base_addr, s_cons_lgth_byte)
  
  begin


    s_addr <= std_logic_vector (unsigned(byte_index_i)+s_base_addr - 1);  -- memory address of
                                                                          -- the byte to be written
                                                                          -- (-1 bc the Ctrl
                                                                          -- byte is not written) 

    case var_i is 

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --      

      when var_1 =>

            cons_var_rst_byte_1_o         <= (others => '0');
            cons_var_rst_byte_2_o         <= (others => '0'); 
            s_base_addr                   <= c_VARS_ARRAY(c_VAR_1_INDEX).base_addr;-- base address
                                                                                -- from WF_package
            --  --  --  --  --  --  --  --  --  --  --  --
            -- in memory mode
            if slone_i = '0' then                                          
                                                                           
              s_slone_write_byte_p        <= (others => '0');       

              if (unsigned(byte_index_i)> 0 and  unsigned(byte_index_i)< 127) then -- memory limits 

                if byte_index_i > c_LENGTH_BYTE_INDEX then                  -- after the reception
                                                                            -- of the Length byte
                  if unsigned(byte_index_i) <= unsigned(s_cons_lgth_byte) + two  then -- less or eq
                    s_write_byte_to_mem_p <= byte_ready_p_i;                -- "Length" amount of
                                                                            -- bytes are written
                  else                                   
                    s_write_byte_to_mem_p <= '0';        
                  end if;

                else                                                        -- before the reception
                  s_write_byte_to_mem_p   <= byte_ready_p_i;                -- of the Length byte
                end if;                                                     -- all the bytes (after
                                                                            -- Control) are written 
              else
                s_write_byte_to_mem_p     <= '0';
              end if;

            --  --  --  --  --  --  --  --  --  --  --  --
            -- in stand-alone mode
            elsif slone_i = '1' then

              s_write_byte_to_mem_p       <= '0';

              if byte_index_i = c_1st_DATA_BYTE_INDEX then        -- 1st byte to be transferred
                s_slone_write_byte_p      <= '0'& byte_ready_p_i;					

              elsif byte_index_i = c_2nd_DATA_BYTE_INDEX then     -- 2nd byte to be transferred
                s_slone_write_byte_p      <= byte_ready_p_i & '0';		

              else
                s_slone_write_byte_p      <= (others=>'0');
              end if;
            end if;

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --         

      when var_2 =>
            -- same treatment as var 1 on a different memory location (base_addr)
            cons_var_rst_byte_1_o         <= (others => '0');
            cons_var_rst_byte_2_o         <= (others => '0'); 
            s_base_addr                   <= c_VARS_ARRAY(c_VAR_2_INDEX).base_addr; 

            --  --  --  --  --  --  --  --  --  --  --  --
            -- in memory mode
            if slone_i = '0' then                                          
                                                                           
              s_slone_write_byte_p        <= (others => '0');                    
              
              if (unsigned(byte_index_i)> 0 and  unsigned(byte_index_i)< 127) then  
 
                if byte_index_i > c_LENGTH_BYTE_INDEX then                 
                                                                            
                  if unsigned(byte_index_i) <= unsigned(s_cons_lgth_byte) + two  then
                    s_write_byte_to_mem_p <= byte_ready_p_i;

                  else                                   
                    s_write_byte_to_mem_p <= '0';        
                  end if;

                else
                  s_write_byte_to_mem_p   <= byte_ready_p_i;                 
                end if;                                                  
      
              else
                s_write_byte_to_mem_p     <= '0';
              end if;

            --  --  --  --  --  --  --  --  --  --  --  --
            -- stand-alone mode does not treat consumed broadcast vars
            else                                        
              s_write_byte_to_mem_p       <= '0';
              s_slone_write_byte_p        <= (others => '0');  
            end if;

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --         

      when var_rst =>

            s_write_byte_to_mem_p         <= '0';       -- no writing in memory for the reset var
            s_slone_write_byte_p          <= (others => '0');
            s_base_addr                   <= (others => '0'); 

            if ((byte_ready_p_i = '1')and(byte_index_i = c_1st_DATA_BYTE_INDEX)) then -- 1st byte

              cons_var_rst_byte_1_o       <= byte_i;
              cons_var_rst_byte_2_o       <= (others => '0'); 


            elsif ((byte_ready_p_i='1')and(byte_index_i=c_2nd_DATA_BYTE_INDEX)) then  -- 2nd byte

              cons_var_rst_byte_2_o       <= byte_i;
              cons_var_rst_byte_1_o       <= (others => '0'); 

            else
              cons_var_rst_byte_1_o       <= (others => '0');
              cons_var_rst_byte_2_o       <= (others => '0'); 


            end if;           

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --        

      when var_3 | var_presence | var_identif | var_whatever =>
            s_write_byte_to_mem_p         <= '0';
            s_base_addr                   <= (others => '0');
            s_slone_write_byte_p          <= (others => '0');     
            cons_var_rst_byte_1_o         <= (others => '0');
            cons_var_rst_byte_2_o         <= (others => '0');  

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  

      when others =>
            s_write_byte_to_mem_p         <= '0';
            s_base_addr                   <= (others => '0');
            s_slone_write_byte_p          <= (others => '0');     
            cons_var_rst_byte_1_o         <= (others => '0');
            cons_var_rst_byte_2_o         <= (others => '0');      

      end case;

end process;



---------------------------------------------------------------------------------------------------
--                                 Control, PDU_TYPE, Length bytes                               --
---------------------------------------------------------------------------------------------------
--!@brief Synchronous process Buffer_Ctrl_PDU_Length_bytes: Storage of the Control, PDU_TYPE
--! and Length bytes of an incoming RP_DAT frame. The bytes are sent to the WF_cons_frame_validator
--! unit that validates them and accordingly signals the WF_outcome unit for the activation of the
--! VAR1_RDY(for a var_1), VAR2_RDY(for a var_2), assert_rston_p & rst_nfip_and_fd_p(for a var_rst).

Buffer_Ctrl_PDU_Length_bytes: process (uclk_i)
  begin                                               

  if rising_edge (uclk_i) then
    if nfip_urst_i = '1' then
      cons_ctrl_byte_o     <= (others => '0');
      cons_pdu_byte_o      <= (others => '0');
      s_cons_lgth_byte     <= (others => '0');
    else

      if (var_i = var_1) or (var_i = var_2) or (var_i = var_rst) then  -- only for consumed vars

        if ((byte_index_i = c_CTRL_BYTE_INDEX) and (byte_ready_p_i='1')) then 
          cons_ctrl_byte_o <= byte_i;                                    

        elsif ((byte_index_i = c_PDU_BYTE_INDEX) and (byte_ready_p_i ='1')) then 
          cons_pdu_byte_o  <= byte_i;

        elsif ((byte_index_i = c_LENGTH_BYTE_INDEX) and (byte_ready_p_i ='1')) then 
          s_cons_lgth_byte <= byte_i;
        end if;

      else
        cons_ctrl_byte_o   <= (others => '0');
        cons_pdu_byte_o    <= (others => '0');
        s_cons_lgth_byte   <= (others => '0');
      end if;
    end if;
  end if;
  end process;

--  --  --  --  --  --  --  --  --  --  --  --  
  cons_lgth_byte_o         <= s_cons_lgth_byte;

end architecture rtl;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------