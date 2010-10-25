--=================================================================================================
--! @file wf_cons_bytes_from_rx.vhd
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
--                                       wf_cons_bytes_from_rx                                   --
--                                                                                               --
--                                         CERN, BE/CO/HT                                        --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
-- unit name:  wf_cons_bytes_from_rx
--
--! @brief     Consumption of data bytes, arriving from the wf_rx unit, by registering them in
--!            the Consumend memory, if the operation is in memory mode, or by transferring them
--!            to the user interface data bus, if the operation is stand-alone.
--!            In the case of a consumed reset variable, the 1st and 2nd data byte are registered 
--!            and sent to the reset unit.
--
--
--! @author    Pablo Alvarez Sanchez (pablo.alvarez.sanchez@cern.ch)\n
--!            Evangelia Gousiou (Evangelia.Gousiou@cern.ch)         \n
--        
--
--! @date 07/2010
--
--
--! @version v0.02
--
--
--! @details\n 
--
--!   \n<b>Dependencies:</b>\n
--!          wf_reset_unit  \n
--!          wf_rx           \n
--!          wf_engine_control\n
--
--
--!   \n<b>Modified by:</b>\n
--!     Pablo Alvarez Sanchez\n
--!     Evangelia Gousiou     \n
---------------------------------------------------------------------------------------------------
--
--!   \n\n<b>Last changes:</b>\n
--!     -> 11/09/2009  v0.01  EB  First version \n
--!     ->    09/2010  v0.02  EG  Treatment of reset variable added; Bytes_Transfer_To_DATO unit
--!                               creation for simplification; Signals renamed;
--!                               Ctrl, PDU_TYPE, Length bytes registered;
--!                               Code cleaned-up & commented.\n
--
---------------------------------------------------------------------------------------------------
--
--! @todo 
--!   --> separate unit for the wb_ack treatment
--
---------------------------------------------------------------------------------------------------


---/!\----------------------------/!\----------------------------/!\--------------------------/!\--
--                                    Sunplify Premier Warnings                                  --
-- -- --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --
--                                         No Warnings                                           --
---------------------------------------------------------------------------------------------------


--=================================================================================================
--!                            Entity declaration for wf_cons_bytes_from_rx
--=================================================================================================
entity wf_cons_bytes_from_rx is

port (
  -- INPUTS 
    -- User Interface general signals 
    uclk_i :              in std_logic;                      --! 40MHz clock
    slone_i :             in  std_logic;                     --! stand-alone mode (active high)

    -- Signal from the wf_reset_unit
    nFIP_u_rst_i :        in std_logic;                      --! internal reset

    -- User Interface WISHBONE Slave

    wb_clk_i :            in std_logic;                      --! WISHBONE clock
                                                             -- note: may be independent of uclk
            

    wb_adr_i :            in  std_logic_vector (9 downto 0); --! WISHBONE address to memory

    wb_stb_r_edge_p_i :   in  std_logic;                     --! pulse on the rising edge of stb_i

    wb_cyc_i :            in std_logic;                      --! WISHBONE cycle

    -- Signals from the receiver wf_rx
    byte_i :              in std_logic_vector (7 downto 0);  --! de-serialized byte
    byte_ready_p_i :      in std_logic;                      --! indication of a valid byte 

    -- Signals from the wf_engine_control
    byte_index_i :        in std_logic_vector (7 downto 0);  --! index of a byte inside the frame
    var_i :               in t_var;                          --! variable type            


  -- OUTPUTS
    -- OUTPUTS to the User Interface WISHBONE slave 
    data_o :              out std_logic_vector (15 downto 0);--! DAT_O bus 
    wb_ack_cons_p_o :     out std_logic;                     --! WISHBONE acknowledge

    -- OUTPUTS to the wf_VAR_RDY_generator
    rx_Ctrl_byte_o :      out std_logic_vector (7 downto 0); --! received Control byte
    rx_PDU_byte_o :       out std_logic_vector (7 downto 0); --! received PDY_TYPE byte          
    rx_Length_byte_o :    out std_logic_vector (7 downto 0); --! received Length byte

    -- OUTPUTS to the wf_reset_logic

    rst_var_byte_1_o :    out std_logic_vector (7 downto 0); --! content of the 1st data byte of
                                                             --! a reset variable
    rst_var_byte_2_o :    out std_logic_vector (7 downto 0)  --! content of the 2nd data byte of
                                                             --! a reset variable
);

end entity wf_cons_bytes_from_rx;


--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of wf_cons_bytes_from_rx is

signal s_slone_data :                       std_logic_vector (15 downto 0);
signal s_addr :                             std_logic_vector (8 downto 0);
signal s_mem_data_out, s_rx_Length_byte :   std_logic_vector (7 downto 0);
signal s_slone_write_byte_p :               std_logic_vector (1 downto 0);
signal two :                                unsigned(7 downto 0);
signal s_base_addr :                        unsigned(8 downto 0);
signal s_write_byte_to_mem_p :              std_logic;

--=================================================================================================
--                                      architecture begin
--=================================================================================================
begin

  two    <= to_unsigned (2, two'length);

---------------------------------------------------------------------------------------------------  
-- !@brief Instantiation of a dual port Consumed RAM
--! (for both the consumed and consumed broadcast variables)

  Consumption_DPRAM:  wf_DualClkRAM_clka_rd_clkb_wr

    generic map(C_RAM_DATA_LGTH => 8,     -- 8 bits: length of data word
                C_RAM_ADDR_LGTH => 9)     -- 2^9: depth of consumed RAM
                                          -- first 2 bits: identification of the memory block
                                          -- remaining 7 bits: address of a byte inside the block 


    -- port A: WISHBONE that reads from the Consumed RAM
    -- port B: nanoFIP that writes
    port map (clk_A_i     => wb_clk_i,	           -- WISHBONE clck
             addr_A_i     => wb_adr_i(8 downto 0), -- address of byte to be read
             data_A_o     => s_mem_data_out,       -- output byte read
             
             clk_B_i      => uclk_i,               -- 40 MHz clck 
             addr_B_i     => s_addr(8 downto 0),   -- address of byte to be written
             data_B_i     => byte_i,               -- byte to be written
             write_en_B_i => s_write_byte_to_mem_p -- write enable
             );

--------------------------------------------------------------------------------------------------- 
  --!@brief Generate_wb_ack_cons_p_o:  Generation of the wb_ack_cons_p_o signal
  --! (acknowledgement from WISHBONE slave of the read cycle, as a response to the master's strobe).
  --! wb_ack_cons_p_o is 1 wclk-wide pulse asserted 3 wclk cycles after the assertion of the 
  --! asynchronous strobe signal, if the wb_cyc is asserted and the WISHBONE input address 
  --! corresponds to an address in the Consumed memory block.

  Generate_wb_ack_cons_p_o: wb_ack_cons_p_o <= '1' when ((wb_stb_r_edge_p_i = '1')    and 
                                                        (wb_adr_i(9 downto 8) = "00") and
                                                        (wb_cyc_i = '1'))
                                          else '0';


---------------------------------------------------------------------------------------------------
--!@brief Combinatorial process Bytes_Consumption: Data bytes are consumed according to the
--! variable type they belong.

--! The treatment of a var1 is identical to the one of a var2 for both modes (only the memory block
--! differs in memory mode).
 
--! Bytes are consumed even if the Ctrl, PDU_TYPE, Length, CRC, FES bytes are incorrect or if
--! code violations are detected;
--! It is the VAR_RDY signal that signals the user for the validity of the consumed data.

--! In memory mode, the incoming bytes after the Ctrl byte and before the CRC bytes, are written
--! in the memory one by one as they arrive, on the moments when the signal byte_ready_p_i is
--! active. The signals byte_index_i and Length (s_rx_Length_byte) are used to coordinate which
--! bytes are written and which are not (example Ctrl byte, CRC bytes). 
--! The byte_index_i signal is counting each byte after the FSS and before the FES (therefore,
--! apart from all the pure data-bytes, it also includes the Ctrl, PDU, Length, MPS and CRC bytes).
--! The Length byte (s_rx_Length_byte) is received from the wf_rx when byte_index_i is equal to 3
--! and if it is correct, it indicates the amount of bytes after in the frame the Ctrl, PDU_TYPE
--! and Length and before the CRC.

--! In stand-alone mode, in total two bytes of data have to be transferred to the DAT_O bus. The
--! process manages the signal slone_write_byte_p which indicates which of the bytes of the bus
--! (msb: 15 downto 8 or lsb: 7 downto 0) have to be written.

--! If the consumed variable is the reset one (E0h) the process latches the first and second bytes.

Bytes_Consumption: process (var_i, byte_index_i, slone_i, byte_i, two,
                            byte_ready_p_i, s_base_addr, s_rx_Length_byte)
  
  begin


    s_addr <= std_logic_vector (unsigned(byte_index_i)+s_base_addr - 1);  -- memory address of
                                                                          -- the byte to be written
                                                                          -- (-1 bc the Ctrl
                                                                          -- byte is not written) 

    case var_i is 

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --      
      when var_1 =>

            rst_var_byte_1_o <= (others => '0');
            rst_var_byte_2_o <= (others => '0'); 
            s_base_addr      <= c_VARS_ARRAY(c_VAR_1_INDEX).base_addr;      -- base address info
                                                                            -- from wf_package
            --  --  --  --  --  --  --  --  --  --  --  --
            -- in memory mode
            if slone_i = '0' then                                          
                                                                           
              s_slone_write_byte_p <= (others => '0');                    
              
              if (unsigned(byte_index_i)> 0 and  unsigned(byte_index_i)< 127) then -- memory limits 
 
                if byte_index_i > c_LENGTH_BYTE_INDEX then                  -- after the reception
                                                                            -- of the Length byte
                  if unsigned(byte_index_i) <= unsigned(s_rx_Length_byte) + two  then
                    s_write_byte_to_mem_p <= byte_ready_p_i;                -- the # bytes indicated
                                                                            -- by Length are written
                  else                                   
                    s_write_byte_to_mem_p <= '0';        
                  end if;

                else                                                        -- before the reception
                  s_write_byte_to_mem_p   <= byte_ready_p_i;                -- of the Length byte
                end if;                                                     -- all the bytes
                                                                            -- are written 
              else
                s_write_byte_to_mem_p     <= '0';
              end if;

            --  --  --  --  --  --  --  --  --  --  --  --
            -- in stand-alone mode
            elsif slone_i = '1' then

              s_write_byte_to_mem_p <= '0';

              if byte_index_i = c_1st_DATA_BYTE_INDEX then        -- 1st byte to be transferred
                s_slone_write_byte_p <= '0'& byte_ready_p_i;					

              elsif byte_index_i = c_2nd_DATA_BYTE_INDEX then     -- 2nd byte to be transferred
                s_slone_write_byte_p <= byte_ready_p_i & '0';		

              else
                s_slone_write_byte_p <= (others=>'0');
              end if;
            end if;
      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --         


      when var_2 =>

            rst_var_byte_1_o <= (others => '0');
            rst_var_byte_2_o <= (others => '0'); 
            s_base_addr      <= c_VARS_ARRAY(c_VAR_2_INDEX).base_addr; 

            --  --  --  --  --  --  --  --  --  --  --  --
            -- in memory mode
            if slone_i = '0' then                                          
                                                                           
              s_slone_write_byte_p <= (others => '0');                    
              
              if (unsigned(byte_index_i)> 0 and  unsigned(byte_index_i)< 127) then  
 
                if byte_index_i > c_LENGTH_BYTE_INDEX then                 
                                                                            
                  if unsigned(byte_index_i) <= unsigned(s_rx_Length_byte) + two  then
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
            -- in stand-alone mode
            else                                        
              s_write_byte_to_mem_p  <= '0';

              if byte_index_i = c_1st_DATA_BYTE_INDEX then        
                s_slone_write_byte_p <= '0'& byte_ready_p_i;					

              elsif byte_index_i = c_2nd_DATA_BYTE_INDEX then     
                s_slone_write_byte_p <= byte_ready_p_i & '0';		

              else
                s_slone_write_byte_p <= (others=>'0');
              end if;
            end if;

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --         

      when reset_var =>

            s_write_byte_to_mem_p <= '0';
            s_slone_write_byte_p  <= (others => '0');
            s_base_addr           <= c_VARS_ARRAY(c_RESET_VAR_INDEX).base_addr;  

            if ((byte_ready_p_i = '1')and(byte_index_i = c_1st_DATA_BYTE_INDEX)) then -- 1st byte

               rst_var_byte_1_o   <= byte_i;
               rst_var_byte_2_o   <= (others => '0'); 


            elsif ((byte_ready_p_i='1')and(byte_index_i=c_2nd_DATA_BYTE_INDEX)) then  -- 2nd byte

              rst_var_byte_2_o    <= byte_i;
              rst_var_byte_1_o    <= (others => '0'); 

            else
              rst_var_byte_1_o    <= (others => '0');
              rst_var_byte_2_o    <= (others => '0'); 


            end if;           
      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --        

      when others =>
            s_write_byte_to_mem_p <= '0';
            s_base_addr           <= (others => '0');
            s_slone_write_byte_p  <= (others => '0');     
            rst_var_byte_1_o      <= (others => '0');
            rst_var_byte_2_o      <= (others => '0');      

      end case;

end process;


---------------------------------------------------------------------------------------------------
--! @brief Instantiation of the unit responsible for the transfer of 2 de-serialized data bytes
--! to DAT_O;

  Bytes_Transfer_To_DATO:  wf_slone_bytes_to_DATO
  port map(
    uclk_i            => uclk_i, 
    nFIP_u_rst_i      => nFIP_u_rst_i, 
    transfer_byte_p_i => s_slone_write_byte_p,
    byte_i            => byte_i,
    slone_data_o      => s_slone_data);

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- -- -- --
  -- in stand-alone mode the 16 bits DAT_O fills up with the output of the wf_slone_bytes_to_DATO
  -- unit.
  -- In memory mode, the lsb of DAT_O contains the output of the reading of the consumed memory. 
  data_o <= s_slone_data when slone_i = '1'
       else "00000000" & s_mem_data_out;  

---------------------------------------------------------------------------------------------------
--!@brief synchronous process Buffer_Ctrl_PDU_Length_bytes: Storage of the rp_dat.Control, PDU_TYPE
--! and Length bytes of an incoming rp_dat frame. The bytes are sent to the wf_VAR_RDY_generator
--! unit that accordingly enables or not the signals VAR1_RDY, VAR2_RDY.

Buffer_Ctrl_PDU_Length_bytes: process (uclk_i)
  begin                                               

  if rising_edge(uclk_i) then
    if nFIP_u_rst_i = '1' then
      rx_Ctrl_byte_o     <= (others=>'0');
      rx_PDU_byte_o      <= (others=>'0');
      s_rx_Length_byte   <= (others=>'0');
    else

      if ((byte_ready_p_i='1') and (byte_index_i = c_CTRL_BYTE_INDEX)) then 
        rx_Ctrl_byte_o   <= byte_i;                                    

      elsif byte_index_i = c_PDU_BYTE_INDEX and byte_ready_p_i ='1'then 
        rx_PDU_byte_o    <= byte_i;

      elsif byte_index_i = c_LENGTH_BYTE_INDEX and byte_ready_p_i ='1' then 
        s_rx_Length_byte <= byte_i;
      end if;
    end if;
  end if;
  end process;

  rx_Length_byte_o <= s_rx_Length_byte;

end architecture rtl;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------