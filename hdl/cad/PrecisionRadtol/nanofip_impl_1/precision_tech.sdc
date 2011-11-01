###################################################################################
# Mentor Graphics Corporation
#
# This file is not a constraints report, nor does it list all the
# Tech constraints in the design. This file is created and used by Precision
# to track user Tech constraints that are set during design iterations.
# You should not edit this file because doing so might cause improper
# constraints in the design.
#
# If you want to list all Tech design constraints, use the command
#       report_constraints -design gatelevel
# or double-click on the Tech Constraints Report node in the Output Files
# Folder in the GUI.
#
# For a detailed discussion of how to set constraints, please refer to
# Precision documentation which is available from the Help pulldown menu.
###################################################################################

#################
# Attributes
#################

##################
# Clocks
##################
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

