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

---/!\----------------------------/!\----------------------------/!\-------------------------/!\---
--                               Synplify Premier D-2009.12 Warnings                             --
-- -- --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- --  --  --  --  --  --  --  --  --
--                                         No Warnings                                           --
---------------------------------------------------------------------------------------------------


--=================================================================================================
--!                           Entity declaration for WF_inputs_synchronizer
--=================================================================================================

entity WF_inputs_synchronizer is

  port (
  -- INPUTS 
    -- nanoFIP User Interface, General signals
    uclk_i            : in std_logic;  --! 40 MHz clock
    nostat_a_i        : in std_logic;
    rstin_a_i         : in std_logic;
    slone_a_i         : in std_logic;

    -- Signal from the WF_reset_unit
    nfip_rst_i       : in std_logic;   --! nanoFIP internal reset

    -- nanoFIP WorldFIP Settings
    c_id_a_i          : in std_logic_vector(3 downto 0);
    m_id_a_i          : in std_logic_vector(3 downto 0);
    p3_lgth_a_i       : in std_logic_vector(2 downto 0);
    rate_a_i          : in std_logic_vector(1 downto 0);
    subs_a_i          : in std_logic_vector(7 downto 0);

    -- nanoFIP User Interface, WISHBONE Slave
    wb_clk_i          : in std_logic;  --! WISHBONE clock
    wb_rst_i          : in std_logic;  --! WISHBONE reset, includes also the PowerOnReset
                                       --! Note: wb_rst is not registered, to comply
                                       --! with WISHBONE rule 3.15
    wb_cyc_a_i        : in std_logic;
    wb_stb_a_i        : in std_logic; 
    wb_we_a_i         : in std_logic;

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
    nostat_o          : out std_logic;
    rstin_o           : out std_logic;
    slone_o           : out std_logic;

    -- nanoFIP WorldFIP Settings
    c_id_o            : out std_logic_vector(3 downto 0);
    m_id_o            : out std_logic_vector(3 downto 0);
    p3_lgth_o         : out std_logic_vector(2 downto 0);
    rate_o            : out std_logic_vector(1 downto 0);
    subs_o            : out std_logic_vector(7 downto 0);

    -- nanoFIP User Interface, WISHBONE Slave
    wb_cyc_o          : out std_logic;
    wb_stb_o          : out std_logic; 
    wb_stb_r_edge_p_o : out std_logic; --! 1 wb_clk-wide pulse on the rising edge of a STB_I
    wb_we_o           : out std_logic;

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
--!                                  architecture declaration
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
--                                      architecture begin
--=================================================================================================  
begin


---------------------------------------------------------------------------------------------------
  RSTIN_synchronization_with_uclk: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      s_u_rst_d3    <= s_u_rst_d3 (1 downto 0) &  rstin_a_i;
    end if;
  end process;
  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  rstin_o           <= s_u_rst_d3(2);


---------------------------------------------------------------------------------------------------
  User_interf_general_signals_synchronization: process (uclk_i)
  begin
    if rising_edge (uclk_i) then

      if nfip_rst_i = '1' then
        s_slone_d3  <= (others => '0');
        s_nostat_d3 <= (others => '0');
      else

        s_slone_d3  <= s_slone_d3 (1 downto 0) & slone_a_i;
        s_nostat_d3 <= s_nostat_d3(1 downto 0) & nostat_a_i;
      end if;                                                          
    end if;
  end process;
  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --   --
  slone_o           <= s_slone_d3(2);
  nostat_o          <= s_nostat_d3(2);


---------------------------------------------------------------------------------------------------
  FIELDRIVE_inputs_synchronization: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if nfip_rst_i = '1' then
       s_fd_rxd_d3   <= (others => '0');
       s_fd_wdgn_d3  <= (others => '0');
       s_fd_txer_d3  <= (others => '0');

      else
       s_fd_rxd_d3   <= s_fd_rxd_d3 (1 downto 0)   & fd_rxd_a_i;
       s_fd_wdgn_d3  <= s_fd_wdgn_d3(1 downto 0)   & fd_wdgn_a_i;
       s_fd_txer_d3  <= s_fd_txer_d3(1 downto 0)   & fd_txer_a_i; 
       s_fd_rxcdn_d3 <= s_fd_rxcdn_d3(1 downto 0)  & fd_rxcdn_a_i;   
      end if; 
    end if;
  end process;
  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  fd_wdgn_o          <= s_fd_wdgn_d3(2);
  fd_txer_o          <= s_fd_txer_d3(2);
  fd_rxd_o           <= s_fd_rxd_d3 (2) and (not s_fd_rxcdn_d3(2)); -- to clean rxd from txd

  s_fd_rxd_r_edge    <= (not s_fd_rxd_d3(2)) and (s_fd_rxd_d3(1)) and (not s_fd_rxcdn_d3(2)); 
  s_fd_rxd_f_edge    <= (s_fd_rxd_d3(2)) and (not s_fd_rxd_d3(1)) and (not s_fd_rxcdn_d3(2));

  fd_rxd_r_edge_p_o  <= s_fd_rxd_r_edge;
  fd_rxd_f_edge_p_o  <= s_fd_rxd_f_edge;

  fd_rxd_edge_p_o    <= s_fd_rxd_r_edge or s_fd_rxd_f_edge;


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


---------------------------------------------------------------------------------------------------
  WISHBONE_inputs_synchronization: process (wb_clk_i)
  begin
   if rising_edge (wb_clk_i) then
     if wb_rst_i = '1' then          -- wb_rst is not buffered to comply with WISHBONE rule 3.15
       s_wb_stb_d1   <= '0';
       s_wb_stb_d2   <= '0';
       s_wb_stb_d3   <= '0';
       s_wb_we_d1    <= '0';
       s_wb_we_d2    <= '0';
       s_wb_we_d3    <= '0';
       s_wb_cyc_d1   <= '0';
       s_wb_cyc_d2   <= '0';
       s_wb_cyc_d3   <= '0';

      else
        s_wb_stb_d1  <= wb_stb_a_i;
        s_wb_stb_d2  <= s_wb_stb_d1; 
        s_wb_stb_d3  <= s_wb_stb_d2;   
        s_wb_stb_d4  <= s_wb_stb_d3;   

        s_wb_we_d1   <= wb_we_a_i;
        s_wb_we_d2   <= s_wb_we_d1;
        s_wb_we_d3   <= s_wb_we_d2;    

        s_wb_cyc_d1  <= wb_cyc_a_i;
        s_wb_cyc_d2  <= s_wb_cyc_d1; 
        s_wb_cyc_d3  <= s_wb_cyc_d2;   

      end if;
    end if;
  end process;
  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  wb_cyc_o           <= s_wb_cyc_d3;
  wb_we_o            <= s_wb_we_d3;
  wb_stb_o           <= s_wb_stb_d3;
  wb_stb_r_edge_p_o  <= (not s_wb_stb_d4) and s_wb_stb_d3; 


--------------------------------------------------------------------------------------------------
  Slone_dat_i_synchronization: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
      if nfip_rst_i = '1' then 
        s_slone_dati_d1 <= (others => '0');
        s_slone_dati_d2 <= (others => '0');
        s_slone_dati_d3 <= (others => '0');

      else
        s_slone_dati_d3 <= s_slone_dati_d2;
        s_slone_dati_d2 <= s_slone_dati_d1; 
        s_slone_dati_d1 <= dat_a_i (15 downto 0);

      end if;
    end if;
  end process;
  --  --  --  --  --  --  --  --  --  --  --  --  --
  slone_dati_o          <= s_slone_dati_d3;


--------------------------------------------------------------------------------------------------
  WorldFIP_Settings_synchronization: process (uclk_i)
  begin
    if rising_edge (uclk_i) then
     if nfip_rst_i = '1' then
       s_rate_d1    <= (others => '0');
       s_rate_d2    <= (others => '0');
       s_rate_d3    <= (others => '0');
       s_subs_d1    <= (others => '0');
       s_subs_d2    <= (others => '0');
       s_subs_d3    <= (others => '0');
       s_mid_d1     <= (others => '0');
       s_mid_d2     <= (others => '0');
       s_mid_d3     <= (others => '0');
       s_cid_d1     <= (others => '0');
       s_cid_d2     <= (others => '0');
       s_cid_d3     <= (others => '0');
       s_p3_lgth_d1 <= (others => '0');
       s_p3_lgth_d2 <= (others => '0');
       s_p3_lgth_d3 <= (others => '0');


     else
       s_rate_d1    <= rate_a_i;
       s_rate_d2    <= s_rate_d1;
       s_rate_d3    <= s_rate_d2;

       s_subs_d1    <= subs_a_i;
       s_subs_d2    <= s_subs_d1;
       s_subs_d3    <= s_subs_d2;

       s_mid_d1     <= m_id_a_i;
       s_mid_d2     <= s_mid_d1;
       s_mid_d3     <= s_mid_d2;

       s_cid_d1     <= c_id_a_i;
       s_cid_d2     <= s_cid_d1;
       s_cid_d3     <= s_cid_d2;

       s_p3_lgth_d1 <= p3_lgth_a_i;
       s_p3_lgth_d2 <= s_p3_lgth_d1;
       s_p3_lgth_d3 <= s_p3_lgth_d2;     
       end if;
     end if;
  end process;
  --  --  --  --  --  --  --  --  --  --
  rate_o            <= s_rate_d3;
  subs_o            <= s_subs_d3;
  m_id_o            <= s_mid_d3;
  c_id_o            <= s_cid_d3;
  p3_lgth_o         <= s_p3_lgth_d3;



end architecture rtl;
--=================================================================================================
--                                      architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                    E N D   O F   F I L E
---------------------------------------------------------------------------------------------------