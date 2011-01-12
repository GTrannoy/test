---------------------------------------------------------------------------------------------------
--! @file WF_reset_unit.vhd
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
--                                        WF_reset_unit                                          --
--                                                                                               --
--                                        CERN, BE/CO/HT                                         --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
-- unit name: WF_reset_unit
--
--! @brief Reset logic. Manages the three nanoFIP reset signals: internal reset, FIELDRIVE reset
--! and user interface reset (RSTON)
--
--
--! @author Erik van der Bij (Erik.van.der.Bij@cern.ch)
--!         Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)
--!         Evangelia Gousiou (Evangelia.Gousiou@cern.ch)
--
--
--! @date 08/2010
--
--
--! @version v0.02
--
--
--! @details 
--
--!   \n<b>Dependencies:</b>    \n
--!     wf_cons_bytes_processor \n
-- 
--
--!   \n<b>Modified by:</b>\n
--!     Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch) \n
--!     Evangelia Gousiou (Evangelia.Gousiou@cern.ch)         \n
--
---------------------------------------------------------------------------------------------------
--
--!   \n\n<b>Last changes:</b>\n
--!     07/2009  v0.01  EB  First version \n
--!     08/2010  v0.02  EG  checking of bytes1 and2 of reset var added \n
--!                         fd_rstn_o, nFIP_rst_o enabled only if rstin has been active for > 16 uclk \n
--
---------------------------------------------------------------------------------------------------
--
--! @todo 
--
---------------------------------------------------------------------------------------------------



--=================================================================================================
--!                           Entity declaration for WF_reset_unit
--=================================================================================================
entity WF_reset_unit is
  port (
  -- INPUTS
    -- nanoFIP User Interface, General signals (synchronized with uclk) (after synchronization)
    uclk_i :              in std_logic;                     --! 40 MHz clock
    urst_i :              in std_logic;                     --! initialisation control, active low
    urst_r_edge_i :       in std_logic;
    subs_i :              in std_logic_vector (7 downto 0); --! Subscriber number coding
    rate_i :              in std_logic_vector (1 downto 0);

    -- Signal from the central control unit WF_engine_control
    var_i :               in t_var;                         --! variable type that is being treated
    rst_nFIP_and_FD_p_i : in std_logic;
    assert_RSTON_p_i :    in std_logic;


  -- OUTPUTS
    -- nanoFIP internal reset
    nFIP_rst_o :          out std_logic;                    --! nanoFIP internal reset, active high

    -- nanoFIP User Interface output 
    rston_o :             out std_logic;                    --! reset output, active low

    -- nanoFIP FIELDRIVE output
    fd_rstn_o :           out std_logic                     --! FIELDRIVE reset, active low
       );
end entity WF_reset_unit;


--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of WF_reset_unit is

  signal s_rst  : std_logic;
  signal s_rstin_c :                                  unsigned(4 downto 0) := (others=>'0'); 
                                                      -- counter init for simulation purpuses
 

--=================================================================================================
--                                      architecture begin
--================================================================================================= 
begin

---------------------------------------------------------------------------------------------------
--!@brief Synchronous process s_rst_creation: the process follows the (buffered) input signal rstin 
--! and confirms that it stays active for more than 16 uclk cycles;
--! if so, it enables the signal s_rst to follow it.

  s_rst_creation: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
 
      if (urst_i = '1')  then                       -- when the rstin in ON
        if (s_rstin_c(s_rstin_c'left) = '0')  then  -- counter counts until 16 (then stays at 16)
          s_rstin_c <= s_rstin_c+1;
        end if;
 
      else                                          -- when the reset is OFF
        s_rstin_c <= (others => '0');               -- counter reinitialised
      end if;

-------------------------------------------------

      if (s_rstin_c(s_rstin_c'left) = '1')  then    -- if rstin was ON for at least 16 uclk ticks
        s_rst <= urst_i;                            -- the signal s_rst starts following rstin

      else                                          
        s_rst <= '0';                               -- otherwise it stays to 0
      end if;

    end if;
  
end process;



---------------------------------------------------------------------------------------------------
--!@brief Synchronous process Reset_Outputs: definitions of the three reset outputs: 
--! rston_o: user interface reset, active low; active when a reset variable is received and the 2nd
--! byte contains the station address.
--! The signal reset_RSTON stays asserted until the end of the transmission of the RP_DAT frame

--! nFIP_rst_o: nanoFIP internal reset, active high;active when rstin is active or when a reset variable
--! is received and the 1st byte contains the station address.
--!The signal reset_nFIP_and_FD stays asserted until the end of the transmission of the RP_DAT frame

--! fd_rstn_o: FIELDRIVE reset, active low; active when a reset variable is received and the 1st
--! byte contains the station address.
--! The signal reset_nFIP_and_FD_i stays asserted until a new variable for this station is received
 
  Reset_Outputs: process (uclk_i)
  begin
    if rising_edge (uclk_i) then

      rston_o    <= not assert_RSTON_p_i; 
      nFIP_rst_o <= s_rst or rst_nFIP_and_FD_p_i;
      fd_rstn_o  <= not (s_rst or rst_nFIP_and_FD_p_i);                                                       
 
   end if;
  end process;


end architecture rtl;

--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------