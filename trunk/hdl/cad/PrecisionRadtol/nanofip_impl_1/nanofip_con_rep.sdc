###################################################################################
# Mentor Graphics Corporation
#
###################################################################################

#################
# Attributes
#################
set_attribute -name buffer_sig -value "CLKBUF" -net uclk_i -design rtl 
set_attribute -name buffer_sig -value "CLKBUF" -net wclk_i -design rtl 
set_attribute -name MEMORYFILE -value "" -instance -type string Consumption/Consumption_Bytes_Processor/Consumption_RAM_DualRam_A9D8DualClkRAM_R0C0 -design rtl 
set_attribute -name MEMORYFILE -value "" -instance -type string Consumption/Consumption_Bytes_Processor/Consumption_JTAG_RAM_DualRam_A9D8DualClkRAM_R0C0 -design rtl 

set_attribute -name MEMORYFILE -value "" -instance -type string Production/production_bytes_retriever/Produced_Bytes_From_RAM_DualRam_A9D8DualClkRAM_R0C0 -design rtl 

set_attribute -name BUFFER_SIG -value "CLKINT" -net JTAG_controller/jc_tck_o -design rtl 

##################
# Clocks
##################
create_clock { uclk_i } -name uclk_i -period 25.000000 -waveform { 0.000000 12.500000 } -design rtl 
create_clock { wclk_i } -name wclk_i -period 25.000000 -waveform { 0.000000 12.500000 } -design rtl 

##################
# Input delays
##################
set_input_delay 10.000 -clock uclk_i -add_delay  -design rtl  {dat_i(*) fd_rxd_i fd_txer_i fd_wdgn_i rstin_i var1_acc_i var2_acc_i var3_acc_i}
set_input_delay 10.000 -clock wclk_i -add_delay  -design rtl  {adr_i(*) cyc_i rst_i stb_i we_i}
set_input_delay 15.000 -clock uclk_i -add_delay  -design rtl  {c_id_i(*) m_id_i(*)}

###################
# Output delays
###################
set_output_delay 10.000 -clock uclk_i -add_delay  -design rtl  {dat_o(*) fd_rstn_o fd_txck_o fd_txd_o fd_txena_o r_fcser_o r_tler_o rston_o u_cacer_o u_pacer_o var1_rdy_o var2_rdy_o var3_rdy_o}
set_output_delay 10.000 -clock wclk_i -add_delay  -design rtl  {ack_o}
set_output_delay 15.000 -clock uclk_i -add_delay  -design rtl  {s_id_o(*)}

