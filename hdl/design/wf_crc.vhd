--_________________________________________________________________________________________________
--                                                                                                |
--                                        |The nanoFIP|                                           |
--                                                                                                |
--                                        CERN,BE/CO-HT                                           |
--________________________________________________________________________________________________|
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--! @file WF_crc.vhd                                                                              |
---------------------------------------------------------------------------------------------------

--! Standard library
library IEEE;

--! Standard packages
use IEEE.STD_LOGIC_1164.all; --! std_logic definitions
use IEEE.NUMERIC_STD.all;    --! conversion functions

--! specific packages
use work.WF_PACKAGE.all;     --! definitions of types, constants, entities

---------------------------------------------------------------------------------------------------
--                                                                                               --
--                                          WF_crc                                               --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
--
--! @brief     The unit creates the modules:
--!              o for the generation of the CRC of serial data,
--!              o for the verification of an incoming CRC syndrome.
--
--
--! @author    Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)\n
--!            Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)    \n
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
--!     WF_reset_unit       \n
--!     WF_rx_deserializer  \n
--!     WF_tx_serializer    \n
--
--
--!   \n<b>Modified by:</b>   \n
--!     Pablo Alvarez Sanchez \n
--!     Evangelia Gousiou     \n
--
---------------------------------------------------------------------------------------------------
--
--!   \n\n<b>Last changes:</b>\n
--!     -> 07/08/2009  v0.02  PAS Entity Ports added, start of architecture content \n
--!     -> 08/2010     v0.03  EG  Data_FCS_select and crc_ready_p_o signals removed,
--!                           variable v_q_check_mask replaced with a signal,
--!                           code cleaned-up+commented \n
--
---------------------------------------------------------------------------------------------------
--
--! @todo
--!
---------------------------------------------------------------------------------------------------

---/!\----------------------------/!\----------------------------/!\-------------------------/!\---
--                               Synplify Premier D-2009.12 Warnings                             --
-- -- --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --
--                                         No Warnings                                           --
---------------------------------------------------------------------------------------------------


--=================================================================================================
--!                                 Entity declaration for WF_crc
--=================================================================================================
entity WF_crc is
generic (c_GENERATOR_POLY_length : natural := 16);  --! default value
port (
  -- INPUTS 
    -- nanoFIP User Interface, General signals
    uclk_i             : in std_logic;              --! 40 MHz clock

    -- Signal from the WF_reset_unit  
    nfip_urst_i        : in std_logic;              --! nanoFIP internal reset

    -- Signals from the WF_rx_deserializer/ WF_tx_serializer units
    data_bit_i         : in std_logic;              --! incoming data bit stream
    data_bit_ready_p_i : in std_logic;              --! indicates the sampling moment of data_bit_i
    start_crc_p_i      : in std_logic;              --! beginning of the CRC calculation

    
  -- OUTPUTS 
    -- Signal to the WF_rx_deserializer unit
    crc_ok_p           : out std_logic;             --! signals a correct received CRC syndrome

    -- Signal to the WF_tx_serializer unit
    crc_o              : out  std_logic_vector (c_GENERATOR_POLY_length-1 downto 0)--!calculated CRC
     );                                                         

end entity WF_crc;


--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of WF_crc is

signal s_crc_bit_ready_p            : std_logic;
signal s_q, s_q_nx, s_q_check_mask  : std_logic_vector (c_GENERATOR_POLY_length - 1 downto 0);

--=================================================================================================
--                                      architecture begin
--=================================================================================================
begin

---------------------------------------------------------------------------------------------------
--!@brief The Gen_16_bit_Register_and_Interconnections generator, follows the scheme of figure A.1  
--! of the Annex A 61158-4-7 IEC:2007 and constructs a register of 16 master-slave flip-flops which
--! are interconnected as a linear feedback shift register.

Gen_16_bit_Register_and_Interconnections:

  for I in 0 to c_GENERATOR_POLY'left generate

    iteration_0: if I = 0 generate
      s_q_nx(I) <= ((data_bit_i) xor s_q(s_q'left));
    end generate;
  
    next_iterations: if I > 0 generate
      s_q_nx(I) <= s_q(I-1) xor (c_GENERATOR_POLY(I) and (data_bit_i xor s_q(s_q'left)));      
    end generate;

  end generate;


---------------------------------------------------------------------------------------------------
--!@brief Synchronous process CRC_calculation: the process "moves" the shift register described
--! above, for the calculation of the CRC

CRC_calculation: process (uclk_i)
begin
  if rising_edge (uclk_i) then

    if nfip_urst_i = '1' then
      s_q <= (others => '0');
         
    else

      if start_crc_p_i = '1' then
        s_q <= (others => '1');           -- register initialization
                                          -- (initially preset, according to the Annex)

      elsif data_bit_ready_p_i = '1' then -- new data bit to be considered for the CRC calculation
        s_q <= s_q_nx;                    -- data propagation
      end if;

        s_crc_bit_ready_p <= data_bit_ready_p_i; 

    end if;
  end if;
end process;

--  --  --  --  --  
crc_o <= not s_q;


---------------------------------------------------------------------------------------------------
--!@brief Combinatorial process Syndrome_Verification: On the reception, the CRC is being
--! calculated as data is arriving (same as in the transmission) and it is being compared to the
--! predefined c_VERIFICATION_MASK. When the CRC calculated from the received data matches the
--! c_VERIFICATION_MASK, it is implied that a correct CRC word has been received for the preceded
--! data and the signal crc_ok_p gives a pulse. 

Syndrome_Verification: process (s_q, s_crc_bit_ready_p)

begin
  
  s_q_check_mask <= s_q xor c_VERIFICATION_MASK;
  
  if (unsigned(not s_q_check_mask)) = 0 then 
    crc_ok_p     <= s_crc_bit_ready_p;

  else
    crc_ok_p     <= '0';

  end if;
end process;


end architecture rtl;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------