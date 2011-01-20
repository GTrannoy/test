-- Created by : G. Penacoba
-- Creation Date: MAy 2010
-- Description: Module emulating all the user logic activity
-- Modified by: G. Penacoba
-- Modification Date: September 2010
-- Modification consisted on: Configuration settings retrieved from a text file through an independent module.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.tb_package.all;

entity user_interface is
	port(
		urstn_from_nf		: in std_logic;
		var1_rdy_i			: in std_logic;
		var2_rdy_i			: in std_logic;
		var3_rdy_i			: in std_logic;

		rstpon_o			: out std_logic;
		uclk_o				: out std_logic;
		urstn_to_nf			: out std_logic;
		var1_acc_o			: out std_logic;
		var2_acc_o			: out std_logic;
		var3_acc_o			: out std_logic;

		ack_i				: in std_logic;
		dat_i				: in std_logic_vector(15 downto 0);

		adr_o				: out std_logic_vector(9 downto 0);
		cyc_o				: out std_logic;
		dat_o				: out std_logic_vector(15 downto 0);
		rst_o				: out std_logic;
		stb_o				: out std_logic;
		wclk_o				: out std_logic;
		we_o				: out std_logic
	);
end user_interface;

architecture archi of user_interface is

	component slone_interface
	port(
		launch_slone_read	: in std_logic;
		launch_slone_write	: in std_logic;
		uclk				: in std_logic;
		ureset				: in std_logic;

		dat_o				: out std_logic_vector(15 downto 0);
		slone_access_read	: out std_logic;
		slone_access_write	: out std_logic
	);
	end component;

	component slone_monitor
	port(
		dat_i				: in std_logic_vector(15 downto 0);
		dat_o				: in std_logic_vector(15 downto 0);
		slone_access_read	: in std_logic;
		slone_access_write	: in std_logic;
		uclk				: in std_logic;
		ureset				: in std_logic;
		var_id				: in std_logic_vector(1 downto 0)
	);
	end component;

	component user_sequencer
	port(
		urstn_from_nf		: in std_logic;
		uclk_period			: in time;
		wclk_period			: in time;

		block_size			: out std_logic_vector(6 downto 0);
		launch_slone_read	: out std_logic;
		launch_slone_write 	: out std_logic;
		launch_wb_read		: out std_logic;
		launch_wb_write 	: out std_logic;
		transfer_length		: out std_logic_vector(6 downto 0);
		transfer_offset		: out std_logic_vector(6 downto 0);
		var_id			 	: out std_logic_vector(1 downto 0)
	);
	end component;
	
	component user_access_monitor is
	port(
		cyc					: in std_logic;
		slone_access_read	: in std_logic;
		slone_access_write	: in std_logic;
		var1_rdy_i			: in std_logic;
		var2_rdy_i			: in std_logic;
		var3_rdy_i			: in std_logic;
		var_id			 	: in std_logic_vector(1 downto 0);

		var1_acc_o			: out std_logic;
		var2_acc_o			: out std_logic;
		var3_acc_o			: out std_logic
	);
	end component;

	component wishbone_interface
	port(
		block_size			: in std_logic_vector(6 downto 0);
		launch_wb_read		: in std_logic;
		launch_wb_write 	: in std_logic;
		transfer_length		: in std_logic_vector(6 downto 0);
		transfer_offset		: in std_logic_vector(6 downto 0);
		var_id			 	: in std_logic_vector(1 downto 0);
		
		ack_i				: in std_logic;
		clk_i				: in std_logic;
		dat_i				: in std_logic_vector(7 downto 0);
		rst_i				: in std_logic;

		adr_o				: out std_logic_vector(9 downto 0);
		cyc_o				: out std_logic;
		dat_o				: out std_logic_vector(7 downto 0);
		stb_o				: out std_logic;
		we_o				: out std_logic
	);
	end component;

	component wishbone_monitor
	port(
		ack_i					: in std_logic;
		clk_o					: in std_logic;
		dat_i					: in std_logic_vector(7 downto 0);
		rst_o					: in std_logic;

		adr_o					: in std_logic_vector(9 downto 0);
		cyc_o					: in std_logic;
		dat_o					: in std_logic_vector(7 downto 0);
		stb_o					: in std_logic;
		we_o					: in std_logic
	);
	end component;

	component user_config is
	port(
		config_validity		: out time;
		uclk_period			: out time;
		ureset_length		: out time;
		wclk_period			: out time;
		wreset_length		: out time;
		preset_length		: out time
	);
	end component;
	
	signal adr					: std_logic_vector(9 downto 0);
	signal data_from_wb			: std_logic_vector(7 downto 0);
	signal stb					: std_logic;
	signal we					: std_logic;

	signal block_size			: std_logic_vector(6 downto 0):="000" & x"0";
	signal config_validity_time	: time;
	signal cyc					: std_logic;
	signal data_from_slone		: std_logic_vector(15 downto 0);
	signal memory_output		: boolean;
	signal slone_access_read	: std_logic;
	signal slone_access_write	: std_logic;
	signal slone_output			: boolean;
	signal launch_slone_read	: std_logic:='0';
	signal launch_slone_write 	: std_logic:='0';
	signal launch_wb_read		: std_logic:='0';
	signal launch_wb_write 		: std_logic:='0';
	signal transfer_length		: std_logic_vector(6 downto 0):="000" & x"0";
	signal transfer_offset		: std_logic_vector(6 downto 0):="000" & x"0";
	signal uclk					: std_logic:='0';
	signal uclk_period			: time;
	signal ureset				: std_logic;
	signal ureset_length		: time;
	signal var_id		 		: std_logic_vector(1 downto 0):="00";
	signal wclk					: std_logic:='0';
	signal wclk_period			: time;
	signal wreset				: std_logic;
	signal wreset_length		: time;
	signal preset				: std_logic;
	signal preset_length		: time;

begin

	user_clock: process
	begin
		wait for 0 us;			-- wait needed for the config text file to be read
		uclk		<= not(uclk);
		wait for uclk_period/2;
	end process;

	user_reset: process
	begin
		wait for 0 us;			-- wait needed for the config text file to be read
		ureset			<= '1';
		wait for ureset_length;
		ureset			<= '0';
		wait for config_validity_time - ureset_length;
	end process;
	
	wb_clock: process
	begin
		wait for 0 us;			-- wait needed for the config text file to be read
		wclk		<= not(wclk);
		wait for wclk_period/2;
	end process;
	
	wb_reset: process
	begin
		wait for 0 us;			-- wait needed for the config text file to be read
		wreset			<= '1';
		wait for wreset_length;
		wreset			<= '0';
		wait for config_validity_time - wreset_length;
	end process;
	
	por_reset: process
	begin
		wait for 0 us;			-- wait needed for the config text file to be read
		preset			<= '1';
		wait for preset_length;
		preset			<= '0';
		wait for config_validity_time - preset_length;
	end process;
	
	slone_output_detector: process
	begin
		if launch_slone_write ='1' then
			slone_output		<= TRUE;
		elsif memory_output then
			slone_output		<= FALSE;
		end if;
		wait until uclk ='1';
	end process;
	
	memory_output_detector: process
	begin
		if launch_wb_write ='1' then
			memory_output		<= TRUE;
		elsif slone_output then
			memory_output		<= FALSE;
		end if;
		wait until wclk ='1';
	end process;
	
	sa_interface: slone_interface
	port map(
		launch_slone_read		=> launch_slone_read,
		launch_slone_write		=> launch_slone_write,
		uclk					=> uclk,
		ureset					=> ureset,
		
		dat_o					=> data_from_slone,
		slone_access_read		=> slone_access_read,
		slone_access_write		=> slone_access_write
	);
	
	sa_monitor: slone_monitor
	port map(
		dat_i					=> dat_i,
		dat_o					=> data_from_slone,
		slone_access_read		=> slone_access_read,
		slone_access_write		=> slone_access_write,
		uclk					=> uclk,
		ureset					=> ureset,
		var_id					=> var_id
	);
	
	user_sequence: user_sequencer
	port map(
		urstn_from_nf			=> urstn_from_nf,
		uclk_period				=> uclk_period,
		wclk_period				=> wclk_period,
		
		block_size				=> block_size,
		launch_slone_read		=> launch_slone_read,
		launch_slone_write 		=> launch_slone_write,
		launch_wb_read			=> launch_wb_read,
		launch_wb_write 		=> launch_wb_write,
		transfer_length			=> transfer_length,
		transfer_offset			=> transfer_offset,
		var_id					=> var_id
	);

	user_acc_monitor: user_access_monitor
	port map(
		cyc						=> cyc,
		slone_access_read		=> slone_access_read,
		slone_access_write		=> slone_access_write,
		var1_rdy_i				=> var1_rdy_i,
		var2_rdy_i				=> var2_rdy_i,
		var3_rdy_i				=> var3_rdy_i,
		var_id					=> var_id,

		var1_acc_o				=> var1_acc_o,
		var2_acc_o				=> var2_acc_o,
		var3_acc_o				=> var3_acc_o
	);

	wb_interface:  wishbone_interface
	port map(
		block_size				=> block_size,
		launch_wb_read			=> launch_wb_read,
		launch_wb_write 		=> launch_wb_write,
		transfer_length			=> transfer_length,
		transfer_offset			=> transfer_offset,
		var_id					=> var_id,

		ack_i					=> ack_i,
		clk_i					=> wclk,
		dat_i					=> dat_i(7 downto 0),
		rst_i					=> wreset,

		adr_o					=> adr,
		cyc_o					=> cyc,
		dat_o					=> data_from_wb,
		stb_o					=> stb,
		we_o					=> we
	);
	
	wb_monitor: wishbone_monitor
	port map(
		ack_i					=> ack_i,
		clk_o					=> wclk,
		dat_i					=> dat_i(7 downto 0),
		rst_o					=> wreset,
		adr_o					=> adr,
		cyc_o					=> cyc,
		dat_o					=> data_from_wb,
		stb_o					=> stb,
		we_o					=> we
	);
	
	user_configuration: user_config
	port map(
		config_validity			=> config_validity_time,
		uclk_period				=> uclk_period,
		ureset_length			=> ureset_length,
		wclk_period				=> wclk_period,
		wreset_length			=> wreset_length,
		preset_length			=> preset_length
	);
	
	uclk_o				<= uclk;
	urstn_to_nf			<= not(ureset);
	rstpon_o			<= not(preset);

	adr_o				<= adr;
	cyc_o				<= cyc;
	rst_o				<= wreset;
	wclk_o				<= wclk;
	stb_o				<= stb;
	we_o				<= we;

	dat_o				<=		data_from_slone			when slone_output
						else	x"00" & data_from_wb	when memory_output
						else	(others=>'0');
	
end archi;
