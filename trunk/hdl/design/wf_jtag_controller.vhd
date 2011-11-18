--_________________________________________________________________________________________________
--                                                                                                |
--                                         |The nanoFIP|                                          |
--                                                                                                |
--                                         CERN,BE/CO-HT                                          |
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--                                                                                                |
--                                       wf_jtag_controller                                       |
--                                                                                                |
---------------------------------------------------------------------------------------------------
-- File         wf_jtag_controller.vhd                                                            |
--                                                                                                |
-- Description  After the reception and validation of a consumed var_4 RP_DAT frame, the unit     |
--              is responsible for driving the "nanoFIP, User Interface, JTAG Controller" signals |
--              JC_TCK, JC_TMS, JC_TDI and for sampling the JC_TDO input.                         |
--                                                                                                |
--                o JC_TCK is a 5 MHz clock generated by the 40 MHz uclk; a cycle is created for  |
--                  every JC_TMS/ JC_TDI pair.                                                    |
--                                                                                                |
--                o JC_TMS and JC_TDI are being retreived from the JC_consumed memory and are     |
--                  put to the corresponding outputs on each falling edge of the JC_TCK.          |
--                                                                                                |
--                o The first and second data bytes of the JC_consumed memory do not contain      |
--                  JC_TMS/ JC_TDI bits, but are used to indicate, in big endian order, the       |
--                  amount of JC_TMS and JC_TDI bits that have to be output.                      |
--                                                                                                |
--                o the JC_TDO input is sampled on the rising edge of JC_TCK; only the last       |
--                  sampled JC_TDO bit is significant. It is registered and sent to the           |
--                  wf_production unit for it to be delivered in the next produced var_5 frame.   |
--                                                                                                |
--                                                                                                |
-- Authors      Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)                             |
--              Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)                                 |
-- Date         09/2011                                                                           |
-- Version      v0.02                                                                             |
-- Depends on   wf_reset_unit                                                                     |
--              wf_consumption                                                                    |
----------------                                                                                  |
-- Last changes                                                                                   |
--     07/07/2011  v0.01  EG  First version                                                       |
--        09/2011  v0.02  EG  added counter for counting the outgoing TMS/TDI bits; combinatorial |
--                            was too heavy; changed a bit state machine to include counter       |
--                            put session_timedout in the synchronous FSM process                 |
--        11/2011  v0.021 EG  timeout counter has different size (constant added)                 |
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
--                               GNU LESSER GENERAL PUBLIC LICENSE                                |
--                              ------------------------------------                              |
-- This source file is free software; you can redistribute it and/or modify it under the terms of |
-- the GNU Lesser General Public License as published by the Free Software Foundation; either     |
-- version 2.1 of the License, or (at your option) any later version.                             |
-- This source is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;       |
-- without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.      |
-- See the GNU Lesser General Public License for more details.                                    |
-- You should have received a copy of the GNU Lesser General Public License along with this       |
-- source; if not, download it from http://www.gnu.org/licenses/lgpl-2.1.html                     |
---------------------------------------------------------------------------------------------------



--=================================================================================================
--                                       Libraries & Packages
--=================================================================================================

-- Standard library
library IEEE;
use IEEE.STD_LOGIC_1164.all; -- std_logic definitions
use IEEE.NUMERIC_STD.all;    -- conversion functions
-- Specific library
library work;
use work.wf_PACKAGE.all;     -- definitions of types, constants, entities


--=================================================================================================
--                            Entity declaration for wf_jtag_controller
--=================================================================================================
entity wf_jtag_controller is port(
  -- INPUTS
    -- nanoFIP User Interface, General signal
    uclk_i          : in std_logic;                      -- 40 MHz clock

    -- nanoFIP User Interface, JTAG Controller signal
    jc_tdo_i        : in std_logic;                      -- JTAG TDO input 

    -- Signal from the wf_reset_unit
    nfip_rst_i      : in std_logic;                      -- nanoFIP internal reset

    -- Signals from the wf_consumption unit
    jc_start_p_i    : in std_logic;                      -- pulse upon validation of a var_4 RP_DAT frame
    jc_mem_data_i   : in std_logic_vector (7 downto 0);  -- byte retreived from the JC_consumed memory


  -- OUTPUTS
    -- nanoFIP User Interface, JTAG Controller signals
    jc_tms_o        : out std_logic;                     -- JTAG TMS output
    jc_tdi_o        : out std_logic;                     -- JTAG TDI output
    jc_tck_o        : out std_logic;                     -- JTAG TCK output

    -- Signal to the wf_production unit
    jc_tdo_byte_o   : out std_logic_vector (7 downto 0); -- byte containing the TDO sample for the next var_5 

    -- Signal to the wf_consumption unit
    jc_mem_adr_rd_o : out std_logic_vector (8 downto 0));-- address of byte to be retreived from the JC_cons memory

end entity wf_jtag_controller;


--=================================================================================================
--                                    architecture declaration
--=================================================================================================
architecture rtl of wf_jtag_controller is
  -- FSM
  type jc_st_t  is (IDLE, GET_BYTE, PLAY_BYTE, SET_ADDR);
  signal jc_st, nx_jc_st                           : jc_st_t;
  signal s_idle, s_play_byte, s_set_addr           : std_logic;
  signal s_not_play_byte                           : std_logic;
  signal s_session_timedout                        : std_logic;
  -- bytes counter
  signal s_bytes_c, s_bytes_c_d1                   : unsigned (6 downto 0);
  -- retrieval of the number of TMS/ TDI bits that have to be delivered
  signal s_frame_bits_lsb, s_frame_bits_msb        : std_logic_vector (7 downto 0);
  signal s_frame_bits                              : unsigned (15 downto 0);
  -- number of TMS/ TDI bits delivered so far
  signal s_bits_so_far                             : unsigned (15 downto 0);
  -- TCK generation
  signal s_tck, s_tck_c_is_full                    : std_logic;
  signal s_tck_r_edge_p, s_tck_f_edge_p            : std_logic;
  signal s_tck_c, s_tck_period, s_tck_four_periods : unsigned (c_FOUR_JC_TCK_C_LGTH-1 downto 0);
  signal s_tck_half_period, s_tck_quarter_period   : unsigned (c_FOUR_JC_TCK_C_LGTH-1 downto 0);

 
--=================================================================================================
--                                       architecture begin
--=================================================================================================
begin


---------------------------------------------------------------------------------------------------
--                                             FSM                                               --
---------------------------------------------------------------------------------------------------

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- JTAG Controller FSM: the state machine is divided in three parts (a clocked process
-- to store the current state, a combinatorial process to manage state transitions and finally a
-- combinatorial process to manage the output signals), which are the three processes that follow.

-- After the reception of a var_4 RP_DAT frame the FSM starts retrieving one by one bytes from
-- the JC_consumed memory. The first two bytes concatenated in big endian encoding indicate the
-- total amount of TMS/ TDI bits that have to be retrieved and output.
-- The rest of the bytes contain the TMS/ TDI bits.
-- The FSM goes back to IDLE if the counter that counts the amount the bits that have been output
-- reaches the total amount.

-- To add a robust layer of protection to the FSM, we have implemented a counter, dependent only on
-- the system clock, that from any state can bring the FSM back to IDLE. A frame with the maximum
-- number of TMS/ TDI bits needs: 122 bytes * ((4 * JC_TCK) + 2 uclk) seconds to be treated.
-- For a 5 MHz JC_TCK clock this is 103.7 us. We use a counter of 13 bits which means that the FSM
-- is reset if 204.8 us have passed since it has left the IDLE state.

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Synchronous process JC_FSM_Sync: storage of the current state of the FSM

  JC_FSM_Sync: process (uclk_i)
    begin
      if rising_edge (uclk_i) then
        if nfip_rst_i = '1' or s_session_timedout = '1' then
          jc_st <= IDLE;
        else
          jc_st <= nx_jc_st;
        end if;
      end if;
    end process;


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Combinatorial process JC_FSM_Comb_State_Transitions: Definition of the state
-- transitions of the FSM.

  JC_FSM_Comb_State_Transitions: process (jc_st, s_bytes_c, s_frame_bits,s_bits_so_far, jc_start_p_i,
                                                    s_tck_c_is_full, s_tck_r_edge_p, s_tck_f_edge_p)
  begin

  case jc_st is


    when IDLE      =>
                        if jc_start_p_i = '1' then     -- consumed var_4 frame validated
                          nx_jc_st <= SET_ADDR;

                        else
                          nx_jc_st <= IDLE;
                        end if;

    when SET_ADDR  =>
                          nx_jc_st <= GET_BYTE;        -- 1 uclk cycle for the setting of the memory
                                                       -- address; byte available at the next cycle 


    when GET_BYTE  =>

                        if s_bytes_c < 2 then          -- 2 first bytes: amount of JC_TMS & JC_TDI bits
                          nx_jc_st <= SET_ADDR;
                        else                           -- the rest of the bytes have to be "played"
                          nx_jc_st <= PLAY_BYTE;
                        end if;

    when PLAY_BYTE =>

                        if s_frame_bits <= 0 or s_frame_bits > c_MAX_FRAME_BITS then
                          nx_jc_st <= IDLE;            -- outside expected limits

                        elsif s_frame_bits > s_bits_so_far then -- still available bits to go..

                          if s_tck_c_is_full = '1' then-- byte completed; a new one has
                            nx_jc_st <= SET_ADDR;      -- to be retrieved
                          else                         -- byte being output
                            nx_jc_st <= PLAY_BYTE;
                          end if;

                        else                           -- last bit

                          if s_tck_r_edge_p = '1' or s_tck_f_edge_p = '1' then
                            nx_jc_st <= IDLE;          -- wait until the completion of a JC_TCK cycle
                          else
                            nx_jc_st <= PLAY_BYTE;
                          end if;
                        end if;

    when OTHERS    =>
                        nx_jc_st <= IDLE;

    end case;
  end process;


  JCTRLer_FSM_Comb_Output_Signals: process (jc_st)

  begin

    case jc_st is

    when IDLE      =>
                        -----------------------------
                          s_idle      <= '1';
                        -----------------------------
                          s_set_addr  <= '0';
                          s_play_byte <= '0';


    when SET_ADDR  =>

                          s_idle      <= '0';
                        -----------------------------
                          s_set_addr  <= '1';
                        -----------------------------
                          s_play_byte <= '0';


    when GET_BYTE  =>

                          s_idle      <= '0';
                          s_set_addr  <= '0';
                          s_play_byte <= '0';


    when PLAY_BYTE =>

                          s_idle      <= '0';
                          s_set_addr  <= '0';
                        -----------------------------
                          s_play_byte <= '1';
                        -----------------------------


    when OTHERS    =>
                        -----------------------------
                          s_idle      <= '1';
                        -----------------------------
                          s_set_addr  <= '0';
                          s_play_byte <= '0';

    end case;
  end process;



---------------------------------------------------------------------------------------------------
--                                       JC_TCK generation                                       --
---------------------------------------------------------------------------------------------------
-- Instantiation of a wf_incr_counter used for the generation of the JC_TCK output clock.
-- The counter is filled up after having counted 4 JC_TCK periods; this corresponds to the amount
-- of periods needed for outputting a full JC_TMS/ JC_TDI byte.

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -
  JC_TCK_periods_counter: wf_incr_counter
  generic map(g_counter_lgth => c_FOUR_JC_TCK_C_LGTH)
  port map(
    uclk_i            => uclk_i,
    counter_reinit_i  => s_not_play_byte,
    counter_incr_i    => s_play_byte,
    counter_is_full_o => s_tck_c_is_full,
    ------------------------------------------
    counter_o         => s_tck_c);
    ------------------------------------------
    s_not_play_byte   <= not s_play_byte;

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  JC_TCK_Construction: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if nfip_rst_i = '1' then
        s_tck   <= '1';
      else

        if s_tck_f_edge_p = '1' or s_tck_r_edge_p = '1' then
          s_tck <= not s_tck;
        end if;

      end if;
    end if;
  end process;

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  s_tck_four_periods   <= (others => '1');              -- # uclk ticks for 4   JC_TCK periods i.e delivery of 1 byte
  s_tck_period         <= (s_tck_four_periods srl 2)+1; -- # uclk ticks for 1   JC_TCK period
  s_tck_half_period    <= (s_tck_four_periods srl 3)+1; -- # uclk ticks for 1/2 JC_TCK period
  s_tck_quarter_period <= (s_tck_four_periods srl 4)+1; -- # uclk ticks for 1/4 JC_TCK period

  -- s_tck_four_periods  : >------------------------<
  -- s_tck_period        :   >-----<
  -- s_tck_half_period   :   >--<
  -- s_tck_quarter_period: >-<
  -- s_tck               :  -|__|--|__|--|__|--|__|-

  s_tck_f_edge_p       <= '1' when (s_tck_c = s_tck_quarter_period) or 
                                   (s_tck_c = (2*s_tck_half_period) +s_tck_quarter_period) or
                                   (s_tck_c = (4*s_tck_half_period) +s_tck_quarter_period) or
                                   (s_tck_c = (6*s_tck_half_period) +s_tck_quarter_period) else '0';

  s_tck_r_edge_p       <= '1' when (s_tck_c = s_tck_half_period+s_tck_quarter_period) or
                                   (s_tck_c = (3*s_tck_half_period) +s_tck_quarter_period) or
                                   (s_tck_c = (5*s_tck_half_period) +s_tck_quarter_period) or
                                   (s_tck_c = (7*s_tck_half_period) +s_tck_quarter_period) else '0';

  jc_tck_o             <= s_tck;  



---------------------------------------------------------------------------------------------------
--                                         Bytes counter                                         --
---------------------------------------------------------------------------------------------------
-- Instantiation of a wf_incr_counter for the counting of the bytes that are being retreived from
-- the JC_cons memory.

  JC_bytes_counter: wf_incr_counter
  generic map(g_counter_lgth => 7)
  port map(
    uclk_i            => uclk_i,
    counter_reinit_i  => s_idle,
    counter_incr_i    => s_set_addr,
    counter_is_full_o => open,
    ------------------------------------------
    counter_o         => s_bytes_c);
    ------------------------------------------

    jc_mem_adr_rd_o   <= std_logic_vector (resize((s_bytes_c + 2), jc_mem_adr_rd_o'length));
                      -- "+2" is bc the first 2 bytes in the memory (PDU_TYPE and LGTH) are not read



---------------------------------------------------------------------------------------------------
--                                    Delivered bits counter                                     --
---------------------------------------------------------------------------------------------------
-- Creation of a counter counting the number of TMS and TDI bits that have been output.
-- The output of this counter, s_bits_so_far, could have been derived from the s_bytes_c with some
-- combinatorial logic, but then the timing performance was prohibiting. 

  JC_bits_counter: process (uclk_i)

  begin
    if rising_edge (uclk_i) then

      if s_idle = '1' then       
        s_bits_so_far <= (others => '0');

      elsif s_tck_f_edge_p = '1' then
        s_bits_so_far <= s_bits_so_far + 2; -- 1 TMS + 1 TDI bits
      end if;

    end if;        
  end process;


 
---------------------------------------------------------------------------------------------------
--                                     Frame bits retrieval                                      --
---------------------------------------------------------------------------------------------------
-- Construction of the 16 bits word that indicates the amount of TMS/ TDI bits that have to be
-- played from this frame. The word is the result of the big endian concatenation of the 1st and
-- 2nd data bytes from the memory.   

  Bits_Number_retrieval: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if nfip_rst_i = '1' then
          s_bytes_c_d1     <= (others => '0');
          s_frame_bits_msb <= (others => '0');
          s_frame_bits_lsb <= (others => '0');
      else
          s_bytes_c_d1     <= s_bytes_c;

        if s_set_addr = '1' and s_bytes_c_d1 = 0 then
          s_frame_bits_msb <= jc_mem_data_i;
        end if;
        if s_set_addr = '1' and s_bytes_c_d1 = 1 then
          s_frame_bits_lsb <= jc_mem_data_i;
        end if;
      end if;
    end if;
  end process;

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  s_frame_bits             <= unsigned (s_frame_bits_msb) & unsigned (s_frame_bits_lsb);



---------------------------------------------------------------------------------------------------
--                                      TMS and TDI player                                       --
---------------------------------------------------------------------------------------------------
-- Delivery of the jc_tms_o and jc_tdi_o bits on the falling edge of the jc_tck_o clock.
-- At the "PLAY_BYTE" state of the FSM the incoming jc_mem_data_i byte is decomposed to 4 TMS and
-- 4 TDI bits; a pair of TMS/ TDI bits is output on every TCK falling edge.

  JC_TMS_TDI_player: process (uclk_i)
  begin

    if rising_edge (uclk_i) then
      if nfip_rst_i = '1' then
        jc_tms_o   <= '0';
        jc_tdi_o   <= '0';
    
      elsif s_tck_f_edge_p = '1' then

        if s_tck_c < (s_tck_period) then                         -- 1st JC_TMS/ JC_TDI pair
          jc_tms_o <= jc_mem_data_i(7);
          jc_tdi_o <= jc_mem_data_i(6);

        elsif s_tck_c < (s_tck_period sll 1) then                -- 2nd JC_TMS/ JC_TDI pair
          jc_tms_o <= jc_mem_data_i(5);
          jc_tdi_o <= jc_mem_data_i(4);

        elsif s_tck_c < ((s_tck_period sll 1)+s_tck_period) then -- 3rd JC_TMS/ JC_TDI pair
          jc_tms_o <= jc_mem_data_i(3);
          jc_tdi_o <= jc_mem_data_i(2);

        else
          jc_tms_o <= jc_mem_data_i(1);                          -- 4th JC_TMS/ JC_TDI pair
          jc_tdi_o <= jc_mem_data_i(0);
        end if;
      end if;
    end if;        
  end process;



---------------------------------------------------------------------------------------------------
--                                          TDO sampler                                          --
---------------------------------------------------------------------------------------------------
-- Sampling of the jc_tdo_i input on the rising edge of the jc_tck_o clock. Only the last sampled
-- bit is significant and is delivered.

-- Note: on the side of the target TAP, the jc_tdo should be provided on the falling edge of jc_tck;
-- a falling jc_tck edge comes many uclk cycles before a rising one, which is nanoFIP's sampling
-- moment for jc_tdo; therefore on the rising edges, jc_tdo is not expected to be metastable.
-- That is why we have decided not to synchronize the jc_tdo input. 

  JC_TDO_sampling: process (uclk_i)

  begin
    if rising_edge (uclk_i) then

      if nfip_rst_i = '1' then       
        jc_tdo_byte_o <= (others => '0');

      elsif s_tck_r_edge_p = '1' then
        jc_tdo_byte_o <= "0000000" & jc_tdo_i;
      end if;

    end if;        
  end process;



---------------------------------------------------------------------------------------------------
--                                  Independent Timeout Counter                                  --
---------------------------------------------------------------------------------------------------
-- Instantiation of a wf_decr_counter relying only on the system clock, as an additional
-- way to go back to Idle state, in case any other logic is being stuck. The timeout is 204.8 us.

  Session_Timeout_Counter: wf_decr_counter
  generic map(g_counter_lgth => c_JC_TIMEOUT_C_LGTH)
  port map(
    uclk_i            => uclk_i,
    counter_rst_i     => nfip_rst_i,
    counter_top_i     => (others => '1'),
    counter_load_i    => s_idle,
    counter_decr_i    => '1', -- on each uclk tick
    counter_o         => open,
    ---------------------------------------------------
    counter_is_zero_o => s_session_timedout);
    ---------------------------------------------------


end architecture rtl;
--=================================================================================================
--                                        architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------