--=================================================================================================
--! @file wf_status_bytes_gen.vhd
--=================================================================================================

--! standard library
library IEEE;

--! standard packages
use IEEE.STD_LOGIC_1164.all;  --! std_logic definitions
use IEEE.NUMERIC_STD.all;     --! conversion functions

--! specific packages
use work.WF_PACKAGE.all;      --! definitions of supplemental types, subtypes, constants

---------------------------------------------------------------------------------------------------
--                                                                                               --
--                                       wf_status_bytes_generator                               --
--                                                                                               --
--                                           CERN, BE/CO/HT                                      --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
-- unit name   wf_status_bytes_gen
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
--!     wf_tx_rx            \n
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
--!                            
--
---------------------------------------------------------------------------------------------------
--
--! @todo bits 6 and 7 reset only when nanoFIP is reset...
--
---------------------------------------------------------------------------------------------------


--=================================================================================================
-- Entity declaration for wf_status_bytes_gen
--=================================================================================================
entity wf_status_bytes_gen is

port (
  -- INPUTS 
    -- User Interface general signals 
    uclk_i :               in std_logic;  --! 40 MHz Clock
    slone_i :              in  std_logic; --! Stand-alone mode

    -- Signal from the reset_logic unit
    nFIP_rst_i :           in std_logic;  --! internal reset

    -- Signals from the fieldrive interface  
    fd_wdgn_i :            in  std_logic; --! Watchdog on transmitter
    fd_txer_i :            in  std_logic; --! Transmitter error

    -- Signals from the non-WISHBONE user interface
    var1_access_a_i :      in std_logic; --! Variable 1 access (asynchronous)
    var2_access_a_i :      in std_logic; --! Variable 2 access (asynchronous)
    var3_access_a_i :      in std_logic; --! Variable 3 access (asynchronous)

    -- Signal from the receiver wf_rx
    code_violation_p_i :   in std_logic; 
    crc_wrong_p_i :        in std_logic;
    
    -- Signals from the central control unit wf_engine_control
    var_i :                in t_var;     --! variable type 
    var1_rdy_i :           in std_logic; --! Variable 1 ready
    var2_rdy_i :           in std_logic; --! Variable 2 ready
    var3_rdy_i :           in std_logic; --! Variable 3 ready
    

    -- Signal from nanofip
    reset_status_bytes_i : in std_logic; --! both status bytes are reinitialized
                                         --! right after having been delivered

  -- OUTPUTS 
    -- Output to wf_produced_vars
    nFIP_status_byte_o :   out std_logic_vector (7 downto 0);  --! status byte
    mps_status_byte_o :    out std_logic_vector (7 downto 0)   --! mps byte
     ); 
end entity wf_status_bytes_gen;

--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of wf_status_bytes_gen is

signal s_var1_access_d1, s_var2_access_d1, s_var3_access_d1 :                std_logic;
signal s_var1_access_d2, s_var2_access_d2, s_var3_access_d2, s_refreshment : std_logic; 


--=================================================================================================
--                                      architecture begin
--=================================================================================================
begin

---------------------------------------------------------------------------------------------------
--@brief: VAR_ACC_synchronisation
-- Use of double buffers to synchronise the incoming signals var1_acc, va2_acc, var3_acc.
 
  VAR_ACC_synchronisation: process(uclk_i) 
  begin
    if rising_edge (uclk_i) then
      if nFIP_rst_i = '1' then
        s_var1_access_d1 <= '0';
        s_var1_access_d2 <= '0';
        s_var2_access_d1 <= '0'; 
        s_var2_access_d2 <= '0';
        s_var3_access_d1 <= '0';
        s_var3_access_d2 <= '0';

      else
        s_var1_access_d1 <= var1_access_a_i;
        s_var1_access_d2 <= s_var1_access_d1;

        s_var2_access_d1 <= var2_access_a_i; 
        s_var2_access_d2 <= s_var2_access_d1;

        s_var3_access_d1 <= var3_access_a_i;
        s_var3_access_d2 <= s_var3_access_d1;
      end if;
    end if;
  end process;

---------------------------------------------------------------------------------------------------
--! @brief Synchronous process Status_byte_Formation: Formation of the nanoFIP status byte
--! according to the definitions in Table 8 of specs.

  status_byte_formation: process(uclk_i) 
  begin

    if rising_edge(uclk_i) then
  
      if ((nFIP_rst_i = '1') or (reset_status_bytes_i = '1')) then -- the byte is reinitialized
        nFIP_status_byte_o                    <= (others => '0');  -- after having been delivered

        else

        if ((var1_rdy_i = '0' and s_var1_access_d2 = '1') or      -- since the last time the status
            (var2_rdy_i = '0' and s_var2_access_d2 = '1')) then   -- byte was delivered,
          nFIP_status_byte_o(c_U_CACER_INDEX) <= '1';             -- the user logic accessed a cosmd
        end if;                                                   -- variable when it was not ready

        if ((var3_rdy_i = '0') and (s_var3_access_d2 = '1')) then -- since the last time the status 
          nFIP_status_byte_o(c_U_PACER_INDEX) <= '1';             -- byte was delivered,
        end if;                                                   -- the user logic accessed a prod
                                                                  -- variable when it was not ready

        if ((var_i = var_1 or var_i = var_2) and (code_violation_p_i = '1')) then 
          nFIP_status_byte_o(c_R_BNER_INDEX)  <= '1';             -- since the last time the status 
                                                                  -- byte was delivered, 
        end if;                                                   -- a consumed var arrived for 
                                                                  -- this station with a manch code
                                                                  -- violation (on the rp_dat.Data)

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
--!@brief Synchronous process Refreshment_bit_Formation: Formation of the refreshment bit (used in
--! the mps status byte). It is set to 1 if the user has updated the produced variable (var3_access
--! has been asserted since the last time a variable was produced).
 
  refreshment_bit_formation: process(uclk_i) 
  begin
    if rising_edge(uclk_i) then

      if nFIP_rst_i = '1' or reset_status_bytes_i = '1' then -- the bit is reinitialized
        s_refreshment   <= '0';                              -- after having been delivered
      else

        if (var3_access_a_i = '1') then -- indication that the memory has been accessed
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
 --   if slone_i='1' then
      mps_status_byte_o (7 downto 3)           <= (others => '0');   
      mps_status_byte_o (c_SIGNIFICANCE_INDEX) <= '1';
      mps_status_byte_o (1)                    <= '0';
      mps_status_byte_o (c_REFRESHMENT_INDEX)  <= '1'; 


 --   else
 --     mps_status_byte_o                        <= (others => '0');      
 --     mps_status_byte_o (c_REFRESHMENT_INDEX)  <= s_refreshment; 
 --     mps_status_byte_o (c_SIGNIFICANCE_INDEX) <= s_refreshment;
 --   end if;
  end process;


end architecture rtl;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------