
project -new

#project files
add_file -vhdl -lib work "C:/ohr/cern-fip/trunk/hdl/design/dualram_512x8.vhd"
add_file -vhdl -lib work "C:/ohr/cern-fip/trunk/hdl/design/wf_package.vhd"
add_file -vhdl -lib work "C:/ohr/cern-fip/trunk/hdl/design/wf_dualram_512x8_clka_rd_clkb_wr.vhd"
add_file -vhdl -lib work "C:/ohr/cern-fip/trunk/hdl/design/wf_cons_bytes_processor.vhd"
add_file -vhdl -lib work "C:/ohr/cern-fip/trunk/hdl/design/wf_cons_outcome.vhd"
add_file -vhdl -lib work "C:/ohr/cern-fip/trunk/hdl/design/wf_consumption.vhd"
add_file -vhdl -lib work "C:/ohr/cern-fip/trunk/hdl/design/wf_rx_deglitcher.vhd"
add_file -vhdl -lib work "C:/ohr/cern-fip/trunk/hdl/design/wf_decr_counter.vhd"
add_file -vhdl -lib work "C:/ohr/cern-fip/trunk/hdl/design/wf_crc.vhd"
add_file -vhdl -lib work "C:/ohr/cern-fip/trunk/hdl/design/wf_rx_deserializer.vhd"
add_file -vhdl -lib work "C:/ohr/cern-fip/trunk/hdl/design/wf_incr_counter.vhd"
add_file -vhdl -lib work "C:/ohr/cern-FIP/trunk/hdl/design/wf_rx_osc.vhd"
add_file -vhdl -lib work "C:/ohr/cern-fip/trunk/hdl/design/wf_fd_receiver.vhd"
add_file -vhdl -lib work "C:/ohr/cern-fip/trunk/hdl/design/wf_tx_osc.vhd"
add_file -vhdl -lib work "C:/ohr/cern-fip/trunk/hdl/design/wf_tx_serializer.vhd"
add_file -vhdl -lib work "C:/ohr/cern-fip/trunk/hdl/design/wf_fd_transmitter.vhd"
add_file -vhdl -lib work "C:/ohr/cern-fip/trunk/hdl/design/wf_model_constr_decoder.vhd"
add_file -vhdl -lib work "C:/ohr/cern-fip/trunk/hdl/design/wf_prod_bytes_retriever.vhd"
add_file -vhdl -lib work "C:/ohr/cern-fip/trunk/hdl/design/wf_prod_permit.vhd"
add_file -vhdl -lib work "C:/ohr/cern-fip/trunk/hdl/design/wf_status_bytes_gen.vhd"
add_file -vhdl -lib work "C:/ohr/cern-fip/trunk/hdl/design/wf_production.vhd"
add_file -vhdl -lib work "C:/ohr/cern-fip/trunk/hdl/design/wf_reset_unit.vhd"
add_file -vhdl -lib work "C:/ohr/cern-fip/trunk/hdl/design/wf_wb_controller.vhd"
add_file -vhdl -lib work "C:/ohr/cern-fip/trunk/hdl/design/wf_prod_data_lgth_calc.vhd"
add_file -vhdl -lib work "C:/ohr/cern-fip/trunk/hdl/design/wf_engine_control.vhd"
add_file -vhdl -lib work "C:/ohr/cern-fip/trunk/hdl/design/wf_jtag_controller.vhd"
add_file -vhdl -lib work "C:/ohr/cern-fip/trunk/hdl/design/nanofip.vhd"


#implementation: "synthesis"
impl -add synthesis -type fpga

#device options
set_option -technology ProASIC3
set_option -part A3P400
set_option -package PQFP208
set_option -speed_grade Std

#compilation/mapping options
set_option -top_module "work.nanofip"

# mapper_options
set_option -frequency 40.000000

# Actel 400K
#set_option -run_prop_extract 1
set_option -disable_io_insertion 0


set_option -maxfan 10
set_option -maxfan_hard 1 
set_option -retiming 0
set_option -resource_sharing 1

set_option -default_enum_encoding onehot
set_option -symbolic_fsm_compiler 1


# Actel 500K
#set_option -globalthreshold 50

# Compiler Options



#set result format/file last
project -result_file "./nanofip.edn"

#design plan options
set_option -nfilter_user_path ""
impl -active "synthesis"


# ###################
# Constraints file
# ##################
add_file -constraint "C:/ohr/cern-fip/trunk/hdl/cad/Synplify/synplify_constraints.sdc"


project -run

