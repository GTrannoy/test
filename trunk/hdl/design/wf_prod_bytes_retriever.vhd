--_________________________________________________________________________________________________
--                                                                                                |
--                                        |The nanoFIP|                                           |
--                                                                                                |
--                                        CERN,BE/CO-HT                                           |
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--                                                                                               --
--                                    WF_prod_bytes_retriever                                    --
--                                                                                               --
---------------------------------------------------------------------------------------------------
-- File         WF_prod_bytes_retriever.vhd
--
-- Description  After an ID_DAT frame requesting for a variable to be produced, the unit provides
--              to the WF_tx_serializer unit one by one, all the bytes of data needed for the
--              RP_DAT frame (apart from the  FSS, FCS and FES bytes). The coordination of the
--              retreival is done through the WF_engine_control and the signal byte_index_i.
--
--              General structure of a produced RP_DAT frame :
--    ___________ ______  _______ ______ _________________ _______ _______  ___________ _______
--   |____FSS____|_Ctrl_||__PDU__|_LGTH_|_...User-Data..._|_nstat_|__MPS__||____FCS____|__FES__|
--
--              Data provided by the this unit :
--                ______  _______ ______ ________________________________________ _______ _______
--               |_Ctrl_||__PDU__|_LGTH_|_____________..User-Data..______________|_nstat_|__MPS__||
--
--              If the variable to be produced is the
--                o presence       : The unit retreives the bytes from the WF_package.
--                                   No MPS & no nanoFIP status are associated with this variable.
--                ______  _______ ______ ______ ______ ______ ______ ______
--               |_Ctrl_||__PDU__|__05__|__80__|__03__|__00__|__F0__|__00__||
--
--
--                o identification : The unit retreives the Constructor & Model bytes from the
--                                   WF_model_constr_decoder, and all the rest from the WF_package.
--                                   No MPS & no nanoFIP status are associated with this variable.
--                ______  _______ ______ ______ ______ ______ ______ _______ ______ ______ ______
--               |_Ctrl_||__PDU__|__08__|__01__|__00__|__00__|_cons_|__mod__|__00__|__00__|__00__||
--
--
--                o var_3          : If the operation is in stand-alone mode, the unit retreives the
--                                   user-data bytes from the "nanoFIP User Interface, NON-WISHBONE"
--                                   bus DAT_I. If it is in memory mode, it retreives them from the
--                                   Produced RAM. The unit retreives the MPS and nanoFIP status
--                                   bytes from the WF_status_bytes_gen, and the LGTH byte from the
--                                   WF_prod_data_lgth_calc (inside the WF_engine_control). The
--                                   rest of the bytes (Ctrl & PDU) come from the WF_package.
--                ______  _______ ______ ________________________________________ _______ _______
--               |_Ctrl_||__PDU__|_LGTH_|_____________..User-Data..______________|_nstat_|__MPS__||
--
--
-- Authors      Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)
--              Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)
-- Date         04/01/2011
-- Version      v0.05
-- Depends on   WF_reset_unit
--              WF_wb_controller
--              WF_engine_control
--              WF_prod_permit
--              WF_status_bytes_gen
--              WF_model_constr_dec
----------------
-- Last changes
--     06/2010  v0.02  EG  subs_i is not sent in the RP_DAT frames
--                         signal s_wb_we includes the wb_stb_r_edge_p_i
--                         cleaner structure
--     06/2010  v0.03  EG  signal s_mem_byte was not in sensitivity list in v0.01! by adding it
--                         changes were essential in the timing of the tx (WF_osc, WF_tx,
--                         WF_engine_control and the configuration of the memory needed changes)
--     11/2010  v0.04  EG  for simplification, new unit Slone_Data_Sampler created
--     4/1/2011 v0.05  EG  unit renamed from WF_prod_bytes_to_tx to WF_prod_bytes_retriever;
--                         input byte_being_sent_p_i added, so that the reseting of status bytes
--                         does not pass from the engine; clening-up+commenting
--       2/2011 v0.051 EG  WF_prod_bytes_from_dati unit removed.
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
--                                      Libraries & Packages
--=================================================================================================

-- Standard library
library IEEE;
use IEEE.STD_LOGIC_1164.all; -- std_logic definitions
use IEEE.NUMERIC_STD.all;    -- conversion functions
-- Specific library
library work;
use work.WF_PACKAGE.all;     -- definitions of types, constants, entities


--=================================================================================================
--                           Entity declaration for WF_prod_bytes_retriever
--=================================================================================================

entity WF_prod_bytes_retriever is

  port (
  -- INPUTS
    -- nanoFIP User Interface, General signals
    uclk_i               : in std_logic;                      -- 40 MHz clock
    nostat_i             : in std_logic;                      -- if negated, nFIP status is sent
    slone_i              : in std_logic;                      -- stand-alone mode

    -- Signal from the WF_reset_unit
    nfip_rst_i           : in std_logic;                      -- nanoFIP internal reset

    -- nanoFIP User Interface, WISHBONE Slave
    wb_clk_i             : in std_logic;                      -- WISHBONE clock
    wb_adr_i             : in std_logic_vector (8 downto 0);  -- WISHBONE address to memory
    wb_data_i            : in std_logic_vector (7 downto 0);  -- WISHBONE data bus

    -- Signal from the WF_wb_controller
    wb_ack_prod_p_i      : in std_logic;                      -- WISHBONE acknowledge
                                                              -- latching moment of wb_data_i

    -- nanoFIP User Interface, NON WISHBONE
    slone_data_i         : in std_logic_vector (15 downto 0); -- input data bus for slone mode

    -- Signals from the WF_engine_control unit
    byte_index_i         : in std_logic_vector (7 downto 0);  --index of the byte to be retrieved

    byte_being_sent_p_i  : in std_logic;                      -- pulse on the beginning of the
                                                              -- delivery of a new byte

    data_lgth_i          : in std_logic_vector (7 downto 0);  -- # bytes of the Conrol&Data fields
                                                              -- of the RP_DAT frame; includes:
                                                              -- 1 byte RP_DAT.Control,
                                                              -- 1 byte RP_DAT.Data.PDU_type,
                                                              -- 1 byte RP_DAT.Data.LENGTH
                                                              -- 2-124 bytes of RP_DAT.Data,
                                                              -- 1 byte RP_DAT.Data.MPS_status &
                                                              -- optionally 1 byte for the
                                                              -- RP_DAT.Data.nanoFIP_status


    var_i                : in t_var;                          --variable type that is being treated

    -- Signals from the WF_prod_permit
    var3_rdy_i           : in std_logic;                      -- nanoFIP output VAR3_RDY

    -- Signals from the WF_status_bytes_gen
    mps_status_byte_i    : in std_logic_vector (7 downto 0);  -- MPS status byte
    nFIP_status_byte_i   : in std_logic_vector (7 downto 0);  -- nanoFIP status byte

    -- Signals from the WF_model_constr_dec unit
    constr_id_dec_i      : in  std_logic_vector (7 downto 0); -- decoded constructor id settings
    model_id_dec_i       : in  std_logic_vector (7 downto 0); -- decoded model id settings

    -- Signals from the WF_jtag_controller unit
    jc_tdo_byte_i        : in std_logic_vector (7 downto 0);  -- 8 last JC_TDO bits

  -- OUTPUTS
    -- Signal to the WF_status_bytes_gen
    rst_status_bytes_p_o : out std_logic;                     -- reset for the nanoFIP&MPS status
                                                              -- status bytes.It is activated after
                                                              -- the delivery of the last one (MPS)

    -- Signal to the WF_tx_serializer
    byte_o               : out std_logic_vector (7 downto 0)  -- output byte to be serialized

      );
end entity WF_prod_bytes_retriever;


--=================================================================================================
--                                    architecture declaration
--=================================================================================================
architecture rtl of WF_prod_bytes_retriever is

  signal s_base_addr, s_mem_addr_offset : unsigned (8 downto 0);
  signal s_mem_addr_A                   : std_logic_vector (8 downto 0);
  signal s_byte_index_d1                : std_logic_vector (7 downto 0);
  signal s_byte_index_d_aux             : integer range 0 to 15;
  signal s_mem_byte, s_slone_byte       : std_logic_vector (7 downto 0);
  signal s_slone_bytes                  : std_logic_vector (15 downto 0);
  signal s_lgth_byte                    : std_logic_vector (7 downto 0);

--=================================================================================================
--                                       architecture begin
--=================================================================================================
begin


---------------------------------------------------------------------------------------------------
--                                    Memory mode Produced RAM                                   --
--               Storage (by the user) & retreival (by the unit) of produced bytes               --
---------------------------------------------------------------------------------------------------
-- Instantiation of a Produced Dual Port RAM.
-- Port A is used by the nanoFIP for the readings from the Produced RSM;
-- Port B is connected to the WISHBONE interface for the writings from the user.

  Produced_Bytes_From_RAM:  WF_DualClkRAM_clka_rd_clkb_wr
  generic map (
    g_ram_data_lgth  => 8,                     -- 8 bits: length of data word
    g_ram_addr_lgth  => 9)                     -- 2^9: depth of Produced ram
                                               -- first 2 bits : identification of memory block
                                               -- remaining 7  : address of a byte inside the blck
  port map (
    clk_porta_i      => uclk_i,	               -- 40 MHz clock
    addr_porta_i     => s_mem_addr_A,          -- address of byte to be read from memory
    clk_portb_i      => wb_clk_i,              -- WISHBONE clock
    addr_portb_i     => wb_adr_i,              -- address of byte to be written
    data_portb_i     => wb_data_i,             -- byte to be written
    write_en_portb_i => wb_ack_prod_p_i,       -- WISHBONE write enable
   -----------------------------------------
    data_porta_o     => s_mem_byte);           -- output byte read
   -----------------------------------------


---------------------------------------------------------------------------------------------------
--                                 Slone mode DAT_I bus Sampling                                 --
--                           Retreival of the two bytes to be produced                           --
---------------------------------------------------------------------------------------------------
-- Sampling of the input data bus DAT_I(15:0) for the operation in stand-alone mode.
-- The sampling takes place on the 1st clock cycle after the VAR3_RDY has been de-asserted.

  Sample_DAT_I_bus: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if nfip_rst_i = '1' then
        s_slone_bytes   <= (others=>'0');

     else
        if var3_rdy_i = '1' then   -- data latching
          s_slone_bytes <= slone_data_i;
        end if;

      end if;
    end if;
  end process;

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  s_slone_byte          <= s_slone_bytes(7 downto 0) when byte_index_i = c_1st_DATA_BYTE_INDEX
                      else s_slone_bytes(15 downto 8);



---------------------------------------------------------------------------------------------------
--                                        Bytes Generation                                       --
---------------------------------------------------------------------------------------------------
-- Combinatorial process Bytes_Generation: Generation of bytes for the Control and Data
-- fields of an RP_DAT frame: If the variable requested in the ID_DAT is of "produced" type
-- (identification/ presence/ var3) the process prepares accordingly, one by one, bytes of data
-- to be sent. The pointer "s_byte_index_d1" (or "s_byte_index_d_aux") indicates which byte of the
-- frame is to be sent. Some of the bytes are defined in the WF_package, the rest come either from
-- the memory (if slone = 0) or from the the input bus DAT_I (if slone = 1) or from the
-- WF_status_bytes_gen or the WF_model_constr_decoder units. The output byte "byte_o" is sent to
-- the WF_tx_serializer unit for manchester encoding and serialization.

  Bytes_Generation: process (var_i, s_byte_index_d1, data_lgth_i, constr_id_dec_i, model_id_dec_i,
                             nFIP_status_byte_i, mps_status_byte_i, s_slone_byte, s_byte_index_d_aux,
                             s_mem_byte, nostat_i, byte_being_sent_p_i, s_lgth_byte, slone_i, jc_tdo_byte_i)

  begin

    --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    -- generation of bytes according to the type of produced var:
    case var_i is


	-- case: presence variable
    -- all the bytes for the RP_DAT.Control and RP_DAT.Data fields are predefined
    -- in the c_VARS_ARRAY matrix.
    when var_presence =>

      byte_o                   <= c_VARS_ARRAY(c_VAR_PRESENCE_INDEX).byte_array(s_byte_index_d_aux);

      s_base_addr              <= (others => '0');
      rst_status_bytes_p_o     <= '0';

    --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --


	-- case: identification variable
    -- The Constructor and Model bytes of the identification variable arrive from the
    -- WF_model_constr_decoder, wereas all the rest are predefined in the c_VARS_ARRAY matrix.
    when var_identif =>

      if s_byte_index_d1 = c_CONSTR_BYTE_INDEX then
        byte_o                 <= constr_id_dec_i;

      elsif s_byte_index_d1 = c_MODEL_BYTE_INDEX then
        byte_o                 <= model_id_dec_i;

      else
        byte_o                 <= c_VARS_ARRAY(c_VAR_IDENTIF_INDEX).byte_array(s_byte_index_d_aux);
      end if;

      s_base_addr              <= (others => '0');
      rst_status_bytes_p_o     <= '0';

    --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --


    -- case: variable 3
    -- For a var_3 there is a separation according to the operational mode (stand-alone or memory)
    -- In general, few of the bytes are predefined in the c_VARS_ARRAY matrix, wereas the rest come
    -- either from the memory/ DAT_I bus or from wf_status_bytes_generator unit.
    when var_3 =>

      ---------------------------------------------------------------------------------------------
      -- In memory mode:
      if slone_i = '0' then

        -- retreival of base address info for the memory from the WF_package
        s_base_addr            <= c_VARS_ARRAY(c_VAR_3_INDEX).base_addr;


        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
        -- The first (Control) and second (PDU_TYPE) bytes to be sent
        -- are predefined in the c_VARS_ARRAY matrix of the WF_package

        if unsigned(s_byte_index_d1) <= c_VARS_ARRAY(c_VAR_3_INDEX).array_lgth  then  -- less or eq
          byte_o               <= c_VARS_ARRAY(c_VAR_3_INDEX).byte_array(s_byte_index_d_aux);
          rst_status_bytes_p_o <= '0';

        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
        -- The &c_LGTH_BYTE_INDEX byte is the Length

        elsif s_byte_index_d1 = c_LGTH_BYTE_INDEX then
          byte_o               <= s_lgth_byte;
          rst_status_bytes_p_o <= '0';

        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
        -- If the nostat_i is negated, the one but last byte is the nanoFIP status byte

        elsif (unsigned(s_byte_index_d1) = (unsigned(data_lgth_i)-1 )) and nostat_i = '0' then
          byte_o               <= nFIP_status_byte_i;
          rst_status_bytes_p_o <= '0';

        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
        -- The last byte is the MPS status
        elsif s_byte_index_d1 = (data_lgth_i)  then
          byte_o               <= mps_status_byte_i;
          rst_status_bytes_p_o <= byte_being_sent_p_i; -- reset signal for both status bytes;
                                                       -- the reset arrives after the delivery
                                                       -- of the MPS byte to the WF_tx_serializer

        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      -- The rest of the bytes come from the memory
        else
          byte_o               <= s_mem_byte;
          rst_status_bytes_p_o <= '0';

        end if;

      ---------------------------------------------------------------------------------------------
      -- In stand-alone mode:
      else

        s_base_addr            <= (others => '0');            -- no memory access needed

        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
        -- The first (Control) and second (PDU type) bytes to be sent
        -- are predefined in the c_VARS_ARRAY matrix of the WF_package

        if unsigned(s_byte_index_d1) <= c_VARS_ARRAY(c_VAR_3_INDEX).array_lgth then -- less or eq
          byte_o               <= c_VARS_ARRAY(c_VAR_3_INDEX).byte_array(s_byte_index_d_aux);
          rst_status_bytes_p_o <= '0';

        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
        -- The &c_LGTH_BYTE_INDEX byte is the Length

        elsif s_byte_index_d1 = c_LGTH_BYTE_INDEX then
          byte_o               <= s_lgth_byte;
          rst_status_bytes_p_o <= '0';

        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
        -- If the nostat_i is negated, the one but last byte is the nanoFIP status byte

        elsif unsigned(s_byte_index_d1) = (unsigned(data_lgth_i)-1 ) and nostat_i = '0' then
          byte_o               <= nFIP_status_byte_i;
          rst_status_bytes_p_o <= '0';

        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
        -- The last byte is the MPS status
        elsif s_byte_index_d1 = data_lgth_i then
          byte_o               <= mps_status_byte_i;
          rst_status_bytes_p_o <= byte_being_sent_p_i; -- reset signal for both status bytes.
                                                       -- The reset arrives after having sent the
                                                       -- MPS byte to the WF_tx_serializer.

        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
        -- The rest of the bytes come from the input bus DAT_I(15:0)
        else
          byte_o               <= s_slone_byte;
          rst_status_bytes_p_o <= '0';

        end if;
      end if;

    --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --


    -- case: jatg produced
    -- For ..............
    when var_jc3 =>

        s_base_addr            <= (others => '0');            -- no memory access needed

        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
        -- The first (Control) and second (PDU type) bytes to be sent
        -- are predefined in the c_VARS_ARRAY matrix of the WF_package

        if unsigned(s_byte_index_d1) <= c_VARS_ARRAY(c_VAR_JC3_INDEX).array_lgth then -- less or eq
          byte_o               <= c_VARS_ARRAY(c_VAR_JC3_INDEX).byte_array(s_byte_index_d_aux);
          rst_status_bytes_p_o <= '0';

        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
        -- The &c_LGTH_BYTE_INDEX byte is the Length

        elsif s_byte_index_d1 = c_LGTH_BYTE_INDEX then
          byte_o               <= s_lgth_byte;
          rst_status_bytes_p_o <= '0';

        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
        -- The one but last byte is the nanoFIP status byte

        elsif unsigned(s_byte_index_d1) = (unsigned(data_lgth_i)-1 ) then
          byte_o               <= nFIP_status_byte_i;
          rst_status_bytes_p_o <= '0';

        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
        -- The last byte is the MPS status
        elsif s_byte_index_d1 = data_lgth_i then
          byte_o               <= mps_status_byte_i;
          rst_status_bytes_p_o <= byte_being_sent_p_i; -- reset signal for both status bytes.
                                                       -- The reset arrives after having sent the
                                                       -- MPS byte to the WF_tx_serializer.

        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
        -- The other byte comes from the JATG_controller
        else
          byte_o               <= jc_tdo_byte_i;
          rst_status_bytes_p_o <= '0';

        end if;

    --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --

    when others =>
      rst_status_bytes_p_o     <= '0';
      byte_o                   <= (others => '0');
      s_base_addr              <= (others => '0');

    end case;
  end process;


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Synchronous process Delay_byte_index_i: in the combinatorial process Bytes_Generation,
-- according to the value of the signal s_byte_index_d1, a byte is retrieved either from the memory,
-- or from the WF_package or from the WF_status_bytes_gen or WF_model_constr_decoder units.
-- Since the memory needs one clock cycle to output its data (as opposed to the other units that
-- have them ready) the signal s_byte_index_d1 has to be a delayed version of the byte_index_i
-- (byte_index_i is the signal used as address for the mem; s_byte_index_d1 is the delayed one
-- used for the other units).

  Delay_byte_index_i: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if nfip_rst_i = '1' then
        s_byte_index_d1 <= (others => '0');
      else

        s_byte_index_d1 <= byte_index_i;   -- index of byte to be sent
      end if;
    end if;
  end process;



---------------------------------------------------------------------------------------------------
--                                       Auxiliary signals                                       --
---------------------------------------------------------------------------------------------------

  s_mem_addr_A       <= std_logic_vector (s_base_addr + s_mem_addr_offset - 1);
  -- address of the byte to be read from memory: base_address(from WF_package) + byte_index_i - 1
  -- (the -1 is because the byte_index_i counts also the Control byte, that is not part of the
  -- memory; for example when byte_index_i is 3 which means that the Control, PDU_TYPE and Length
  -- bytes have preceded and a byte from the memory is now requested, the byte from the memory cell
  -- 2 (00000010) has to be retrieved).

  s_mem_addr_offset  <= (resize((unsigned(byte_index_i)), s_mem_addr_offset'length));

  s_byte_index_d_aux <= (to_integer(unsigned(s_byte_index_d1(3 downto 0))));
                                                      -- index of byte to be sent(range restricted)
                                                      -- used to retreive bytes from the matrix
                                                      -- c_VARS_ARRAY.byte_array, with a predefined
                                                      -- width of 15 bytes

  s_lgth_byte        <= std_logic_vector (resize((unsigned(data_lgth_i)-2),byte_o'length));
                                                      -- represents the RP_DAT.Data.LENGTH byte
                                                      -- it includes the # bytes of user-data
                                                      -- (P3_LGTH) plus 1 byte of MPS_status
                                                      -- plus 1 byte of nanoFIP_status, if
                                                      -- applicable. It does not include the
                                                      -- Control byte and itself.


end architecture rtl;
--=================================================================================================
--                                        architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------