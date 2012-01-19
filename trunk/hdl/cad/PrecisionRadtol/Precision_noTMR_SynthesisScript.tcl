#
#  Precision RTL Synthesis 2010a_Update2.254 (Production Release) Tue Oct 26 22:20:12 PDT 2010
#  
#  Copyright (c) Mentor Graphics Corporation, 1996-2010, All Rights Reserved.
#             Portions copyright 1991-2008 Compuware Corporation
#                       UNPUBLISHED, LICENSED SOFTWARE.
#            CONFIDENTIAL AND PROPRIETARY INFORMATION WHICH IS THE
#          PROPERTY OF MENTOR GRAPHICS CORPORATION OR ITS LICENSORS
#  
#  Running on Windows XP egousiou@PCBE13136 Service Pack 3 5.01.2600 x86
#  
#  Last Saved: 03/08/11 11:25:56
#

set_input_dir C:/ohr/cern-fip/trunk/hdl/cad/PrecisionRadtol
set_results_dir C:/ohr/cern-fip/trunk/hdl/cad/PrecisionRadtol/nanofip_noTMR_impl_1/

#open_project C:/ohr/cern-fip/trunk/hdl/cad/precision_radtol/nanofip.psp

# ###################
# VHDL files
# ##################
add_input_file {
../../design/nanofip.vhd 
../../design/dualram_512x8.vhd 
../../design/wf_cons_bytes_processor.vhd 
../../design/wf_cons_outcome.vhd 
../../design/wf_consumption.vhd 
../../design/wf_crc.vhd 
../../design/wf_decr_counter.vhd 
../../design/wf_dualram_512x8_clka_rd_clkb_wr.vhd 
../../design/wf_engine_control.vhd 
../../design/wf_fd_receiver.vhd 
../../design/wf_fd_transmitter.vhd 
../../design/wf_incr_counter.vhd 
../../design/wf_jtag_controller.vhd 
../../design/wf_model_constr_decoder.vhd 
../../design/wf_package.vhd 
../../design/wf_prod_bytes_retriever.vhd 
../../design/wf_prod_data_lgth_calc.vhd 
../../design/wf_prod_permit.vhd 
../../design/wf_production.vhd 
../../design/wf_reset_unit.vhd 
../../design/wf_rx_deglitcher.vhd 
../../design/wf_rx_deserializer.vhd 
../../design/wf_rx_osc.vhd 
../../design/wf_status_bytes_gen.vhd 
../../design/wf_tx_osc.vhd 
../../design/wf_tx_serializer.vhd
../../design/wf_wb_controller.vhd}

# ###################
# Constraints file
# ##################
add_input_file {./constraints/Precision_Constraints.sdc}

# ###################
# Chip
# ##################
setup_design -manufacturer Actel -family ProASIC3 -part A3P400 -speed STD -package "208 PQFP"
setup_design -hdl vhdl_2002
setup_design -addio=true
# -max_fanout_strategy=AUTO
setup_design -frequency 40.000000
#setup_design -input_delay 5 -output_delay 5 

setup_design -max_fanout=10
setup_design -retiming=false
setup_design -resource_sharing=false -dsp_across_hier=false



# ###################
# TMR
# ##################
setup_design -encoding=onehot
setup_design -advanced_fsm_optimization=false  -reencode_fsm_outputs=false
setup_design -safe_fsm_type=basic -radhardmethod=none

# ###################
# Synthesis Output
# ##################
setup_design -edif=true
setup_design -vendor_constraint_file=false
setup_analysis -clock_frequency=true -summary=true -num_summary_paths=20 -critical_paths=true  -num_critical_paths=5 -timing_violations=true -net_fanout=true -clock_domain_crossing=true -missing_constraints=true

# ###################
# Compile
# ##################
compile

# ###################
# Synthesize
# ##################
synthesize

# ###################
# PnR
# ##################
#setup_place_and_route -flow "Actel Designer" -command "Launch Designer" -install_dir C:/Actel/Designer
#place_and_route
