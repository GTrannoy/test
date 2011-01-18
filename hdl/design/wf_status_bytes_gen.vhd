--_________________________________________________________________________________________________
--                                                                                                |
--                                        |The nanoFIP|                                           |
--                                                                                                |
--                                        CERN,BE/CO-HT                                           |
--________________________________________________________________________________________________|
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--! @file WF_status_bytes_gen.vhd                                                                 |
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
--                                       WF_status_bytes_gen                                     --
--                                                                                               --
--                                         CERN, BE/CO/HT                                        --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
-- unit name   WF_status_bytes_gen
--
--
--! @brief     Generation of the nanoFIP status and MPS status bytes.
--!            The unit is also responsible for outputting the "nanoFIP User Interface, 
--!            NON_WISHBONE" signals U_CACER, U_PACER, R_TLER, R_FCSER, that correspond to nanoFIP
--!            status bits 2 to 5.
--!
--!            The information contained in the nanoFIP status byte is coming from :
--!            o the WF_consumption unit,
--!            o the "nanoFIP FIELDRIVE" inputs fd_wdgn and fd_txer
--!            o the "nanoFIP User Interface, NON_WISHBONE" inputs (VAR_ACC) and outputs (VAR_RDY). 
--!
--!            For the refreshment and significance bits of the MPS status, the signal
--!            "nanoFIP User Interface, NON_WISHBONE" input VAR3_ACC is used.
--!
--!            The MPS status byte and the bits 0 to 5 of the nanoFIP status byte are reset after
--!            having been sent.            
--
--
--! @author    Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch) \n
--!            Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)     \n
--
--
--! @date 10/01/2011
--
--
--! @version v0.03
--
--
--! @details\n 
--
--!   \n<b>Dependencies:</b>\n
--!     WF_consumption      \n
--!     WF_bytes_retriever  \n
--!     WF_prod_permit      \n
--!     WF_reset_unit       \n
--
--
--!   \n<b>Modified by:</b>\n
--!    Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch)
--!    Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)
--
---------------------------------------------------------------------------------------------------
--
--!   \n\n<b>Last changes:</b>\n
--!     -> 07/07/2009  v0.01  PA  First version \n
--!     ->    08/2010  v0.02  EG  Internal extention of the var_rdy signals to avoid nanoFIP status
--!                               errors few cycles after var_rdy deactivation
--!     ->    01/2011  v0.03  EG  u_cacer,pacer etc outputs added; new input nfip_status_r_tler_i
--!                               for nanoFIP status bit 4; var_i input not needed as the signals
--!                               nfip_status_r_fcser_p_i and nfip_status_r_tler_i check the var
--
---------------------------------------------------------------------------------------------------
--
--! @todo 
--
---------------------------------------------------------------------------------------------------

---/!\----------------------------/!\----------------------------/!\-------------------------/!\---
--                               Synplify Premier D-2009.12 Warnings                             --
-- -- --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --
-- "W CL189	Register bits s_nFIP_status_byte(0), s_nFIP_status_byte(1) are always 0, optimizing" --
-- "W CL260	Pruning Register bits 0 and 1 of s_nFIP_status_byte(7 downto 0)"                     --
-- Bits 0 and 1 of nanoFIP status byte are reserved for future ideas.                            --
---------------------------------------------------------------------------------------------------


--=================================================================================================
-- Entity declaration for WF_status_bytes_gen
--=================================================================================================
entity WF_status_bytes_gen is

port (
  -- INPUTS 
    -- nanoFIP User Interface, General signals (synchronized with uclk) 
    uclk_i                  : in std_logic;  --! 40 MHz Clock
    slone_i                 : in  std_logic; --! stand-alone mode

    -- Signal from the WF_reset_unit
    nfip_rst_i              : in std_logic;  --! nanaoFIP internal reset

    -- nanoFIP FIELDRIVE (synchronized with uclk)
    fd_txer_i               : in  std_logic; --! transmitter error
    fd_wdgn_i               : in  std_logic; --! watchdog on transmitter

    -- nanoFIP User Interface, NON-WISHBONE (synchronized with uclk)
    var1_acc_i              : in std_logic;  --! variable 1 access 
    var2_acc_i              : in std_logic;  --! variable 2 access 
    var3_acc_i              : in std_logic;  --! variable 3 access

   -- Signals from the WF_consumption unit 
    nfip_status_r_fcser_p_i : in std_logic;  --! wrong CRC bytes received
    nfip_status_r_tler_i    : in std_logic;  --! wrong PDU_TYPE, Control or Length bytes received
    var1_rdy_i              : in std_logic;  --! variable 1 ready
    var2_rdy_i              : in std_logic;  --! variable 2 ready

   -- Signals from the WF_prod_bytes_retriever unit
    rst_status_bytes_p_i    : in std_logic;  --! reset for both status bytes (apart from bits 6 & 7
                                             --! of nanoFIP status byte); the bytes are reset
                                             --! right after having been delivered

   -- Signals from the WF_prod_permit unit
    var3_rdy_i             : in std_logic;   --! variable 3 ready


  -- OUTPUTS 
    -- nanoFIP User Interface, NON-WISHBONE outputs
    r_fcser_o            : out std_logic;    --! nanoFIP status byte, bit 5
    r_tler_o             : out std_logic;    --! nanoFIP status byte, bit 4
    u_cacer_o            : out std_logic;    --! nanoFIP status byte, bit 2
    u_pacer_o            : out std_logic;    --! nanoFIP status byte, bit 3

    -- Signal to the WF_prod_bytes_retriever
    mps_status_byte_o    : out std_logic_vector (7 downto 0); --! MPS status byte
    nFIP_status_byte_o   : out std_logic_vector (7 downto 0)  --! nanoFIP status byte
     ); 
end entity WF_status_bytes_gen;

--=================================================================================================
--!                                  architecture declaration
--=================================================================================================
architecture rtl of WF_status_bytes_gen is

signal s_refreshment                                                                  : std_logic;
signal s_nFIP_status_byte : std_logic_vector (7 downto 0);
--signal s_var1_rdy_incr_c, s_var1_rdy_extended                                         : std_logic;
--signal s_var2_rdy_incr_c, s_var2_rdy_extended, s_var3_rdy_incr_c, s_var3_rdy_extended : std_logic; 
--signal s_var1_rdy_c, s_var2_rdy_c, s_var3_rdy_c                           : unsigned (3 downto 0);


--=================================================================================================
--                                      architecture begin
--=================================================================================================
begin

---------------------------------------------------------------------------------------------------
--! @brief Synchronous process Status_byte_Formation: Formation of the nanoFIP status byte
--! according to the definitions in Table 8 of nanoFIP's functional specifications.

  nFIP_status_byte_generation: process (uclk_i) 
  begin

    if rising_edge (uclk_i) then
  
      if (nfip_rst_i = '1') then 
        s_nFIP_status_byte                      <= (others => '0'); 

        else
        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
        -- reinitialisation after the transmission of a produced variable
        if (rst_status_bytes_p_i = '1') then                        -- bits 0 to 5 reinitialised
          s_nFIP_status_byte(5 downto 0)        <= (others => '0'); -- after having been delivered
                                                                    -- bits 6 and 7 are only reset
                                                                    -- when nanoFIP is reset
        else
        
          --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
          -- u_cacer
          if ((var1_rdy_i = '0' and var1_acc_i = '1') or
              (var2_rdy_i = '0' and var2_acc_i = '1')) then      -- since the last time the status
                                                                 -- byte was delivered,
            s_nFIP_status_byte(c_U_CACER_INDEX) <= '1';          -- the user logic accessed a cons.
                                                                 -- var. when it was not ready
          end if;                                                


          --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
          -- u_pacer
          if (VAR3_RDY_i = '0' and var3_acc_i = '1') then  
                                                                 -- since the last time the status 
            s_nFIP_status_byte(c_U_PACER_INDEX) <= '1';          -- byte was delivered,
                                                                 -- the user logic accessed a prod.
                                                                 -- var. when it was not ready
          end if;  


          --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
          -- t_wder
          if (fd_wdgn_i = '0') then                              -- FIELDRIVE transmission error 
            s_nFIP_status_byte(c_T_WDER_INDEX)  <= '1';
          end if;


          --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
          -- t_rxer
          if (fd_txer_i = '1') then                              -- FIELDRIVE watchdog timer problem
            s_nFIP_status_byte(c_T_TXER_INDEX)  <= '1';
          end if;


          --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
          --r_tler
          s_nFIP_status_byte(c_R_TLER_INDEX)    <= nfip_status_r_tler_i;


           --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --
          --r_fcser
          s_nFIP_status_byte(c_R_FCSER_INDEX)   <= nfip_status_r_fcser_p_i; 


          --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
 
        end if;
      end if;
    end if;
  end process;
  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -
  --! @brief Concurrent signal assignments
  nFIP_status_byte_o                            <= s_nFIP_status_byte;
  u_cacer_o                                     <= s_nFIP_status_byte(c_U_CACER_INDEX);  
  u_pacer_o                                     <= s_nFIP_status_byte(c_U_PACER_INDEX);
  r_tler_o                                      <= s_nFIP_status_byte(c_R_TLER_INDEX);
  r_fcser_o                                     <= s_nFIP_status_byte(c_R_FCSER_INDEX);

---------------------------------------------------------------------------------------------------
--!@brief Synchronous process 
 
  -- Extend_VAR1_RDY: WF_incr_counter
  -- generic map (g_counter_lgth => 4)
  -- port map(
    -- uclk_i            => uclk_i,
    -- nfip_rst_i       => nfip_rst_i,
    -- reinit_counter_i  => var1_rdy_i,
    -- incr_counter_i    => s_var1_rdy_incr_c,
    -- counter_o         => s_var1_rdy_c,
    -- counter_is_full_o => open);

    -- s_var1_rdy_incr_c   <= '1' when s_var1_rdy_c < "1111"
                      -- else '0';

    -- s_var1_rdy_extended <= '1' when var1_rdy_i= '1' or s_var1_rdy_incr_c = '1'
                      -- else '0';
-------------------------------------------------------------------------------------------------
  -- Extend_VAR2_RDY: WF_incr_counter
  -- generic map (g_counter_lgth => 4)
  -- port map(
    -- uclk_i            => uclk_i,
    -- nfip_rst_i       => nfip_rst_i,
    -- reinit_counter_i  => var2_rdy_i,
    -- incr_counter_i    => s_var2_rdy_incr_c,
    -- counter_o         => s_var2_rdy_c,
    -- counter_is_full_o => open);

    -- s_var2_rdy_incr_c   <= '1' when s_var1_rdy_c < "1111"
                      -- else '0';

    -- s_var2_rdy_extended <= '1' when var2_rdy_i= '1' or s_var2_rdy_incr_c = '1'
                      -- else '0';


-------------------------------------------------------------------------------------------------
  -- Extend_VAR3_RDY: WF_incr_counter
  -- generic map (g_counter_lgth => 4)
  -- port map(
    -- uclk_i            => uclk_i,
    -- nfip_rst_i       => nfip_rst_i,
    -- reinit_counter_i  => VAR3_RDY_i,
    -- incr_counter_i    => s_var3_rdy_incr_c,
    -- counter_o         => s_var3_rdy_c,
    -- counter_is_full_o => open);

    -- s_var3_rdy_incr_c   <= '1' when s_var3_rdy_c < "1111"
                      -- else '0';

    -- s_var3_rdy_extended <= '1' when VAR3_RDY_i= '1' or s_var3_rdy_incr_c = '1'
                      -- else '0';



---------------------------------------------------------------------------------------------------
--!@brief Synchronous process Refreshment_bit_Creation: Creation of the refreshment bit (used in
--! the MPS status byte). The bit is set to 1 if the user has updated the produced variable since
--! its last transmission. The process is checking if the signal var3_access has been asserted
--! since the last production of a variable.
 
  Refreshment_bit_Creation: process (uclk_i) 
  begin
    if rising_edge (uclk_i) then
      if nfip_rst_i = '1' then 
        s_refreshment   <= '0';
      else

        if rst_status_bytes_p_i = '1' then          -- bit reinitialized after a var production
          s_refreshment <= '0';  

        elsif (var3_acc_i = '1') then               -- indication that the memory has been accessed
          s_refreshment <= '1';
        end if;

      end if;
    end if;
end process;

---------------------------------------------------------------------------------------------------
--!@brief Combinatorial process MPS_byte_Creation: Creation of the MPS byte according to the
--! definitions in the Table 2 of the specs.
 
  MPS_byte_Creation: process (slone_i, s_refreshment)
  
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