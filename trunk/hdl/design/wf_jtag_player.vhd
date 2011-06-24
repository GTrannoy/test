--_________________________________________________________________________________________________
--                                                                                                |
--                                        |The nanoFIP|                                           |
--                                                                                                |
--                                        CERN,BE/CO-HT                                           |
--________________________________________________________________________________________________|
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
-- File         WF_cons_bytes_processor.vhd                                                       |
---------------------------------------------------------------------------------------------------

-- Standard library
library IEEE;
-- Standard packages
use IEEE.STD_LOGIC_1164.all; -- std_logic definitions
use IEEE.NUMERIC_STD.all;    -- conversion functions

-- Specific packages
use work.WF_PACKAGE.all;     -- definitions of types, constants, entities

---------------------------------------------------------------------------------------------------
--                                                                                               --
--                                     WF_cons_bytes_processor                                   --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
--
-- Description  The unit is consuming the RP_DAT data bytes that are arriving from the
--              WF_fd_receiver, according to the following:
--
--              o If the variable identifier of the preceded ID_DAT was a var_1 or a var_2:
--
--                o If the operation is in memory mode    : the unit is registering the
--                  application-data bytes along with the PDU_TYPE, Length and MPS bytes in the
--                  Consumed memories
--
--                o If the operation is in stand-alone mode: the unit is transferring the 2 appli-
--                  cation-data bytes to the "nanoFIP User Interface, NON_WISHBONE" data bus DAT_O
--
--              o If the consumed variable had been a var_rst, the 2 application-data bytes are
--                identified and sent to the WF_reset_unit.
--
--              Note: The validity of the consumed bytes (stored in the memory or transfered to DATO
--              or transfered to the WF_reset_unit) is indicated by the "nanoFIP User Interface,
--              NON_WISHBONE" signals VAR1_RDY/ VAR2_RDY or the nanoFIP internal signals
--              rst_nFIP_and_FD_p/ assert_RSTON_p, which are treated in the WF_cons_outcome unit and
--              are assessed after the end of the reception of a complete frame.
--
--
--              Reminder:
--
--              Consumed RP_DAT frame structure :
--           ___________ ______  _______ ________ __________________ _______  ___________ _______
--          |____FSS____|_Ctrl_||__PDU__|__LGTH__|__..ApplicData..__|__MPS__||____FCS____|__FES__|
--
--                                               |--------&LGTH bytes-------|
--                              |---------write to Consumed memory----------|
--                                               |-----to DAT_O-----|
--                                               |---to Reset Unit--|
--
--
--
-- Authors      Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)
--              Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)
--
--
-- Date         15/12/2010
--
--
-- Version      v0.03
--
--
-- Depends on   WF_reset_unit
--              WF_fd_receiver
--              WF_engine_control
--
--
---------------------------------------------------------------------------------------------------
--
-- Last changes
--     -> 11/09/2009  v0.01  EB  First version
--     ->    09/2010  v0.02  EG  Treatment of reset variable added; Bytes_Transfer_To_DATO unit
--                               creation for simplification; Signals renamed;
--                               Ctrl, PDU_TYPE, Length bytes registered;
--                               Code cleaned-up & commented.
--     -> 15/12/2010  v0.03  EG  Unit renamed from WF_cons_bytes_from_rx to WF_cons_bytes_processor
--                               byte_ready_p comes from the rx_deserializer (no need to pass from
--                               the engine) Code cleaned-up & commented (more!)
--
---------------------------------------------------------------------------------------------------



--=================================================================================================
--                            Entity declaration for WF_cons_bytes_processor
--=================================================================================================
entity WF_jtag_player is

port (
  -- INPUTS
    -- nanoFIP User Interface, General signals
    uclk_i          : in std_logic;                       -- 40 MHz clock

    -- Signal from the WF_reset_unit
    nfip_rst_i      : in std_logic;                       -- nanoFIP internal reset

    -- Signals from the WF_fd_receiver unit
    jc_mem_data_i   : in std_logic_vector (7 downto 0);   -- input byte

    jc_start_p_i    : in std_logic;

    jc_tdo_i        : in std_logic;

  -- OUTPUTS
    jc_tms_o        : out std_logic;
    jc_tdi_o        : out std_logic;
    jc_tck_o        : out std_logic;

    jc_tdo_byte_o   : out std_logic_vector (7 downto 0);

    jc_mem_adr_rd_o : out std_logic_vector (8 downto 0)
);

end entity WF_jtag_player;


--=================================================================================================
--                                    architecture declaration
--=================================================================================================
architecture rtl of WF_jtag_player is

  type jtag_pl_st_t  is (idle, get_byte, play_byte, set_address);
  signal jtag_pl_st, nx_jtag_pl_st : jtag_pl_st_t;

  signal s_idle, s_get_size, s_get_byte, s_play_byte, s_set_adr              : std_logic;
  signal s_bytes_c_reinit, s_bytes_c_incr                         : std_logic;
  signal s_tck_c_reinit, s_tck_c_incr, s_tck, s_tck_c_is_full, s_tck_d1     : std_logic;
  signal s_bytes_c, s_bytes_c_d1                                                : unsigned (6 downto 0);
  signal s_tck_c                                                  : unsigned (4 downto 0);
  signal s_frame_size_lsb, s_frame_size_msb                       : std_logic_vector (7 downto 0);
  signal s_jc_tdo_byte                                            : std_logic_vector (7 downto 0);
  signal s_frame_size                                             : unsigned (15 downto 0);

--=================================================================================================
--                                       architecture begin
--=================================================================================================
begin


---------------------------------------------------------------------------------------------------
--                         FSM                          --
---------------------------------------------------------------------------------------------------
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Synchronous process JATG_Player_FSM_Sync: storage of the current state of the FSM

  JATG_Player_FSM_Sync: process (uclk_i)
    begin
      if rising_edge (uclk_i) then
        if nfip_rst_i = '1' then
          jtag_pl_st <= idle;
        else
          jtag_pl_st <= nx_jtag_pl_st;
        end if;
      end if;
    end process;


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Combinatorial process JATG_Player_FSM_Comb_State_Transitions: Definition of the state
-- transitions of the FSM.

  JATG_Player_FSM_Comb_State_Transitions: process (jtag_pl_st, s_bytes_c, s_frame_size, jc_start_p_i, s_tck_c, s_tck_c_is_full)
  begin

  case jtag_pl_st is


    when idle =>

                        if jc_start_p_i = '1' then
                          nx_jtag_pl_st <= set_address;

                        else
                          nx_jtag_pl_st <= idle;
                        end if;

    when set_address =>
                        if s_bytes_c < 2 then -- getting size bytes
                          nx_jtag_pl_st <= get_byte;

                        else
                          if resize((s_bytes_c sll 3), s_frame_size'length)  > s_frame_size then
                            nx_jtag_pl_st <= idle;
                          else
                            nx_jtag_pl_st <= get_byte;
                          end if;
                        end if;

    when get_byte =>
                        if s_bytes_c < 2 then -- getting size bytes
                          nx_jtag_pl_st <= set_address;
                        else
                          nx_jtag_pl_st <= play_byte;
                        end if;

    when play_byte =>

                        if s_frame_size - resize((s_bytes_c sll 3), s_frame_size'length)  >= 8 then --complete bytes
                          if s_tck_c_is_full = '1' then 
                            nx_jtag_pl_st <= set_address;
                          else
                            nx_jtag_pl_st <= play_byte;
                          end if;

                        else
                          if s_tck_c <= (s_frame_size - resize((s_bytes_c sll 3), s_frame_size'length)) sll 2 then --last byte/ bits
                            nx_jtag_pl_st <= play_byte;
                          else
                            nx_jtag_pl_st <= idle;
                          end if;
                        end if;

    when others =>
                        nx_jtag_pl_st <= idle;
  end case;
  end process;


  JATG_Player_FSM_Comb_Output_Signals: process (jtag_pl_st)

  begin

    case jtag_pl_st is

    when idle =>
                  ------------------------------------
                   s_idle      <= '1';
                  ------------------------------------
                   s_get_size  <= '0';
                   s_set_adr   <= '0';
                   s_get_byte  <= '0';
                   s_play_byte <= '0';


    when set_address =>
                   s_idle      <= '0';
                   s_get_size  <= '0';
                  ------------------------------------
                   s_set_adr   <= '1';
                  ------------------------------------
                   s_get_byte  <= '0';
                   s_play_byte <= '0';

    when get_byte  =>

                   s_idle      <= '0';
                   s_get_size  <= '0';
                   s_set_adr   <= '0';
                  ------------------------------------
                   s_get_byte  <= '1';
                  ------------------------------------
                   s_play_byte <= '0';

    when play_byte  =>

                   s_idle      <= '0';
                   s_get_size  <= '0';
                   s_get_byte  <= '0';
                   s_set_adr   <= '0';
                  ------------------------------------
                   s_play_byte <= '1';
                  ------------------------------------
    end case;
  end process;



--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Instantiation of a WF_incr_counter for the retreival of bytes from the JTAG consumed memory.

  JTAG_player_bytes_count: WF_incr_counter
  generic map (g_counter_lgth => 7)
  port map (
    uclk_i            => uclk_i,
    reinit_counter_i  => s_bytes_c_reinit,
    incr_counter_i    => s_bytes_c_incr,
    counter_is_full_o => open,
    ------------------------------------------
    counter_o         => s_bytes_c);
    ------------------------------------------

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Instantiation of a WF_incr_counter for the generation of the JC_TCK output 5 MHz clock

  JC_TCK_periods_counter: WF_incr_counter
  generic map (g_counter_lgth => 5)
  port map (
    uclk_i            => uclk_i,
    reinit_counter_i  => s_tck_c_reinit,
    incr_counter_i    => s_tck_c_incr,
    counter_is_full_o => s_tck_c_is_full,
    ------------------------------------------
    counter_o         => s_tck_c);
    ------------------------------------------

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Combinatorial process that according to the state of the FSM sets values to the
-- Incoming_Bits_Index inputs.

  Bit_Index: process (s_idle, s_get_size, s_get_byte, s_play_byte)
  begin

    if s_idle ='1' then
      -- bytes counter reinitialization
      s_bytes_c_reinit <= '1';
      s_bytes_c_incr   <= '0';

      -- JC_TCK reinitialization
      s_tck_c_reinit   <= '1';
      s_tck_c_incr     <= '0';


    elsif s_set_adr = '1' then
      -- bytes counter counting
      s_bytes_c_reinit <= '0';
      s_bytes_c_incr   <= '1';

      -- JC_TCK reinitialization
      s_tck_c_reinit   <= '1';
      s_tck_c_incr     <= '0';

    elsif s_get_byte = '1' then
      -- bytes counter counts one byte
      s_bytes_c_reinit <= '0';
      s_bytes_c_incr   <= '0';

      -- JC_TCK reinitialization
      s_tck_c_reinit   <= '1';
      s_tck_c_incr     <= '0';

    elsif s_play_byte = '1' then
      -- bytes counter doesn t move
      s_bytes_c_reinit <= '0';
      s_bytes_c_incr   <= '0';

      -- JC_TCK reinitialization
      s_tck_c_reinit   <= '0';
      s_tck_c_incr     <= '1';

    else
      -- bytes counter
      s_bytes_c_reinit <= '1';
      s_bytes_c_incr   <= '0';

      -- JC_TCK reinitialization
      s_tck_c_reinit   <= '1';
      s_tck_c_incr     <= '0';

    end if;
  end process;


   s_tck <= '0' when (s_tck_c >1  and s_tck_c < 6) or (s_tck_c > 9 and s_tck_c < 14) or
                     (s_tck_c > 17 and s_tck_c < 22) or (s_tck_c > 25 and s_tck_c < 30) else '1';



   jc_mem_adr_rd_o <= std_logic_vector (resize((s_bytes_c + 2), jc_mem_adr_rd_o'length));
 
  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  JC_TCK_Construction: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if nfip_rst_i = '1' then
        s_tck_d1     <= '0';
        s_bytes_c_d1 <= (others => '0');
        s_frame_size_msb <= (others => '0');
        s_frame_size_msb <= (others => '0');
      else
        s_tck_d1     <= s_tck;
        s_bytes_c_d1 <= s_bytes_c;

        if s_bytes_c_d1 = 0 then
          s_frame_size_msb <= jc_mem_data_i;
        end if;
        if s_bytes_c_d1 = 1 then
          s_frame_size_lsb <= jc_mem_data_i;
        end if;

      end if;
    end if;
  end process;

  s_frame_size     <= unsigned(s_frame_size_msb) & unsigned (s_frame_size_lsb);


  jc_tck_o <= s_tck_d1;
  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  JTAG_TMS_TDI_bits_player: process (s_tck_d1)
  begin

    if falling_edge (s_tck_d1) then
      if nfip_rst_i = '1' then
        jc_tms_o    <= '0';
        jc_tdi_o    <= '0';
      else
        if s_tck_c < 4 then
          jc_tms_o    <= jc_mem_data_i(7);
          jc_tdi_o    <= jc_mem_data_i(6);

        elsif s_tck_c < 12 then
          jc_tms_o    <= jc_mem_data_i(5);
          jc_tdi_o    <= jc_mem_data_i(4);

        elsif s_tck_c < 20 then
          jc_tms_o    <= jc_mem_data_i(3);
          jc_tdi_o    <= jc_mem_data_i(2);

        elsif s_tck_c < 28 then
          jc_tms_o    <= jc_mem_data_i(1);
          jc_tdi_o    <= jc_mem_data_i(0);

        else
          jc_tms_o    <= jc_mem_data_i(7);
          jc_tdi_o    <= jc_mem_data_i(6);
        end if;
      end if;        
    end if;
  end process;


  JTAG_TDO_bits_retreiver: process (s_tck_d1)
  begin

    if rising_edge (s_tck_d1) then
      if nfip_rst_i = '1' or s_idle= '1' then
        s_jc_tdo_byte <= (others => '0');
      else
        s_jc_tdo_byte <= s_jc_tdo_byte (6 downto 0) & jc_tdo_i;

      end if;        
    end if;
  end process;

  jc_tdo_byte_o <= s_jc_tdo_byte;


end architecture rtl;
--=================================================================================================
--                                        architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------