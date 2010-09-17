--=================================================================================================
--! @file wf_consumed_vars.vhd
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
--                                           wf_consumed_vars                                    --
--                                                                                               --
--                                           CERN, BE/CO/HT                                      --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
-- unit name:  wf_consumed_vars
--
--! @brief     Consumption of data bytes (from the  receiver's unit, wf_rx) by registering them in
--!            the Cosumend memory, if the operation is in memory mode, or by transfering them to
--!            the user interface data bus, if the operation is stand-alone.
--!            In the case of a consumed reset variable, the unit checks the 1st and 2nd data byte
--!            and treats the signals reset_nFIP_and_FD_o and reset_RSTON_o accordingly.
--
--
--! @author    Pablo Alvarez Sanchez (pablo.alvarez.sanchez@cern.ch)
--!            Evangelia Gousiou (Evangelia.Gousiou@cern.ch)
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
--!
--
--
--!   \n<b>Modified by:</b>\n
--!     Pablo Alvarez Sanchez (pablo.alvarez.sanchez@cern.ch)\n
--!     Evangelia Gousiou (Evangelia.Gousiou@cern.ch)        \n
---------------------------------------------------------------------------------------------------
--
--!   \n\n<b>Last changes:</b>\n
--!     11/09/2009  v0.01  EB  First version \n
--
---------------------------------------------------------------------------------------------------
--
--! @todo 
--
---------------------------------------------------------------------------------------------------


--=================================================================================================
--!                            Entity declaration for wf_consumed_vars
--=================================================================================================
entity wf_consumed_vars is

port (
  -- INPUTS 
    -- User Interface general signals 
    uclk_i :              in std_logic;                      --! 40MHz clock
    slone_i :             in  std_logic;                     --! stand-alone mode (active high)
    subs_i :              in  std_logic_vector (7 downto 0); --! Subscriber number coding.

    -- Signal from the wf_reset_unit unit
    nFIP_rst_i :          in std_logic;                      --! internal reset

   -- User Interface WISHBONE Slave

    wb_clk_i :            in std_logic;                      --! WISHBONE clock
                                                             -- note: may be indipendant of uclk
            

    wb_adr_i :            in  std_logic_vector (9 downto 0); --! WISHBONE address to memory
                                                             -- (buffered once with wb_clk) 
                                                             -- note: msb allways 0!

    wb_stb_r_edge_p_i :   in  std_logic;                     --! pulse on the rising edge of stb_i
                                                             -- the pulse appears 2 wclk ticks after 
                                                             -- a rising edge on the stb_i
                                                             -- note: indication that master
                                                             -- is ready to transfer data

    wb_cyc_i :            in std_logic;                      --! WISHBONE cycle
                                                             -- indicates a valid cycle in progress

   -- Signals for the wf_engine_control
    byte_ready_p_i :      in std_logic;
	byte_index_i :        in std_logic_vector (7 downto 0);
	var_i :               in t_var;

   -- Signals for the receiver wf_rx
	byte_i :              in std_logic_vector (7 downto 0);


  -- OUTPUTS
    -- OUTPUTS to the User Interface WISHBONE slave 
    data_o :              out std_logic_vector (15 downto 0);--! DAT_O bus 
    wb_ack_cons_p_o :     out std_logic;                     --! WISHBONE acknowledge

    -- OUTPUTS to the wf_engine_control
    rx_Ctrl_byte_o :      out std_logic_vector (7 downto 0); --! received Control byte
    rx_PDU_byte_o :       out std_logic_vector (7 downto 0); --! received PDY_TYPE byte          
    rx_Length_byte_o :    out std_logic_vector (7 downto 0); --! received Length byte

    -- OUTPUTS to the wf_reset_logic
    reset_nFIP_and_FD_o : out std_logic;                --! signals that the 1st byte of a consumed 
                                                        --! reset var contains the station address   
    reset_RSTON_o :       out std_logic                 --! signals that the 2nd byte of a consumed
                                                        --! reset var contains the station address 

);

end entity wf_consumed_vars;


--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of wf_consumed_vars is

signal s_slone_datao :                      std_logic_vector (15 downto 0);
signal s_addr:                              std_logic_vector (8 downto 0);
signal s_mem_data_out :                     std_logic_vector (7 downto 0);
signal s_rst_var_byte_1, s_rst_var_byte_2 : std_logic_vector (7 downto 0);
signal s_slone_write_byte_p :               std_logic_vector (1 downto 0);
signal s_base_addr :                        unsigned(8 downto 0);
signal s_write_byte_to_mem_p :              std_logic;

--=================================================================================================
--                                      architecture begin
--=================================================================================================
begin

---------------------------------------------------------------------------------------------------  
-- !@brief synchronous process consumtion_dpram: Instanciation of a "Consumed RAM"
--! (for both consumed and consumed broadcast variables)

  consumtion_dpram:  wf_DualClkRAM_clka_rd_clkb_wr

    generic map(c_data_length => 8,         -- 8 bits: length of data word
 			    c_addr_length => 9)         -- 2^9: depth of consumed RAM
                                            -- first 2 bits: identification of the memory block
                                            -- remaining 7 bits: address of a byte inside the block 


   -- port A corresponds to: WISHBONE that reads from the Consumed RAM & B to: nanoFIP that writes
    port map (clk_A_i     => wb_clk_i,	           -- WISHBONE clck
             addr_A_i     => wb_adr_i(8 downto 0), -- address of byte to be read
             data_A_o     => s_mem_data_out,       -- output byte read
             
             clk_B_i      => uclk_i,               -- 40 MHz clck 
             addr_B_i     => s_addr(8 downto 0),   -- address of byte to be written
             data_B_i     => byte_i,               -- byte to be written
             write_en_B_i => s_write_byte_to_mem_p -- WISHBONE write enable
             );


--------------------------------------------------------------------------------------------------- 
--!@brief Generate_wb_ack_cons_p_o:  Generation of the wb_ack_cons_p_o signal
--! (acknowledgement from WISHBONE slave of the read cycle, as a response to the master's storbe).
--! wb_ack_cons_p_o is asserted two wb_clk cycles after the assertion of the input strobe signal,
--! if the WISHBONE cycle signal is asserted and the WISHBONE input address corresponds to an
--! address in the Consumed memory block.

Generate_wb_ack_cons_p_o: wb_ack_cons_p_o <= '1' when ((wb_stb_r_edge_p_i = '1')     and 
                                                       (wb_adr_i(9 downto 8) = "00") and
                                                       (wb_cyc_i = '1'))
                                          else '0';

---------------------------------------------------------------------------------------------------
--!@brief combinatorial process Latch_Ctrl_PDU_Length_bytes_received: Latching the rp_dat.Control,
--! PDU_TYPE and Length bytes of an incoming rp_dat frame. The bytes are sent to the control unit
--! that verifies if they are correct and accordingly enables or not the signals var1_rdy, var2_rdy

Latch_Ctrl_PDU_Length_bytes_received: process (uclk_i)

begin                                               

  if rising_edge(uclk_i) then
    if nFIP_rst_i = '1' then
      rx_Ctrl_byte_o   <= (others=>'0');
      rx_PDU_byte_o    <= (others=>'0');
      rx_Length_byte_o <= (others=>'0');
    else

      if ((byte_ready_p_i='1') and (byte_index_i = c_CTRL_BYTE_INDEX)) then 
        rx_Ctrl_byte_o <= byte_i;                                    

      elsif byte_index_i = c_PDU_BYTE_INDEX and byte_ready_p_i ='1'then 
        rx_PDU_byte_o <= byte_i;

      elsif byte_index_i = c_LENGTH_BYTE_INDEX and byte_ready_p_i ='1' then 
        rx_Length_byte_o <= byte_i;
      end if;
    end if;
  end if;
end process;


---------------------------------------------------------------------------------------------------
--!@brief Combinatorial process Bytes_Consumption: Consumption of incoming data bytes (from the 
--! receiver's unit, wf_rx) by registering them in the Cosumend memory, if the operation is in
--! memory mode, or by transfering them to the user interface data bus (DAT_O), if the operation is
--! stand-alone. Bytes are consumed even if the Ctrl, PDU_TYPE or Length bytes are incorrect;
--! it is the VAR_RDY signal that signals the user for the validity of the consumed data.
--! In memory mode, the incoming bytes are written in the memory on the moments when the signal
--! byte_ready_p_i is enabled.
--! In stand-alone mode, in total two bytes of data have to be transferred to the dat_o bus. The
--! process manages the signal slone_write_byte_p which indicates which of the bytes of the bus
--! (msb: 15 downto 8 or lsb: 7 downto 0) have to be written.
--! If the consumed variable is the reset one (E0h) the process checks the first and second bytes
--! and manages the signals reset_nFIP_and_FD and reset_RSTON accordingly.
 
--! Note: in stand-alone mode nanoFIP does not handdle the var2 broadcast variable.  

Bytes_Consumption: process (var_i, byte_index_i, slone_i, byte_i,
                            byte_ready_p_i, s_base_addr)
  
  begin


      s_addr <= std_logic_vector (unsigned(byte_index_i)+s_base_addr - 1);-- address in memory
                                                                          -- of the byte to be
                                                                          -- written (-1 bc Ctrl byte
                                                                          -- should not be written) 

      case var_i is 

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --      

      when var_1 =>

            s_rst_var_byte_1      <= (others => '0');
            s_rst_var_byte_2      <= (others => '0'); 
            s_base_addr             <= c_VARS_ARRAY(c_VAR_1_INDEX).base_addr; -- base addr info
                                                                             -- from wf_package

            --  --  --  --  --  --  --  --  --  --  --  --
            -- in memory mode
            if slone_i = '0' then

              s_slone_write_byte_p  <= (others => '0');
              
              if (unsigned(s_addr) >= s_base_addr) and (s_addr <= c_VARS_ARRAY(c_VAR_1_INDEX).last_addr) then  
                s_write_byte_to_mem_p <= byte_ready_p_i;      -- managment of the write enable signal
                                                              -- of the Consumed memory
              else
                s_write_byte_to_mem_p <= '0';
              end if;

            --  --  --  --  --  --  --  --  --  --  --  --
            -- in stand-alone mode
            elsif slone_i = '1' then

              s_write_byte_to_mem_p      <= '0';

              if byte_index_i = c_1st_DATA_BYTE_INDEX then        -- 1st byte to be transferred
                s_slone_write_byte_p  <= '0'& byte_ready_p_i;					

              elsif byte_index_i = c_2nd_DATA_BYTE_INDEX then     -- 2nd byte to be transferred
                s_slone_write_byte_p <= byte_ready_p_i & '0';		

              else
                s_slone_write_byte_p <= (others=>'0');
              end if;
            end if;
      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --         


      when var_2 =>

            s_rst_var_byte_1      <= (others => '0');
            s_rst_var_byte_2      <= (others => '0'); 
            s_base_addr           <= c_VARS_ARRAY(c_VAR_2_INDEX).base_addr; -- base addr info
                                                                            -- from wf_package

            --  --  --  --  --  --  --  --  --  --  --  --
            -- in memory mode
            if slone_i = '0' then 

              s_slone_write_byte_p  <= (others => '0');

              if (unsigned(s_addr) >= s_base_addr) and (s_addr <= c_VARS_ARRAY(c_VAR_2_INDEX).last_addr) then   
                s_write_byte_to_mem_p <= byte_ready_p_i;  -- managment of the write enable signal
                                                          -- of the Consumed memory(same as in var_1)
              else
                s_write_byte_to_mem_p <= '0';
              end if;


            --  --  --  --  --  --  --  --  --  --  --  --
            -- in stand-alone mode
            else                                        -- in slone mode nanoFIP is not able to
              s_write_byte_to_mem_p <= '0';             -- receive the broadcast variable
              s_slone_write_byte_p  <= (others => '0');              
            end if;

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --         

      when reset_var =>

            s_write_byte_to_mem_p   <= '0';
            s_slone_write_byte_p    <= (others => '0');
            s_base_addr             <= c_VARS_ARRAY(c_RESET_VAR_INDEX).base_addr;  -- base addr info
                                                                                   --from wf_package

            if ((byte_ready_p_i = '1')and(byte_index_i = c_1st_DATA_BYTE_INDEX)) then -- 1st byte

               s_rst_var_byte_1 <= byte_i;
               s_rst_var_byte_2 <= (others => '0'); 


            elsif ((byte_ready_p_i='1')and(byte_index_i=c_2nd_DATA_BYTE_INDEX)) then  -- 2nd byte

              s_rst_var_byte_2 <= byte_i;
              s_rst_var_byte_1 <= (others => '0'); 

            else
              s_rst_var_byte_1 <= (others => '0');
              s_rst_var_byte_2 <= (others => '0'); 


            end if;           
      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --        

      when others =>
            s_write_byte_to_mem_p <= '0';
            s_base_addr           <= (others => '0');
            s_slone_write_byte_p  <= (others => '0');     
            s_rst_var_byte_1      <= (others => '0');
            s_rst_var_byte_2      <= (others => '0');      

      end case;

end process;

---------------------------------------------------------------------------------------------------
Reset_Signals: process (uclk_i) 
begin
  if rising_edge(uclk_i) then

    if nFIP_rst_i = '1' then
      reset_nFIP_and_FD_o <= '0';
      reset_RSTON_o       <= '0';
 
    else

      if s_rst_var_byte_1 = subs_i then

        reset_nFIP_and_FD_o <= '1'; -- reset_nFIP_and_FD_o stays asserted until 
      end if;                       -- the end of this rp_dat frame

      if s_rst_var_byte_2 = subs_i then  

        reset_RSTON_o       <= '1'; -- reset_RSTON_o stays asserted until 
      end if;                       -- the end of this rp_dat frame

    end if;
  end if;
end process;




---------------------------------------------------------------------------------------------------
--!@brief synchronous process Data_Transfer_To_Dat_o: In stand-alone mode, accrording to the signal
--! s_slone_write_byte_p, the first or second byte of the user interface bus DAT_o takes the
--! incoming byte byte_i.
--! In memory mode, the lsb of DAT_O (DAT_O(7 downto 0)), receives the byte that is also written in
--! the memory.

Data_Transfer_To_Dat_o: process (uclk_i) 
begin
  if rising_edge(uclk_i) then
    if nFIP_rst_i = '1' then
      s_slone_datao  <= (others => '0');           -- bus initialization
 
    else

      --  --  --  --  --  --  --  --  --  --  --  --
      -- in stand-alone mode
      if slone_i = '1' then                   -- 2 data bytes have to be transferred
 
        if s_slone_write_byte_p(0) = '1' then -- the 1st byte is written in the lsb of the bus 
          if byte_ready_p_i ='1' then
            s_slone_datao(7 downto 0)   <= byte_i;   -- the data stays there until a new byte arrives
          end if;      
        end if;                               -- on purpose latch, to store the value on DAT_O 

        if s_slone_write_byte_p(1) = '1' then -- the 2nd byte is written in the msb of the bus
          if byte_ready_p_i ='1' then
            s_slone_datao(15 downto 8)  <= byte_i;   -- the data stays there until a new byte arrives
          end if;
        end if;


      --  --  --  --  --  --  --  --  --  --  --  --
      -- in memory mode
      else
        s_slone_datao(7 downto 0)     <= (others=>'0'); 

      end if;
    end if;
  end if;
end process;

---------------------------------------------------------------------------------------------------
  data_o(7 downto 0) <= s_mem_data_out when slone_i = '0'
                    else s_slone_datao(7 downto 0);

  data_o(15 downto 8) <= s_slone_datao(15 downto 8);  

end architecture rtl;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------