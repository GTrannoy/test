--________________________________________________________________________________________________|
--                                                                                                |
--                                        |The nanoFIP|                                           |
--                                                                                                |
--                                        CERN,BE/CO-HT                                           |
--________________________________________________________________________________________________|
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--! @file WF_model_constr_decoder.vhd                                                             |
---------------------------------------------------------------------------------------------------

--! standard library
library IEEE;

--! standard packages
use IEEE.STD_LOGIC_1164.all;  --! std_logic definitions
use IEEE.NUMERIC_STD.all;     --! conversion functions


---------------------------------------------------------------------------------------------------
--                                                                                               --
--                                     WF_model_constr_decoder                                   --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
-- unit name   WF_model_constr_decoder
--
--
--! @brief     Generation of the nanoFIP output S_ID and decoding of the inputs C_ID and M_ID.
--!            The output S_ID0 is a clock with period the double of uclk's period and the S_ID1
--!            is the opposite clock (it is '0' when S_ID0 is '1' and '1' when S_ID0 is '0').  
--!            Each one of the 4 pins of the M_ID and C_ID can be connected to either Vcc, Gnd,
--!            S_ID1 or S_ID0. Like this (after 2 uclk periods) the 8 bits of the Model and
--!            Constructor words take a value, according to the table: Gnd    00
--!                                                                    S_ID0  01
--!                                                                    S_ID1  10
--!                                                                    Vcc    11
--
--
--! @author    Pablo Alvarez Sanchez (pablo.alvarez.sanchez@cern.ch)\n
--!            Evangelia Gousiou (evangelia.gousiou@cern.ch)         \n
--
--! @date      08/2010
--
--
--! @version   v0.02
--
--
--! @details\n 
--
--!   \n<b>Dependencies:</b>\n
--!    WF_reset_unit\n
--
--
--!   \n<b>Modified by:</b>\n
--!     Pablo Alvarez Sanchez\n
--!     Evangelia Gousiou     \n
--
---------------------------------------------------------------------------------------------------
--
--!   \n\n<b>Last changes:</b>\n
--!     -> 11/09/2009  v0.01  EB  First version \n
--!     -> 20/08/2010  v0.02  EG  S_ID corrected so that S_ID0 is always the opposite of S_ID1
--!                               "for" loop replaced with signals concatenation; 
--!                               Counter is of C_RELOAD_MID_CID bits; Code cleaned-up \n
--
---------------------------------------------------------------------------------------------------
--
--! @todo 
--!
--
---------------------------------------------------------------------------------------------------

---/!\----------------------------/!\----------------------------/!\--------------------------/!\--
--                                    Sunplify Premier Warnings                                  --
-- -- --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --
--                                         No Warnings                                           --
---------------------------------------------------------------------------------------------------


--=================================================================================================
--!                             Entity declaration for WF_model_constr_decoder
--=================================================================================================
entity WF_model_constr_decoder is
  generic (C_RELOAD_MID_CID : natural);             --! reloading of model & constructor 
                                                    --! every 2^(C_RELOAD_MID_CID) uclk ticks
  port (
  -- INPUTS 
    -- User Interface general signal
    uclk_i :     in std_logic;                      --! 40 Mhz clock

    -- Signal from the WF_reset_unit
    nFIP_urst_i : in std_logic;                    --! nanoFIP internal reset

    -- WorldFIP settings
    m_id_i :     in  std_logic_vector (3 downto 0); --! Model identification settings
    c_id_i :     in  std_logic_vector (3 downto 0); --! Constructor identification settings


  -- OUTPUTS
    -- WorldFIP settings nanoFIP output
    s_id_o :     out std_logic_vector (1 downto 0); --! Identification selection

    -- Output to WF_prod_bytes_to_tx
    m_id_dec_o : out std_logic_vector (7 downto 0); --! Model identification decoded
    c_id_dec_o : out std_logic_vector (7 downto 0)  --! Constructor identification decoded
    );

end entity WF_model_constr_decoder;




--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of WF_model_constr_decoder is


  signal s_load_model_constr_p :       std_logic;
  signal s_counter, s_counter_full :   unsigned (C_RELOAD_MID_CID-1 downto 0);
  signal s_model_even, s_model_odd :   std_logic_vector (3 downto 0);
  signal s_constr_even, s_constr_odd : std_logic_vector (3 downto 0);


--=================================================================================================
--                                      architecture begin
--=================================================================================================
begin

  s_counter_full <= (others => '1');

---------------------------------------------------------------------------------------------------
--!@brief Synchronous process Model_Constructor_Decoder:
--! For M_ID and C_ID to be decoded, 2 uclk periods are needed: on the first uclk tick, the values
--! of all the odd bits of M_ID and C_ID are loaded on the registers s_model_odd/ s_constr_odd
--! and on the second uclk tick, the values of all the even bits are loaded on the registers
--! s_model_even/ s_constr_even.
--! The signal s_load_model_constr_p signals the recalculation of the model and constructor.
--! It is activated every 2^(C_RELOAD_MID_CID) uclk periods. At those moments, the odd and even
--! parts are concatenated to form the m_id_dec_o and c_id_dec_o decoded outputs.

  Model_Constructor_Decoder: process(uclk_i)
  begin
    if rising_edge(uclk_i) then                            -- initializations
      if nFIP_urst_i = '1' then
       s_counter     <= (others => '0');
       m_id_dec_o    <= (others => '0');
       c_id_dec_o    <= (others => '0');
       s_model_odd   <= (others => '0');
       s_model_even  <= (others => '0');
       s_constr_odd  <= (others => '0');
       s_constr_even <= (others => '0');

      else

       s_counter     <= s_counter +1;                      -- when the counter is full, the C_ID
                                                           -- and M_ID are recalculated
       
       s_model_odd   <= m_id_i;                            -- 1st clock tick for the loading of the
       s_model_even  <= s_model_odd;                       -- odd bits; 2nd clock tick for the even

       s_constr_odd  <= c_id_i;                            -- same for the constructor
       s_constr_even <= s_constr_odd;

        if s_load_model_constr_p = '1' then

          m_id_dec_o  <= s_model_even(3) & s_model_odd(3) &-- putting together odd and even bits
                         s_model_even(2) & s_model_odd(2) &
                         s_model_even(1) & s_model_odd(1) &
                         s_model_even(0) & s_model_odd(0);

          c_id_dec_o  <= s_constr_even(3) & s_constr_odd(3) & 
                         s_constr_even(2) & s_constr_odd(2) &
                         s_constr_even(1) & s_constr_odd(1) &
                         s_constr_even(0) & s_constr_odd(0);
        end if;
      end if;
    end if;
  end process;

  s_load_model_constr_p <= '1' when s_counter = s_counter_full 
                      else '0';                            -- recalculation of C_ID and M_ID 
                                                           -- when the counter fills up

                                                           -- 2 opposite clocks generated using
                                                           -- the LSB of the counter
  s_id_o <=  ((not s_counter(0)) & s_counter(0));          -- S_ID0: |--|__|--|__|--|__|--|__
                                                           -- S_ID1:  __|--|__|--|__|--|__|--|


end architecture rtl;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------