###################################################################################
# Mentor Graphics Corporation
#
###################################################################################

#################
# Attributes
#################
set_attribute -name buffer_sig -value "CLKBUF" -net uclk_i -design gatelevel 
set_attribute -name buffer_sig -value "CLKBUF" -net wclk_i -design gatelevel 
set_attribute -name NOBUFF -value "TRUE" -net manual_uclk_i -design gatelevel 
set_attribute -name NOBUFF -value "TRUE" -net manual_wclk_i -design gatelevel 
set_attribute -name lut_max_fanout -value "1000000" -net -type integer s_nfip_intern_rst_int -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance FIELDRIVE_Receiver_FIELDRIVE_Receiver_Deglitcher_modgen_counter_s_filt_c_reg_q(3) -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance FIELDRIVE_Receiver_FIELDRIVE_Receiver_Deglitcher_modgen_counter_s_filt_c_reg_q(2) -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance FIELDRIVE_Receiver_FIELDRIVE_Receiver_Deglitcher_modgen_counter_s_filt_c_reg_q(1) -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance FIELDRIVE_Receiver_FIELDRIVE_Receiver_Deglitcher_modgen_counter_s_filt_c_reg_q(0) -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance model_constr_decoder_modgen_counter_s_counter_reg_q(1) -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance model_constr_decoder_modgen_counter_s_counter_reg_q(0) -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance FIELDRIVE_Receiver_FIELDRIVE_Receiver_Deglitcher_modgen_counter_s_filt_c_reg_q(3)_TMR1 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance FIELDRIVE_Receiver_FIELDRIVE_Receiver_Deglitcher_modgen_counter_s_filt_c_reg_q(3)_TMR2 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance FIELDRIVE_Receiver_FIELDRIVE_Receiver_Deglitcher_modgen_counter_s_filt_c_reg_q(2)_TMR1 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance FIELDRIVE_Receiver_FIELDRIVE_Receiver_Deglitcher_modgen_counter_s_filt_c_reg_q(2)_TMR2 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance FIELDRIVE_Receiver_FIELDRIVE_Receiver_Deglitcher_modgen_counter_s_filt_c_reg_q(1)_TMR1 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance FIELDRIVE_Receiver_FIELDRIVE_Receiver_Deglitcher_modgen_counter_s_filt_c_reg_q(1)_TMR2 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance FIELDRIVE_Receiver_FIELDRIVE_Receiver_Deglitcher_modgen_counter_s_filt_c_reg_q(0)_TMR1 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance FIELDRIVE_Receiver_FIELDRIVE_Receiver_Deglitcher_modgen_counter_s_filt_c_reg_q(0)_TMR2 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance model_constr_decoder_modgen_counter_s_counter_reg_q(1)_TMR1 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance model_constr_decoder_modgen_counter_s_counter_reg_q(1)_TMR2 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance model_constr_decoder_modgen_counter_s_counter_reg_q(0)_TMR1 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance model_constr_decoder_modgen_counter_s_counter_reg_q(0)_TMR2 -design gatelevel 
set_attribute -name NOBUFF -value "TRUE" -net reset_unit/uclk_i -design gatelevel 
set_attribute -name NOBUFF -value "TRUE" -net reset_unit/wb_clk_i -design gatelevel 

set_attribute -name NOBUFF -value "TRUE" -net JTAG_controller/uclk_i -design gatelevel 
set_attribute -name BUFFER_SIG -value "CLKINT" -net JTAG_controller/jc_tck_o -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance JTAG_controller/JC_TCK_periods_counter_modgen_counter_counter_o_reg_q(4) -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance JTAG_controller/JC_TCK_periods_counter_modgen_counter_counter_o_reg_q(3) -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance JTAG_controller/JC_TCK_periods_counter_modgen_counter_counter_o_reg_q(2) -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance JTAG_controller/JC_TCK_periods_counter_modgen_counter_counter_o_reg_q(1) -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance JTAG_controller/JC_TCK_periods_counter_modgen_counter_counter_o_reg_q(0) -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance JTAG_controller/JC_bytes_counter_modgen_counter_counter_o_reg_q(6) -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance JTAG_controller/JC_bytes_counter_modgen_counter_counter_o_reg_q(5) -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance JTAG_controller/JC_bytes_counter_modgen_counter_counter_o_reg_q(4) -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance JTAG_controller/JC_bytes_counter_modgen_counter_counter_o_reg_q(3) -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance JTAG_controller/JC_bytes_counter_modgen_counter_counter_o_reg_q(2) -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance JTAG_controller/JC_bytes_counter_modgen_counter_counter_o_reg_q(1) -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance JTAG_controller/JC_bytes_counter_modgen_counter_counter_o_reg_q(0) -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance JTAG_controller/JC_TCK_periods_counter_modgen_counter_counter_o_reg_q(4)_TMR1 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance JTAG_controller/JC_TCK_periods_counter_modgen_counter_counter_o_reg_q(4)_TMR2 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance JTAG_controller/JC_TCK_periods_counter_modgen_counter_counter_o_reg_q(3)_TMR1 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance JTAG_controller/JC_TCK_periods_counter_modgen_counter_counter_o_reg_q(3)_TMR2 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance JTAG_controller/JC_TCK_periods_counter_modgen_counter_counter_o_reg_q(2)_TMR1 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance JTAG_controller/JC_TCK_periods_counter_modgen_counter_counter_o_reg_q(2)_TMR2 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance JTAG_controller/JC_TCK_periods_counter_modgen_counter_counter_o_reg_q(1)_TMR1 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance JTAG_controller/JC_TCK_periods_counter_modgen_counter_counter_o_reg_q(1)_TMR2 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance JTAG_controller/JC_TCK_periods_counter_modgen_counter_counter_o_reg_q(0)_TMR1 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance JTAG_controller/JC_TCK_periods_counter_modgen_counter_counter_o_reg_q(0)_TMR2 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance JTAG_controller/JC_bytes_counter_modgen_counter_counter_o_reg_q(6)_TMR1 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance JTAG_controller/JC_bytes_counter_modgen_counter_counter_o_reg_q(6)_TMR2 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance JTAG_controller/JC_bytes_counter_modgen_counter_counter_o_reg_q(5)_TMR1 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance JTAG_controller/JC_bytes_counter_modgen_counter_counter_o_reg_q(5)_TMR2 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance JTAG_controller/JC_bytes_counter_modgen_counter_counter_o_reg_q(4)_TMR1 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance JTAG_controller/JC_bytes_counter_modgen_counter_counter_o_reg_q(4)_TMR2 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance JTAG_controller/JC_bytes_counter_modgen_counter_counter_o_reg_q(3)_TMR1 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance JTAG_controller/JC_bytes_counter_modgen_counter_counter_o_reg_q(3)_TMR2 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance JTAG_controller/JC_bytes_counter_modgen_counter_counter_o_reg_q(2)_TMR1 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance JTAG_controller/JC_bytes_counter_modgen_counter_counter_o_reg_q(2)_TMR2 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance JTAG_controller/JC_bytes_counter_modgen_counter_counter_o_reg_q(1)_TMR1 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance JTAG_controller/JC_bytes_counter_modgen_counter_counter_o_reg_q(1)_TMR2 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance JTAG_controller/JC_bytes_counter_modgen_counter_counter_o_reg_q(0)_TMR1 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance JTAG_controller/JC_bytes_counter_modgen_counter_counter_o_reg_q(0)_TMR2 -design gatelevel 
set_attribute -name NOBUFF -value "TRUE" -net JTAG_controller/Session_Timeout_Counter/uclk_i -design gatelevel 


set_attribute -name NOBUFF -value "TRUE" -net engine_control/uclk_i -design gatelevel 
set_attribute -name NOBUFF -value "TRUE" -net engine_control/Produced_Data_Length_Calculator/uclk_i -design gatelevel 

set_attribute -name NOBUFF -value "TRUE" -net engine_control/Session_Timeout_Counter/uclk_i -design gatelevel 

set_attribute -name NOBUFF -value "TRUE" -net engine_control/Turnaround_and_Silence_Time_Counter/uclk_i -design gatelevel 


set_attribute -name NOBUFF -value "TRUE" -net Consumption_Consumption_Bytes_Processor/uclk_i -design gatelevel 
set_attribute -name NOBUFF -value "TRUE" -net Consumption_Consumption_Bytes_Processor/wb_clk_i -design gatelevel 
set_attribute -name MEMORYFILE -value "" -instance -type string Consumption_Consumption_Bytes_Processor/Consumption_RAM_DualRam_A9D8DualClkRAM_R0C0 -design gatelevel 
set_attribute -name MEMORYFILE -value "" -instance -type string Consumption_Consumption_Bytes_Processor/Consumption_JTAG_RAM_DualRam_A9D8DualClkRAM_R0C0 -design gatelevel 
set_attribute -name MEMORYFILE -value "" -instance -type string Consumption_Consumption_Bytes_Processor/Consumption_RAM_DualRam_A9D8DualClkRAM_R0C0_TMR1 -design gatelevel 
set_attribute -name MEMORYFILE -value "" -instance -type string Consumption_Consumption_Bytes_Processor/Consumption_RAM_DualRam_A9D8DualClkRAM_R0C0_TMR2 -design gatelevel 
set_attribute -name MEMORYFILE -value "" -instance -type string Consumption_Consumption_Bytes_Processor/Consumption_JTAG_RAM_DualRam_A9D8DualClkRAM_R0C0_TMR1 -design gatelevel 
set_attribute -name MEMORYFILE -value "" -instance -type string Consumption_Consumption_Bytes_Processor/Consumption_JTAG_RAM_DualRam_A9D8DualClkRAM_R0C0_TMR2 -design gatelevel 

set_attribute -name NOBUFF -value "TRUE" -net Consumption_Consumption_Outcome/uclk_i -design gatelevel 
set_attribute -name NOBUFF -value "TRUE" -net FIELDRIVE_Receiver_FIELDRIVE_Receiver_Oscillator/uclk_i -design gatelevel 
set_attribute -name NOBUFF -value "TRUE" -net FIELDRIVE_Receiver_FIELDRIVE_Receiver_Deserializer/uclk_i -design gatelevel 
set_attribute -name NOBUFF -value "TRUE" -net FIELDRIVE_Receiver_FIELDRIVE_Receiver_Deserializer/Session_Timeout_Counter/uclk_i -design gatelevel 


set_attribute -name NOBUFF -value "TRUE" -net Production_production_bytes_retriever/uclk_i -design gatelevel 
set_attribute -name NOBUFF -value "TRUE" -net Production_production_bytes_retriever/wb_clk_i -design gatelevel 
set_attribute -name MEMORYFILE -value "" -instance -type string Production_production_bytes_retriever/Produced_Bytes_From_RAM_DualRam_A9D8DualClkRAM_R0C0 -design gatelevel 
set_attribute -name MEMORYFILE -value "" -instance -type string Production_production_bytes_retriever/Produced_Bytes_From_RAM_DualRam_A9D8DualClkRAM_R0C0_TMR1 -design gatelevel 
set_attribute -name MEMORYFILE -value "" -instance -type string Production_production_bytes_retriever/Produced_Bytes_From_RAM_DualRam_A9D8DualClkRAM_R0C0_TMR2 -design gatelevel 

set_attribute -name NOBUFF -value "TRUE" -net Production_production_status_bytes_generator/uclk_i -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance Production_production_status_bytes_generator/Extend_VAR1_RDY_modgen_counter_counter_o_reg_q(3) -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance Production_production_status_bytes_generator/Extend_VAR1_RDY_modgen_counter_counter_o_reg_q(2) -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance Production_production_status_bytes_generator/Extend_VAR1_RDY_modgen_counter_counter_o_reg_q(1) -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance Production_production_status_bytes_generator/Extend_VAR1_RDY_modgen_counter_counter_o_reg_q(0) -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance Production_production_status_bytes_generator/Extend_VAR2_RDY_modgen_counter_counter_o_reg_q(3) -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance Production_production_status_bytes_generator/Extend_VAR2_RDY_modgen_counter_counter_o_reg_q(2) -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance Production_production_status_bytes_generator/Extend_VAR2_RDY_modgen_counter_counter_o_reg_q(1) -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance Production_production_status_bytes_generator/Extend_VAR2_RDY_modgen_counter_counter_o_reg_q(0) -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance Production_production_status_bytes_generator/Extend_VAR3_RDY_modgen_counter_counter_o_reg_q(3) -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance Production_production_status_bytes_generator/Extend_VAR3_RDY_modgen_counter_counter_o_reg_q(2) -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance Production_production_status_bytes_generator/Extend_VAR3_RDY_modgen_counter_counter_o_reg_q(1) -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance Production_production_status_bytes_generator/Extend_VAR3_RDY_modgen_counter_counter_o_reg_q(0) -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance Production_production_status_bytes_generator/Extend_VAR1_RDY_modgen_counter_counter_o_reg_q(3)_TMR1 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance Production_production_status_bytes_generator/Extend_VAR1_RDY_modgen_counter_counter_o_reg_q(3)_TMR2 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance Production_production_status_bytes_generator/Extend_VAR1_RDY_modgen_counter_counter_o_reg_q(2)_TMR1 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance Production_production_status_bytes_generator/Extend_VAR1_RDY_modgen_counter_counter_o_reg_q(2)_TMR2 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance Production_production_status_bytes_generator/Extend_VAR1_RDY_modgen_counter_counter_o_reg_q(1)_TMR1 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance Production_production_status_bytes_generator/Extend_VAR1_RDY_modgen_counter_counter_o_reg_q(1)_TMR2 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance Production_production_status_bytes_generator/Extend_VAR1_RDY_modgen_counter_counter_o_reg_q(0)_TMR1 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance Production_production_status_bytes_generator/Extend_VAR1_RDY_modgen_counter_counter_o_reg_q(0)_TMR2 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance Production_production_status_bytes_generator/Extend_VAR2_RDY_modgen_counter_counter_o_reg_q(3)_TMR1 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance Production_production_status_bytes_generator/Extend_VAR2_RDY_modgen_counter_counter_o_reg_q(3)_TMR2 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance Production_production_status_bytes_generator/Extend_VAR2_RDY_modgen_counter_counter_o_reg_q(2)_TMR1 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance Production_production_status_bytes_generator/Extend_VAR2_RDY_modgen_counter_counter_o_reg_q(2)_TMR2 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance Production_production_status_bytes_generator/Extend_VAR2_RDY_modgen_counter_counter_o_reg_q(1)_TMR1 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance Production_production_status_bytes_generator/Extend_VAR2_RDY_modgen_counter_counter_o_reg_q(1)_TMR2 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance Production_production_status_bytes_generator/Extend_VAR2_RDY_modgen_counter_counter_o_reg_q(0)_TMR1 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance Production_production_status_bytes_generator/Extend_VAR2_RDY_modgen_counter_counter_o_reg_q(0)_TMR2 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance Production_production_status_bytes_generator/Extend_VAR3_RDY_modgen_counter_counter_o_reg_q(3)_TMR1 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance Production_production_status_bytes_generator/Extend_VAR3_RDY_modgen_counter_counter_o_reg_q(3)_TMR2 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance Production_production_status_bytes_generator/Extend_VAR3_RDY_modgen_counter_counter_o_reg_q(2)_TMR1 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance Production_production_status_bytes_generator/Extend_VAR3_RDY_modgen_counter_counter_o_reg_q(2)_TMR2 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance Production_production_status_bytes_generator/Extend_VAR3_RDY_modgen_counter_counter_o_reg_q(1)_TMR1 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance Production_production_status_bytes_generator/Extend_VAR3_RDY_modgen_counter_counter_o_reg_q(1)_TMR2 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance Production_production_status_bytes_generator/Extend_VAR3_RDY_modgen_counter_counter_o_reg_q(0)_TMR1 -design gatelevel 
set_attribute -name no_enable_dff -value "TRUE" -instance Production_production_status_bytes_generator/Extend_VAR3_RDY_modgen_counter_counter_o_reg_q(0)_TMR2 -design gatelevel 

set_attribute -name NOBUFF -value "TRUE" -net FIELDRIVE_Transmitter_tx_oscillator/uclk_i -design gatelevel 

set_attribute -name NOBUFF -value "TRUE" -net FIELDRIVE_Transmitter_tx_serializer/uclk_i -design gatelevel 
set_attribute -name NOBUFF -value "TRUE" -net FIELDRIVE_Transmitter_tx_serializer/Session_Timeout_Counter/uclk_i -design gatelevel 




##################
# Clocks
##################
create_clock { uclk_i } -name uclk_i -period 25.000000 -waveform { 0.000000 12.500000 } -design gatelevel 
create_clock { wclk_i } -name wclk_i -period 25.000000 -waveform { 0.000000 12.500000 } -design gatelevel 

##################
# Input delays
##################
set_input_delay 10.000 -clock uclk_i -add_delay  -design gatelevel  {dat_i(*) fd_rxd_i fd_txer_i fd_wdgn_i rstin_i var1_acc_i var2_acc_i var3_acc_i}
set_input_delay 10.000 -clock wclk_i -add_delay  -design gatelevel  {adr_i(*) cyc_i rst_i stb_i we_i}
set_input_delay 15.000 -clock uclk_i -add_delay  -design gatelevel  {c_id_i(*) m_id_i(*)}

###################
# Output delays
###################
set_output_delay 10.000 -clock uclk_i -add_delay  -design gatelevel  {dat_o(*) fd_rstn_o fd_txck_o fd_txd_o fd_txena_o r_fcser_o r_tler_o rston_o u_cacer_o u_pacer_o var1_rdy_o var2_rdy_o var3_rdy_o}
set_output_delay 10.000 -clock wclk_i -add_delay  -design gatelevel  {ack_o}
set_output_delay 15.000 -clock uclk_i -add_delay  -design gatelevel  {s_id_o(*)}

