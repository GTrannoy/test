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
-- unit name: wf_consumed_vars
--
--! @brief     Nanofip control unit. It accepts variable data and store them into block RAM or in stand alone mode directly to the wf_wishbone. \n
--!
--! 
--!
--!
--!
--!
--!
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

    -- Signal from the reset_logic unit
    nFIP_rst_i :          in std_logic;                      --! internal reset

   -- User Interface Wishbone Slave
    wb_rst_i :            in std_logic;                      --! wishbone reset

    wb_clk_i :            in std_logic;                      --! wishbone clock
                                                             -- note: may be indipendant of uclk
            

    wb_adr_i :            in  std_logic_vector (9 downto 0); --! wishbone address to memory
                                                             -- (buffered once with wb_clk) 
                                                             -- note: msb allways 0!

    wb_stb_p_i :          in  std_logic;                     --! wishbone strobe
                                                             -- (buffered once with wb_clk)
                                                             -- note: indication that master
                                                             -- is ready to transfer data

   -- Signals for the wf_engine_control
    byte_ready_p_i :      in std_logic;
	index_offset_i :        in std_logic_vector(6 downto 0);
	var_i :               in t_var;

   -- Signals for the receiver wf_rx
	byte_i :              in std_logic_vector(7 downto 0);


  -- OUTPUTS
    -- User Interface WISHBONE slave 
    wb_data_o :           out std_logic_vector (15 downto 0); --! 
    wb_ack_cons_p_o :     out std_logic; --! Acknowledge

    -- OUTPUTS to the wf_reset_logic
    reset_nFIP_and_FD_o : out std_logic;
    reset_RSTON_o :       out std_logic
);

end entity wf_consumed_vars;


--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of wf_consumed_vars is

signal s_addr:                    std_logic_vector(8 downto 0);
signal s_mem_data_out :           std_logic_vector(7 downto 0);
signal s_slone_write_byte_p :     std_logic_vector(1 downto 0);
signal s_slone_data_out :         std_logic_vector(15 downto 0);
signal s_base_addr :              unsigned(8 downto 0);
signal s_write_byte_to_mem_p, wb_ack_cons_p_o_d:     std_logic;
signal s_rp_dat_control_byte_ok : std_logic := '0'; -- for simulation esthetics

--=================================================================================================
--                                      architecture begin
--=================================================================================================
begin

---------------------------------------------------------------------------------------------------  
-- !@brief synchronous process consumtion_dpram: Instanciation of a "Consumed RAM"
--! (for both consumed and consumed broadcast variables)

  consumtion_dpram:  dpblockram_clka_rd_clkb_wr

    generic map(c_data_length => 8,         -- 8 bits: length of data word
 			    c_addr_length => 9)         -- 2^9: depth of consumed RAM
                                            -- first 2 bits: identification of the memory block
                                            -- remaining 7 bits: address of a byte inside the block 


   -- port A corresponds to: wishbone that reads from the Consumed RAM & B to: nanoFIP that writes
    port map (clk_A_i     => wb_clk_i,	                         -- wishbone clck
             addr_A_i     => wb_adr_i(8 downto 0), -- address of byte to be read
             data_A_o     => s_mem_data_out,                     -- output byte read
             
             clk_B_i      => uclk_i,                             -- 40 MHz clck 
             addr_B_i     => s_addr(8 downto 0),        -- address of byte to be written
             data_B_i     => byte_i,                             -- byte to be written
             write_en_B_i => s_write_byte_to_mem_p               -- wishbone write enable
             );


--------------------------------------------------------------------------------------------------- 
--!@brief synchronous process Generate_wb_ack_cons_p_o:  Generation of the wb_ack_cons_p_o signal
--! (acknowledgement from wishbone slave of the read cycle, as a response to the master's storbe).
--! wb_ack_cons_p_o is asserted two wb_clk cycles after the assertion of the input strobe signal,
--! (reminder: stb_i is buffered once in the input stage), if the wishbone input address
--! corresponds to an address in the Consumed memory block.

Generate_wb_ack_cons_p_o: process (wb_clk_i)

begin

  if rising_edge(wb_clk_i) then
    if wb_rst_i = '1' then
      wb_ack_cons_p_o_d <= '0';
    else

      if wb_adr_i(9 downto 8) = "00" then          -- checking of the 2 first bits of the address,
                                                   -- to confirm that the request to write is on
                                                   -- the Cosumed or Cosumed broadcast memory block 

        wb_ack_cons_p_o_d <= wb_stb_p_i;             -- slave's indication: valid data available

      else
        wb_ack_cons_p_o_d <= '0';
      end if;
    end if;
  end if;
end process;

wb_ack_cons_p_o <= wb_stb_p_i; 


---------------------------------------------------------------------------------------------------
--!@brief combinatorial process Check_rp_dat_control_byte:Verification of wether the rp_dat.Control
--! byte of the received rp_dat frame is the correct one. The generated signal 
--! s_rp_dat_control_byte_ok stays asserted until a new consumed variable arrives and its 
--! rp_dat.Control byte is to be checked. The signal is used by the process Bytes_Consumption.

Check_rp_dat_control_byte: process (byte_ready_p_i,index_offset_i,byte_i)

begin

  if ((byte_ready_p_i='1') and (index_offset_i = c_CTRL_BYTE_INDEX)) then

    if byte_i = c_RP_DAT_CTRL_BYTE then
      s_rp_dat_control_byte_ok <= '1';
    else 
      s_rp_dat_control_byte_ok <= '0';
    end if;

  end if;
end process;


---------------------------------------------------------------------------------------------------
--!@brief Combinatorial process Bytes_Consumption: Consumption of incoming data bytes (from the 
--! receiver's unit, wf_rx) by registering them in the Cosumend memory, if the operation is in
--! memory mode, or by transfering them to the user interface data bus, if the operation is
--! stand-alone. Only if the signal rp_dat_control_byte_ok is asserted the process performs the
--! bytes consumption.
--! In memory mode, the incoming bytes are written in the memory on the moments when the signal
--! byte_ready_p_i is enabled.
--! In stand-alone mode, in total two bytes of data have to be transferred to the dat_o bus. The
--! process manages the signal slone_write_byte_p which indicates which of the bytes of the bus
--! (msb: 15 downto 8 or lsb: 7 downto 0) have to be written.
--! If the consumed variable is the reset one (E0h) the process checks the first and second bytes
--! and manages the signals reset_nFIP_and_FD and reset_RSTON accordingly.
 
--! Note: in stand-alone mode nanoFIP does not handdle the var2 broadcast variable.  

Bytes_Consumption: process (var_i, index_offset_i, slone_i, byte_ready_p_i)
  begin

    if s_rp_dat_control_byte_ok = '1' then        -- only if the rp_dat.control byte is correct the 
                                                  -- process continues with the bytes' consumption

      s_addr <= std_logic_vector(unsigned(index_offset_i)+s_base_addr - 2);-- address in memory
                                                                     -- of the byte to be
                                                                     -- written
      case var_i is 

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --      

      when var_1 =>

            reset_RSTON_o <= '0'; 
            reset_nFIP_and_FD_o <= '0';
            s_base_addr <= c_VARS_ARRAY(c_VAR_1_INDEX).base_add; -- base addr info from the wf_package

            --  --  --  --  --  --  --  --  --  --  --  --
            -- in memory mode
            if slone_i = '0' then

              s_slone_write_byte_p  <= (others => '0');

              s_write_byte_to_mem_p <= byte_ready_p_i;      -- managment of the write enable signal
                                                            -- of the Consumed memory

            --  --  --  --  --  --  --  --  --  --  --  --
            -- in stand-alone mode
            elsif slone_i = '1' then

              s_write_byte_to_mem_p      <= '0';

              if index_offset_i = c_1st_byte_addr then        -- 1st byte to be transferred
                s_slone_write_byte_p(0) <= byte_ready_p_i ;					
              end if;

              if index_offset_i = c_2nd_byte_addr then        -- 2nd byte to be transferred
                s_slone_write_byte_p(1) <= byte_ready_p_i ;		
              end if;
            end if;
      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --         


      when var_2 =>

            reset_nFIP_and_FD_o <= '0';
            reset_RSTON_o <= '0'; 
            s_base_addr <= c_VARS_ARRAY(c_VAR_2_INDEX).base_add;-- base addr info from the wf_package

            --  --  --  --  --  --  --  --  --  --  --  --
            -- in memory mode
            if slone_i = '0' then 

              s_slone_write_byte_p <= (others => '0');

              s_write_byte_to_mem_p <= byte_ready_p_i;  -- managment of the write enable signal
                                                        -- of the Consumed memory(same as in var_1)

            --  --  --  --  --  --  --  --  --  --  --  --
            -- in stand-alone mode
            else                                        -- in slone mode nanoFIP is not able to
              s_write_byte_to_mem_p <= '0';             -- receive the broadcast variable
              s_slone_write_byte_p <= (others => '0');              
            end if;

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --         

      when reset_var =>

            s_write_byte_to_mem_p <= '0';
            s_slone_write_byte_p <= (others => '0');
            s_base_addr <= c_VARS_ARRAY(c_RESET_VAR_INDEX).base_add;-- base addr info from the wf_package

            if ((byte_ready_p_i = '1')and(index_offset_i = c_1st_byte_addr)) then -- 1st byte

              if byte_i = subs_i then
                reset_nFIP_and_FD_o <= '1'; -- reset_nFIP_and_FD_o stays asserted until 
              end if;                       -- the end of this rp_dat frame
               

            elsif ((byte_ready_p_i='1')and(index_offset_i=c_2nd_byte_addr)) then  -- 2nd byte

              if byte_i = subs_i then  
                reset_RSTON_o <= '1';       -- reset_RSTON_o stays asserted until 
              end if;                       -- the end of this rp_dat frame

            end if;           
      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --        

      when others =>
            reset_RSTON_o         <= '0'; 
            reset_nFIP_and_FD_o   <= '0';
            s_write_byte_to_mem_p <= '0';
            s_base_addr           <= (others => '0');
            s_slone_write_byte_p  <= (others => '0');           
      end case;



    else                                    -- if the rp_dat.control byte is incorrect, 
                                            -- none of the incoming bytes is considered
      reset_RSTON_o         <= '0'; 
      reset_nFIP_and_FD_o   <= '0';
      s_write_byte_to_mem_p <= '0';
      s_addr                <= (others => '0');
      s_base_addr           <= (others => '0');
      s_slone_write_byte_p  <= (others => '0');   

    end if;

end process;


---------------------------------------------------------------------------------------------------
--!@brief synchronous process Data_Transfer_To_Dat_o: In stand-alone mode, accrording to the signal
--! s_slone_write_byte_p, the first or second byte of the user interface bus DAT_o takes the
--! incoming byte byte_i.
--! In memory mode, the lsb of dat_o (DAT_O(7 downto 0)), receives the byte that is also written in
--! the memory.

Data_Transfer_To_Dat_o: process (uclk_i) 
begin
  if rising_edge(uclk_i) then
    if nFIP_rst_i = '1' then
      wb_data_o  <= (others => '0');           -- bus initialization
 
    else

      --  --  --  --  --  --  --  --  --  --  --  --
      -- in stand-alone mode
      if slone_i = '1' then                   -- 2 data bytes have to be transferred
 
        if s_slone_write_byte_p(0) = '1' then -- the 1st byte is written in the lsb of the bus 
          wb_data_o(7 downto 0)   <= byte_i;  -- the data stays there until a new byte arrives
        end if;

        if s_slone_write_byte_p(1) = '1' then -- the 2nd byte is written in the msb of the bus
          wb_data_o(15 downto 8)  <= byte_i;  -- the data stays there until a new byte arrives
        end if;


      --  --  --  --  --  --  --  --  --  --  --  --
      -- in memory mode
      else
        wb_data_o(7 downto 0) <= s_mem_data_out; -- the lsb of the bus receives the byte that is
                                                 -- also written in the memory
      end if;
    end if;
  end if;
end process;


end architecture rtl;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------