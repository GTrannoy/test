---------------------------------------------------------------------------------------------------
--! @file WF_status_bytes_gen.vhd
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
--                                       WF_status_bytes_generator                               --
--                                                                                               --
--                                           CERN, BE/CO/HT                                      --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
-- unit name   WF_status_bytes_gen
--
--
--! @brief     Generation of the NanoFIP status, as well as the MPS status bytes. 
--
--
--! @author    Erik van der Bij (Erik.van.der.Bij@cern.ch)
--!            Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)
--!            Evangelia Gousiou (Evangelia.Gousiou@cern.ch)
--
--
--! @date 07/2010
--
--
--! @version v0.01
--
--
--! @details\n 
--
--!   \n<b>Dependencies:</b>\n
--!     data_if             \n
--!     tx_engine           \n
--!     WF_tx_rx            \n
--!     reset_logic         \n
--
--
--!   \n<b>Modified by:</b>\n
--!    Pablo Alvarez Sanchez (pablo.alvarez.sanchez@cern.ch)
--
---------------------------------------------------------------------------------------------------
--
--!   \n\n<b>Last changes:</b>\n
--!     07/07/2009  v0.01  EB  First version \n
--!        08/2010  v0.02  EG  code violation & CRC errors considered
--!                            only during a concumed var reception
--!                            extended var_rdy
--!                            
--
---------------------------------------------------------------------------------------------------
--
--! @todo bits 6 and 7 reset only when nanoFIP is reset...
--
---------------------------------------------------------------------------------------------------


--=================================================================================================
-- Entity declaration for WF_status_bytes_gen
--=================================================================================================
entity WF_status_bytes_gen is

port (
  -- INPUTS 
    -- User Interface general signals (synchronized) 
    uclk_i :               in std_logic;  --! 40 MHz Clock
    slone_i :              in  std_logic; --! Stand-alone mode

    -- Signal from the reset_logic unit
    nFIP_urst_i :           in std_logic;  --! internal reset

    -- Signals from the fieldrive interface  
    fd_wdgn_i :            in  std_logic; --! Watchdog on transmitter
    fd_txer_i :            in  std_logic; --! Transmitter error

    -- Signals from the non-WISHBONE user interface
    var1_acc_i :          in std_logic; --! Variable 1 access (asynchronous)
    var2_acc_i :          in std_logic; --! Variable 2 access (asynchronous)
    var3_acc_i :          in std_logic; --! Variable 3 access (asynchronous)

    -- Signal from the receiver WF_rx
    crc_wrong_p_i :        in std_logic;
    
    -- Signals from the central control unit WF_engine_control
    var_i :                in t_var;     --! variable type 
    var1_rdy_i :           in std_logic; --! Variable 1 ready
    var2_rdy_i :           in std_logic; --! Variable 2 ready
    var3_rdy_i :           in std_logic; --! Variable 3 ready
    

    -- Signal from nanofip
    rst_status_bytes_i : in std_logic; --! both status bytes are reinitialized
                                         --! right after having been delivered

  -- OUTPUTS 
    -- Output to WF_prod_bytes_to_tx
    nFIP_status_byte_o :   out std_logic_vector (7 downto 0);  --! status byte
    mps_status_byte_o :    out std_logic_vector (7 downto 0)   --! mps byte
     ); 
end entity WF_status_bytes_gen;

--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of WF_status_bytes_gen is

signal s_refreshment, s_VAR1_RDY_incr_c, s_VAR1_RDY_extended                          : std_logic;
signal s_VAR2_RDY_incr_c, s_VAR2_RDY_extended, s_VAR3_RDY_incr_c, s_VAR3_RDY_extended : std_logic; 
signal s_VAR1_RDY_c, s_VAR2_RDY_c, s_VAR3_RDY_c :                           unsigned (3 downto 0);


--=================================================================================================
--                                      architecture begin
--=================================================================================================
begin


---------------------------------------------------------------------------------------------------
--! @brief Synchronous process Status_byte_Formation: Formation of the nanoFIP status byte
--! according to the definitions in Table 8 of specs.

  nFIP_status_byte_generation: process(uclk_i) 
  begin

    if rising_edge(uclk_i) then
  
      if ((nFIP_urst_i = '1') or (rst_status_bytes_i = '1')) then -- bytes reinitialized
        nFIP_status_byte_o                    <= (others => '0'); -- after having been delivered


        else

        if ((s_VAR1_RDY_extended = '0' and var1_acc_i = '1') or   -- since the last time the status
            (s_VAR2_RDY_extended = '0' and var2_acc_i = '1')) then         -- byte was delivered,
  
        nFIP_status_byte_o(c_U_CACER_INDEX) <= '1';             -- the user logic accessed a cosmd
        end if;                                                   -- variable when it was not ready

        if (s_VAR3_RDY_extended = '0' and var3_acc_i = '1') then -- since the last time the status 
          nFIP_status_byte_o(c_U_PACER_INDEX) <= '1';             -- byte was delivered,
        end if;                                                   -- the user logic accessed a prod
                                                                  -- variable when it was not ready

        if ((var_i = var_1 or var_i = var_2) and (crc_wrong_p_i = '1')) then -------------------------------------------------------------
          nFIP_status_byte_o(c_R_BNER_INDEX)  <= '1';             -- since the last time the status 
                                                                  -- byte was delivered, 
        end if;                                                   -- a consumed var arrived for 
                                                                  -- this station with a manch. code
                                                                  -- violation (on the RP_DAT.Data)

        if ((var_i = var_1 or var_i = var_2)and(crc_wrong_p_i = '1')) then
          nFIP_status_byte_o(c_R_FCSER_INDEX) <= '1';            -- since the last time the status  
                                                                 -- byte was delivered,
        end if;                                                  -- a consumed var with a wrong CRC 
                                                                 -- arrived for this station

        if (fd_wdgn_i = '0') then                                -- since the last time the status 
          nFIP_status_byte_o(c_T_TXER_INDEX)  <= '1';            -- byte was delivered,
        end if;                                                  -- there has been a signal for
                                                                 -- a FIELDRIVE transmission error

        if (fd_txer_i = '1') then                                -- since the last time the status
          nFIP_status_byte_o(c_T_WDER_INDEX)  <= '1';            -- byte was delivered,
        end if;                                                  -- there has been a signal for a
                                                                 -- FIELDRIVE watchdog timer problem
      end if;
    end if;
end process;

---------------------------------------------------------------------------------------------------
--!@brief Synchronous process 
 
  Extend_VAR1_RDY: WF_incr_counter
  generic map (counter_length => 4)
  port map(
    uclk_i            => uclk_i,
    nFIP_urst_i       => nFIP_urst_i,
    reinit_counter_i  => VAR1_RDY_i,
    incr_counter_i    => s_VAR1_RDY_incr_c,
    counter_o         => s_VAR1_RDY_c,
    counter_is_full_o => open);

    s_VAR1_RDY_incr_c   <= '1' when s_VAR1_RDY_c < "1111"
                      else '0';

    s_VAR1_RDY_extended <= '1' when VAR1_RDY_i= '1' or s_VAR1_RDY_incr_c = '1'
                      else '0';
---------------------------------------------------------------------------------------------------
  Extend_VAR2_RDY: WF_incr_counter
  generic map (counter_length => 4)
  port map(
    uclk_i            => uclk_i,
    nFIP_urst_i       => nFIP_urst_i,
    reinit_counter_i  => VAR2_RDY_i,
    incr_counter_i    => s_VAR2_RDY_incr_c,
    counter_o         => s_VAR2_RDY_c,
    counter_is_full_o => open);

    s_VAR2_RDY_incr_c   <= '1' when s_VAR1_RDY_c < "1111"
                      else '0';

    s_VAR2_RDY_extended <= '1' when VAR2_RDY_i= '1' or s_VAR2_RDY_incr_c = '1'
                      else '0';


---------------------------------------------------------------------------------------------------
  Extend_VAR3_RDY: WF_incr_counter
  generic map (counter_length => 4)
  port map(
    uclk_i            => uclk_i,
    nFIP_urst_i       => nFIP_urst_i,
    reinit_counter_i  => VAR3_RDY_i,
    incr_counter_i    => s_VAR3_RDY_incr_c,
    counter_o         => s_VAR3_RDY_c,
    counter_is_full_o => open);

    s_VAR3_RDY_incr_c   <= '1' when s_VAR3_RDY_c < "1111"
                      else '0';

    s_VAR3_RDY_extended <= '1' when VAR3_RDY_i= '1' or s_VAR3_RDY_incr_c = '1'
                      else '0';



---------------------------------------------------------------------------------------------------
--!@brief Synchronous process Refreshment_bit_Formation: Formation of the refreshment bit (used in
--! the mps status byte). It is set to 1 if the user has updated the produced variable (var3_access
--! has been asserted since the last time a variable was produced).
 
  refreshment_bit_formation: process(uclk_i) 
  begin
    if rising_edge(uclk_i) then

      if nFIP_urst_i = '1' or rst_status_bytes_i = '1' then -- the bit is reinitialized
        s_refreshment   <= '0';                             -- after having been delivered
      else

        if (var3_acc_i = '1') then -- indication that the memory has been accessed
          s_refreshment <= '1';
        end if;

      end if;
    end if;
end process;

---------------------------------------------------------------------------------------------------
--!@brief Combinatorial process MPS_byte_Formation: Formation of the MPS byte according to the
--! definitions in the Table 2 of the specs.
 
  MPS_byte_formation: process (slone_i, s_refreshment)
  
  begin
    if slone_i='1' then
      mps_status_byte_o (7 downto 3)           <= (others => '0');   
      mps_status_byte_o (c_SIGNIFICANCE_INDEX) <= '1';
      mps_status_byte_o (1)                    <= '0';
      mps_status_byte_o (c_REFRESHMENT_INDEX)  <= '1'; 


    else
      mps_status_byte_o (7 downto 3)           <= (others => '0');      
      mps_status_byte_o (c_REFRESHMENT_INDEX)  <= s_refreshment; 
      mps_status_byte_o (1)                    <= '0';
      mps_status_byte_o (c_SIGNIFICANCE_INDEX) <= s_refreshment;
    end if;
  end process;


end architecture rtl;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------