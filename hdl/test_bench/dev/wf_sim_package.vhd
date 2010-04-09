--	Package File Template
--
--	Purpose: This package defines supplemental types, subtypes, 
--		 constants, and functions 


LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.all;
USE ieee.numeric_std.ALL;
use IEEE.math_real.all;
use work.wf_package.all;

package wf_sim_package is

  type  t_nanofip_config is record
    rate    :   std_logic_vector (1 downto 0); --! Bit rate
    subs    :   std_logic_vector (7 downto 0); --! Subscriber number coding.
    m_id    :   std_logic_vector (3 downto 0); --! Model identification settings
    c_id    :   std_logic_vector (3 downto 0); --! Constructor identification settings
    p3_lgth :   std_logic_vector (2 downto 0); --! Produced variable data length
    slone     :   std_logic;
    nostat    :   std_logic;
  end record;

  type t_tx_rx_i is record
    start_send_p : std_logic;
    byte_ready_p :  std_logic;
    byte :  std_logic_vector(7 downto 0);
    last_byte :  std_logic;
  end record;

  type  t_tx_rx_o is record
--		request_byte_p : std_logic;
    byte_ready_p :  std_logic;
    byte :  std_logic_vector(7 downto 0);
    last_byte_p :  std_logic;
  end record;

  type t_data_array is array (natural range <>) of std_logic_vector(7 downto 0);


  type  t_mes_array is record
    data :  t_data_array(0 to 123);
    meslength :  integer;
  end record;

  type  t_wb_master_to_slave is record

    --! Data in. Wishbone access only on bits 7-0. Bits 15-8 only used
    --!  stand-alone mode.
    dat_i     :   std_logic_vector (15 downto 0); --! Data in

    adr_i     :   std_logic_vector ( 9 downto 0); --! Address
    rst_i     :   std_logic; --! Wishbone reset. Does not reset other internal logic.
    stb_i     :   std_logic; --! Strobe
    we_i      :   std_logic;  --! Write enable
   end record;


  type  t_wb_slave_to_master is record
    dat_o     :  std_logic_vector (15 downto 0); --! Data out
    ack_o     :  std_logic; --! Acknowledge
   end record;

  procedure init(
    signal tx_rx_i : out t_tx_rx_i);

  procedure send_array(
    signal clk_i : in std_logic;
    constant C_MES_ARRAY : t_mes_array;
    signal tx_rx_i : out t_tx_rx_i;
    signal request_byte_p : in std_logic);
  

  procedure get_array(
    signal clk_i : in std_logic;
    constant C_MES_ARRAY : t_mes_array;
    signal dec_array : out t_mes_array;
    signal tx_rx_o :  in t_tx_rx_o);

  procedure gen_random_array(signal mes_array : out t_mes_array);

  procedure gen_array(
    constant substation :  std_logic_vector(7 downto 0);
    constant do_id_dat : boolean;
    constant do_rp_dat : boolean;
    constant var_pos : integer;
    constant var_length : integer;
    signal mes_array : out t_mes_array);

  procedure prod_var(
    signal clk_i : in std_logic;
    signal tx_rx_i : out t_tx_rx_i;
    signal request_byte_p : in std_logic;
    constant substation :  std_logic_vector(7 downto 0);
    constant nanofip_config : t_nanofip_config;
    constant var_pos : integer;
    signal mes_array : inout t_mes_array);

  procedure req_var(
    signal clk_i : in std_logic;
    signal tx_rx_i : out t_tx_rx_i;
    signal request_byte_p : in std_logic;
    constant substation :  std_logic_vector(7 downto 0);
    constant nanofip_config : t_nanofip_config;
    constant var_pos : integer;
    signal mes_array : inout t_mes_array);
  
procedure init_wb(
    signal wclk_i    : in  std_logic; --! Wishbone clock. May be independent of UCLK.
    signal wb_i : out t_wb_master_to_slave);

    procedure write_wb(

    signal wclk_i    : in  std_logic; --! Wishbone clock. May be independent of UCLK.
    signal wb_m_to_s_o : out t_wb_master_to_slave;
    signal wb_s_to_m_i : in t_wb_slave_to_master; 
    constant data_i : in integer;
    constant add_i :  integer) ;
    
procedure read_wb(
    signal wclk_i    : in  std_logic; --! Wishbone clock. May be independent of UCLK.
    signal wb_m_to_s_o : out t_wb_master_to_slave;
    signal wb_s_to_m_i : in t_wb_slave_to_master; 
    signal data_o : out std_logic_vector(7 downto 0);
    constant add_i :  integer) ;

end wf_sim_package;


package body wf_sim_package is

  procedure init(
    signal tx_rx_i : out t_tx_rx_i) is
  begin
    tx_rx_i.start_send_p <= '0';
    tx_rx_i.byte_ready_p <= '0';
    tx_rx_i.byte <= (others => '1');
    tx_rx_i.last_byte <= '0';
  end;


  procedure send_array(
    signal clk_i : in std_logic;
    constant C_MES_ARRAY : t_mes_array;
    signal tx_rx_i : out t_tx_rx_i;
    signal request_byte_p : in std_logic) is
    variable I : integer := 0;	
    variable vFirst : std_logic;					
  begin
    I := 0; 
    tx_rx_i.start_send_p <= '0';
    tx_rx_i.byte_ready_p <= '0';
    tx_rx_i.byte <= (others => 'X');
    tx_rx_i.last_byte <= '0';

    vFirst := '1';

    while I < (C_MES_ARRAY.meslength - 2) loop
      if vFirst = '1' then
        vFirst := '0';
        wait until rising_edge(clk_i);
        wait for 1 ns;
        tx_rx_i.start_send_p <= '1';
        tx_rx_i.byte_ready_p <= '1';
        tx_rx_i.byte <= C_MES_ARRAY.data(I);
        tx_rx_i.last_byte <= '0';
      else
        wait until request_byte_p = '1';
        wait until rising_edge(clk_i);
        wait for 1 ns;
        tx_rx_i.start_send_p <= vFirst;
        tx_rx_i.byte_ready_p <= '1';
        tx_rx_i.byte <= C_MES_ARRAY.data(I);
        tx_rx_i.last_byte <= '0';
      end if;
      wait until rising_edge(clk_i);
      wait for 1 ns;
      tx_rx_i.start_send_p <= '0';
      tx_rx_i.byte_ready_p <= '0';
--   tx_rx_i.byte <= (others => 'X');
      tx_rx_i.last_byte <= '0';
      I := I + 1; 
    end loop;

    wait until request_byte_p = '1';
    wait until rising_edge(clk_i);
    wait for 1 ns;
    tx_rx_i.start_send_p <= vFirst;
    tx_rx_i.byte_ready_p <= '1';
    tx_rx_i.byte <= C_MES_ARRAY.data(I);

    report "Sent :"&integer'image(conv_integer(C_MES_ARRAY.data(I)))&"at add"&integer'image(I); 

    tx_rx_i.last_byte <= '1';

    wait until rising_edge(clk_i);
    wait for 1 ns;
    tx_rx_i.start_send_p <= '0';
    tx_rx_i.byte_ready_p <= '0';
--   tx_rx_i.byte <= (others => 'X');
    tx_rx_i.last_byte <= '0';
  end;

  procedure get_array(
    signal clk_i : in std_logic;
    constant C_MES_ARRAY : t_mes_array;
    signal dec_array : out t_mes_array;
    signal tx_rx_o :  in t_tx_rx_o) is
    
    variable I : integer := 0;		
    variable v_there_is_a_message : boolean;
    variable vDec_array  : t_mes_array;
  begin
    I := 0; 
    v_there_is_a_message := true;
    while v_there_is_a_message loop
      wait until tx_rx_o.byte_ready_p = '1' or tx_rx_o.last_byte_p = '1';
      wait until falling_edge(clk_i);
      if tx_rx_o.last_byte_p = '1' then
        v_there_is_a_message := false;	
      end if; 
      

      if tx_rx_o.byte_ready_p = '1' then
        vDec_array.meslength := I;
        vDec_array.data(I) :=  tx_rx_o.byte;
        dec_array <= vDec_array;
        I := I + 1;
--			assert C_MES_ARRAY.data(I) /= vdec_array.data(I) report "Data do not match. Received:"&integer'image(to_integer(unsigned(vDec_array.data(I))))&" Should be:"&integer'image(to_integer(unsigned(C_MES_ARRAY.data(I)))) severity failure;
      end if; 
    end loop;
  end;


  procedure gen_random_array(signal mes_array : out t_mes_array) is

    variable vRand : real;
    variable vRandByte : std_logic_vector(7 downto 0);
    variable vRandIndex : integer;

    variable u1 : integer := 3;
    variable u2 : integer := 7;
    variable vMes_array : t_mes_array;
  begin
    uniform(seed1 => u1,seed2 => u2,x => vRand);
    vMes_array.meslength := integer(vRand*123.0);

    for I in 0 to vMes_array.meslength loop
      uniform(seed1 => u1,seed2 => u2,x => vRand);
      vMes_array.data(I) := std_logic_vector(to_unsigned(integer(vRand*256.0), 8));
    end loop;
    mes_array <= vMes_array;
  end;

  procedure gen_array(
    constant substation :  std_logic_vector(7 downto 0);
    constant do_id_dat : boolean;
    constant do_rp_dat : boolean;
    constant var_pos : integer;
    constant var_length : integer;
    signal mes_array : out t_mes_array) is

    variable vRand : real;
    variable vRandByte : std_logic_vector(7 downto 0);
    variable vRandIndex : integer;
    variable u1 : integer := 3;
    variable u2 : integer := 7;
    variable vMes_array : t_mes_array;
  begin
    uniform(seed1 => u1,seed2 => u2,x => vRand);

    for I in 0 to vMes_array.meslength loop
      uniform(seed1 => u1,seed2 => u2,x => vRand);
      vMes_array.data(I) := std_logic_vector(to_unsigned(integer(vRand*256.0), 8));
    end loop;

    if do_id_dat then
      vMes_array.meslength := 4;
      vMes_array.data(0) := c_id_dat;
      vMes_array.data(1) := c_var_array(var_pos).hexvalue;
      vMes_array.data(2) := substation; 
      
    end if;

    if do_rp_dat then
      vMes_array.meslength := var_length;
      vMes_array.data(0) := c_rp_dat;
      vMes_array.data(1) := substation;

      vMes_array.data(2) := c_var_array(var_pos).byte_array(2);
      if c_var_array(var_pos).response = consume then 
        vMes_array.data(3) :=std_logic_vector(to_unsigned(var_length - 2,8));
      else
        vMes_array.data(3) := c_var_array(var_pos).byte_array(3);
      end if;
        report "Var length:"&integer'image(var_length); 
      for I in 4 to var_length loop
        uniform(seed1 => u1,seed2 => u2,x => vRand);
        vMes_array.data(I) := std_logic_vector(to_unsigned(integer(vRand*256.0), 8));

      end loop;
    end if;
    mes_array <= vMes_array;
  end;




  procedure req_var(
    signal clk_i : in std_logic;
    signal tx_rx_i : out t_tx_rx_i;
    signal request_byte_p : in std_logic;
    constant substation :  std_logic_vector(7 downto 0);
    constant nanofip_config : t_nanofip_config;
    constant var_pos : integer;
    signal mes_array : inout t_mes_array) is

    variable v_var_length : integer;
    variable v_t : integer;
  begin

    v_var_length :=  to_integer(unsigned(calc_data_length(c_var_array(var_pos).var, nanofip_config.p3_lgth, nanofip_config.nostat, nanofip_config.slone)));
    
    -- v_var_length :=  calc_data_length(c_var_array(var_pos).var, nanofip_config.p3_lgth, nanofip_config.nostat, nanofip_config.slone);
    gen_array(substation => substation, do_id_dat => true, do_rp_dat => false, 
              var_pos => var_pos, var_length => 0, mes_array => mes_array);

    send_array(clk_i => clk_i, C_MES_ARRAY => mes_array, tx_rx_i => tx_rx_i, request_byte_p => request_byte_p);
    v_t := c_timeouts_table(to_integer(unsigned(nanofip_config.rate))).silence;
    wait for (real(v_t)*C_QUARTZ_PERIOD)*(1 ns);
-- For the moment I just wait a timeout. 
  end;


  procedure prod_var(
    signal clk_i : in std_logic;
    signal tx_rx_i : out t_tx_rx_i;
    signal request_byte_p : in std_logic;
    constant substation :  std_logic_vector(7 downto 0);
    constant nanofip_config : t_nanofip_config;
    constant var_pos : integer;
    signal mes_array : inout t_mes_array) is

    variable v_var_length : integer;
    variable v_t : integer;
  begin


    v_var_length := 15;-- to_integer(unsigned(calc_data_length(c_var_array(var_pos).var, nanofip_config.p3_lgth, nanofip_config.nostat, nanofip_config.slone)));
 
         report "Var length:"&integer'image(v_var_length);

    gen_array(substation => substation, do_id_dat => true, do_rp_dat => false, 
              var_pos => var_pos, var_length => 0, mes_array => mes_array);

    send_array(clk_i => clk_i, C_MES_ARRAY => mes_array, tx_rx_i => tx_rx_i, request_byte_p => request_byte_p);

    v_t := c_timeouts_table(to_integer(unsigned(nanofip_config.rate))).response;
    wait for (real(v_t)*C_QUARTZ_PERIOD)*(1 ns); 

    gen_array(substation => substation, do_id_dat => false, 
              do_rp_dat => true, var_pos => var_pos, var_length => v_var_length, mes_array => mes_array);
    send_array(clk_i => clk_i, C_MES_ARRAY => mes_array, tx_rx_i => tx_rx_i, 
               request_byte_p => request_byte_p);

  end;


procedure init_wb(
    signal wclk_i    : in  std_logic; --! Wishbone clock. May be independent of UCLK.
    signal wb_i : out t_wb_master_to_slave
) is
  begin
    wb_i.dat_i <= (others => 'X'); 
    wb_i.adr_i <= (others => 'X'); 
    wb_i.stb_i <= '0'; 
    wb_i.we_i <= '0';
    wb_i.rst_i <= '0'; 
    wait until rising_edge(wclk_i);
    wb_i.rst_i <= '1';
    wait until rising_edge(wclk_i);
    wb_i.rst_i <= '0'; 
  end;

   
    procedure write_wb(

    signal wclk_i    : in  std_logic; --! Wishbone clock. May be independent of UCLK.
    signal wb_m_to_s_o : out t_wb_master_to_slave;
    signal wb_s_to_m_i : in t_wb_slave_to_master; 
    constant data_i : in integer;
    constant add_i :  integer
) is

  begin

    wb_m_to_s_o.dat_i <= (others => 'X'); 
    wb_m_to_s_o.adr_i <= (others => 'X'); 
    wb_m_to_s_o.stb_i <= '0'; 
    wb_m_to_s_o.we_i <= '0';
    wb_m_to_s_o.rst_i <= '0';

    wait until rising_edge(wclk_i);
    while wb_s_to_m_i.ack_o /= '0' loop
      wait until rising_edge(wclk_i);
    end loop;
    wb_m_to_s_o.dat_i <= std_logic_vector(to_unsigned(data_i,wb_m_to_s_o.dat_i'length)); 
    wb_m_to_s_o.adr_i <= std_logic_vector(to_unsigned(add_i,wb_m_to_s_o.adr_i'length)); 
    wb_m_to_s_o.we_i <= '1';
    wb_m_to_s_o.stb_i <= '1'; 

    wait until rising_edge(wclk_i);
    wb_m_to_s_o.rst_i <= '0';
    wb_m_to_s_o.dat_i <= (others => 'X'); 
    wb_m_to_s_o.adr_i <= (others => 'X'); 
    wb_m_to_s_o.stb_i <= '0'; 
    wb_m_to_s_o.we_i <= '0';

  end;

    procedure read_wb(
    signal wclk_i    : in  std_logic; --! Wishbone clock. May be independent of UCLK.
    signal wb_m_to_s_o : out t_wb_master_to_slave;
    signal wb_s_to_m_i : in t_wb_slave_to_master; 
    signal data_o : out std_logic_vector(7 downto 0);
    constant add_i :  integer
) is
  variable v_data : std_logic_vector(data_o'range); 
  begin

    wb_m_to_s_o.dat_i <= (others => 'X'); 
    wb_m_to_s_o.adr_i <= (others => 'X'); 
    wb_m_to_s_o.stb_i <= '0'; 
    wb_m_to_s_o.we_i <= '0';
    wb_m_to_s_o.rst_i <= '0';

    wait until rising_edge(wclk_i);
    while wb_s_to_m_i.ack_o /= '0' loop
       wait until rising_edge(wclk_i);
    end loop;

  --  wb_m_to_s_o.dat_i <= std_logic_vector(to_unsigned(0,wb_m_to_s_o.dat_i'length)); 
    wb_m_to_s_o.adr_i <= std_logic_vector(to_unsigned(add_i,wb_m_to_s_o.adr_i'length)); 
    wb_m_to_s_o.we_i <= '0';
    wb_m_to_s_o.stb_i <= '1';

    while wb_s_to_m_i.ack_o = '0' loop
     v_data := wb_s_to_m_i.dat_o(v_data'range);
     wait until rising_edge(wclk_i);
    end loop;

    data_o <= wb_s_to_m_i.dat_o(data_o'range);

    wb_m_to_s_o.rst_i <= '0';
    wb_m_to_s_o.dat_i <= (others => 'X'); 
    wb_m_to_s_o.adr_i <= (others => 'X'); 
    wb_m_to_s_o.stb_i <= '0'; 
    wb_m_to_s_o.we_i <= '0';

  end;

--    procedure write_wb_rand_var(

--    signal wclk_i    : in  std_logic; --! Wishbone clock. May be independent of UCLK.
--    signal wb_m_to_s_o : out t_wb_master_to_slave;
--    signal wb_s_to_m_i : in t_wb_slave_to_master;
--    signal var_rdy : in std_logic;
--    signal mes_length : in integer;
--    signal var_acc : out std_logic;
--    signal mes_array : out t_mes_array;
--    constant var_pos : integer

--) is
--variable v_add : integer;
--variable u1, u2 : integer;
--variable  vRand : real;
--variable v_data : std_logic_vector(7 downto 0);
--begin
-- u1 := 2;
-- u2 := 7;
--   uniform(seed1 => u1,seed2 => u2,x => vRand);


----    for I in 0 to mes_length - 1 loop
----          mes_array.data(I) <= std_logic_vector(to_unsigned(integer(vRand*256.0), 8));
----    end loop;

--    var_acc <= '0';

--    v_add := to_integer(unsigned(c_var_array(var_pos).base_add)); 
--    wait until var_rdy = '1' ;
--    var_acc <= '1';
--    for I in 0 to mes_length  loop
--       uniform(seed1 => u1,seed2 => u2,x => vRand);
             
--             v_data :=  std_logic_vector(to_unsigned(integer(vRand*256.0), 8));
--              mes_array.data(I) <= v_data; 
--       write_wb(wclk_i => wclk_i, wb_m_to_s_o => wb_m_to_s_o, 
--          wb_s_to_m_i => wb_s_to_m_i, data_i => to_integer(unsigned(mes_array.data(I))), add_i => v_add);
--       v_add := v_add + 1;
--    assert var_rdy = '0' report "Var_rdy went to 0 while producing varible!!! Var name:"&t_var'image(c_var_array(var_pos).var) severity warning; 
--    end loop;
--    var_acc <= '0';
--end; 


--    procedure read_wb_var(
--    signal wclk_i    : in  std_logic; --! Wishbone clock. May be independent of UCLK.
--    signal wb_m_to_s_o : out t_wb_master_to_slave;
--    signal wb_s_to_m_i : in t_wb_slave_to_master;
--    signal var_rdy : in std_logic;
--    signal var_acc : out std_logic;
--    signal mes_array : inout t_mes_array;
--    constant var_pos : integer

--) is
--variable v_add : integer;
--begin
--    var_acc <= '0';
--    v_add := to_integer(unsigned(c_var_array(var_pos).base_add)); 
--    wait until var_rdy = '1' ;
--    var_acc <= '1';
--    for I in mes_array.data'range  loop
--       read_wb(wclk_i => wclk_i, wb_m_to_s_o => wb_m_to_s_o, 
--          wb_s_to_m_i => wb_s_to_m_i, data_i => mes_array.data(I), add_i => v_add);
--       v_add := v_add + 1;
--    assert var_rdy = '0' report "Var_rdy went to 0 while producing varible!!! Var name:"&t_var'image(c_var_array(var_pos).var) severity warning; 
--    end loop;
--    var_acc <= '0';
--end; 



  
end wf_sim_package;