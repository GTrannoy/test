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

---------------------------------------------------------------------------------------------------
--                                                                                               --
--                                  WF_DualClkRAM_clka_rd_clkb_wr                                --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
-- unit name   WF_DualClkRAM_clka_rd_clkb_wr.vhd
--
--
--! @brief     The unit provides, transparently to the outside world, the memory triplication.
--!            The component DualClkRam (512 bytes) is triplicated; each incoming byte is written 
--!            at the same position in the three memories, whereas each outgoing byte is the 
--!            outcome of a majority voter.
--!            The memory is dual port; port A is used for reading only, port B for writing only.
-- 
-- 
--! @author	   Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch) \n
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
--!@brief: component DualClkRam declaration

  component DualClkRam is 
    port(
    CLKA   : in std_logic; 
    ADDRA  : in std_logic_vector (8 downto 0);
    DINA   : in std_logic_vector (7 downto 0);  
    RWA    : in std_logic;                   

    CLKB   : in std_logic; 
    ADDRB  : in std_logic_vector (8 downto 0); 
    DINB   : in std_logic_vector (7 downto 0);  
    RWB    : in std_logic;                   
    RESETn : in std_logic;                  
    
    DOUTA  : out std_logic_vector (7 downto 0); 
    DOUTB  : out std_logic_vector (7 downto 0)  
    );
  end component DualClkRam;
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
--!@brief majority voter: when a reading is done from the memory, the output of the unit is the
--! output of the majority voter. The majority voter considers the outputs of the three memories
--! and "calculates" their majority with combinatorial logic.

majority_voter: data_porta_o <= (data_o_A_array(0) and data_o_A_array(1)) or
                            (data_o_A_array(1) and data_o_A_array(2)) or
                            (data_o_A_array(2) and data_o_A_array(0));

end syn;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------