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
--! @date      21/01/2011
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
--
--!   \n<b>Modified by:</b>\n
--!     Evangelia Gousiou (Evangelia.Gousiou@cern.ch)
--
---------------------------------------------------------------------------------------------------
--
--!   \n\n<b>Last changes:</b>\n
--!     -> 21/01/2011  v0.011  EG  changed registering
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
--                                         No Warnings!                                          --
---------------------------------------------------------------------------------------------------


--=================================================================================================
--!                           Entity declaration for WF_wb_controller
--=================================================================================================

entity WF_wb_controller is

  port (
  -- INPUTS 
    -- nanoFIP User Interface, WISHBONE Slave
    wb_clk_i        : in std_logic;                      --! WISHBONE clock
    wb_rst_i        : in std_logic;                      --! WISHBONE reset
    wb_stb_i        : in std_logic;                      --! WISHBONE strobe
    wb_cyc_i        : in std_logic;                      --! WISHBONE cycle
    wb_we_i         : in std_logic;                      --! WISHBONE write enable
    wb_adr_id_i     : in  std_logic_vector (2 downto 0); --! 3 first bits of WISHBONE address


  -- OUTPUTS

    -- Signal from the WF_production_unit
    wb_ack_prod_p_o : out std_logic;                     --! response to a write cycle
                                                         -- latching moment of wb_dat_i

    -- nanoFIP User Interface, WISHBONE Slave output
    wb_ack_p_o      : out std_logic                      --! WISHBONE acknowledge

      );
end entity WF_wb_controller;


--=================================================================================================
--!                                    architecture declaration
--=================================================================================================
architecture rtl of WF_wb_controller is


  signal s_wb_ack_write_p, s_wb_ack_read_p, s_wb_stb_r_edge_p : std_logic;
  signal s_wb_we_d3, s_wb_cyc_d3                              : std_logic_vector (2 downto 0);
  signal s_wb_stb_d4                                          : std_logic_vector (3 downto 0);


begin

---------------------------------------------------------------------------------------------------
--!@brief Triple buffering of the WISHBONE control signals: stb, cyc, we.

  WISHBONE_inputs_synchronization: process (wb_clk_i)
  begin
   if rising_edge (wb_clk_i) then
     if wb_rst_i = '1' then          -- wb_rst is not buffered to comply with WISHBONE rule 3.15
       s_wb_stb_d4  <= (others => '0');
       s_wb_cyc_d3  <= (others => '0');
       s_wb_we_d3   <= (others => '0');

      else
        s_wb_stb_d4 <= s_wb_stb_d4 (2 downto 0) & wb_stb_i;   
        s_wb_cyc_d3 <= s_wb_cyc_d3 (1 downto 0) & wb_cyc_i; 
        s_wb_we_d3  <= s_wb_we_d3  (1 downto 0) & wb_we_i;   
      end if;
    end if;
  end process;

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  s_wb_stb_r_edge_p  <= (not s_wb_stb_d4(3)) and s_wb_stb_d4(2); 


---------------------------------------------------------------------------------------------------
--!@brief Generate_wb_ack_write_p_o: Generation of the wb_ack_write_p signal
--! (acknowledgement from WISHBONE Slave of the write cycle, as a response to the master's storbe).
--! The 1 wb_clk-wide pulse is generated if the wb_cyc and wb_we are asserted and the WISHBONE input 
--! address corresponds to an address in the Produced memory block.
  
  Generate_wb_ack_write_p_o: s_wb_ack_write_p <= '1' when ((s_wb_stb_r_edge_p = '1') and 
                                                           (s_wb_we_d3 (2)    = '1') and 
                                                           (s_wb_cyc_d3(2)    = '1') and
                                                           (wb_adr_id_i       = "010"))
                                            else '0';


---------------------------------------------------------------------------------------------------
--!@brief Generate_wb_ack_read_p:  Generation of the wb_ack_read_p signal
--! (acknowledgement from WISHBONE Slave of the read cycle, as a response to the master's strobe).
--! The 1 wb_clk-wide pulse is generated if the wb_cyc is asserted and the WISHBONE input address
--! corresponds to an address in the Consumed memory block.

  Generate_wb_ack_read_p_o: s_wb_ack_read_p <= '1' when ((s_wb_stb_r_edge_p       = '1') and 
                                                         (s_wb_cyc_d3(2)          = '1') and
                                                         (s_wb_we_d3(2)           = '0') and
                                                         (wb_adr_id_i(2 downto 1) = "00"))
                                          else '0';


---------------------------------------------------------------------------------------------------
--!@brief Output_Register 

   WB_ACK: process (wb_clk_i) 
   begin
     if rising_edge (wb_clk_i) then
       if wb_rst_i = '1' then
         wb_ack_p_o      <= '0';
         wb_ack_prod_p_o <= '0';
       else  
         wb_ack_p_o      <= s_wb_ack_read_p or s_wb_ack_write_p; 
         wb_ack_prod_p_o <= s_wb_ack_write_p;               
       end if;
     end if;
   end process;



end architecture rtl;
--=================================================================================================
--                                        architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------