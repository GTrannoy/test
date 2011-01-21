--_________________________________________________________________________________________________
--                                                                                                |
--                                        |The nanoFIP|                                           |
--                                                                                                |
--                                        CERN,BE/CO-HT                                           |
--________________________________________________________________________________________________|
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--! @file WF_wb_controller.vhd
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
--                                       WF_wb_controller                                        --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
--
--! @brief     The unit generates the "User Interface WISHBONE" signal ACK, nanoFIP's answer to 
--!            the user's STBs. 
--
--
--! @author    Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)
--!            Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)
--
--
--! @date      20/01/2011
--
--
--! @version   v0.01
--
--
--! @details \n  
--
--!   \n<b>Dependencies:</b>  \n
--!            WF_production  \n
--!            WF_consumption \n
--
--------------------------------------------------------------------------------------------------- 
--
--!   \n<b>Modified by:</b>\n
--!     Evangelia Gousiou (Evangelia.Gousiou@cern.ch)
--
--
--!   \n\n<b>Last changes:</b>\n
--!     -> 
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
---------------------------------------------------------------------------------------------------


--=================================================================================================
--!                           Entity declaration for WF_wb_controller
--=================================================================================================

entity WF_wb_controller is

  port (
  -- INPUTS 
    -- nanoFIP User Interface, WISHBONE Slave
    wb_clk_i          : in std_logic;                      --! WISHBONE clock
    wb_rst_i          : in std_logic;                      --! WISHBONE reset
    wb_cyc_i          : in std_logic;                      --! WISHBONE cycle
    wb_stb_r_edge_p_i : in std_logic;                      --! rising edge on WISHBONE strobe
    wb_we_i           : in std_logic;                      --! WISHBONE write enable
 
   wb_adr_id_i        : in  std_logic_vector (2 downto 0); --! 3 first bits of WISHBONE address


  -- OUTPUTS

    -- Signal from the WF_production_unit
    wb_ack_prod_p_o : out std_logic;                        --! response to a write cycle
                                                            -- latching moment of wb_dat_i

    -- nanoFIP User Interface, WISHBONE Slave output
    wb_ack_p_o      : out std_logic                         --! WISHBONE acknowledge
                                                            -- response to master's strobe
      );
end entity WF_wb_controller;


--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of WF_wb_controller is

  signal s_wb_ack_write_p, s_wb_ack_read_p, s_wb_ack_write_p_d, s_wb_ack_read_p_d : std_logic;

begin

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
--!@brief Generate_wb_ack_write_p_o: Generation of the wb_ack_write_p signal
--! (acknowledgement from WISHBONE Slave of the write cycle, as a response to the master's storbe).
--! The 1 wb_clk-wide pulse is generated if the wb_cyc and wb_we are asserted and the WISHBONE input 
--! address corresponds to an address in the Produced memory block.
  
  Generate_wb_ack_write_p_o: s_wb_ack_write_p <= '1' when ((wb_stb_r_edge_p_i = '1') and 
                                                           (wb_adr_id_i = "010")     and
                                                           (wb_we_i = '1')           and 
                                                           (wb_cyc_i = '1'))
                                          else '0';

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
--!@brief Generate_wb_ack_read_p:  Generation of the wb_ack_read_p signal
--! (acknowledgement from WISHBONE Slave of the read cycle, as a response to the master's strobe).
--! The 1 wb_clk-wide pulse is generated if the wb_cyc is asserted and the WISHBONE input address
--! corresponds to an address in the Consumed memory block.

  Generate_wb_ack_read_p_o: s_wb_ack_read_p <= '1' when ((wb_stb_r_edge_p_i = '1')        and 
                                                         (wb_adr_id_i(1 downto 0) = "00") and
                                                         (wb_cyc_i = '1'))
                                          else '0';

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
--!@brief Output_Register: 
   WB_ACK: process (wb_clk_i) 
   begin
     if rising_edge (wb_clk_i) then
       if wb_rst_i = '1' then
         s_wb_ack_read_p_d <= '0';
         s_wb_ack_write_p_d <= '0';
       else  

        s_wb_ack_read_p_d  <= s_wb_ack_read_p;
        s_wb_ack_write_p_d <= s_wb_ack_write_p;               
       end if;
     end if;
   end process;


   wb_ack_p_o       <= s_wb_ack_read_p_d or s_wb_ack_write_p_d; 
   wb_ack_prod_p_o  <= s_wb_ack_write_p_d; 

end architecture rtl;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------