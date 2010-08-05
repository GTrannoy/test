--------------------------------------------------------------------------------------------------- 
--! @file dpblockram.vhd
--------------------------------------------------------------------------------------------------- 
--! Standard library
library IEEE;
--! Standard packages
use IEEE.STD_LOGIC_1164.all; --! std_logic definitions
use IEEE.NUMERIC_STD.all;    --! conversion functions

--------------------------------------------------------------------------------------------------- 
--------------------------------------------------------------------------------------------------- 
-- --
-- CERN, BE  --
-- --
--------------------------------------------------------------------------------------------------- 
--
-- unit name: dpblockram.vhd
--
--! @brief The unit provides transparently to the outside world the memory triplication and all the
--! associated actions.
--!
--! 
--! @author <Pablo Alvarez(pablo.alvarez.sanchez@cern.ch)>
--
--! @date 24\01\2009
--
--! @version 1
--!
--! @details The component DualClkRam is triplicated.
--! Each incoming byte is written at the same position in the three memories, whereas
--! each outgoing byte is the outcome of a majority voting system from the three memories.
--!
--! <b>Dependencies:</b>\n
--! DualClkRAM.vhd \n
--!
--! <b>References:</b>\n
--!
--! <b>Modified by:</b>\n
--! Author: Pablo Alvarez Sanchez (pablo.alvarez.sanchez@cern.ch)
--------------------------------------------------------------------------------------------------- 
--! @todo 
--
--------------------------------------------------------------------------------------------------- 

entity dpblockram_clka_rd_clkb_wr is
  generic (c_data_length : integer := 8; 		-- 8: length of data word 
           c_addr_length : integer := 9);       -- 2^9: memory depth


  port (
        clk_A_i  :     in std_logic;
        addr_A_i :     in std_logic_vector(c_addr_length - 1 downto 0);
        
        clk_B_i :      in std_logic;
        addr_B_i :     in std_logic_vector(c_addr_length - 1 downto 0);
        data_B_i :     in std_logic_vector(c_data_length - 1 downto 0);
        write_en_B_i : in std_logic;
 
       data_A_o :      out std_logic_vector(c_data_length -1 downto 0)
);
end dpblockram_clka_rd_clkb_wr; 


architecture syn of dpblockram_clka_rd_clkb_wr is 

---------------------------------------------------------------------------------------------------
--!@brief: component DualClkRam declaration
  component DualClkRam is 
    port(
    DINA :   in std_logic_vector(7 downto 0);  
    ADDRA :  in std_logic_vector(8 downto 0);
    RWA :    in std_logic;                   
    CLKA :   in std_logic;                 

    DINB :   in std_logic_vector(7 downto 0);  
    ADDRB :  in std_logic_vector(8 downto 0); 
    RWB :    in std_logic;                   
    CLKB :   in std_logic;                   
    RESETn : in std_logic;                  
    
    DOUTA :  out std_logic_vector(7 downto 0); 
    DOUTB :  out std_logic_vector(7 downto 0)  
    );
  end component DualClkRam;
---------------------------------------------------------------------------------------------------

signal zero : std_logic;
signal one : std_logic;
signal s_rwB : std_logic;
signal s_zeros : std_logic_vector(7 downto 0);

type t_data_o_A_array is array (natural range <>) of std_logic_vector(7 downto 0);
signal data_o_A_array : t_data_o_A_array(0 to 2); --will keep the DOUTA of each one of the memories
--------------------------------------------------------------------------------------------------- 

begin 

zero <= '0';
one <= '1';
s_zeros <= (others => '0');
s_rwB <= not write_en_B_i;

--------------------------------------------------------------------------------------------------- 
--!@brief: memory triplication
--! The component DualClkRam is generated three times.
--! Port A is used for reading, port B for writing.
--! The input DINB is written in the same position in the 3 memories.
--! The output DOUTA from each memory is kept in the array data_o_A_array.

memory_triplication: for I in 0 to 2 generate 

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
--!@brief: majority voter after a memory reading
--! when a reading is done from the memory, the process majority_voter considers internally the
--! outputs of the three memories and defines as final output, the majority of the three.

majority_voter: process (data_o_A_array)
  begin
    data_A_o <= (data_o_A_array(0) and data_o_A_array(1)) or
               (data_o_A_array(1) and data_o_A_array(2)) or
               (data_o_A_array(2) and data_o_A_array(0));
end process;

end syn;