--=================================================================================================
--! @file wf_reset_unit.vhd
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
--                                        wf_reset_unit                                          --
--                                                                                               --
--                                        CERN, BE/CO/HT                                         --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
-- unit name: wf_reset_unit
--
--! @brief Reset logic. Manages the three nanoFIP reset signals: internal reset, FIELDRIVE reset
--! and user interface reset (RSTON)
--
--
--! @author Erik van der Bij (Erik.van.der.Bij@cern.ch)
--!         Pablo Alvarez Sanchez (pablo.alvarez.sanchez@cern.ch)
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
--!   \n<b>Dependencies:</b>\n
--!     wf_cons_bytes_from_rx\n
-- 
--
--!   \n<b>Modified by:</b>\n
--!     Pablo Alvarez Sanchez (pablo.alvarez.sanchez@cern.ch) \n
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
--!                           Entity declaration for wf_reset_unit
--=================================================================================================
entity wf_reset_unit is
  generic (C_RSTIN_C_LGTH : integer := 3);                   --! rstin counter length 

  port (
  -- INPUTS
    -- User Interface general signals 
    uclk_i :              in std_logic;                      --! 40 MHz clock
    rsti_i :              in  std_logic;                     --! initialisation control, active low
    subs_i :              in  std_logic_vector (7 downto 0); --! Subscriber number coding

    -- Signal from the central control unit wf_engine_control
    var_i :                in t_var;                         --! variable type 

    -- Signals from the wf_cons_bytes_from_rx unit
    rst_var_byte_1_i :    in std_logic_vector (7 downto 0);

    rst_var_byte_2_i :    in std_logic_vector (7 downto 0);


  -- OUTPUTS
    -- nanoFIP internal reset
    nFIP_rst_o :          out std_logic;                    --! nanoFIP internal reset, active high

    -- nanoFIP output to the User Interface 
    rston_o :             out std_logic;                    --! reset output, active low

    -- nanoFIP output to FIELDRIVE
    fd_rstn_o :           out std_logic                     --! FIELDRIVE reset, active low
       );
end entity wf_reset_unit;


--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of wf_reset_unit is

  signal s_rst, s_reset_nFIP_and_FD, s_reset_RSTON  : std_logic;
  signal s_rstin_c :                                  unsigned(C_RSTIN_C_LGTH downto 0)
                                                      := (others=>'0'); -- init for simulation
                                                      
 

--=================================================================================================
--                                      architecture begin
--================================================================================================= 
  begin

---------------------------------------------------------------------------------------------------
--!@brief Synchronous process s_rst_creation: the process follows the input signal rstin 
--! and confirms that it stays active for more than 2^(C_RSTIN_C_LGTH-1) uclk cycles;
--! If so, it enables the signal s_rst to follow it.

  s_rst_creation: process (uclk_i)
  begin
    if rising_edge(uclk_i) then
 
      if (rsti_i = '1')  then                       -- when the rstin in ON
        if (s_rstin_c(s_rstin_c'left) = '0')  then  -- counter counts until 2^(C_RSTIN_C_LGTH-1)
          s_rstin_c <= s_rstin_c+1;                 -- then stays at 2^(C_RSTIN_C_LGTH-1)
        end if;
 
      else                                          -- when the reset is OFF
        s_rstin_c <= (others => '0');               -- counter reinitialized
      end if;

-------------------------------------------------

      if (s_rstin_c(s_rstin_c'left) = '1')  then    -- if rstin was ON for > 2^(C_RSTIN_C_LGTH-1)
        s_rst <= rsti_i;                            -- uclk ticks, the s_rst starts following rstin

      else                                          
        s_rst <= '0';                               -- otherwise it stays to 0
      end if;

    end if;
  
end process;




---------------------------------------------------------------------------------------------------
--!@ brief: Generation of the signals s_reset_nFIP_and_FD: signals that the 1st byte of a consumed 
--!                                                        reset var contains the station address   
--!                               and s_reset_RSTON:       signals that the 2nd byte of a consumed
--!                                                        reset var contains the station address 

Reset_Signals: process (uclk_i) 
begin
  if rising_edge(uclk_i) then

    if s_rst = '1' then
      s_reset_nFIP_and_FD <= '0';
      s_reset_RSTON       <= '0';
 
    else

      if var_i = reset_var then
 
        if rst_var_byte_1_i = subs_i then

          s_reset_nFIP_and_FD <= '1'; -- reset_nFIP_and_FD_o stays asserted until 
        end if;                       -- the end of the current rp_dat frame

        if rst_var_byte_2_i = subs_i then  

          s_reset_RSTON       <= '1'; -- reset_RSTON_o stays asserted until 
        end if;                       -- the end of the current rp_dat frame
      else
        s_reset_nFIP_and_FD <= '0';
        s_reset_RSTON       <= '0';
      end if;
    end if;
  end if;
end process;

---------------------------------------------------------------------------------------------------
--!@brief Synchronous process Reset_Outputs: definitions of the three reset outputs: 
--! rston_o: user interface reset, active low; active when a reset variable is received and the 2nd
--! byte contains the station address.
--! The signal reset_RSTON stays asserted until the end of the transmission of the rp_dat frame

--! nFIP_rst_o: nanoFIP internal reset, active high;active when rstin is active or when a reset variable
--! is received and the 1st byte contains the station address.
--!The signal reset_nFIP_and_FD stays asserted until the end of the transmission of the rp_dat frame

--! fd_rstn_o: fieldrive reset, active low; active when a reset variable is received and the 1st
--! byte contains the station address.
--! The signal reset_nFIP_and_FD_i stays asserted until a new variable for this station is received
 
  Reset_Outputs: process (uclk_i)
  begin
    if rising_edge(uclk_i) then

      rston_o    <= not s_reset_RSTON; 
      nFIP_rst_o <= s_rst or s_reset_nFIP_and_FD;
      fd_rstn_o  <= not (s_rst or s_reset_nFIP_and_FD);                                                       
 
   end if;
  end process;


end architecture rtl;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------