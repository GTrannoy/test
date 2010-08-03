probe -create -shm -waveform :fieldrive:clk
probe -create -shm -waveform :fieldrive:reset

probe -create -shm -waveform :fieldrive:launch_fip_transmit

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

probe -create -shm -waveform :fx_rxa
probe -create -shm -waveform :fx_rxd

probe -create -shm -waveform :fd_wdgn
probe -create -shm -waveform :fd_txer

probe -create -shm -waveform :fd_rstn
probe -create -shm -waveform :fd_txck
probe -create -shm -waveform :fx_txd
probe -create -shm -waveform :fd_txena

probe -create -shm -waveform :uclk
probe -create -shm -waveform :urstin
probe -create -shm -waveform :fieldrive:clk


run 600 us
