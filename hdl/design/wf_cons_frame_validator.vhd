---------------------------------------------------------------------------------------------------
--! @file WF_cons_frame_validator.vhd
---------------------------------------------------------------------------------------------------

--! standard library
library IEEE; 

--! standard packages
use IEEE.STD_LOGIC_1164.all;  --! std_logic definitions
use IEEE.NUMERIC_STD.all;     --! conversion functions

--! specific packages
use work.WF_PACKAGE.all;      --! definitions of supplemental types, subtypes, constants

---------------------------------------------------------------------------------------------------
--                                                                                               --
--                                 WF_cons_frame_validator                                       --
--                                                                                               --
--                                  CERN, BE/CO/HT                                               --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
--
--! @brief     Validation of a received RP_DAT frame with respect to: Ctrl, PDU, Length bytes as 
--!            well as CRC and FSS, FES and code violations.
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
--!                           Entity declaration for WF_cons_frame_validator
--=================================================================================================

entity WF_cons_frame_validator is

  port (
  -- INPUTS 
    -- Signals from the WF_cons_bytes_from_rx unit
    rx_Ctrl_byte_i :         in std_logic_vector (7 downto 0); --! received Ctrl byte
    rx_PDU_byte_i :          in std_logic_vector (7 downto 0); --! received PDU_TYPE byte          
    rx_Length_byte_i :       in std_logic_vector (7 downto 0); --! received Length byte

    -- Signal from the WF_rx unit
    rx_FSS_CRC_FES_viol_ok_p_i : in std_logic; --! indication that CRC and FES have 

   -- Signals from WF_engine_control
    var_i:                   in t_var;
    rx_byte_index_i :        in unsigned(7 downto 0);


  -- OUTPUT
    -- Signal to WF_engine_control
    cons_frame_ok_p_o :      out std_logic
      );
end entity WF_cons_frame_validator;


--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of WF_cons_frame_validator is

signal s_rx_ctrl_byte_ok, s_rx_PDU_byte_ok, s_rx_length_byte_ok : std_logic;

--=================================================================================================
--                                      architecture begin
--=================================================================================================  
  begin

--------------------------------------------------------------------------------------------------- 
--!@brief Combinatorial process Consumed_Frame_Validator: validation of an RP_DAT 
--! frame with respect to: Ctrl, PDU, Length bytes as well as CRC and FSS, FES and code violations.

 Consumed_Frame_Validator: process ( var_i, rx_FSS_CRC_FES_viol_ok_p_i, rx_byte_index_i, rx_PDU_byte_i,
                                    rx_Ctrl_byte_i, rx_Length_byte_i )
  begin
  
  if var_i = var_1 or var_i = var_2 then

    --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    if rx_Ctrl_byte_i = c_RP_DAT_CTRL_BYTE then                  -- comparison with the expected
      s_rx_ctrl_byte_ok <= '1';                                  -- RP_DAt_CTRL byte
    else
      s_rx_ctrl_byte_ok <= '0';
    end if; 

    --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    if rx_PDU_byte_i = c_PROD_CONS_PDU_TYPE_BYTE then             -- comparison with the expected
      s_rx_PDU_byte_ok <= '1';                                    -- PDU_TYPE byte
    else 
      s_rx_PDU_byte_ok <= '0' ;
    end if;

    --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    if rx_FSS_CRC_FES_viol_ok_p_i = '1' then                         -- checking the RP_DAT.Data.Length
                                                                 -- byte, when the end of frame
                                                                 -- arrives correctly
      if rx_byte_index_i = (unsigned(rx_Length_byte_i) + 5) then   -- rx_byte_index starts counting 
        s_rx_length_byte_ok <= '1';                              -- from 0 and apart from the user-data
                                                                 -- bytes, also counts ctrl, PDU,
      else                                                       -- Length, 2 CRC and FES bytes 
        s_rx_length_byte_ok <= '0';
      end if;                                                          

  
    else 
      s_rx_length_byte_ok <= '0';
    end if;   

    --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --


  else
    s_rx_ctrl_byte_ok   <= '0';
    s_rx_PDU_byte_ok    <= '0';
    s_rx_length_byte_ok <= '0';
  end if;

end process;            

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- -- -
 cons_frame_ok_p_o <= rx_FSS_CRC_FES_viol_ok_p_i and
                      s_rx_length_byte_ok    and
                      s_rx_ctrl_byte_ok      and
                      s_rx_PDU_byte_ok;


end architecture rtl;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------