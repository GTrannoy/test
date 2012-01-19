# Synopsys, Inc. constraint file
# C:/ohr/cern-fip/trunk/hdl/cad/Synplify/synplify_constraints.sdc
# Written on Fri Sep 16 17:43:25 2011
# by Synplify Premier, D-2009.12 Scope Editor

#
# Collections
#

#
# Clocks
#
define_clock   { uclk_i } -name { uclk_i }  -period 25
define_clock   { wclk_i } -name { wclk_i }  -period 25

#
# Clock to Clock
#

#
# Inputs/Outputs
#

#
# Registers
#

#
# Delay Paths
#

#
# Attributes
#
define_attribute {reset_unit.rstin_st[0:4]} syn_encoding {safe, onehot}
define_attribute {reset_unit.var_rst_st[0:5]} syn_encoding {safe, onehot}
define_attribute {FIELDRIVE_Receiver.FIELDRIVE_Receiver_Deserializer.rx_st[0:5]} syn_encoding {safe, onehot}
define_attribute {FIELDRIVE_Transmitter.tx_serializer.tx_st[0:6]} syn_encoding {safe, onehot}
define_attribute {JTAG_controller.jc_st[0:3]} syn_encoding {safe, onehot}
define_attribute {engine_control.control_st[0:9]} syn_encoding {safe, onehot}

define_attribute {v:work.nanofip} {syn_radhardlevel} {tmr}

### For TMR of the block RAMs check comments on the wf_dualram_512x8_clka_rd_clkb_wr.vhd file ### 

#
# I/O Standards
#

#
# Compile Points
#

#
# Other
#
