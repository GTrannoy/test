--________________________________________________________________________________________________|
--                                                                                                |
--                                        |The nanoFIP|                                           |
--                                                                                                |
--                                        CERN,BE/CO-HT                                           |
--________________________________________________________________________________________________|
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--! @file WF_crc.vhd
---------------------------------------------------------------------------------------------------

--! Standard library
library IEEE;

--! Standard packages
use IEEE.STD_LOGIC_1164.all; --! std_logic definitions
use IEEE.NUMERIC_STD.all;    --! conversion functions

--! specific packages
use work.WF_PACKAGE.all;     --! definitions of supplemental types, subtypes, constants

---------------------------------------------------------------------------------------------------
--                                                                                               --
--                                          WF_crc                                               --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
-- unit name   WF_crc
--
--
--! @brief     The unit includes the modules for the generation of the CRC of serialized data,
--!            as well as for the verification of an incoming CRC syndrome
--
--
--! @author	   Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)
--!            Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)
--
--
--! @date      08/2010
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
--!   Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)
--!   Evangelia Gousiou (evangelia.gousiou@cern.ch)
--
---------------------------------------------------------------------------------------------------
--
--!   \n\n<b>Last changes:</b>\n
--!   07/08/2009  v0.02  PAS Entity Ports added, start of architecture content
--!   08/2010     v0.03  EG  Data_FCS_select and crc_ready_p_o signals removed,
--!                          variable v_q_check_mask replaced with a signal,
--!                          code cleaned-up+commented
--
---------------------------------------------------------------------------------------------------
--
--! @todo
--!
---------------------------------------------------------------------------------------------------


--=================================================================================================
--!                                 Entity declaration for WF_crc
--=================================================================================================
entity WF_crc is
generic(c_GENERATOR_POLY_length :  natural);
port (
  -- INPUTS 
    uclk_i :             in std_logic; --! 40 MHz clock
    nFIP_urst_i :         in std_logic; --! internal reset
    start_CRC_p_i :      in std_logic; --! signaling the beginning of the CRC calculation
    data_bit_i :         in std_logic; --! incoming data bit stream
    data_bit_ready_p_i : in std_logic; --! signaling that data_bit_i can be sampled
    
  -- OUTPUTS 
    CRC_ok_p :           out std_logic;            --! signaling of a correct received CRC syndrome
    CRC_o :              out  std_logic_vector (c_GENERATOR_POLY_length-1 downto 0)--!calculated CRC
     );                                                         

end entity WF_crc;


--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of WF_crc is

signal s_crc_bit_ready_p : std_logic;
signal s_q, s_q_nx, s_q_check_mask  : std_logic_vector (c_GENERATOR_POLY_length - 1 downto 0);

--=================================================================================================
--                                      architecture begin
--=================================================================================================
begin

---------------------------------------------------------------------------------------------------
--!@brief The gen_16_bit_Register_and_Interconnections generator, follows the scheme of figure A.1  
--! of the Annex A 61158-4-7 IEC:2007 and constructs a register of 16 master-slave flip-flops which
--! are interconnected as a linear feedback shift register.

gen_16_bit_Register_and_Interconnections: for I in 0 to c_GENERATOR_POLY'left generate

  iteration_0: if I = 0 generate
    s_q_nx(I) <= ((data_bit_i) xor s_q(s_q'left));
  end generate;
  
  iterations: if I > 0 generate
    s_q_nx(I) <= s_q(I-1) xor (c_GENERATOR_POLY(I) and (data_bit_i xor s_q(s_q'left)));      
  end generate;

end generate;


---------------------------------------------------------------------------------------------------
--!@brief Synchronous process CRC_calculation: the process "moves" the shift register described
--! above, for the calculation of the CRC

CRC_calculation: process(uclk_i)
begin
  if rising_edge(uclk_i) then
    if nFIP_urst_i = '1' then
      s_q <= (others => '1');             -- register initialization
                                          -- (initially preset, according to annex A)
         
    else

      if start_CRC_p_i = '1' then
        s_q <= (others => '1');           -- register initialization

      elsif data_bit_ready_p_i = '1' then -- new data bit to be considered for the CRC calculation
        s_q <= s_q_nx;                    -- data propagation
      end if;

        s_crc_bit_ready_p <= data_bit_ready_p_i; 

    end if;
  end if;
end process;

--  --  --  --  --  
CRC_o <= not s_q;


---------------------------------------------------------------------------------------------------
--!@brief Combinatorial process Syndrome_Verification: On the reception, the CRC is being
--! calculated as data is arriving (same as in the transmission) and it is being compared to the
--! predefined c_VERIFICATION_MASK. When the CRC calculated from the received data maches the
--! c_VERIFICATION_MASK, it means a correct CRC word has been received and the signal CRC_ok_p
--! gives a pulse. 

Syndrome_Verification: process(s_q, s_crc_bit_ready_p)

begin
  
  s_q_check_mask <= s_q xor c_VERIFICATION_MASK;
  
  if (unsigned(not s_q_check_mask)) = 0 then 
    CRC_ok_p <= s_crc_bit_ready_p;

  else
    CRC_ok_p <= '0';

  end if;
end process;


end architecture rtl;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------
