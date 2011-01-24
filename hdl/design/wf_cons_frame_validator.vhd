--_________________________________________________________________________________________________
--                                                                                                |
--                                        |The nanoFIP|                                           |
--                                                                                                |
--                                        CERN,BE/CO-HT                                           |
--________________________________________________________________________________________________|
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--! @file WF_cons_frame_validator.vhd                                                             |
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
--                                    WF_cons_frame_validator                                    --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
--
--! @brief     Validation of a consumed RP_DAT frame with respect to the correctness of:
--!              o the Control, PDU_TYPE and Length bytes;
--!                the bytes are received from the the WF_cons_bytes_processor unit.
--!              o the CRC, FSS, FES bytes and the Manchester encoding;
--!                the rx_fss_crc_fes_manch_ok_p_i pulse from the WF_rx_deserializer unit groups
--!                these checks.
--!
--!            The output cons_frame_ok_p is used by the WF_cons_outcome unit, which handles
--!            accordingly the signals VAR1_RDY/ VAR2_RDY   (if it had been a var_1 or a var_2)
--!            or the signals nFIP_and_FD_p/ assert_RSTON_p (if it had been a var_rst) 
--!
--!
--!            Reminder:
--!
--!            Consumed RP_DAT frame structure :
--!             ___________ ______  _______ ______ _________________________ _______  ___________ _______
--!            |____FSS____|_Ctrl_||__PDU__|_LGTH_|_____..Applic-Data.._____|__MPS__||____FCS____|__FES__|
--!
--!                                        |---------------LGTH bytes---------------|
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
--!            WF_cons_bytes_processor \n
--!            WF_engine_control       \n
--!            WF_rx_deserializer      \n
--
--
--!   \n<b>Modified by:</b>\n
--!            Evangelia Gousiou (Evangelia.Gousiou@cern.ch)
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
--                               Synplify Premier D-2009.12 Warnings                             --
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
    -- Signals from the WF_cons_bytes_processor unit
    cons_ctrl_byte_i           : in std_logic_vector (7 downto 0); --! received RP_DAT Control byte
    cons_lgth_byte_i           : in std_logic_vector (7 downto 0); --! received RP_DAT Length byte
    cons_pdu_byte_i            : in std_logic_vector (7 downto 0); --!received RP_DAT PDU_TYPE byte          

    -- Signal from the WF_rx_deserializer unit
    rx_fss_crc_fes_manch_ok_p_i: in std_logic; --! indication of a frame with correct FSS, FES, CRC 
                                               --! and manch. encoding

   -- Signals from the WF_engine_control unit
    rx_byte_index_i            : in std_logic_vector (7 downto 0); --! index of byte being received
    var_i                      : in t_var;      --! variable type that is being treated


  -- OUTPUT
    -- Signal to the WF_cons_outcome unit
    cons_frame_ok_p_o          : out std_logic; --! pulse at the end of the FES
                                                --! indicating a valid received RP_DAT frame

    -- Signal to the WF_status_bytes_gen unit
    nfip_status_r_tler_o       : out std_logic  --! received PDU_TYPE or Length error
                                                --! nanoFIP status byte bit 6 
      );
end entity WF_cons_frame_validator;


--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of WF_cons_frame_validator is

signal s_cons_ctrl_byte_ok, s_cons_pdu_byte_ok, s_cons_lgth_byte_ok : std_logic;

--=================================================================================================
--                                      architecture begin
--=================================================================================================  
begin

--------------------------------------------------------------------------------------------------- 
--!@brief Combinatorial process Consumed_Frame_Validator: validation of an RP_DAT 
--! frame with respect to the Ctrl, PDU_TYPE and Length bytes as well as to the CRC, FSS, FES and
--! to the Manchester encoding. The bytes cons_ctrl_byte_i, cons_pdu_byte_i, cons_lgth_byte_i that
--! arrive at the beginning of a frame, have been registered and keep their values until the end
--! of it. The signal rx_fss_crc_fes_manch_ok_p_i, is a pulse at the end of the FES that combines
--! the checks of the FSS, CRC, FES and of the manch. encoding. 

 Consumed_Frame_Validator: process (var_i, cons_ctrl_byte_i, rx_byte_index_i, cons_pdu_byte_i,
                                    rx_fss_crc_fes_manch_ok_p_i, cons_lgth_byte_i)
  begin
  
  case var_i is

  -------------------------------------------------------------------------------------------------
  when var_1 | var_2 | var_rst =>                               -- only for consumed RP_DAT frames

    --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    if cons_ctrl_byte_i = c_RP_DAT_CTRL_BYTE then               -- comparison with the expected
      s_cons_ctrl_byte_ok   <= '1';                             -- RP_DAT.CTRL byte
    else
      s_cons_ctrl_byte_ok   <= '0';
    end if; 


    --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    if cons_pdu_byte_i = c_PROD_CONS_PDU_TYPE_BYTE then         -- comparison with the expected
      s_cons_pdu_byte_ok    <= '1';                             -- PDU_TYPE byte
    else 
      s_cons_pdu_byte_ok    <= '0' ;
    end if;


    --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    if rx_fss_crc_fes_manch_ok_p_i = '1' then                   -- checking the RP_DAT.Data.Length
                                                                -- byte, when the FES arrives.
      if unsigned(rx_byte_index_i ) = (unsigned(cons_lgth_byte_i) + 5) then 
        s_cons_lgth_byte_ok <= '1';                             -- rx_byte_index starts counting 
                                                                -- from 0 and apart from the 
                                                                -- user-data bytes, also counts the
      else                                                      -- Control, PDU_TYPE, Length,
                                                                -- the 2 CRC and the FES bytes 
        s_cons_lgth_byte_ok <= '0';
      end if;                                                          

  
    else 
      s_cons_lgth_byte_ok   <= '0';
    end if;   


  -------------------------------------------------------------------------------------------------
  when others =>

    s_cons_ctrl_byte_ok     <= '0';
    s_cons_pdu_byte_ok      <= '0';
    s_cons_lgth_byte_ok     <= '0';

  end case;

end process;            


  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- -- -
  -- Concurrent signal assignments 

  cons_frame_ok_p_o          <= rx_fss_crc_fes_manch_ok_p_i and
                                s_cons_lgth_byte_ok         and
                                s_cons_ctrl_byte_ok         and
                                s_cons_pdu_byte_ok;

  nfip_status_r_tler_o       <= s_cons_lgth_byte_ok         and
                                s_cons_ctrl_byte_ok         and
                                s_cons_pdu_byte_ok;


end architecture rtl;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------