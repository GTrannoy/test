--=================================================================================================
--! @file wf_VAR_RDY_generator.vhd
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
--                                 wf_VAR_RDY_generator                                       --
--                                                                                               --
--                                  CERN, BE/CO/HT                                               --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
--
--! @brief     Generation of the nanoFIP output signals VAR1_RDY, VAR2_RDY, VAR3_RDY according to
--!            the variable that is being treated (wf_engine_control signal)
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
--
--------------------------------------------------------------------------------------------------- 
--
--! @todo 
--!   -> 
--
--------------------------------------------------------------------------------------------------- 


--=================================================================================================
--!                           Entity declaration for wf_VAR_RDY_generator
--=================================================================================================

entity wf_VAR_RDY_generator is

  port (
  -- INPUTS 
    -- User Interface general signals 
    uclk_i :            in std_logic;                    --! 40MHz clock
    slone_i :           in std_logic;                    --! Stand-alone mode 

    -- Signal from the wf_reset_unit unit
    nFIP_u_rst_i :      in std_logic;                  --! internal reset

   -- Signals from wf_engine_control
    cons_frame_ok_p_i : in std_logic;                    --! pulse after a valid consumed frame
    var_i             : in t_var;                        --! variable that is being treated


  -- OUTPUT
    -- Signal to wf_engine_control
    var1_rdy_o :        out std_logic;
    var2_rdy_o :        out std_logic;
    var3_rdy_o :        out std_logic
      );
end entity wf_VAR_RDY_generator;


--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of wf_VAR_RDY_generator is

signal s_var1_received, s_var2_received, cons_frame_ok_p_d1 : std_logic;

--=================================================================================================
--                                      architecture begin
--=================================================================================================  
  begin

---------------------------------------------------------------------------------------------------
--!@brief Synchronous process VAR_RDY_Generation: 

--! The signal var_i gets its value (var1, var2, var3, presence etc) after the reception of a valid
--! id_dat frame and retains it until the end of the reception of a consumed rp_dat or the end of
--! the transmission of a produced rp_dat.

--! VAR1_RDY (for consumed vars): signals that the user can safely read from the consumed variable
--! memory or retreive data from the dat_o bus. The signal is asserted only after a consumed var
--! that has been received correctly.
--! It is deasserted after the reception of a correct var1 ID_DAT frame. 

--! VAR2_RDY (for broadcast consumed vars): signals that the user can safely read from the consumed
--! broadcast variable memory. The signal is asserted only after a broadcast consumed var that has 
--! been received correctly.
--! It is deasserted after the reception of a correct var2 ID_DAT frame. 

--! VAR3_RDY (for produced vars): signals that the user can safely write to the produced variable
--! memory. It is deasserted right after the end of the reception of a correct  var3 id_dat and
--! stays deasserted until the end of the transmission of the corresponding rp_dat from nanoFIP
--! (in detail, it stays deasserted until the end of the transmission of the
--! rp_dat.data field and is enabled during the rp_dat.fcs and rp_dat.fes transmission.

--! Note: in memory mode, since the three memories (consumed, consumed broadcast, produced) are
--! independant, when a produced var is being sent, the user can read form the consumed memories;
--! similarly,when a consumed variable is being received the user can write to the produced momory.
--! In stand-alone mode, since the DAT_O bus is the same for consumed and consumed broadcast
--! variables, only one of the VAR1_RDY and VAR2_RDY can be enabled at a time.
--! VAR3_RDY remains independant.  


  VAR_RDY_Generation: process(uclk_i) 
  begin
    if rising_edge(uclk_i) then
      if nFIP_u_rst_i = '1' then
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
          var1_rdy_o <= '0';                       -- while consuming VAR1_RDY is 0
          var3_rdy_o <= '1';                       -- VAR3_RDY independant of var1
          var2_rdy_o <= s_var2_received;           -- VAR2_RDY enabled only after a valid var2
                                                   -- frame reception

          --  --  --  --  --  --  --  --  --  --  --
          if cons_frame_ok_p_d1 = '1' then        
                                                   -- only if the received rp_dat frame is correct,
            s_var1_received <= '1';                -- the nanoFIP signals the user to retreive data
                                                   -- note: the signal s_var1_received stays asserted
                                                   -- even after the end of the rx_CRC_FES_ok_p_i pulse
            if slone_i = '1' then
              s_var2_received <= '0';              -- in slone mode, only one of the VAR1_RDY,
            end if;                                -- VAR2_RDY can be enabled at a time
          end if;


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --
        when var_2 =>                              -- nanoFIP consuming broadcast     
                                                   ------------------------------ 
          var2_rdy_o <= '0';                       -- while consuming broadcast VAR2_RDY is 0
          var3_rdy_o <= '1';                       -- VAR3_RDY independant of var1
          var1_rdy_o <= s_var1_received;           -- VAR1_RDY enabled only after a valid var1
                                                   -- frame reception

          if cons_frame_ok_p_d1 = '1' then        
                                                   -- only if the received rp_dat frame is correct,
            s_var2_received <= '1';                -- the nanoFIP signals the user to retreive data
                                                   -- note: the signal s_var2_received stays asserted
                                                   -- even after the end of the rx_CRC_FES_ok_p_i pulse
            if slone_i = '1' then
              s_var1_received <= '0';              -- in slone mode, only one of the VAR1_RDY,
            end if;                                -- VAR2_RDY can be enable at a time
          end if;

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --

        when var_3 =>                              -- nanoFIP producing 
                                                   --------------------
          var3_rdy_o <= '0';                       -- while producing VAR3_RDY is 0
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
      if nFIP_u_rst_i = '1' then
        cons_frame_ok_p_d1 <= '0';
      else
        cons_frame_ok_p_d1 <= cons_frame_ok_p_i;
      end if;
    end if;
  end process;


end architecture rtl;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------