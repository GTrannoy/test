###################
# Clocks
###################

create_clock { uclk_i } -name uclk_i -period 25.000000
create_clock { wclk_i } -name wclk_i -period 25.000000

#create_clock { jc_tck_o } -name JTAG_controller/reg_s_tck:Q -period 200


##################
# Input delays
##################

set_input_delay 10.000 -clock uclk_i {dat_i(*) fd_rxd_i fd_txer_i fd_wdgn_i rstin_i var1_acc_i var2_acc_i var3_acc_i}
set_input_delay 10.000 -clock wclk_i {adr_i(*) cyc_i rst_i stb_i we_i}
set_input_delay 15.000 -clock uclk_i {c_id_i(*) m_id_i(*)}

###################
# Output delays
###################

set_output_delay 10.000 -clock uclk_i {dat_o(*) fd_rstn_o fd_txck_o fd_txd_o fd_txena_o r_fcser_o r_tler_o rston_o u_cacer_o u_pacer_o var1_rdy_o var2_rdy_o var3_rdy_o}
set_output_delay 10.000 -clock wclk_i {ack_o}
set_output_delay 15.000 -clock uclk_i {s_id_o(*)}