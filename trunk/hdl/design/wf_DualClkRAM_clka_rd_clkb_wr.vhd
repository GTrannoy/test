--------------------------------------------------------------------------------------------------- 
--! @file wf_DualClkRAM_clka_rd_clkb_wr.vhd
--------------------------------------------------------------------------------------------------- 

-- Standard library
library IEEE;

-- Standard packages
use IEEE.STD_LOGIC_1164.all;  -- std_logic definitions
use IEEE.NUMERIC_STD.all;     -- conversion functions

---------------------------------------------------------------------------------------------------
--                                                                                               --
--                              wf_DualClkRAM_clka_rd_clkb_wr                                    --
--                                                                                               --
--                                   CERN, BE/CO/HT                                              --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
-- unit name   dpblockram.vhd
--
--
--! @brief     The unit provides, transparently to the outside world, the memory triplication.
--!            The component DualClkRam (512 bytes) is triplicated; each incoming byte is written 
--!            at the same position in the three memories, whereas each outgoing byte is the 
--!            outcome of a majority voter.
-- 
-- 
--! @author	   Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)
--!            Evangelia Gousiou (Evangelia.Gousiou@cern.ch) 
--
--
--! @date      08/2010
--
--
--! @version   v0.1
--
--
--! @details\n
--
--!   \n<b>Dependencies:</b>\n 
--!     DualClkRAM.vhd \n
--
--
--!   \n<b>Modified by:</b>\n
--!     Evangelia Gousiou (Evangelia.Gousiou@cern.ch) \n 
--
--------------------------------------------------------------------------------------------------- 
--
--!   \n\n<b>Last changes: </b>\n
--!     -> code cleaned-up and commented 
--
--------------------------------------------------------------------------------------------------- 
--
--! @todo 
--
--------------------------------------------------------------------------------------------------- 


--=================================================================================================
--!                   Entity declaration for wf_DualClkRAM_clka_rd_clkb_wr
--=================================================================================================

entity wf_DualClkRAM_clka_rd_clkb_wr is
  generic (c_data_length : integer := 8; 		-- 8: length of data word (1 byte)
           c_addr_length : integer := 9);       -- 2^9: memory depth (512 bytes)


  port (
        clk_A_i  :     in std_logic;
        addr_A_i :     in std_logic_vector (c_addr_length - 1 downto 0);
        
        clk_B_i :      in std_logic;
        addr_B_i :     in std_logic_vector (c_addr_length - 1 downto 0);
        data_B_i :     in std_logic_vector (c_data_length - 1 downto 0);
        write_en_B_i : in std_logic;
 
       data_A_o :      out std_logic_vector (c_data_length -1 downto 0)
);
end wf_DualClkRAM_clka_rd_clkb_wr; 


--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture syn of wf_DualClkRAM_clka_rd_clkb_wr is 

---------------------------------------------------------------------------------------------------
--!@brief: component DualClkRam declaration
  component DualClkRam is 
    port(
    DINA :   in std_logic_vector (7 downto 0);  
    ADDRA :  in std_logic_vector (8 downto 0);
    RWA :    in std_logic;                   
    CLKA :   in std_logic;                 

    DINB :   in std_logic_vector (7 downto 0);  
    ADDRB :  in std_logic_vector (8 downto 0); 
    RWB :    in std_logic;                   
    CLKB :   in std_logic;                   
    RESETn : in std_logic;                  
    
    DOUTA :  out std_logic_vector (7 downto 0); 
    DOUTB :  out std_logic_vector (7 downto 0)  
    );
  end component DualClkRam;
---------------------------------------------------------------------------------------------------

type t_data_o_A_array is array (natural range <>) of std_logic_vector (7 downto 0);

signal data_o_A_array :   t_data_o_A_array (0 to 2); -- keeps the DOUTA of each one of the memories
signal zero, one, s_rwB : std_logic;
signal s_zeros :          std_logic_vector (7 downto 0);


--=================================================================================================
--                                      architecture begin
--=================================================================================================
begin 

zero <= '0';
one <= '1';
s_zeros <= (others => '0');
s_rwB <= not write_en_B_i;

--------------------------------------------------------------------------------------------------- 
--!@brief: memory triplication
--! The component DualClkRam is generated three times.
--! Port A is used for reading only, port B for writing only.
--! The input DINB is written in the same position in the 3 memories.
--! The output DOUTA from each memory is kept in the array data_o_A_array.

G_memory_triplication: for I in 0 to 2 generate 

UDualClkRam : DualClkRam  
   port map ( DINA   => s_zeros,
              ADDRA  => addr_A_i,
              RWA    => one, 
              CLKA   => clk_A_i, 

              DINB   => data_B_i,
              ADDRB  => addr_B_i, 
              RWB    => s_rwB, 
              CLKB   => clk_B_i, 

              RESETn => one,

              DOUTA  => data_o_A_array(I),
              DOUTB  => open) ;
end generate;

--------------------------------------------------------------------------------------------------- 
--without memory triplication:
--UDualClkRam : DualClkRam  
--    port map ( DINA   => s_zeros,
--               ADDRA  => addr_A_i,
--               RWA    => one, 
--               CLKA   => clk_A_i, 
--
--               DINB   => data_B_i,
--               ADDRB  => addr_B_i, 
--               RWB    => s_rwB, 
--               CLKB   => clk_B_i, 
--
--               RESETn => one,
--
--               DOUTA  => data_A_o,
--               DOUTB  => open) ;

--------------------------------------------------------------------------------------------------- 
--!@brief majority voter: when a reading is done from the memory, the output of the unit is the
--! output of the majority voter. The majority voter considers the outputs of the three memories
--! and "calculates" their majority with combinatorial logic.

majority_voter: data_A_o <= (data_o_A_array(0) and data_o_A_array(1)) or
                            (data_o_A_array(1) and data_o_A_array(2)) or
                            (data_o_A_array(2) and data_o_A_array(0));

end syn;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------
