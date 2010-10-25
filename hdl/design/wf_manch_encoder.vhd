--=================================================================================================
--! @file wf_manch_encoder.vhd
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
--                                 wf_manch_encoder                                        --
--                                                                                               --
--                                  CERN, BE/CO/HT                                               --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
--
--! @brief      
--
--
--! @author    Pablo Alvarez Sanchez (pablo.alvarez.sanchez@cern.ch)
--!            Evangelia Gousiou (evangelia.gousiou@cern.ch)
--
--
--! @date      06/2010
--
--
--! @version   v0.02
--
--
--! @details \n  
--
--!   \n<b>Dependencies:</b>\n
--
--
--!   \n<b>Modified by:</b>\n
--!     Evangelia Gousiou (Evangelia.Gousiou@cern.ch)
--
--------------------------------------------------------------------------------------------------- 
--
--!   \n\n<b>Last changes:</b>\n
--
--------------------------------------------------------------------------------------------------- 
--
--! @todo 
--!   -> 
--
--------------------------------------------------------------------------------------------------- 


--=================================================================================================
--!                           Entity declaration for wf_manch_encoder
--=================================================================================================

entity wf_manch_encoder is
generic(word_length :  natural);
  port (
  -- INPUT 

    word_i :       in std_logic_vector(word_length-1 downto 0);          

  -- OUTPUT

    word_manch_o : out std_logic_vector((2*word_length)-1 downto 0)
      );
end entity wf_manch_encoder;


--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of wf_manch_encoder is


--=================================================================================================
--                                      architecture begin
--=================================================================================================  
  begin

---------------------------------------------------------------------------------------------------
--! @brief combinatorial process Manchester_Encoder_byte: The process takes a byte (8 bits) and
--! creates its manchester encoded equivalent (16 bits). Each bit '1' is replaced by '10' and each
--! bit '0' by '01'. 

  Manchester_Encoder_byte: process(word_i)
  begin
    for I in word_i'range loop
      word_manch_o(I*2)   <= not word_i(I);
      word_manch_o(I*2+1) <= word_i(I);
    end loop;
  end process;


end architecture rtl;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------