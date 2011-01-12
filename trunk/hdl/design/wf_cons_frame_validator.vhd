--_________________________________________________________________________________________________
--                                                                                                |
--                                        |The nanoFIP|                                           |
--                                                                                                |
--                                        CERN,BE/CO-HT                                           |
--________________________________________________________________________________________________|
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--! @file WF_cons_frame_validator.vhd
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
--                                   WF_cons_frame_validator                                     --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
--
--! @brief     Validation of a received RP_DAT frame with respect to the correctness of the 
--!            Control, PDU_TYPE and Length bytes, coming from the wf_cons_bytes_processor unit,
--!            as well of the CRC, FSS, FES bytes and of the manchester encoding (no occurence of
--!            unwanted code violations), all coming directly from the wf_rx_deserializer unit.
--!            After these verifications, the unit wf_VAR_RDY_generator treats accordingly the
--!            signals VAR1_RDY/ VAR2_RDY, or nFIP_and_FD_p/ assert_RSTON_p. 
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
--! @details \n  
--
--!   \n<b>Dependencies:</b>    \n
--!     wf_cons_bytes_processor \n
--!     WF_engine_control       \n
--!     wf_rx_deserializer      \n
--
--
--!   \n<b>Modified by:</b>\n
--!     Evangelia Gousiou (Evangelia.Gousiou@cern.ch)
--
--------------------------------------------------------------------------------------------------- 
--
--!   \n\n<b>Last changes:</b>\n
--!     -> 12/2010  v0.02  EG  code cleaned-up+commented \n
--
--------------------------------------------------------------------------------------------------- 
--
--! @todo 
--!   -> 
--
--------------------------------------------------------------------------------------------------- 

---/!\----------------------------/!\----------------------------/!\-------------------------/!\---
--                               Sunplify Premier D-2009.12 Warnings                             --
-- -- --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --
-- "W CL246  Input port bits 0, 2, 5, 6 of var_i(0 to 6) are unused"                             --
-- var_i is one-hot encoded and has 7 values.                                                    -- 
-- The unit is treating only the consumed variables var_1, var_2 and var_rst.                    --
---------------------------------------------------------------------------------------------------


--=================================================================================================
--!                           Entity declaration for WF_cons_frame_validator
--=================================================================================================

entity WF_cons_frame_validator is

  port (
  -- INPUTS 
    -- Signals from the wf_cons_bytes_processor unit
    rx_ctrl_byte_i             : in std_logic_vector (7 downto 0);  --! received Ctrl byte
    rx_pdu_byte_i              : in std_logic_vector (7 downto 0);  --! received PDU_TYPE byte          
    rx_length_byte_i           : in std_logic_vector (7 downto 0);  --! received Length byte

    -- Signal from the wf_rx_deserializer unit
    rx_crc_wrong_p_i           : in std_logic; --! indication of a frame with a wrong CRC
    rx_fss_crc_fes_viol_ok_p_i : in std_logic; --! indication of a frame with a correct FSS,FES,CRC
                                               --! and with no unexpected manch code violations
   -- Signals from the WF_engine_control
    var_i                      : in t_var;                  --! variable type that is being treated
    rx_byte_index_i            : in unsigned (7 downto 0);  --! index of the byte being received


  -- OUTPUT
    -- Signal to the WF_engine_control
    cons_frame_ok_p_o          : out std_logic; --! pulse at the end of the FES
                                                --! indicating a valid frame
    -- Signal to the WF_status_bytes_gen
    nfip_status_r_fcser_p_o    : out std_logic; --! indication of a consumed frame with wrong CRC 
    nfip_status_r_tler_o       : out std_logic  --! indication of the correctness of the PDU_TYPE,
                                                --! Control or Length bytes of the consumed frame 
      );
end entity WF_cons_frame_validator;


--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of WF_cons_frame_validator is

signal s_rx_ctrl_byte_ok, s_rx_pdu_byte_ok, s_rx_length_byte_ok : std_logic;

--=================================================================================================
--                                      architecture begin
--=================================================================================================  
begin

--------------------------------------------------------------------------------------------------- 
--!@brief Combinatorial process Consumed_Frame_Validator: validation of an RP_DAT 
--! frame with respect to: Ctrl, PDU, Length bytes as well as CRC, FSS, FES and code violations.
--! The bytes rx_ctrl_byte_i, rx_pdu_byte_i, rx_length_byte_i that arrive at the beginning of a
--! frame, have been registered and keep their values until the end of a frame.
--! The signal rx_fss_crc_fes_viol_ok_p_i, is a pulse at the end of the FES that combines
--! the check of the FSS, CRC, FES and the code violations. 

 Consumed_Frame_Validator: process (var_i, rx_ctrl_byte_i, rx_byte_index_i, rx_pdu_byte_i,
                                    rx_fss_crc_fes_viol_ok_p_i, rx_length_byte_i, rx_crc_wrong_p_i)
  begin
  
  case var_i is

  -------------------------------------------------------------------------------------------------
  when var_1 | var_2 | var_rst =>                                -- only for consumed RP_DAT frames

    --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    if rx_ctrl_byte_i = c_RP_DAT_CTRL_BYTE then                  -- comparison with the expected
      s_rx_ctrl_byte_ok     <= '1';                              -- RP_DAT.CTRL byte
    else
      s_rx_ctrl_byte_ok     <= '0';
    end if; 


    --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    if rx_pdu_byte_i = c_PROD_CONS_PDU_TYPE_BYTE then             -- comparison with the expected
      s_rx_pdu_byte_ok      <= '1';                               -- PDU_TYPE byte
    else 
      s_rx_pdu_byte_ok      <= '0' ;
    end if;


    --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    if rx_fss_crc_fes_viol_ok_p_i = '1' then                     -- checking the RP_DAT.Data.Length
                                                                 -- byte, when the end of frame
                                                                 -- arrives correctly.
      if rx_byte_index_i = (unsigned(rx_length_byte_i) + 5) then -- rx_byte_index starts counting 
        s_rx_length_byte_ok <= '1';                              -- from 0 and apart from the 
                                                                 -- user-data bytes, also counts the
      else                                                       -- Control, PDU_TYPE, Length,
                                                                 -- the 2 CRC and the FES bytes 
        s_rx_length_byte_ok <= '0';
      end if;                                                          

  
    else 
      s_rx_length_byte_ok   <= '0';
    end if;   


    --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    nfip_status_r_fcser_p_o <= rx_crc_wrong_p_i;


  -----------------------------------------------------------------------------------------------
  -- when var_presence | var_identif | var_3 | var_whatever =>

    -- s_rx_ctrl_byte_ok       <= '0';
    -- s_rx_pdu_byte_ok        <= '0';
    -- s_rx_length_byte_ok     <= '0';


  -------------------------------------------------------------------------------------------------
  when others =>

    s_rx_ctrl_byte_ok       <= '0';
    s_rx_pdu_byte_ok        <= '0';
    s_rx_length_byte_ok     <= '0';
    nfip_status_r_fcser_p_o <= '0';

  end case;

end process;            

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- -- -
  -- Concurrent signal assignment for the output signals
  cons_frame_ok_p_o          <= rx_fss_crc_fes_viol_ok_p_i and
                                s_rx_length_byte_ok        and
                                s_rx_ctrl_byte_ok          and
                                s_rx_pdu_byte_ok;

  nfip_status_r_tler_o       <= s_rx_length_byte_ok        and
                                s_rx_ctrl_byte_ok          and
                                s_rx_pdu_byte_ok;

end architecture rtl;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------