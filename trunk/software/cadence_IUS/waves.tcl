probe -create -shm -waveform :fieldrive:clk
probe -create -shm -waveform :fieldrive:reset

probe -create -shm -waveform :fieldrive:launch_fip_cycle

probe -create -shm -waveform :fieldrive:rx_block:feeder:fstate
probe -create -shm -waveform :fieldrive:rx_block:feeder:fss_start
probe -create -shm -waveform :fieldrive:rx_block:feeder:fss_complete
probe -create -shm -waveform :fieldrive:rx_block:feeder:fes_start
probe -create -shm -waveform :fieldrive:rx_block:feeder:fes_complete

probe -create -shm -waveform :fieldrive:rx_block:msg_start
probe -create -shm -waveform :fieldrive:rx_block:feeder:msg_start_dly
probe -create -shm -waveform :fieldrive:rx_block:msg_complete

probe -create -shm -waveform :fieldrive:rx_block:msg_block:mstate
probe -create -shm -waveform :fieldrive:rx_block:mx

probe -create -shm -waveform :fieldrive:rx_block:crc_gen_start
probe -create -shm -waveform :fieldrive:rx_block:crc_gen_end

probe -create -shm -waveform :fieldrive:rx_block:fcs
probe -create -shm -waveform :fieldrive:rx_block:fcs_ready
probe -create -shm -waveform :fieldrive:rx_block:fcs_valid
probe -create -shm -waveform :fieldrive:rx_block:fcs_complete

probe -create -shm -waveform :fieldrive:rx_block:dx_en
probe -create -shm -waveform :fieldrive:rx_block:mux_select
probe -create -shm -waveform :fieldrive:rx_block:mx_final
probe -create -shm -waveform :fieldrive:rx_block:fx
probe -create -shm -waveform :fieldrive:rx_block:dx_final
probe -create -shm -waveform :fieldrive:rx_block:cd
probe -create -shm -waveform :fieldrive:rx_block:dx

probe -create -shm -waveform :fieldrive:tx_block:decoder:extracted_clk
#probe -create -shm -waveform :fieldrive:tx_block:decoder:locked
#probe -create -shm -waveform :fieldrive:tx_block:decoder:locking
probe -create -shm -waveform :fieldrive:tx_block:chopper:vx
probe -create -shm -waveform :fieldrive:tx_block:chopper:sof
probe -create -shm -waveform :fieldrive:tx_block:chopper:eof

probe -create -shm -waveform :fieldrive:tx_block:fcs_check
probe -create -shm -waveform :fieldrive:tx_block:fcs_ok

probe -create -shm -waveform :fieldrive:tx_block:chopper:enable_chopping
probe -create -shm -waveform :fieldrive:tx_block:chopper:chop_byte
#probe -create -shm -waveform :fieldrive:tx_block:chopper:count_done
probe -create -shm -waveform :fieldrive:tx_block:chopper:byte_nb
probe -create -shm -waveform :fieldrive:tx_block:chopper:bytes_received
probe -create -shm -waveform :fieldrive:tx_block:chopper:current_byte
probe -create -shm -waveform :fieldrive:tx_block:chopper:frame_data
probe -create -shm -waveform :fieldrive:tx_block:chopper:pdu_type_byte
probe -create -shm -waveform :fieldrive:tx_block:chopper:length_byte
probe -create -shm -waveform :fieldrive:tx_block:chopper:control_byte

#probe -create -shm -waveform :fieldrive:tx_block:chopper:control_ok
probe -create -shm -waveform :fieldrive:tx_block:chopper:length_ok
#probe -create -shm -waveform :fieldrive:tx_block:chopper:struct_ok
probe -create -shm -waveform :fieldrive:tx_block:chopper:struct_check
#probe -create -shm -waveform :fieldrive:tx_block:chopper:frame_struct_check
#probe -create -shm -waveform :fieldrive:tx_block:chopper:frame_struct_ok

probe -create -shm -waveform :fx_rxa
probe -create -shm -waveform :fx_rxd
probe -create -shm -waveform :fd_wdgn
probe -create -shm -waveform :fd_txer
probe -create -shm -waveform :fieldrive:clk
probe -create -shm -waveform :fd_rstn
probe -create -shm -waveform :fd_txck
probe -create -shm -waveform :fx_txd
probe -create -shm -waveform :fd_txena

probe -create -shm -waveform :uclk
probe -create -shm -waveform :urst_from_nf
probe -create -shm -waveform :urst_to_nf
probe -create -shm -waveform :var1_rdy
#probe -create -shm -waveform :var1_acc
probe -create -shm -waveform :var2_rdy
#probe -create -shm -waveform :var2_acc
probe -create -shm -waveform :var3_rdy
probe -create -shm -waveform :var3_acc
probe -create -shm -waveform :wclk
probe -create -shm -waveform :rst
probe -create -shm -waveform :cyc
probe -create -shm -waveform :stb
probe -create -shm -waveform :ack
probe -create -shm -waveform :we
probe -create -shm -waveform :adr
probe -create -shm -waveform :dat_from_fip
probe -create -shm -waveform :dat_to_fip
probe -create -shm -waveform :user_logic:wb_interface:valid_bus_cycle
probe -create -shm -waveform :user_logic:wb_interface:wb_state

probe -create -shm -waveform :dut:uwf_produced_vars:s_byte

run 1000 us
