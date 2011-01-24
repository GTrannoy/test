--_________________________________________________________________________________________________
--                                                                                                |
--                                        |The nanoFIP|                                           |
--                                                                                                |
--                                        CERN,BE/CO-HT                                           |
--________________________________________________________________________________________________|
--________________________________________________________________________________________________|

--------------------------------------------------------------------------------------------------- 
--! @file WF_DualClkRAM_clka_rd_clkb_wr.vhd                                                       |
--------------------------------------------------------------------------------------------------- 

--! Standard library
library IEEE;

--! Standard packages
use IEEE.STD_LOGIC_1164.all;  --! std_logic definitions
use IEEE.NUMERIC_STD.all;     --! conversion functions

--! Specific Packages
use work.WF_PACKAGE.all;      --! definitions of types, constants, entities

---------------------------------------------------------------------------------------------------
--                                                                                               --
--                                  WF_DualClkRAM_clka_rd_clkb_wr                                --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
--
--! @brief     The unit provides the memory triplication, transparently to the outside world.
--!            The component DualClkRam (512 bytes) is triplicated: each incoming byte is written 
--!            at the same position in the three memories, whereas each outgoing byte is the 
--!            outcome of a majority voter.
--!            The memory is dual port; port A is used for reading only, port B for writing only.
--!
--!            Remark: MajorityVoter(A,B,C) = (A and B) OR (A and C) OR (B and C)            
-- 
-- 
--! @author    Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch) \n
--!            Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)     \n
--
--
--! @date      10/12/2010
--
--
--! @version   v0.02
--
--
--! @details\n
--
--!   \n<b>Dependencies:</b>\n 
--!            DualClkRAM.vhd \n
--
--
--!   \n<b>Modified by:</b>\n
--!            Evangelia Gousiou (Evangelia.Gousiou@cern.ch) \n 
--
--------------------------------------------------------------------------------------------------- 
--
--!   \n\n<b>Last changes: </b>\n
--!     -> 12/2010  v0.02  EG  code cleaned-up+commented \n
--
--------------------------------------------------------------------------------------------------- 
--
--! @todo 
--
--------------------------------------------------------------------------------------------------- 

---/!\----------------------------/!\----------------------------/!\-------------------------/!\---
--                               Synplify Premier D-2009.12 Warnings                             --
-- -- --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --
--                                         No Warnings                                           --
---------------------------------------------------------------------------------------------------


--=================================================================================================
--!                   Entity declaration for WF_DualClkRAM_clka_rd_clkb_wr
--=================================================================================================

entity WF_DualClkRAM_clka_rd_clkb_wr is
  generic (C_RAM_DATA_LGTH : integer;  -- length of data word
           c_RAM_ADDR_LGTH : integer); -- memory depth
  port (
  -- INPUTS 
    -- Inputs concerning port A
    clk_porta_i      : in std_logic;
    addr_porta_i     : in std_logic_vector (C_RAM_ADDR_LGTH - 1 downto 0);

    -- Inputs concerning port B        
    clk_portb_i      : in std_logic;
    addr_portb_i     : in std_logic_vector (C_RAM_ADDR_LGTH - 1 downto 0);
    data_portb_i     : in std_logic_vector (C_RAM_DATA_LGTH - 1 downto 0);
    write_en_portb_i : in std_logic;


  -- OUTPUT 
    -- Output concerning port A
    data_porta_o     : out std_logic_vector (C_RAM_DATA_LGTH -1 downto 0)
);
end WF_DualClkRAM_clka_rd_clkb_wr; 


--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture syn of WF_DualClkRAM_clka_rd_clkb_wr is 

---------------------------------------------------------------------------------------------------

type t_data_o_A_array is array (natural range <>) of std_logic_vector (7 downto 0);

signal data_o_A_array   : t_data_o_A_array (0 to 2); -- keeps the DOUTA of each one of the memories
signal zero, one, s_rwB : std_logic;
signal s_zeros          : std_logic_vector (7 downto 0);


--=================================================================================================
--                                      architecture begin
--=================================================================================================
begin 

zero    <= '0';
one     <= '1';
s_zeros <= (others => '0');
s_rwB   <= not write_en_portb_i;

--------------------------------------------------------------------------------------------------- 
--!@brief: memory triplication
--! The component DualClkRam is generated three times.
--! Port A is used for reading only, port B for writing only.
--! The input DINB is written in the same position in the 3 memories.
--! The output DOUTA from each memory is kept in the array data_o_A_array.

G_memory_triplication: for I in 0 to 2 generate 

UDualClkRam : DualClkRam  
   port map ( DINA   => s_zeros,
              ADDRA  => addr_porta_i,
              RWA    => one, 
              CLKA   => clk_porta_i, 

              DINB   => data_portb_i,
              ADDRB  => addr_portb_i, 
              RWB    => s_rwB, 
              CLKB   => clk_portb_i, 

              RESETn => one,

              DOUTA  => data_o_A_array(I),
              DOUTB  => open) ;
end generate;


--------------------------------------------------------------------------------------------------- 
--!@brief Combinatorial Majority_Voter

Majority_Voter: data_porta_o <= (data_o_A_array(0) and data_o_A_array(1)) or
                                (data_o_A_array(1) and data_o_A_array(2)) or
                                (data_o_A_array(2) and data_o_A_array(0));

end syn;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------