--=============================================================================
--! @file settings.vhd
--! @brief Settings generator
--=============================================================================
--! Standard library
library IEEE;
--! Standard packages
use IEEE.STD_LOGIC_1164.all; --! std_logic definitions
use IEEE.NUMERIC_STD.all;    --! conversion functions


-------------------------------------------------------------------------------
--                                                                           --
--                                  settings                                 --
--                                                                           --
--                               CERN, BE/CO/HT                              --
--                                                                           --
-------------------------------------------------------------------------------
--
-- unit name: settings
--
--! @brief Settings generator.
--!
--! Used in the NanoFIP design. \n
--! The Settings unit generates the constants used inside the design.
--! Some inputs are directly taken over from the input pins as they don't need
--! any treatment.
--!
--! SEE mitigation techniques used:
--! - mostly combinatiorial logic \n
--! - registered constructor and model id regenerated on request \n
--! 
--! @author Erik van der Bij (Erik.van.der.Bij@cern.ch)
--
--! @date 10/07/2009
--
--! @version v0.01
--
--! @details 
--!
--! <b>Dependencies:</b>\n
--! none                \n
--!
--! <b>References:</b>\n
--! 
--! 
--!
--! <b>Modified by:</b>\n
--! Erik van der Bij
-------------------------------------------------------------------------------
--! \n\n<b>Last changes:</b>\n
--! 10/07/2009  v0.01  EB  First version \n
--!
-------------------------------------------------------------------------------
--! @todo Create testbench and simulate \n
--!
-------------------------------------------------------------------------------


--=============================================================================
--! Entity declaration for settings
--=============================================================================
entity settings is

port (
-------------------------------------------------------------------------------
--  General connections
-------------------------------------------------------------------------------
   clk       : in  std_logic; --! Clock used for generating id's


-------------------------------------------------------------------------------
--  Connections to pins of the NanoFIP
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- WorldFIP settings
-------------------------------------------------------------------------------
      --! Bit rate         \n
      --! 00: 31.25 kbit/s \n
      --! 01: 1 Mbit/s     \n
      --! 10: 2.5 Mbit/s   \n
      --! 11: reserved, do not use
   rate_i    : in  std_logic_vector (1 downto 0); --! Bit rate

      --! Subscriber number coding. Station address.
   subs_i    : in  std_logic_vector (7 downto 0); --! Subscriber number coding.

      --! Identification selection (see M_ID, C_ID)
   s_id_o    : out std_logic_vector (1 downto 0); --! Identification selection

      --! Identification variable settings. 
      --! Connect the ID inputs either to Gnd, Vcc, S_ID[0] or S_ID[1] to 
      --! obtain different values for the Model data (i=0,1,2,3).\n
      --! M_ID[i] connected to: Gnd S_ID0 SID1 Vcc               \n
      --! Model [2*i]            0    1    0    1                \n
      --! Model [2*i+1]          0    0    1    1
   m_id_i    : in  std_logic_vector (3 downto 0); --! Model identification settings

      --! Identification variable settings.
      --! Connect the ID inputs either to Gnd, Vcc, S_ID[0] or S_ID[1] to 
      --! obtain different values for the Model data (i=0,1,2,3).\n
      --! C_ID[i] connected to: Gnd S_ID0 SID1 Vcc               \n
      --! Constructor[2*i]       0    1    0    1                \n
      --! Constructor[2*i+1]     0    0    1    1
   c_id_i    : in  std_logic_vector (3 downto 0); --! Constructor identification settings

      --! Produced variable data length \n
      --! 000: 2 Bytes                  \n
      --! 001: 8 Bytes                  \n
      --! 010: 16 Bytes                 \n
      --! 011: 32 Bytes                 \n
      --! 100: 64 Bytes                 \n
      --! 101: 124 Bytes                \n
      --! 110: reserved, do not use     \n
      --! 111: reserved, do not use     \n
      --! Actual size: +1 NanoFIP Status byte +1 MPS Status byte (last transmitted) 
      --! Note: when SLONE=Vcc, p3_lgth_i should be set to 000.
   p3_lgth_i : in  std_logic_vector (2 downto 0); --! Produced variable data length

      --! Stand-alone mode
      --! If connected to Vcc, disables sending of NanoFIP status together with 
      --! the produced data.
   slone_i   : in  std_logic; --! Stand-alone mode

      --! No NanoFIP status transmission
      --! If connected to Vcc, disables sending of NanoFIP status together with 
      --! the produced data.
   nostat_i  : in  std_logic; --! No NanoFIP status transmission


-------------------------------------------------------------------------------
--  Connections to internal logic
-------------------------------------------------------------------------------
      --! When high, will refresh settings_model/const_id within two clock cycles
   req_id    : in  std_logic; --! Request generation of Model and Constructor ID

      --! Bit rate. 
      --! Straight copy of input pins (allows for further treatment if needed).
   settings_rate : out std_logic_vector (1 downto 0); --! Bit rate

      --! Subscriber number. Station address.
      --! Straight copy of input pins (allows for further treatment if needed).
   settings_subs : out  std_logic_vector (7 downto 0); --! Subscriber number
   
      --! Model Identification. First byte. Second byte is not settable.
      --! Used for production of Identification Variable (10xyh).
   settings_model_id: out std_logic_vector (7 downto 0);  --! Model identification  

      --! Constructor Identification. Second byte. First byte is not settable.
      --! Used for production of Identification Variable (10xyh).
   settings_const_id: out std_logic_vector (7 downto 0);  --! Constructor identification  

      --! Produced variable data length, based on p3_lgth_i and nostat_i
      --! inputs. \n
      --! Outputs the number of data bytes, including the NanoFIP status and
      --! the MPS Status and can be used as the second byte sent and for
      --! variable length counting purposes.    \n <tt>
      --! p3_lgth          nostat=0  nostat=1   \n
      --! 000: 2 Bytes   =>   4          3      \n
      --! 001: 8 Bytes   =>  10          9      \n
      --! 010: 16 Bytes  =>  18         17      \n
      --! 011: 32 Bytes  =>  34         33      \n
      --! 100: 64 Bytes  =>  66         65      \n
      --! 101: 124 Bytes => 126        125      \n
      --! 110: reserved  => 126        125  do not use - mapped onto 101 \n
      --! 111: reserved  => 126        125  do not use - mapped onto 111 \n </tt>
      --! Note: when SLONE=Vcc, p3_lgth_i should be set to 000.
   settings_p3_lgth: out std_logic_vector (7 downto 0); --! # of bytes incl status

      --! Stand-alone mode.
      --! If connected to Vcc, disables sending of NanoFIP status together with 
      --! the produced data.\n
      --! Straight copy of input pin (allows for further treatment if needed).
   settings_slone : out std_logic; --! Stand-alone mode

      --! No NanoFIP status transmission when 1.
      --! Straight copy of input pin (allows for further treatment if needed).\n
   settings_nostat  : out std_logic --! No NanoFIP status transmission
);

end entity settings;



-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- COMPONENT DECLARATIONS
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

--=============================================================================
--=============================================================================
--! Architecture of settings
--=============================================================================
--=============================================================================

architecture rtl of settings is

   type      t_id_state is (IDLE, GET_ODD, PREP, GET_EVEN); --! Type for state
   attribute ENUM_ENCODING : STRING;                        --! define values
   attribute ENUM_ENCODING of t_id_state : type is "00 01 11 10"; --! gray code

   signal    s_id_state    : t_id_state;  --! current state

begin

--=============================================================================
-- Concurrent signal assignments
--=============================================================================
   -- slone, rate, nostat are just copies to allow further treatment in this 
   -- module if needed.
   settings_rate   <= rate;
   settings_subs   <= subs_i;
   settings_slone  <= slone_i;
   settings_nostat <= nostat_i; 

   -- settings_p3_lgth combinatorially generated out of p3_lgth_i & no_stat_i
   -- These signals come directly from input pins.
   -- Outputs the number of data bytes, including the NanoFIP status and
   -- the MPS Status.
   with (p3_lgth_i & no_stat_i) select
      settings_p3_lgth <= std_logic_vector(to_unsigned(  4, 8)) when "000" & '0', 
      settings_p3_lgth <= std_logic_vector(to_unsigned(  3, 8)) when "000" & '1', 
      settings_p3_lgth <= std_logic_vector(to_unsigned( 10, 8)) when "001" & '0', 
      settings_p3_lgth <= std_logic_vector(to_unsigned(  9, 8)) when "001" & '1', 
      settings_p3_lgth <= std_logic_vector(to_unsigned( 18, 8)) when "010" & '0', 
      settings_p3_lgth <= std_logic_vector(to_unsigned( 17, 8)) when "010" & '1', 
      settings_p3_lgth <= std_logic_vector(to_unsigned( 34, 8)) when "011" & '0', 
      settings_p3_lgth <= std_logic_vector(to_unsigned( 33, 8)) when "011" & '1', 
      settings_p3_lgth <= std_logic_vector(to_unsigned( 66, 8)) when "100" & '0', 
      settings_p3_lgth <= std_logic_vector(to_unsigned( 65, 8)) when "100" & '1', 
      settings_p3_lgth <= std_logic_vector(to_unsigned(126, 8)) when "101" & '0', 
      settings_p3_lgth <= std_logic_vector(to_unsigned(125, 8)) when "101" & '1', 
      settings_p3_lgth <= std_logic_vector(to_unsigned(126, 8)) when "110" & '0', 
      settings_p3_lgth <= std_logic_vector(to_unsigned(125, 8)) when "110" & '1', 
      settings_p3_lgth <= std_logic_vector(to_unsigned(126, 8)) when "111" & '0', 
      settings_p3_lgth <= std_logic_vector(to_unsigned(125, 8)) when "111" & '1'; 




--=============================================================================
-- Processes
--=============================================================================
--! State machine to retrieve the full ID codes.
--! Samples the model/constant id settings inputs only when requested by req_id.
--! This way the s_id_o outputs stay fixed and give less noise.
--! Takes 4 clock cycles to have the settings available.
p_id_FSM_state: process(clk)
begin
if (clk'event and clk='1') then
   -- no reset needed, machine will always return to its idle state anyway
   case s_id_state is
      when IDLE     =>
         if req_id = '1' then s_id_state <= GET_ODD  -- wait for req
                         else s_id_state <= IDLE;
         end if;
         -- settings_model_id and settings_const_id keep old value. 
         -- A register is induced.
         -- Do not sample continuously to have a more quieter design.


      when GET_ODD  =>   s_id_state <= PREP; -- grab value for odd bits when 
         settings_model_id(1) <= m_id_i(0);  -- going to the PREP state.
         settings_model_id(3) <= m_id_i(1);
         settings_model_id(5) <= m_id_i(2);
         settings_model_id(7) <= m_id_i(3);

         settings_const_id(1) <= c_id_i(0);
         settings_const_id(3) <= c_id_i(1);
         settings_const_id(5) <= c_id_i(2);
         settings_const_id(7) <= c_id_i(3);


      when PREP     =>   s_id_state <= GET_EVEN;
         -- settings_model_id and settings_const_id keep old value. 
         -- have this idle state to allow the inputs to settle.
         -- Tcko+Tsu, go through I/O buffers and external jumpers.


      when GET_EVEN =>
         if req_id = '0' then s_id_state <= IDLE; -- wait until req gone
                         else s_id_state <= GET_EVEN;
         end if;
         settings_model_id(0) <= m_id_i(0);  -- if req_id stays, continuously
         settings_model_id(2) <= m_id_i(1);  -- samples the even bits.
         settings_model_id(4) <= m_id_i(2);
         settings_model_id(6) <= m_id_i(3);

         settings_const_id(0) <= c_id_i(0);
         settings_const_id(2) <= c_id_i(1);
         settings_const_id(4) <= c_id_i(2);
         settings_const_id(6) <= c_id_i(3);
   end case
end if; -- clk
end process p_id_FSM_state;


--! Generate outputs that select which bits are sampled.
--! When s_id_o(0)==0, the odd bits are sampled.
--! When s_id_o(1)==0, the even bits are sampled.
p_id_FSM_output: process (s_id_state)
begin
   case s_id_state is
      when IDLE     => s_id_o <= "10";  -- does not induce a register:
      when GET_ODD  => s_id_o <= "10";  --  s_id_o(0)=     s_id_state(0)
      when PREP     => s_id_o <= "01";  --  s_id_o(1)= not s_id_state(0)
      when GET_EVEN => s_id_o <= "01";
   end case;
end process p_id_FSM_output;



end architecture rtl;
-------------------------------------------------------------------------------
--                          E N D   O F   F I L E
-------------------------------------------------------------------------------
