--_________________________________________________________________________________________________
--                                                                                                |
--                                        |The nanoFIP|                                           |
--                                                                                                |
--                                        CERN,BE/CO-HT                                           |
--________________________________________________________________________________________________|
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--! @file WF_cons_outcome.vhd                                                                     |
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
--                                         WF_cons_outcome                                       --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
--
--! @brief     According to the consumed variable that has been received (var_1, var_2, var_rst)
--!            and the output of the WF_cons_frame_validator, the unit generates the signals:
--!
--!              o "nanoFIP User Interface, NON_WISHBONE" output signals VAR1_RDY and VAR2_RDY,
--!              o rst_nFIP_and_FD_p and assert_RSTON_p, that are inputs to the WF_reset_unit.    
--
--
--! @author    Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch) \n
--!            Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)     \n
--
--
--! @date      14/01/2011
--
--
--! @version   v0.04
--
--
--! @details \n  
--
--!   \n<b>Dependencies:</b>           \n
--!            WF_reset_unit           \n
--!            WF_engine_control       \n
--!            WF_cons_frame_validator \n
--!            WF_cons_bytes_processor \n
--
--
--!   \n<b>Modified by:</b>\n
--!            Evangelia Gousiou (Evangelia.Gousiou@cern.ch)
--
--------------------------------------------------------------------------------------------------- 
--
--!   \n\n<b>Last changes:</b>\n
--!     -> 10/2010  v0.01  EG  First version \n
--!     -> 11/2010  v0.02  EG  Treatment of reset vars added to the unit
--!                            Correction on var1_rdy, var2_rdy for slone
--!     -> 12/2010  v0.03  EG  Finally no broadcast in slone, cleanning-up+commenting
--!     -> 01/2010  v0.04  EG  Unit WF_var_rdy_generator separated in WF_cons_outcome
--!                            (for var1_rdy,var2_rdy+var_rst outcome) & WF_prod_permit (for var3)
--
--------------------------------------------------------------------------------------------------- 
--
--! @todo 
--
--------------------------------------------------------------------------------------------------- 

---/!\----------------------------/!\----------------------------/!\-------------------------/!\---
--                               Sunplify Premier D-2009.12 Warnings                             --
-- -- --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --
-- "W CL246  Input port bits 0, 5, 6 of var_i(0 to 6) are unused"                                --
-- var_i is one-hot encoded and has 7 values.                                                    -- 
-- The unit is treating only the variables var_1, var_2 and var_rst.                             --
---------------------------------------------------------------------------------------------------


--=================================================================================================
--!                           Entity declaration for WF_cons_outcome
--=================================================================================================

entity WF_cons_outcome is

  port (
  -- INPUTS 
    -- nanoFIP User Interface, General signals (synchronized with uclk) 
    uclk_i                : in std_logic;                   --! 40 MHz clock
    slone_i               : in std_logic;                   --! stand-alone mode 

    -- nanoFIP WorldFIP Settings (synchronized with uclk) 
    subs_i                : in std_logic_vector(7 downto 0);--! subscriber number coding
 
    -- Signal from the WF_reset_unit
    nfip_rst_i            : in std_logic;                   --! nanoFIP internal reset

    -- Signals from the WF_cons_frame_validator
    cons_frame_ok_p_i     : in std_logic;                   --! pulse after a correct cons frame

    -- Signal from the WF_engine_control unit
    var_i                 : in t_var;                       --! variable type that is being treated

    -- Signals from the WF_cons_bytes_processor
    cons_var_rst_byte_1_i : in std_logic_vector(7 downto 0);--! 1st data-byte of a received var_rst
    cons_var_rst_byte_2_i : in std_logic_vector(7 downto 0);--! 2nd data-byte of a received var_rst


  -- OUTPUTS
    -- nanoFIP User Interface, NON-WISHBONE outputs
    var1_rdy_o            : out std_logic; --! signals new data is received and can safely be read
    var2_rdy_o            : out std_logic; --! signals new data is received and can safely be read

    -- Signals to the WF_reset_unit
    assert_rston_p_o      : out std_logic;  --! indicates that a var_rst with its 2nd data-byte
                                            --! containing the station's address has been
                                            --! correctly received

    rst_nfip_and_fd_p_o   : out std_logic   --! indicates that a var_rst with its 1st data-byte
                                            --! containing the station's address has been
                                            --! correctly received
      );
end entity WF_cons_outcome;


--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of WF_cons_outcome is

signal s_var1_received, s_var2_received, cons_frame_ok_p_d1 : std_logic;
signal s_rst_nfip_and_fd, s_assert_rston                    : std_logic;

--=================================================================================================
--                                      architecture begin
--=================================================================================================  
begin

---------------------------------------------------------------------------------------------------
--!@brief Synchronous process VAR_RDY_Generation: 

--! Memory Mode:
  --! Since the three memories (consumed, consumed broadcast, produced) are independent, when a
  --! produced var is being sent, the user can read form the consumed memories; similarly, when a
  --! consumed var is being received the user can read from the consumed broadcast memory.

  --! VAR1_RDY (for consumed vars): signals that the user can safely read from the consumed memory.
  --! The signal is asserted only after the reception of a correct RP_DAT frame.
  --! It is de-asserted after the reception of a correct var_1 ID_DAT frame. 

  --! VAR2_RDY (for broadcast consumed vars): signals that the user can safely read from the
  --! consumed broadcast memory. The signal is asserted only after the reception of a correct
  --! consumed broadcast RP_DAT frame. It is de-asserted after the reception of a correct var_2
  --! ID_DAT frame. 


--! Stand-alone Mode:
  --! Similarly, in stand-alone mode, the DAT_I and DAT_O buses for the produced and the consumed 
  --! bytes are independent. Stand-alone mode though does not treat the consumed broadcast variable.

  --! VAR1_RDY (for consumed vars): signals that the user can safely retrieve data from the DAT_O
  --! bus. The signal is asserted only after the reception of a correct RP_DAT frame.
  --! It is de-asserted after the reception of a correct var_1 ID_DAT frame(same as in memory mode).

  --! VAR2_RDY (for broadcast consumed vars): stays always deasserted.

--! Note: A correct consumed RP_DAT frame is signaled by the cons_frame_ok_p_i, whereas a correct
--! ID_DAT frame along with the variable it contained is signaled by the var_i.
--! For consumed variables, var_i gets its value (var_1, var_2, var_rst) after the reception of a
--! correct ID_DAT frame and of a correct FSS of the corresponding RP_DAT frame and it retains it
--! until the end of the reception.

  VAR_RDY_Generation: process (uclk_i) 
  begin
    if rising_edge (uclk_i) then
      if nfip_rst_i = '1' then
        var1_rdy_o          <= '0';
        var2_rdy_o          <= '0';
        s_var1_received     <= '0';
        s_var2_received     <= '0';

      else
      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --
        case var_i is

        when var_1 =>                              -- nanoFIP consuming
                                                   --------------------   
          var1_rdy_o        <= '0';                -- while consuming a var_1, VAR1_RDY is 0
          var2_rdy_o        <= s_var2_received;    -- VAR2_RDY retains its value


          --  --  --  --  --  --  --  --  --  --  --
          if cons_frame_ok_p_d1 = '1' then        -- only if the received RP_DAT frame is correct,
                                                  -- the nanoFIP signals the user to retreive data 
            s_var1_received <= '1';               -- note:the signal s_var1_received remains asser-
                                                  -- ted after the end of the cons_frame_ok_p pulse
          end if;



      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --
        when var_2 =>                             -- nanoFIP consuming broadcast     
                                                  ------------------------------ 
          var2_rdy_o        <= '0';               -- while consuming a var_2, VAR2_RDY is 0
          var1_rdy_o        <= s_var1_received;   -- VAR1_RDY retains its value

          if slone_i = '0' and cons_frame_ok_p_d1 = '1' then        
                                                  -- only in memory mode and if the received RP_DAT
            s_var2_received <= '1';               -- frame is correct, the nanoFIP signals the user
                                                  -- to retreive data.
                                                  -- note:the signal s_var2_received remains asser-
          end if;                                 -- ted after the end of the cons_frame_ok_p pulse 

    

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --

        when others =>

          var1_rdy_o        <= s_var1_received;
          var2_rdy_o        <= s_var2_received; 
           
      
        end case;	 	 
      end if;
    end if;
  end process;


---------------------------------------------------------------------------------------------------
--!@brief Synchronous process Cons_frame_ok_p_delay : a 1-uclk delay is needed for the signal
--! cons_frame_ok_p_i, so that it gets synchronized with the var_i (the end of the pulse takes
--! place at the same moment that var_i changes from one variable to another).  

  Cons_frame_ok_p_delay: process (uclk_i) 
  begin
    if rising_edge (uclk_i) then
      if nfip_rst_i = '1' then
        cons_frame_ok_p_d1 <= '0';
      else
        cons_frame_ok_p_d1 <= cons_frame_ok_p_i;
      end if;
    end if;
  end process;


---------------------------------------------------------------------------------------------------
--!@ brief: Generation of the signals s_rst_nfip_and_fd : signals that the 1st byte of a consumed 
--!                                                        reset var contains the station address   
--!                                  and s_assert_rston : signals that the 2nd byte of a consumed
--!                                                        reset var contains the station address 

  Cons_Reset_Signals: process (uclk_i) 
  begin
    if rising_edge (uclk_i) then

      if nfip_rst_i = '1' then
        s_rst_nfip_and_fd     <= '0';
        s_assert_rston        <= '0';
 
      else

        if var_i = var_rst then
 
          if cons_var_rst_byte_1_i = subs_i then

            s_rst_nfip_and_fd <= '1';   -- rst_nFIP_and_FD_o stays asserted until 
          end if;                       -- the end of the current RP_DAT frame

          if cons_var_rst_byte_2_i = subs_i then  

            s_assert_rston    <= '1'; -- assert_RSTON_o stays asserted until 
          end if;                     -- the end of the current RP_DAT frame
        else
          s_rst_nfip_and_fd   <= '0';
          s_assert_rston      <= '0';
        end if;
      end if;
    end if;
  end process;

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --
  rst_nfip_and_fd_p_o         <= '1' when s_rst_nfip_and_fd = '1' and cons_frame_ok_p_d1= '1'
                            else '0';


  assert_rston_p_o            <= '1' when s_assert_rston = '1' and cons_frame_ok_p_d1= '1'
                            else '0';


end architecture rtl;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------