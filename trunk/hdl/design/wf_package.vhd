--	Package File Template
--
--	Purpose: This package defines supplemental types, subtypes, 
--		 constants, and functions 


library IEEE;
use IEEE.STD_LOGIC_1164.all;
USE ieee.std_logic_unsigned.all;
USE ieee.numeric_std.ALL;

package wf_package is

  constant C_QUARTZ_PERIOD : real := 25.0;



  type t_timeouts is 
  record
    response : integer;
    silence : integer;
  end record;

  constant c_31k25_rate_pos : integer := 0; 
  constant c_1M_rate_pos : integer := 1; 
  constant c_2M5_rate_pos : integer := 2; 
  constant c_11_rate_pos : integer := 3; 


  type t_timeouts_table is array (natural range <>) of t_timeouts;


  constant c_timeouts_table : t_timeouts_table(0 to 3) := -- Time in ns
     (c_31k25_rate_pos => (response => integer(640000.0/C_QUARTZ_PERIOD), silence => integer(5160000.0/C_QUARTZ_PERIOD)),
      c_1M_rate_pos => (response => integer(10000.0/C_QUARTZ_PERIOD), silence => integer(150000.0/C_QUARTZ_PERIOD)),
      c_2M5_rate_pos => (response => integer(16000.0/C_QUARTZ_PERIOD), silence => integer(100000.0/C_QUARTZ_PERIOD)),
      c_11_rate_pos => (response => integer(640000.0/C_QUARTZ_PERIOD), silence => integer(5160000.0/C_QUARTZ_PERIOD))
      );

  type t_integer_array is array (natural range <>) of integer;

  constant c_p3_var_length_table : t_integer_array(0 to 7) := 
    (0 => 2, 1 => 8, 2 => 16, 3 => 32, 4 => 64, 5 => 124, others => 0);  


  constant c_id_dat : std_logic_vector(7 downto 0) := "00000011";
  constant c_rp_dat : std_logic_vector(7 downto 0) := "00000010";


--constant c_var_presence : std_logic_vector(7 downto 0) := x"14";
--constant c_var_identification : std_logic_vector(7 downto 0) := x"10";
--constant c_var_1 : std_logic_vector(7 downto 0) := x"05";
--constant c_var_2 : std_logic_vector(7 downto 0) :=x"04";
--constant c_var_3 : std_logic_vector(7 downto 0) := x"06";
--constant c_var_reset : std_logic_vector(7 downto 0) := x"e0";


  type t_var is (c_st_var_presence, c_st_var_identification, c_st_var_1, c_st_var_2, c_st_var_3, c_st_var_reset, c_st_var_whatever);

  type t_byte_array is array (natural range <>) of std_logic_vector(7 downto 0);


--constant c_pres_byte_array : t_byte_array(1 to 7) := (1 => x"50", 2 => x"05", 3 => x"80", 4 => x"03", 5 => x"00", 6 => x"f0", 7 => x"00");
--constant c_id_byte_array : t_byte_array(1 to 10) := (1 => x"52", 2 => x"08", 3 => x"01", 4 => x"00", 5 => x"00", 6 => x"f0", 7 => x"00", 8 => x"00", 9 => X"00", 10 => X"00");
--
  type t_var_response is (produce, consume, reset);

  type t_var_record is record
    response : t_var_response;
    hexvalue : std_logic_vector(7 downto 0);
    var : t_var;
    base_add : std_logic_vector(9 downto 0);
    array_length : integer;  --! -1 represents a variable length
    byte_array : t_byte_array(0 to 15);
  end record;
--
  type t_var_array is array (natural range <>) of t_var_record;
  
  constant c_var_length_add : integer := 2;
  constant c_pdu_byte_add : integer := 1;

  constant c_cons_byte_add : integer := 6;
  constant c_model_byte_add : integer := 7;

  constant c_var_presence_pos : integer := 0;
  constant c_var_identification_pos : integer := 1;
  constant c_var_var3_pos : integer := 2;
  constant c_var_var1_pos : integer := 3;
  constant c_var_var2_pos : integer := 4;
  constant c_var_reset_pos : integer := 5;

  constant c_byte_0_add : integer := 2;
  constant c_byte_1_add : integer := 3;


  constant c_var_array : t_var_array(0 to 5):= 
    (c_var_presence_pos       => (var => c_st_var_presence,
                                  hexvalue => x"14", 
                                  response => produce,
                                  base_add => "----------",
                                  array_length => 8, 
                                  byte_array => (0 => c_rp_dat, 1 => x"ff", 2 => x"50", 3 => x"05", 4 => x"80", 5 => x"03", 6 => x"00", 
                                                 7 => x"f0", 8 => x"00", others => x"ff")),
     
     c_var_identification_pos => (var => c_st_var_identification,
                                  hexvalue => x"10",
                                  response => produce,
                                  array_length => 11,
                                  base_add => "----------",
                                  byte_array => (0 => c_rp_dat, 1 => x"ff", 2 => x"52", 3 => x"08", 4 => x"01", 5 => x"00", 6 => x"00", 
                                                 7 => x"f0", 8 => x"00", 9 => x"00", 10 => X"00", 11 => X"00",
                                                 others => x"ff")),
     
     c_var_var3_pos           => (var => c_st_var_3,
                                  hexvalue => x"06", 
                                  response => produce,
                                  base_add => "0000000000",
                                  array_length => 3,  
                                  byte_array => (0 => c_rp_dat, 1 => x"ff", 3 => x"40", others => x"ff")),
     c_var_var1_pos           => (var => c_st_var_1,
                                  hexvalue => x"05", 
                                  response => consume,
                                  base_add => "0000000000",
                                  array_length => 8, 
                                  byte_array => (0 => c_rp_dat, 1 => x"ff", 2 => x"50", 3 => x"05", 4 => x"80", 5 => x"03", 6 => x"00", 
                                                 7 => x"f0", 8 => x"00", others => x"ff")),
     c_var_var2_pos           => (var => c_st_var_2,
                                  hexvalue => x"04", 
                                  response => consume,
                                  base_add => "0100000000",
                                  array_length => 2,  
                                  byte_array => (0 => c_rp_dat, 1 => x"ff", 2 => x"40", others => x"ff")),

     c_var_reset_pos           => (var => c_st_var_reset,
                                   hexvalue => x"e0", 
                                   response => reset,
                                   base_add => "0100000000",
                                   array_length => 2,  
                                   byte_array => (0 => c_rp_dat, 1 => x"ff", 2 => x"40", others => x"ff")));


--Status bit position

  constant c_u_cacer_pos : integer := 2; --! Consumed variable access error
  constant c_u_pacer_pos : integer := 3; --! Produced variable access error
  constant c_r_bner_pos : integer := 4; --! Received bit number error. Replaced by code violation.
  constant c_r_fcser_pos : integer := 5; --! Received FCS access error
  constant c_t_txer_pos : integer := 6; --! Transmit error (FIELDDRIVE)
  constant c_t_wder_pos : integer := 7; --! Watchdog error (FIELDDRIVE)

  constant c_refreshment_pos : integer := 0; --! MPS refreshment bit 
  constant c_significance_pos : integer := 2; --! MPS significance bit



  function calc_data_length(var : t_var; 
                            p3_length : std_logic_vector(2 downto 0);
                            nostat : std_logic;
                            slone : std_logic) return std_logic_vector;
  
  component wf_rx_osc 
    generic (C_OSC_LENGTH : integer := 20;
             C_QUARTZ_PERIOD : real := 25.0;
             C_CLKFCDLENTGTH :  natural := 3 
             );

    port (
      uclk_i    : in std_logic; --! User Clock
      rst_i     : in std_logic;

      d_edge_i : in std_logic;

      load_phase_i : in std_logic;	
      
      --! Bit rate         \n
      --! 00: 31.25 kbit/s => 62.5 KHz \n
      --! 01: 1 Mbit/s  => 2 MHz  \n
      --! 10: 2.5 Mbit/s  => 5 MHz  \n
      --! 11: reserved, do not use
      rate_i    : in  std_logic_vector (1 downto 0); --! Bit rate

      clk_fixed_carrier_p_o : out std_logic;
      clk_fixed_carrier_p_d_o : out std_logic_vector(C_CLKFCDLENTGTH -1 downto 0);
      clk_fixed_carrier_o : out std_logic;
      
      clk_carrier_p_o : out std_logic;
      clk_carrier_180_p_o : out std_logic;
      
      clk_bit_p_o  : out std_logic;
      clk_bit_90_p_o  : out std_logic;
      clk_bit_180_p_o  : out std_logic;
      clk_bit_270_p_o  : out std_logic;
      
      edge_window_o : out std_logic;
      edge_180_window_o : out std_logic;
      phase_o : out std_logic_vector(C_OSC_LENGTH -1  downto 0)
      );

  end component wf_rx_osc;


  component  wf_crc 
    generic( 
      c_poly_length :  natural := 16);
    port (
      uclk_i    : in std_logic; --! User Clock
      rst_i     : in std_logic;
      
      start_p_i : in std_logic;
      d_i       : in std_logic;
      d_rdy_p_i     : in std_logic;
      data_fcs_sel_n  : in std_logic;
      crc_o     : out  std_logic_vector(c_poly_length - 1 downto 0);
      crc_rdy_p_o : out std_logic;
      crc_ok_p : out std_logic

      );
  end component wf_crc;


  component deglitcher 
    Generic (C_ACULENGTH : integer := 10);
    Port ( uclk_i : in  STD_LOGIC;
           d_i : in  STD_LOGIC;
           d_o : out  STD_LOGIC;
           carrier_p_i : in  STD_LOGIC;
           d_ready_p_o : out  STD_LOGIC);
  end component deglitcher;

  component wf_rx 

    port (
      uclk_i    : in std_logic; --! User Clock
      rst_i     : in std_logic;
      
      byte_ready_p_o : out std_logic;
      byte_o : out std_logic_vector(7 downto 0);
      last_byte_p_o : out std_logic;
      fss_decoded_p_o : out std_logic;
      code_violation_p_o : out std_logic;
      crc_bad_p_o : out std_logic;
      crc_ok_p_o : out std_logic;
      
      d_re_i : in std_logic;
      d_fe_i : in std_logic;
      d_filtered_i : in std_logic;
      s_d_ready_p_i : in std_logic;
      load_phase_o : out std_logic;	
      clk_bit_180_p_i  : in std_logic;
      edge_window_i : in std_logic;
      edge_180_window_i : in std_logic

      );

  end component wf_rx;


  component wf_tx 

    generic(
      C_CLKFCDLENTGTH :  natural := 3 );
    port (
      uclk_i    : in std_logic; --! User Clock
      rst_i     : in std_logic;

      start_send_p_i  : in std_logic;
      request_byte_p_o : out std_logic;
      byte_ready_p_i : in std_logic; -- byte_ready_p_i is not used
      byte_i : in std_logic_vector(7 downto 0);
      last_byte_p_i : in std_logic;
      
--	 clk_fixed_carrier_p_d_i(0) : in std_logic;
      clk_fixed_carrier_p_d_i : in std_logic_vector(C_CLKFCDLENTGTH -1 downto 0);

      d_o : out std_logic;
      d_e_o : out std_logic
      );
  end component wf_tx;



  component dpblockram_clka_rd_clkb_wr
    generic (c_dl : integer := 42; 		-- Length of the data word 
             c_al : integer := 10);    -- Number of words
                                           -- 'nw' has to be coherent with 'c_al'

    port (clka_i  : in std_logic; 			-- Global Clock
          aa_i : in std_logic_vector(c_al - 1 downto 0);
          da_o : out std_logic_vector(c_dl -1 downto 0);
          
          clkb_i : in std_logic;
          ab_i : in std_logic_vector(c_al - 1 downto 0);
          db_i : in std_logic_vector(c_dl - 1 downto 0);
          web_i : in std_logic);
  end component dpblockram_clka_rd_clkb_wr; 
  
  component wf_engine_control 
    generic( C_QUARTZ_PERIOD : real := 25.0);

    port (
      uclk_i    : in std_logic; --! User Clock
      rst_i     : in std_logic;

      -- Transmiter interface
      start_send_p_o  : out std_logic;
      request_byte_p_i : in std_logic;
      byte_ready_p_o : out std_logic;
-- 	byte_o : out std_logic_vector(7 downto 0);
      last_byte_p_o : out std_logic;
      

      -- Receiver interface
      fss_decoded_p_i : in std_logic;  -- The frame decoder has detected the start of a frame
      byte_ready_p_i : in std_logic;   -- The frame docoder ouputs a new byte on byte_i
      byte_i : in std_logic_vector(7 downto 0);  -- Decoded byte
      frame_ok_p_i : in std_logic;     
      
      -- Worldfip bit rate
      rate_i    : in std_logic_vector(1 downto 0);
      
      subs_i    : in  std_logic_vector (7 downto 0); --! Subscriber number coding.


      --! Produced variable data length \n
      --! 000: 2 Bytes                  \n
      --! 001: 8 Bytes                  \n
      --! 010: 16 Bytes                 \n
      --! 011: 32 Bytes                 \n
      --! 100: 64 Bytes                 \n
      --! 101: 124 Bytes                \n
      --! 110: reserved, do not use     \n
      --! 111: reserved, do not use     \n
      --! Actual size: +1 NanoFIP Status byte +1 MPS Status byte (last transmitted) 
      --! Note: when SLONE=Vcc, p3_lgth_i should be set to 000.
      p3_lgth_i : in  std_logic_vector (2 downto 0); --! Produced variable data length

      --! Stand-alone mode
      --! If connected to Vcc, disables sending of NanoFIP status together with 
      --! the produced data.
      slone_i   : in  std_logic; --! Stand-alone mode


      --! No NanoFIP status transmission
      --! If connected to Vcc, disables sending of NanoFIP status together with 
      --! the produced data.
      nostat_i  : in  std_logic; --! No NanoFIP status transmission

-------------------------------------------------------------------------------
--  USER INTERFACE, non WISHBONE
-------------------------------------------------------------------------------

      --! Signals new data is received and can safely be read (Consumed 
      --! variable 05xyh). In stand-alone mode one may sample the data on the 
      --! first clock edge VAR1_RDY is high.
      var1_rdy_o: out std_logic; --! Variable 1 ready

      --! Signals new data is received and can safely be read (Consumed 
      --! broadcast variable 04xyh). In stand-alone mode one may sample the 
      --! data on the first clock edge VAR1_RDY is high.
      var2_rdy_o: out std_logic; --! Variable 2 ready


      --! Signals that the variable can safely be written (Produced variable 
      --! 06xyh). In stand-alone mode, data is sampled on the first clock after
      --! VAR_RDY is deasserted.
      var3_rdy_o: out std_logic; --! Variable 3 ready



--   prod_byte_i : in std_logic_vector(7 downto 0);
      var_o : out t_var;
      append_status_o : out std_logic;
      add_offset_o : out std_logic_vector(6 downto 0);
      data_length_o : out std_logic_vector(6 downto 0);
      cons_byte_we_p_o : out std_logic
      );

  end component wf_engine_control;
  


  component wf_consumed_vars 
    port (
      uclk_i    : in std_logic; --! User Clock
      rst_i     : in std_logic;

      --! Stand-alone mode
      --! If connected to Vcc, disables sending of NanoFIP status together with 
      --! the produced data.
      slone_i   : in  std_logic; --! Stand-alone mode

      byte_ready_p_i : in std_logic;
      var_i : in t_var;
--	append_status_i : in std_logic;
      add_offset_i : in std_logic_vector(6 downto 0);
--	data_length_i : in std_logic_vector(6 downto 0);
      byte_i : in std_logic_vector(7 downto 0);

      var1_access_wb_clk_o: out std_logic; --! Variable 1 access flag
      var2_access_wb_clk_o: out std_logic; --! Variable 2 access flag

      reset_var1_access_i: in std_logic; --! Reset Variable 1 access flag
      reset_var2_access_i: in std_logic; --! Reset Variable 2 access flag
-------------------------------------------------------------------------------
--!  USER INTERFACE. Data and address lines synchronized with uclk_i
-------------------------------------------------------------------------------

--   dat_i     : in  std_logic_vector (15 downto 0); --! 
      wb_clk_i     : in std_logic;
      wb_dat_o     : out std_logic_vector (15 downto 0); --! 
      wb_adr_i     : in  std_logic_vector (9 downto 0); --! 
      wb_stb_p_i     : in  std_logic; --! Strobe
      wb_ack_p_o     : out std_logic; --! Acknowledge
      wb_we_p_i      : in  std_logic  --! Write enable

      );

  end component wf_consumed_vars;


  component wf_produced_vars is
    port (
      uclk_i    : in std_logic; --! User Clock
      rst_i     : in std_logic;
      --! Identification selection (see M_ID, C_ID)
--   s_id_o    : out std_logic_vector (1 downto 0); --! Identification selection

      --! Identification variable settings. 
      --! Connect the ID inputs either to Gnd, Vcc, S_ID[0] or S_ID[1] to 
      --! obtain different values for the Model data (i=0,1,2,3).\n
      --! M_ID[i] connected to: Gnd S_ID0 SID1 Vcc               \n
      --! Model [2*i]            0    1    0    1                \n
      --! Model [2*i+1]          0    0    1    1
      m_id_i    : in  std_logic_vector (3 downto 0); --! Model identification settings

      --! Constructor identification settings.
      --! Connect the ID inputs either to Gnd, Vcc, S_ID[0] or S_ID[1] to 
      --! obtain different values for the Model data (i=0,1,2,3).\n
      --! C_ID[i] connected to: Gnd S_ID0 SID1 Vcc               \n
      --! Constructor[2*i]       0    1    0    1                \n
      --! Constructor[2*i+1]     0    0    1    1
      c_id_i    : in  std_logic_vector (3 downto 0); --! Constructor identification settings

      subs_i    : in  std_logic_vector (7 downto 0); --! Subscriber number coding.

      --! Stand-alone mode
      --! If connected to Vcc, disables sending of NanoFIP status together with 
      --! the produced data.
      slone_i   : in  std_logic; --! Stand-alone mode


      --! No NanoFIP status transmission
      --! If connected to Vcc, disables sending of NanoFIP status together with 
      --! the produced data.
      nostat_i  : in  std_logic; --! No NanoFIP status transmission

      stat_i : in std_logic_vector(7 downto 0); --! NanoFIP status 
      mps_i : in std_logic_vector(7 downto 0);
      sending_stat_o : out std_logic; --! The status register is being adressed
      sending_mps_o : out std_logic; --! The status register is being adressed

      var3_access_wb_clk_o: out std_logic; --! Variable 2 access flag

      reset_var3_access_i: in std_logic; --! Reset Variable 1 access flag

--   prod_byte_i : in std_logic_vector(7 downto 0);
      var_i : in t_var;
      append_status_i : in std_logic;
      add_offset_i : in std_logic_vector(6 downto 0);
      data_length_i : in std_logic_vector(6 downto 0);
      byte_o : out std_logic_vector(7 downto 0);

-------------------------------------------------------------------------------
--!  USER INTERFACE. Data and address lines synchronized with uclk_i
-------------------------------------------------------------------------------

      wb_dat_i     : in  std_logic_vector (15 downto 0); --! 
      wb_clk_i     : in std_logic;
      wb_dat_o     : out std_logic_vector (15 downto 0); --! 
      wb_adr_i     : in  std_logic_vector (9 downto 0); --! 
      wb_stb_p_i     : in  std_logic; --! Strobe
      wb_ack_p_o     : out std_logic; --! Acknowledge
      wb_we_p_i      : in  std_logic  --! Write enable
      );


  end component wf_produced_vars;

  component wf_tx_rx

    port (
      uclk_i    : in std_logic; --! User Clock
      rst_i     : in std_logic;

      start_send_p_i  : in std_logic;
      request_byte_p_o : out std_logic;
      byte_ready_p_i : in std_logic;
      byte_i : in std_logic_vector(7 downto 0);
      last_byte_p_i : in std_logic;

--   clk_fixed_carrier_p_o : out std_logic;
      d_o : out std_logic;
      d_e_o : out std_logic;
      d_clk_o : out std_logic;
      
      d_a_i : in std_logic;
      
      rate_i    : in std_logic_vector(1 downto 0);
      
      byte_ready_p_o : out std_logic;
      byte_o : out std_logic_vector(7 downto 0);
      last_byte_p_o : out std_logic;
      fss_decoded_p_o : out std_logic;
      code_violation_p_o : out std_logic;
      crc_bad_p_o : out std_logic;
      crc_ok_p_o : out std_logic

      );

  end component wf_tx_rx;

  component status_gen 

    port (
      uclk_i    : in std_logic; --! User Clock
      rst_i     : in std_logic;


-------------------------------------------------------------------------------
-- Connections to wf_tx_rx (WorldFIP received data)
-------------------------------------------------------------------------------
      fd_wdgn_i : in  std_logic; --! Watchdog on transmitter
      fd_txer_i : in  std_logic; --! Transmitter error

      code_violation_p_i : in std_logic;
      crc_bad_p_i : in std_logic;
-------------------------------------------------------------------------------
--  Connections to wf_engine
------------------------------------------------------------------------------- 
      --! Signals new data is received and can safely be read (Consumed 
      --! variable 05xyh). In stand-alone mode one may sample the data on the 
      --! first clock edge VAR1_RDY is high.
      var1_rdy_i: in std_logic; --! Variable 1 ready

      --! Signals new data is received and can safely be read (Consumed 
      --! broadcast variable 04xyh). In stand-alone mode one may sample the 
      --! data on the first clock edge VAR1_RDY is high.
      var2_rdy_i: in std_logic; --! Variable 2 ready


      --! Signals that the variable can safely be written (Produced variable 
      --! 06xyh). In stand-alone mode, data is sampled on the first clock after
      --! VAR_RDY is deasserted.
      var3_rdy_i: in std_logic; --! Variable 3 ready

      var1_access_a_i: in std_logic; --! Variable 1 access
      var2_access_a_i: in std_logic; --! Variable 2 access
      var3_access_a_i: in std_logic; --! Variable 3 access

      reset_var1_access_o : out std_logic; --! Reset Variable 1 access flag
      reset_var2_access_o : out std_logic; --! Reset Variable 2 access flag
      reset_var3_access_o : out std_logic; --! Reset Variable 2 access flag


      stat_sent_p_i : in std_logic;
      mps_sent_p_i : in std_logic; 
      
      stat_o : out std_logic_vector(7 downto 0); 
      mps_o : out std_logic_vector(7 downto 0)
      
-------------------------------------------------------------------------------
--  Connections to data_if
-------------------------------------------------------------------------------


      );

  end component status_gen;
  
    component reset_logic 
      generic(c_reset_length : integer := 4); --! Reset counter length. 4==> 16 uclk_i ticks 

      port (
        uclk_i    : in std_logic; --! User Clock

        rstin_i   : in  std_logic; --! Initialisation control, active low

        --! Reset output, active low. Active when the reset variable is received 
        --! and the second byte contains the station address.
        rston_o   : out std_logic; --! Reset output, active low

	var_i : in t_var;  --! Received variable
        rst_o     : out std_logic --! Reset ouput active high


        );

    end component reset_logic;

      component nanofip

        port (
-------------------------------------------------------------------------------
-- WorldFIP settings
-------------------------------------------------------------------------------
          --! Bit rate         \n
          --! 00: 31.25 kbit/s \n
          --! 01: 1 Mbit/s     \n
          --! 10: 2.5 Mbit/s   \n
          --! 11: reserved, do not use
          rate_i    : in  std_logic_vector (1 downto 0); --! Bit rate

          --! Subscriber number coding. Station address.
          subs_i    : in  std_logic_vector (7 downto 0); --! Subscriber number coding.

          --! Identification selection (see M_ID, C_ID)
          s_id_o    : out std_logic_vector (1 downto 0); --! Identification selection

          --! Identification variable settings. 
          --! Connect the ID inputs either to Gnd, Vcc, S_ID[0] or S_ID[1] to 
          --! obtain different values for the Model data (i=0,1,2,3).\n
          --! M_ID[i] connected to: Gnd S_ID0 SID1 Vcc               \n
          --! Model [2*i]            0    1    0    1                \n
          --! Model [2*i+1]          0    0    1    1
          m_id_i    : in  std_logic_vector (3 downto 0); --! Model identification settings

          --! Constructor identification settings.
          --! Connect the ID inputs either to Gnd, Vcc, S_ID[0] or S_ID[1] to 
          --! obtain different values for the Model data (i=0,1,2,3).\n
          --! C_ID[i] connected to: Gnd S_ID0 SID1 Vcc               \n
          --! Constructor[2*i]       0    1    0    1                \n
          --! Constructor[2*i+1]     0    0    1    1
          c_id_i    : in  std_logic_vector (3 downto 0); --! Constructor identification settings

          --! Produced variable data length \n
          --! 000: 2 Bytes                  \n
          --! 001: 8 Bytes                  \n
          --! 010: 16 Bytes                 \n
          --! 011: 32 Bytes                 \n
          --! 100: 64 Bytes                 \n
          --! 101: 124 Bytes                \n
          --! 110: reserved, do not use     \n
          --! 111: reserved, do not use     \n
          --! Actual size: +1 NanoFIP Status byte +1 MPS Status byte (last transmitted) 
          --! Note: when SLONE=Vcc, p3_lgth_i should be set to 000.
          p3_lgth_i : in  std_logic_vector (2 downto 0); --! Produced variable data length


-------------------------------------------------------------------------------
--  FIELDRIVE connections
-------------------------------------------------------------------------------
          fd_rstn_o : out std_logic; --! Initialisation control, active low
          fd_wdgn_i : in  std_logic; --! Watchdog on transmitter
          fd_txer_i : in  std_logic; --! Transmitter error
          fd_txena_o: out std_logic; --! Transmitter enable
          fd_txck_o : out std_logic; --! Line driver half bit clock
          fx_txd_o  : out std_logic; --! Transmitter data
          fx_rxa_i  : in  std_logic; --! Reception activity detection
          fx_rxd_i  : in  std_logic; --! Receiver data


-------------------------------------------------------------------------------
--  USER INTERFACE, General signals
-------------------------------------------------------------------------------
          uclk_i    : in  std_logic; --! 40 MHz clock

          --! Stand-alone mode
          --! If connected to Vcc, disables sending of NanoFIP status together with 
          --! the produced data.
          slone_i   : in  std_logic; --! Stand-alone mode

          --! No NanoFIP status transmission
          --! If connected to Vcc, disables sending of NanoFIP status together with 
          --! the produced data.
          nostat_i  : in  std_logic; --! No NanoFIP status transmission

          rstin_i   : in  std_logic; --! Initialisation control, active low

          --! Reset output, active low. Active when the reset variable is received 
          --! and the second byte contains the station address.
          rston_o   : out std_logic; --! Reset output, active low


-------------------------------------------------------------------------------
--  USER INTERFACE, non WISHBONE
-------------------------------------------------------------------------------

          --! Signals new data is received and can safely be read (Consumed 
          --! variable 05xyh). In stand-alone mode one may sample the data on the 
          --! first clock edge VAR1_RDY is high.
          var1_rdy_o: out std_logic; --! Variable 1 ready

          --! Signals that the user logic is accessing variable 1. Only used to 
          --! generate a status that verifies that VAR1_RDY was high when 
          --! accessing. May be grounded.
          var1_acc_i: in  std_logic; --! Variable 1 access

          --! Signals new data is received and can safely be read (Consumed 
          --! broadcast variable 04xyh). In stand-alone mode one may sample the 
          --! data on the first clock edge VAR1_RDY is high.
          var2_rdy_o: out std_logic; --! Variable 2 ready

          --! Signals that the user logic is accessing variable 2. Only used to 
          --! generate a status that verifies that VAR2_RDY was high when 
          --! accessing. May be grounded.
          var2_acc_i: in  std_logic; --! Variable 2 access

          --! Signals that the variable can safely be written (Produced variable 
          --! 06xyh). In stand-alone mode, data is sampled on the first clock after
          --! VAR_RDY is deasserted.
          var3_rdy_o: out std_logic; --! Variable 3 ready

          --! Signals that the user logic is accessing variable 3. Only used to 
          --! generate a status that verifies that VAR3_RDY was high when 
          --! accessing. May be grounded.
          var3_acc_i: in  std_logic; --! Variable 3 access


-------------------------------------------------------------------------------
--  USER INTERFACE, WISHBONE SLAVE
-------------------------------------------------------------------------------
          wclk_i    : in  std_logic; --! Wishbone clock. May be independent of UCLK.

          --! Data in. Wishbone access only on bits 7-0. Bits 15-8 only used
          --! in stand-alone mode.
          dat_i     : in  std_logic_vector (15 downto 0); --! Data in

          --! Data out. Wishbone access only on bits 7-0. Bits 15-8 only used
          --! in stand-alone mode.
          dat_o     : out std_logic_vector (15 downto 0); --! Data out
          --  dat_i     : in  std_logic_vector(15 downto 0);
          adr_i     : in  std_logic_vector ( 9 downto 0); --! Address
          rst_i     : in  std_logic; --! Wishbone reset. Does not reset other internal logic.
          stb_i     : in  std_logic; --! Strobe
          ack_o     : out std_logic; --! Acknowledge
          we_i      : in  std_logic  --! Write enable

          );

      end component nanofip;
  

end wf_package;

package body wf_package is

  function calc_data_length(var : t_var; 
                            p3_length : std_logic_vector(2 downto 0);
                            nostat : std_logic;
                            slone : std_logic) return std_logic_vector is
    
    variable v_nostat : std_logic_vector(1 downto 0);
    variable v_p3_length_decoded, v_data_length: unsigned(7 downto 0);
  begin
    v_nostat := ('0'& ((not nostat) and (not slone)));
    v_p3_length_decoded := to_unsigned(c_p3_var_length_table(to_integer(unsigned(p3_length))), v_p3_length_decoded'length);
    v_data_length := to_unsigned(0,v_data_length'length);
    case var is
      when c_st_var_presence =>
        v_data_length := to_unsigned(6,v_data_length'length);
      when c_st_var_identification => 
        v_data_length := to_unsigned(9,v_data_length'length);
      when c_st_var_1 => 
      when c_st_var_2 =>
      when c_st_var_3 =>  
        if nostat = '1' then
          v_data_length := to_unsigned(3,v_data_length'length);
        else
          v_data_length := v_p3_length_decoded + unsigned(v_nostat) ;
        end if;
      when c_st_var_reset =>  
      when others => 
    end case;
    return std_logic_vector(v_data_length);
  end;

  
end wf_package;
