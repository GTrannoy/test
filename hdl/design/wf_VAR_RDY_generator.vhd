---------------------------------------------------------------------------------------------------
--! @file WF_VAR_RDY_generator.vhd
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
--                                       WF_VAR_RDY_generator                                    --
--                                                                                               --
--                                          CERN, BE/CO/HT                                       --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
--
--! @brief     Generation of the nanoFIP output signals VAR1_RDY, VAR2_RDY, VAR3_RDY according to
--!            the variable that is being treated (var_i) and to the correct frame indicator,
--!            cons_frame_ok_p_i.
--!            If the received variable is the var_rst, the unit generates the signals
--!            rst_nFIP_and_FD_p and assert_RSTON_p, according to the data bytes received and to
--!            the correct frame indicator, cons_frame_ok_p_i.    
--
--
--! @author    Pablo Alvarez Sanchez (pablo.alvarez.sanchez@cern.ch)
--!            Evangelia Gousiou (evangelia.gousiou@cern.ch)
--
--
--! @date      06/2010
--
--
--! @version   v0.02
--
--
--! @details \n  
--
--!   \n<b>Dependencies:</b>\n
--
--
--!   \n<b>Modified by:</b>\n
--!     Evangelia Gousiou (Evangelia.Gousiou@cern.ch)
--
--------------------------------------------------------------------------------------------------- 
--
--!   \n\n<b>Last changes:</b>\n
--!     10/2010  v0.01  EG  First version \n
--!     11/2011  v0.02  EG  Treatment of reset vars added to the unit
--!                         Correction on var1_rdy, var2_rdy for slone
--
--------------------------------------------------------------------------------------------------- 
--
--! @todo 
--!   -> rename the unit to include actions for var reset. 
--
--------------------------------------------------------------------------------------------------- 


--=================================================================================================
--!                           Entity declaration for WF_VAR_RDY_generator
--=================================================================================================

entity WF_VAR_RDY_generator is

  port (
  -- INPUTS 
    -- User Interface general signals (synchronized) 
    uclk_i :              in std_logic;                     --! 40MHz clock
    slone_i :             in std_logic;                     --! Stand-alone mode 
    subs_i :              in std_logic_vector (7 downto 0); --! Station address
 
    -- Signal from the WF_reset_unit unit
    nFIP_urst_i :         in std_logic;                   --! internal reset

   -- Signals from WF_cons_frame_validator
    cons_frame_ok_p_i :   in std_logic;                   --! pulse after a correct consumed frame
    var_i             :   in t_var;                       --! variable that is being treated

  -- Signals from WF_cons_bytes_from_rx
    rx_var_rst_byte_1_i : in std_logic_vector(7 downto 0); --! First & second data bytes of a 
    rx_var_rst_byte_2_i : in std_logic_vector(7 downto 0); --! reset variable


  -- OUTPUT
    -- nanoFIP output signals
    var1_rdy_o :          out std_logic;
    var2_rdy_o :          out std_logic;
    var3_rdy_o :          out std_logic;

    -- Signals for the WF_reset_unit
    assert_RSTON_p_o :    out std_logic;
    rst_nFIP_and_FD_p_o : out std_logic

      );
end entity WF_VAR_RDY_generator;


--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of WF_VAR_RDY_generator is

signal s_var1_received, s_var2_received, cons_frame_ok_p_d1 : std_logic;
signal s_rst_nFIP_and_FD, s_assert_RSTON :                    std_logic;

--=================================================================================================
--                                      architecture begin
--=================================================================================================  
  begin

---------------------------------------------------------------------------------------------------
--!@brief Synchronous process VAR_RDY_Generation: 

--! For produced variables, the signal var_i gets its value (var3, var_presence, var_identif) after 
--! the reception of a correct ID_DAT frame (with correct FSS, Control, PDU_TYPE, Length, CRC and
--! FES bytes and without unexpected code violations) and retains it until the end of the
--! transmission of the corresponding RP_DAT (in detail, until the end of the transmission of the
--! RP_DAT.data field; var_i becomes var_whatever during the RP_DAT.FCS and RP_DAT.FES transmission)
--! For consumed variables, var_i gets its value (var1, var2, var_rst) after the reception of a
--! correct ID_DAT frame and of a correct FSS of the corresponding RP_DAT frame and it retains it
--! unitl the end of the reception.

--! Memory Mode:
  --! In memory mode, since the three memories (consumed, consumed broadcast, produced) are
  --! independant, when a produced var is being sent, the user can read form the consumed memories;
  --! similarly,when a consumed variable is being received the user can write to the produced momory.

  --! VAR1_RDY (for consumed vars): signals that the user can safely read from the consumed
  --! variable memory. The signal is asserted only after the reception of a correct RP_DAT frame.
  --! It is de-asserted after the reception of a correct var1 ID_DAT frame. 

  --! VAR2_RDY (for broadcast consumed vars): signals that the user can safely read from the
  --! consumed broadcast variable memory. The signal is asserted only after the reception of a 
  --! correct consumed broadcast RP_DAT frame. It is de-asserted after the reception of a correct
  --! var2 ID_DAT frame. 

  --! VAR3_RDY (for produced vars): signals that the user can safely write to the produced variable
  --! memory. It is deasserted right after the end of the reception of a correct var3 ID_DAT frame
  --! and stays de-asserted until the end of the transmission of the corresponding RP_DAT from
  --! nanoFIP.

--! Stand-alone Mode:
  --! In stand-alone mode, since the DAT_O bus is the same for consumed and consumed broadcast
  --! variables, only one of the VAR1_RDY and VAR2_RDY can be enabled at a time.
  --! VAR3_RDY remains independant.  

  --! VAR1_RDY (for consumed vars): signals that the user can safely retreive data from the DAT_O
  --! bus. The signal is asserted only after the reception of a correct RP_DAT frame.
  --! It is de-asserted after the reception of a correct var1 or var2 ID_DAT frame. 

  --! VAR2_RDY (for broadcast consumed vars): signals that the user can safely retreive data from
  --! the DAT_O bus. The signal is asserted only after the reception of a correct consumed
  --! broadcast RP_DAT frame. It is deasserted after the reception of a correct var2 or var_1
  --! ID_DAT frame. 

  --! VAR3_RDY (for produced vars): signals that the user can safely access the DAT_I bus
  --! (same treatment as in memory mode).


  VAR_RDY_Generation: process(uclk_i) 
  begin
    if rising_edge(uclk_i) then
      if nFIP_urst_i = '1' then
        var1_rdy_o         <= '0';
        var2_rdy_o         <= '0';
        var3_rdy_o         <= '0';
        s_var1_received    <= '0';
        s_var2_received    <= '0';

      else
      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --
        case var_i is

        when var_1 =>                              -- nanoFIP consuming
                                                   --------------------   
          var1_rdy_o        <= '0';                -- while consuming a var1, VAR1_RDY is 0
          var3_rdy_o        <= '1';                -- VAR3_RDY is independant of var1

          if slone_i = '0' then
            var2_rdy_o      <= s_var2_received;    -- in memory mode VAR2_RDY retains its value
                                                   
          else                                    
            var2_rdy_o      <= '0';                -- in slone VAR2_RDY is de-asserted (bc of the
            s_var2_received <= '0';                -- reception of a valid ID_DAT frame for a var1)
          end if;


          --  --  --  --  --  --  --  --  --  --  --
          if cons_frame_ok_p_d1 = '1' then        -- only if the received RP_DAT frame is correct,
                                                  -- the nanoFIP signals the user to retreive data 
            s_var1_received <= '1';               -- note:the signal s_var1_received remains asser-
                                                  -- ted after the end of the cons_frame_ok_p pulse
          end if;


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --
        when var_2 =>                             -- nanoFIP consuming broadcast     
                                                  ------------------------------ 
          var2_rdy_o        <= '0';               -- while consuming a var2, VAR2_RDY is 0
          var3_rdy_o        <= '1';               -- VAR3_RDY independant of var2


          if slone_i = '0' then
            var1_rdy_o      <= s_var1_received;   -- in memory mode VAR1_RDY retains its value

          else
            var1_rdy_o      <= '0';               -- in slone VAR1_RDY is de-asserted (bc of the
            s_var1_received <= '0';               -- reception of a valid ID_DAT frame for a var2)
          end if;


          if cons_frame_ok_p_d1 = '1' then        -- only if the received RP_DAT frame is correct,
                                                  -- the nanoFIP signals the user to retreive data
            s_var2_received <= '1';               -- note:the signal s_var2_received remains asser-
                                                  -- ted after the end of the cons_frame_ok_p pulse 

          end if;

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --

        when var_3 =>                             -- nanoFIP producing 
                                                  --------------------
          var3_rdy_o <= '0';                      -- while producing VAR3_RDY is 0
          var1_rdy_o <= s_var1_received;          
          var2_rdy_o <= s_var2_received;           

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --

        when others =>

          var1_rdy_o          <= s_var1_received;
          var2_rdy_o          <= s_var2_received; 
          var3_rdy_o          <= '1';               
      
        end case;	 	 
      end if;
    end if;
  end process;


---------------------------------------------------------------------------------------------------
-- a 1-uclk delay is needed for the signal cons_frame_ok_p_i, so that it gets synchronized with
-- the var_i (the end of the pulse takes place at the same moment that var_i changes from one
-- variable to another)  

Cons_frame_ok_p_delay: process(uclk_i) 
  begin
    if rising_edge(uclk_i) then
      if nFIP_urst_i = '1' then
        cons_frame_ok_p_d1 <= '0';
      else
        cons_frame_ok_p_d1 <= cons_frame_ok_p_i;
      end if;
    end if;
  end process;

---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
--!@ brief: Generation of the signals s_rst_nFIP_and_FD: signals that the 1st byte of a consumed 
--!                                                        reset var contains the station address   
--!                               and s_assert_RSTON:    signals that the 2nd byte of a consumed
--!                                                        reset var contains the station address 

Reset_Signals: process (uclk_i) 
  begin
    if rising_edge(uclk_i) then

      if nFIP_urst_i = '1' then
        s_rst_nFIP_and_FD <= '0';
        s_assert_RSTON    <= '0';
 
      else

        if var_i = var_rst then
 
          if rx_var_rst_byte_1_i = subs_i then

            s_rst_nFIP_and_FD <= '1';   -- rst_nFIP_and_FD_o stays asserted until 
          end if;                       -- the end of the current RP_DAT frame

          if rx_var_rst_byte_2_i = subs_i then  

            s_assert_RSTON    <= '1'; -- assert_RSTON_o stays asserted until 
          end if;                     -- the end of the current RP_DAT frame
        else
          s_rst_nFIP_and_FD   <= '0';
          s_assert_RSTON      <= '0';
        end if;
      end if;
    end if;
  end process;

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --
  rst_nFIP_and_FD_p_o <= '1' when s_rst_nFIP_and_FD = '1' and cons_frame_ok_p_d1= '1'
                    else '0';


  assert_RSTON_p_o    <= '1' when s_assert_RSTON = '1' and cons_frame_ok_p_d1= '1'
                    else '0';


end architecture rtl;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------