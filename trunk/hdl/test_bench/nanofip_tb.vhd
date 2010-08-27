-- Created by : G. Penacoba
-- Creation Date: March 2010
-- Description: 
-- Modified by:
-- Modification Date:
-- Modification consisted on:

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;

entity nanofip_tb is
end nanofip_tb;

architecture archi of nanofip_tb is

  component nanofip
  port (
    rate_i    : in  std_logic_vector (1 downto 0); --! Bit rate
    subs_i    : in  std_logic_vector (7 downto 0); --! Subscriber number coding.
    s_id_o    : out std_logic_vector (1 downto 0); --! Identification selection
    m_id_i    : in  std_logic_vector (3 downto 0); --! Model identification settings
    c_id_i    : in  std_logic_vector (3 downto 0); --! Constructor identification settings
    p3_lgth_i : in  std_logic_vector (2 downto 0); --! Produced variable data length

    fd_rstn_o : out std_logic; --! Initialisation control, active low
    fd_wdgn_i : in  std_logic; --! Watchdog on transmitter
    fd_txer_i : in  std_logic; --! Transmitter error
    fd_txena_o: out std_logic; --! Transmitter enable
    fd_txck_o : out std_logic; --! Line driver half bit clock
    fx_txd_o  : out std_logic; --! Transmitter data
    fx_rxa_i  : in  std_logic; --! Reception activity detection
    fx_rxd_i  : in  std_logic; --! Receiver data

    uclk_i    : in  std_logic; --! 40 MHz clock
    slone_i   : in  std_logic; --! Stand-alone mode
    nostat_i  : in  std_logic; --! No NanoFIP status transmission
    rstin_i   : in  std_logic; --! Initialisation control, active low
    rston_o   : out std_logic; --! Reset output, active low
    var1_rdy_o: out std_logic; --! Variable 1 ready
    var1_acc_i: in  std_logic; --! Variable 1 access
    var2_rdy_o: out std_logic; --! Variable 2 ready
    var2_acc_i: in  std_logic; --! Variable 2 access
    var3_rdy_o: out std_logic; --! Variable 3 ready
    var3_acc_i: in  std_logic; --! Variable 3 access
    wclk_i    : in  std_logic; --! Wishbone clock. May be independent of UCLK.
    dat_i     : in  std_logic_vector (15 downto 0); --! Data in
    dat_o     : out std_logic_vector (15 downto 0); --! Data out
    adr_i     : in  std_logic_vector ( 9 downto 0); --! Address
    rst_i     : in  std_logic; --! Wishbone reset. Does not reset other internal logic.
    stb_i     : in  std_logic; --! Strobe
    ack_o     : out std_logic; --! Acknowledge
    cyc_i     : in std_logic;
	we_i      : in  std_logic  --! Write enable
    );
  end component;

	component user_interface
	port(
		urstn_i				: in std_logic;
		var1_rdy_i			: in std_logic;
		var2_rdy_i			: in std_logic;
		var3_rdy_i			: in std_logic;

		uclk_o				: out std_logic;
		urstn_o				: out std_logic;
		var1_acc_o			: out std_logic;
		var2_acc_o			: out std_logic;
		var3_acc_o			: out std_logic;

		ack_i				: in std_logic;
		dat_i				: in std_logic_vector(7 downto 0);

		adr_o				: out std_logic_vector(9 downto 0);
		cyc_o				: out std_logic;
		dat_o				: out std_logic_vector(7 downto 0);
		rst_o				: out std_logic;
		stb_o				: out std_logic;
		wclk_o				: out std_logic;
		we_o				: out std_logic
	);
	end component;

	component fieldrive_interface
	port(
		fd_rstn_i		: in std_logic;
		fd_txck_i		: in std_logic;
		fx_txd_i		: in std_logic;
		fd_txena_i		: in std_logic;

		fx_rxa_o		: out std_logic;
		fx_rxd_o		: out std_logic;
		fd_txer_o		: out std_logic;
		fd_wdgn_o		: out std_logic
	);
	end component;

	component board_settings
	port(
		s_id_i			: in std_logic_vector(1 downto 0);
		
		c_id_o			: out std_logic_vector(3 downto 0);
		m_id_o			: out std_logic_vector(3 downto 0);
		nostat_o		: out std_logic;
		p3_lgth_o		: out std_logic_vector(2 downto 0);
		rate_o			: out std_logic_vector(1 downto 0);
		slone_o			: out std_logic;
		subs_o			: out std_logic_vector(7 downto 0)
	);
	end component;


	signal rate			: std_logic_vector (1 downto 0); --! Bit rate
	signal subs			: std_logic_vector (7 downto 0); --! Subscriber number coding.
	signal s_id			: std_logic_vector (1 downto 0); --! Identification selection
	signal m_id			: std_logic_vector (3 downto 0); --! Model identification settings
	signal c_id			: std_logic_vector (3 downto 0); --! Constructor identification settings
	signal p3_lgth		: std_logic_vector (2 downto 0); --! Produced variable data length

	signal fx_rxa		: std_logic; --! Reception activity detection
	signal fx_rxd		: std_logic; --! Receiver data
	signal fd_txer		: std_logic; --! Transmitter error
	signal fd_wdgn		: std_logic; --! Watchdog on transmitter

	signal fd_rstn		: std_logic; --! Initialisation control, active low
	signal fd_txck		: std_logic; --! Line driver half bit clock
	signal fx_txd		: std_logic; --! Transmitter data
	signal fd_txena		: std_logic; --! Transmitter enable

	signal slone		: std_logic; --! Stand-alone mode
	signal nostat		: std_logic; --! No NanoFIP status transmission

	signal uclk			: std_logic; --! 40 MHz clock
	signal urst_to_nf	: std_logic; --! Initialisation control, active low
	signal urst_from_nf	: std_logic; --! Reset output, active low
	
	signal var1_rdy		: std_logic; --! Variable 1 ready
	signal var1_acc		: std_logic; --! Variable 1 access
	signal var2_rdy		: std_logic; --! Variable 2 ready
	signal var2_acc		: std_logic; --! Variable 2 access
	signal var3_rdy		: std_logic; --! Variable 3 ready
	signal var3_acc		: std_logic; --! Variable 3 access

	signal clk			: std_logic:='1';
	signal reset		: std_logic;

	signal ack			: std_logic:='0';
	signal dat_from_fip	: std_logic_vector(7 downto 0);
	signal slone_dat_o	: std_logic_vector(7 downto 0);
	signal dat_o		: std_logic_vector(15 downto 0);

	signal adr			: std_logic_vector(9 downto 0);
	signal cyc			: std_logic;
	signal dat_to_fip	: std_logic_vector(7 downto 0);
	signal slone_dat_i	: std_logic_vector(7 downto 0);
	signal dat_i		: std_logic_vector(15 downto 0);

	signal rst			: std_logic := '0';
	signal stb			: std_logic;
	signal wclk			: std_logic;
	signal we			: std_logic;

begin

	dut: nanofip
  port map(
    rate_i    => rate,
    subs_i    => subs,
    s_id_o    => s_id,
    m_id_i    => m_id,
    c_id_i    => c_id,
    p3_lgth_i => p3_lgth,

    fx_rxa_i  => fx_rxa,
    fx_rxd_i  => fx_rxd,
    fd_txer_i => fd_txer,
    fd_wdgn_i => fd_wdgn,

    fd_rstn_o => fd_rstn,
    fd_txck_o => fd_txck,
    fx_txd_o  => fx_txd,
    fd_txena_o=> fd_txena,

    uclk_i    => uclk,
    slone_i   => slone,
    nostat_i  => nostat,
    rstin_i   => urst_to_nf,
    rston_o   => urst_from_nf,
    var1_rdy_o=> var1_rdy,
    var1_acc_i=> var1_acc,
    var2_rdy_o=> var2_rdy,
    var2_acc_i=> var2_acc,
    var3_rdy_o=> var3_rdy,
    var3_acc_i=> var3_acc,
    wclk_i    => wclk,
    dat_i     => dat_i,
    dat_o     => dat_o,
    adr_i     => adr,
    rst_i     => rst,
    stb_i     => stb,
    ack_o     => ack,
	cyc_i     => cyc,
    we_i      => we
    );

    dat_i(7 downto 0)	<= dat_to_fip;
    dat_o(7 downto 0)	<= dat_from_fip;
    dat_i(15 downto 8)	<= slone_dat_i;
    dat_o(15 downto 8)	<= slone_dat_o;

	board: board_settings
	port map(
		s_id_i			=> s_id,

		c_id_o			=> c_id,
		m_id_o			=> m_id,
		nostat_o		=> nostat,
		p3_lgth_o		=> p3_lgth,
		rate_o			=> rate,
		slone_o			=> slone,
		subs_o			=> subs
	);
	
	user_logic:  user_interface
	port map(
		urstn_i			=> urst_from_nf,
		var1_rdy_i		=> var1_rdy,
		var2_rdy_i		=> var2_rdy,
		var3_rdy_i		=> var3_rdy,

		uclk_o			=> uclk,
		urstn_o			=> urst_to_nf,
		var1_acc_o		=> var1_acc,
		var2_acc_o		=> var2_acc,
		var3_acc_o		=> var3_acc,

		ack_i			=> ack,
		dat_i			=> dat_from_fip,

		adr_o			=> adr,
		cyc_o			=> cyc,
		dat_o			=> dat_to_fip,
		rst_o			=> rst,
		stb_o			=> stb,
		wclk_o			=> wclk,
		we_o			=> we
	);
	
	fieldrive: fieldrive_interface
	port map(
		fd_rstn_i		=> fd_rstn,
		fd_txck_i		=> fd_txck,
		fx_txd_i		=> fx_txd,
		fd_txena_i		=> fd_txena,

		fd_wdgn_o		=> fd_wdgn,
		fd_txer_o		=> fd_txer,
		fx_rxa_o		=> fx_rxa,
		fx_rxd_o		=> fx_rxd
	);

end archi;
