--_________________________________________________________________________________________________
--                                                                                                |
--                                        |The nanoFIP|                                           |
--                                                                                                |
--                                        CERN,BE/CO-HT                                           |
--________________________________________________________________________________________________|
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--! @file WF_inputs_synchronizer.vhd                                                              |
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
--                                     WF_inputs_synchronizer                                    --
--                                                                                               --
---------------------------------------------------------------------------------------------------
--
--
--! @brief     The unit synchronizes the nanoFIP's input signals to the uclk or the wb_clk;
--!            a set of 3 registers is used for each signal.
--!            Notes : Regarding the WISHBONE interface, only the control signals STB, CYC, WE are
--!                    synchronized. 
--
--
--! @author    Pablo Alvarez Sanchez (Pablo.Alvarez.Sanchez@cern.ch) \n
--!            Evangelia Gousiou     (Evangelia.Gousiou@cern.ch)     \n
--
--
--! @date      09/12/2010
--
--
--! @version   v0.02
--
--
--! @details \n  
--
--!   \n<b>Dependencies:</b>  \n
--!             WF_reset_unit \n
--
--
--!   \n<b>Modified by:</b>\n
--!            Evangelia Gousiou (Evangelia.Gousiou@cern.ch)
--
--------------------------------------------------------------------------------------------------- 
--
--!   \n\n<b>Last changes:</b>\n
--!   10/2010  v0.01  EG First version
--!   12/2010  v0.02  EG fd_rxcdn added;
--!                      in nanoFIP input fd_rxd we also see the nanoFIP output fd_txd; in order to
--!                      get only the receiver's data, we filter fd_rxd with the reception activity
--!                      detection fd_rxcdn. 
--!   1/2011   v0.021 EG wb_rst_a_i renamed to wb_rst_i
--
--------------------------------------------------------------------------------------------------- 
--
--! @todo 
--!   -> 
--
--------------------------------------------------------------------------------------------------- 



--=================================================================================================
--!                           Entity declaration for WF_inputs_synchronizer
--=================================================================================================

entity WF_inputs_synchronizer is

  port (
  -- INPUTS 
    -- nanoFIP User Interface, General signals
    uclk_i            : in std_logic;  --! 40 MHz clock

    -- Signal from the WF_reset_unit
    nfip_rst_i       : in std_logic;   --! nanoFIP internal reset

    -- nanoFIP User Interface, NON WISHBONE 
    dat_a_i           : in std_logic_vector(15 downto 0);
    var1_access_a_i   : in std_logic;
    var2_access_a_i   : in std_logic;
    var3_access_a_i   : in std_logic;

    -- nanoFIP FIELDRIVE
    fd_rxcdn_a_i      : in std_logic; 
    fd_rxd_a_i        : in std_logic; 
    fd_txer_a_i       : in std_logic; 
    fd_wdgn_a_i       : in std_logic; 


  -- OUTPUTS
    -- nanoFIP User Interface, General signals
    rstin_o           : out std_logic;

    -- nanoFIP User Interface, NON WISHBONE 
    slone_dati_o      : out std_logic_vector(15 downto 0);
    var1_access_o     : out std_logic;
    var2_access_o     : out std_logic;
    var3_access_o     : out std_logic;

    -- nanoFIP FIELDRIVE
    fd_rxd_o          : out std_logic;
    fd_rxd_edge_p_o   : out std_logic; 
    fd_rxd_f_edge_p_o : out std_logic;
    fd_rxd_r_edge_p_o : out std_logic; 
    fd_txer_o         : out std_logic; 
    fd_wdgn_o         : out std_logic
      );
end entity WF_inputs_synchronizer;


--=================================================================================================
--!                                    architecture declaration
--=================================================================================================
architecture rtl of WF_inputs_synchronizer is

  signal s_wb_we_d3, s_wb_cyc_d1, s_wb_cyc_d2, s_wb_cyc_d3, s_fd_rxd_f_edge            : std_logic;
  signal s_var1_access_d1, s_var2_access_d1, s_var3_access_d1, s_fd_rxd_r_edge         : std_logic;
  signal s_var1_access_d2, s_var2_access_d2, s_var3_access_d2                          : std_logic;
  signal s_var1_access_d3, s_var2_access_d3, s_var3_access_d3                          : std_logic;
  signal s_wb_stb_d1, s_wb_stb_d2, s_wb_stb_d3, s_wb_stb_d4, s_wb_we_d1, s_wb_we_d2    : std_logic;
  signal s_mid_d1, s_mid_d2, s_mid_d3, s_cid_d1, s_cid_d2, s_cid_d3 : std_logic_vector(3 downto 0);
  signal s_fd_txer_d3, s_fd_wdgn_d3, s_fd_rxd_d3, s_fd_rxcdn_d3     : std_logic_vector(2 downto 0);
  signal s_p3_lgth_d1, s_p3_lgth_d2, s_p3_lgth_d3                   : std_logic_vector(2 downto 0);
  signal s_u_rst_d3                                                 : std_logic_vector(2 downto 0);
  signal s_nostat_d3, s_slone_d3                                    : std_logic_vector(2 downto 0);  
  signal s_rate_d1, s_rate_d2, s_rate_d3                            : std_logic_vector(1 downto 0);   
  signal s_subs_d1, s_subs_d2, s_subs_d3                            : std_logic_vector(7 downto 0); 
  signal s_slone_dati_d1, s_slone_dati_d3, s_slone_dati_d2          :std_logic_vector(15 downto 0);

   


--=================================================================================================
--                                        architecture begin
--=================================================================================================  
begin

---------------------------------------------------------------------------------------------------
  VAR_ACC_synchronization: process (uclk_i) 
  begin
    if rising_edge (uclk_i) then
      if nfip_rst_i = '1' then
        s_var1_access_d1 <= '0';
        s_var1_access_d2 <= '0';
        s_var1_access_d3 <= '0';
        s_var2_access_d1 <= '0'; 
        s_var2_access_d2 <= '0';
        s_var1_access_d3 <= '0';
        s_var3_access_d1 <= '0';
        s_var3_access_d2 <= '0';
        s_var1_access_d3 <= '0';

      else
        s_var1_access_d1 <= var1_access_a_i;
        s_var1_access_d2 <= s_var1_access_d1;
        s_var1_access_d3 <= s_var1_access_d2;

        s_var2_access_d1 <= var2_access_a_i; 
        s_var2_access_d2 <= s_var2_access_d1;
        s_var2_access_d3 <= s_var2_access_d2;

        s_var3_access_d1 <= var3_access_a_i;
        s_var3_access_d2 <= s_var3_access_d1;
        s_var3_access_d3 <= s_var3_access_d2;

      end if;
    end if;
  end process;
  --  --  --  --  --  --  --  --  --  --  --  --
  var1_access_o          <= s_var1_access_d3;
  var2_access_o          <= s_var2_access_d3;
  var3_access_o          <= s_var3_access_d3; 











end architecture rtl;
--=================================================================================================
--                                        architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------