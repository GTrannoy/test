#ncvhdl -nocopyright -nolog -messages -linedebug -v93 -cdslib ./cds.lib -work proasic3 ../src/proasic3_library/proasic3.vhd
ncvhdl -nocopyright -nolog -messages -linedebug -v93 -cdslib ./cds.lib -work worklib ../src/design/wf_package.vhd
ncvhdl -nocopyright -nolog -messages -linedebug -v93 -cdslib ./cds.lib -work worklib ../src/design/reset_logic.vhd
ncvhdl -nocopyright -nolog -messages -linedebug -v93 -cdslib ./cds.lib -work worklib ../src/design/wf_crc.vhd
ncvhdl -nocopyright -nolog -messages -linedebug -v93 -cdslib ./cds.lib -work worklib ../src/design/wf_tx.vhd
ncvhdl -nocopyright -nolog -messages -linedebug -v93 -cdslib ./cds.lib -work worklib ../src/design/wf_rx.vhd
ncvhdl -nocopyright -nolog -messages -linedebug -v93 -cdslib ./cds.lib -work worklib ../src/design/wf_rx_osc.vhd
ncvhdl -nocopyright -nolog -messages -linedebug -v93 -cdslib ./cds.lib -work worklib ../src/design/deglitcher.vhd
ncvhdl -nocopyright -nolog -messages -linedebug -v93 -cdslib ./cds.lib -work worklib ../src/design/wf_tx_rx.vhd
ncvhdl -nocopyright -nolog -messages -linedebug -v93 -cdslib ./cds.lib -work worklib ../src/design/wf_engine_control.vhd
ncvhdl -nocopyright -nolog -messages -linedebug -v93 -cdslib ./cds.lib -work worklib ../src/design/DualClkRAM.vhd
ncvhdl -nocopyright -nolog -messages -linedebug -v93 -cdslib ./cds.lib -work worklib ../src/design/dpblockram_clka_rd_clkb_wr_syn.vhd
ncvhdl -nocopyright -nolog -messages -linedebug -v93 -cdslib ./cds.lib -work worklib ../src/design/wf_consumed_vars.vhd
ncvhdl -nocopyright -nolog -messages -linedebug -v93 -cdslib ./cds.lib -work worklib ../src/design/wf_produced_vars.vhd
ncvhdl -nocopyright -nolog -messages -linedebug -v93 -cdslib ./cds.lib -work worklib ../src/design/status_gen.vhd
ncvhdl -nocopyright -nolog -messages -linedebug -v93 -cdslib ./cds.lib -work worklib ../src/design/wf_dec_m_ids.vhd
ncvhdl -nocopyright -nolog -messages -linedebug -v93 -cdslib ./cds.lib -work worklib ../src/design/nanofip.vhd

ncvhdl -nocopyright -nolog -messages -linedebug -v93 -cdslib ./cds.lib -work worklib ../src/tb_files/encounter.vhd
ncvhdl -nocopyright -nolog -messages -linedebug -v93 -cdslib ./cds.lib -work worklib ../src/tb_files/board_settings.vhd
ncvhdl -nocopyright -nolog -messages -linedebug -v93 -cdslib ./cds.lib -work worklib ../src/tb_files/user_sequencer.vhd
ncvhdl -nocopyright -nolog -messages -linedebug -v93 -cdslib ./cds.lib -work worklib ../src/tb_files/wishbone_interface.vhd
ncvhdl -nocopyright -nolog -messages -linedebug -v93 -cdslib ./cds.lib -work worklib ../src/tb_files/user_interface.vhd
ncvhdl -nocopyright -nolog -messages -linedebug -v93 -cdslib ./cds.lib -work worklib ../src/tb_files/fss_gen.vhd
ncvhdl -nocopyright -nolog -messages -linedebug -v93 -cdslib ./cds.lib -work worklib ../src/tb_files/fes_gen.vhd
ncvhdl -nocopyright -nolog -messages -linedebug -v93 -cdslib ./cds.lib -work worklib ../src/tb_files/halfer.vhd
ncvhdl -nocopyright -nolog -messages -linedebug -v93 -cdslib ./cds.lib -work worklib ../src/tb_files/crc_gen.vhd
ncvhdl -nocopyright -nolog -messages -linedebug -v93 -cdslib ./cds.lib -work worklib ../src/tb_files/serializer.vhd
ncvhdl -nocopyright -nolog -messages -linedebug -v93 -cdslib ./cds.lib -work worklib ../src/tb_files/onetime_serializer.vhd
ncvhdl -nocopyright -nolog -messages -linedebug -v93 -cdslib ./cds.lib -work worklib ../src/tb_files/msg_sender.vhd
ncvhdl -nocopyright -nolog -messages -linedebug -v93 -cdslib ./cds.lib -work worklib ../src/tb_files/rx_feeder.vhd
ncvhdl -nocopyright -nolog -messages -linedebug -v93 -cdslib ./cds.lib -work worklib ../src/tb_files/rx.vhd

ncvhdl -nocopyright -nolog -messages -linedebug -v93 -cdslib ./cds.lib -work worklib ../src/tb_files/manchester_decoder.vhd
ncvhdl -nocopyright -nolog -messages -linedebug -v93 -cdslib ./cds.lib -work worklib ../src/tb_files/frame_detector.vhd
ncvhdl -nocopyright -nolog -messages -linedebug -v93 -cdslib ./cds.lib -work worklib ../src/tb_files/frame_chopper.vhd
ncvhdl -nocopyright -nolog -messages -linedebug -v93 -cdslib ./cds.lib -work worklib ../src/tb_files/crc_check.vhd
ncvhdl -nocopyright -nolog -messages -linedebug -v93 -cdslib ./cds.lib -work worklib ../src/tb_files/tx.vhd

ncvhdl -nocopyright -nolog -messages -linedebug -v93 -cdslib ./cds.lib -work worklib ../src/tb_files/bus_arbitrer.vhd
ncvhdl -nocopyright -nolog -messages -linedebug -v93 -cdslib ./cds.lib -work worklib ../src/tb_files/fieldrive_interface.vhd
ncvhdl -nocopyright -nolog -messages -linedebug -v93 -cdslib ./cds.lib -work worklib ../src/tb_files/nanofip_tb.vhd

ncelab -nocopyright -nolog -messages -access +wc -messages -v93 -cdslib ./cds.lib -work worklib worklib.nanofip_tb:archi
#ncsim -gui -cdslib ./cds.lib -nocopyright -nolog -nokey worklib.nanofip_tb:archi -input waves.tcl
