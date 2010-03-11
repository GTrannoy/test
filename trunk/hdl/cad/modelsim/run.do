quietly set ACTELLIBNAME proasic3
quietly set PROJECT_DIR "E:/ohr/CernFIP/trunk/software/New Folder/NanoFip"

if {[file exists presynth/_info]} {
   echo "INFO: Simulation library presynth already exists"
} else {
   vlib presynth
}
vmap presynth presynth
vmap proasic3 "C:/Actel/Libero_v8.6/Designer/lib/modelsim/precompiled/vhdl/proasic3"

vcom -93 -explicit -work presynth "E:/ohr/CernFIP/trunk/hdl/design/wf_rx_osc.vhd"
vcom -93 -explicit -work presynth "E:/ohr/CernFIP/trunk/hdl/design/deglitcher.vhd"
vcom -93 -explicit -work presynth "E:/ohr/CernFIP/trunk/hdl/design/wf_crc.vhd"
vcom -93 -explicit -work presynth "E:/ohr/CernFIP/trunk/hdl/design/wf_package.vhd"
vcom -93 -explicit -work presynth "E:/ohr/CernFIP/trunk/hdl/design/wf_rx.vhd"
vcom -93 -explicit -work presynth "E:/ohr/CernFIP/trunk/hdl/design/wf_tx.vhd"
vcom -93 -explicit -work presynth "E:/ohr/CernFIP/trunk/hdl/design/wf_tx_rx.vhd"
vcom -93 -explicit -work presynth "E:/ohr/CernFIP/trunk/hdl/design/reset_logic.vhd"
vcom -93 -explicit -work presynth "E:/ohr/CernFIP/trunk/hdl/design/wf_engine_control.vhd"
vcom -93 -explicit -work presynth "E:/ohr/CernFIP/trunk/hdl/design/dpblockram_clka_rd_clkb_wr.vhd"
vcom -93 -explicit -work presynth "E:/ohr/CernFIP/trunk/hdl/design/wf_consumed_vars.vhd"
vcom -93 -explicit -work presynth "E:/ohr/CernFIP/trunk/hdl/design/status_gen.vhd"
vcom -93 -explicit -work presynth "E:/ohr/CernFIP/trunk/hdl/design/wf_produced_vars.vhd"
vcom -93 -explicit -work presynth "E:/ohr/CernFIP/trunk/hdl/design/nanofip.vhd"
vcom -93 -explicit -work presynth "E:/ohr/CernFIP/trunk/hdl/test_bench/wf_sim_package.vhd"
vcom -93 -explicit -work presynth "E:/ohr/CernFIP/trunk/hdl/test_bench/wf_nanofip_tx_rx_tb.vhd"

vsim -L proasic3 -L presynth  -t 1ps presynth.nanofip_tx_rx_tb_vhd
# The following lines are commented because no testbench is associated with the project
# add wave /testbench/*
# run 1000ns
