--_________________________________________________________________________________________________
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

--! specific packages
use work.WF_PACKAGE.all;      --! definitions of types, constants, entities

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
--! @author    Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)\n
--!            Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)    \n
--
--! @date      06/10/2010
--
--
--! @version   v0.03
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
--!     Evangelia Gousiou    \n
--
---------------------------------------------------------------------------------------------------
--
--!   \n\n<b>Last changes:</b>\n
--!     -> 11/09/2009  v0.01  PAS First version \n
--!     -> 20/08/2010  v0.02  EG  S_ID corrected so that S_ID0 is always the opposite of S_ID1
--!                               "for" loop replaced with signals concatenation; 
--!                               Counter is of c_RELOAD_MID_CID bits; Code cleaned-up \n
--!     -> 06/10/2010  v0.03  EG  generic c_RELOAD_MID_CID removed;
--!                               separate processes for counter and the rest
--
---------------------------------------------------------------------------------------------------
--
--! @todo 
--!
--
---------------------------------------------------------------------------------------------------

---/!\----------------------------/!\----------------------------/!\-------------------------/!\---
--                               Synplify Premier D-2009.12 Warnings                             --
-- -- --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --
--                                         No Warnings                                           --
---------------------------------------------------------------------------------------------------


--=================================================================================================
--!                             Entity declaration for WF_model_constr_decoder
--=================================================================================================
entity WF_model_constr_decoder is

  port (
  -- INPUTS 
    -- nanoFIP User Interface general signal
    uclk_i          : in std_logic;                      --! 40 Mhz clock

    -- Signal from the WF_reset_unit
    nfip_urst_i     : in std_logic;                      --! nanoFIP internal reset

    -- nanoFIP WorldFIP Settings (synchronised with uclk_i)
    constr_id_i     : in  std_logic_vector (3 downto 0); --! Constructor identification settings
    model_id_i      : in  std_logic_vector (3 downto 0); --! Model identification settings


  -- OUTPUTS
    -- nanoFIP WorldFIP Settings output
    select_id_o     : out std_logic_vector (1 downto 0); --! Identification selection

    -- Signal to the WF_prod_bytes_retriever unit
    constr_id_dec_o : out std_logic_vector (7 downto 0); --! Constructor identification decoded
    model_id_dec_o  : out std_logic_vector (7 downto 0)  --! Model identification decoded
    );

end entity WF_model_constr_decoder;




--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of WF_model_constr_decoder is


  signal s_counter_is_full                        : std_logic;
  signal s_counter                                : unsigned (1 downto 0);
  signal s_model_stage2, s_model_stage1           : std_logic_vector (3 downto 0);
  signal s_constr_stage2, s_constr_stage1         : std_logic_vector (3 downto 0);


--=================================================================================================
--                                      architecture begin
--=================================================================================================
begin

---------------------------------------------------------------------------------------------------
--!@brief Synchronous process Model_Constructor_Decoder:
--! For M_ID and C_ID to be loaded, 2 uclk periods are needed: on the first uclk tick, the values
--! of all the odd bits of M_ID & C_ID are loaded on the registers s_model_stage1/ s_constr_stage1
--! and on the second uclk tick, the values of the odd bits move to the registers s_model_stage2/
--! s_constr_stage2, giving place to all the even bits to be loaded to the s_model_stage1/
--! s_constr_stage1. On a third uclk tick the loaded odd and even values are combined to give
--! the decoded outputs (model_id_dec_o & constr_id_dec_o).

  Model_Constructor_Decoder: process (uclk_i)
  begin
    if rising_edge (uclk_i) then                    -- initializations
      if nfip_urst_i = '1' then
       model_id_dec_o  <= (others => '0');
       constr_id_dec_o <= (others => '0');
       s_model_stage1  <= (others => '0');
       s_model_stage2  <= (others => '0');
       s_constr_stage1 <= (others => '0');
       s_constr_stage2 <= (others => '0');

      else
      
       s_model_stage1   <= model_id_i;            -- after 2 uclk ticks stage1 keeps the even bits
       s_model_stage2  <= s_model_stage1;         -- and stage2 the odd ones

       s_constr_stage1  <= constr_id_i;           -- same for the constructor
       s_constr_stage2 <= s_constr_stage1;

       if  s_counter="10" then

         model_id_dec_o  <= s_model_stage2(3) & s_model_stage1(3) & -- putting together 
                            s_model_stage2(2) & s_model_stage1(2) & -- odd and even bits
                            s_model_stage2(1) & s_model_stage1(1) &
                            s_model_stage2(0) & s_model_stage1(0);

         constr_id_dec_o <= s_constr_stage1(3) & s_constr_stage2(3) & 
                            s_constr_stage1(2) & s_constr_stage2(2) &
                            s_constr_stage1(1) & s_constr_stage2(1) &
                            s_constr_stage1(0) & s_constr_stage2(0);
       end if;

      end if;
    end if;
  end process;


---------------------------------------------------------------------------------------------------
--!@brief Instantiation of a counter WF_incr_counter

  Free_Counter: WF_incr_counter
  generic map(g_counter_lgth => 2)
  port map(
    uclk_i            => uclk_i,
    nfip_urst_i       => nfip_urst_i,
    reinit_counter_i  => '0',
    incr_counter_i    => '1',
    -----------------------------------------
    counter_o         => s_counter,
    counter_is_full_o => s_counter_is_full);
    -----------------------------------------
      

---------------------------------------------------------------------------------------------------
--!@brief Concurrent signal assignment for the output select_id_o

  select_id_o <=  ((not s_counter(0)) & s_counter(0)); -- 2 opposite clocks generated using
                                                       -- the LSB of the counter 
                                                       -- uclk_i: |-|__|-|__|-|__|-|__|-|__|-|_
                                                       -- S_ID0 : |----|____|----|____|----|___
                                                       -- S_ID1 : |____|----|____|----|____|---


end architecture rtl;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------