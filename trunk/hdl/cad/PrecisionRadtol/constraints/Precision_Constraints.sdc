###################
# Clocks
###################

create_clock { uclk_i } -name uclk_i -period 25.000000

create_clock { wclk_i } -name wclk_i -period 25.000000

#create_clock -design rtl -period 200 -name JTAG_controller/reg_s_tck/out JTAG_controller.reg_s_tck.out


###################
# Global Resources
###################

set_attribute -design rtl -name buffer_sig -value CLKBUF -net { uclk_i }

set_attribute -design rtl -name buffer_sig -value CLKBUF -net { wclk_i }

set_attribute -design rtl -name BUFFER_SIG -value CLKINT -net {JTAG_controller.jc_tck_o}

###################
# Input delays
###################

set_input_delay 10.000 -clock uclk_i -add_delay  -design rtl  {dat_i(*) fd_rxd_i fd_txer_i fd_wdgn_i rstin_i var1_acc_i var2_acc_i var3_acc_i}

set_input_delay 15.000 -clock uclk_i -add_delay  -design rtl  {m_id_i(*) c_id_i(*)}

set_input_delay 10.000 -clock wclk_i -add_delay  -design rtl  {adr_i(*) cyc_i rst_i stb_i we_i}


###################
# Output delays
###################

set_output_delay 10.000 -clock uclk_i -add_delay  -design rtl  {dat_o(*) fd_rstn_o fd_txck_o fd_txd_o fd_txena_o r_fcser_o r_tler_o rston_o s_id_o(*) u_cacer_o u_pacer_o var1_rdy_o var2_rdy_o var3_rdy_o}

set_output_delay 15.000 -clock uclk_i -add_delay  -design rtl  {s_id_o(*)}

set_output_delay 10.000 -clock wclk_i -add_delay  -design rtl  {ack_o}