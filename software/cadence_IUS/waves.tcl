probe -create -shm -waveform :fieldrive:f_clk
probe -create -shm -waveform :fieldrive:fd_reset

#probe -create -shm -waveform :board:read_config_trigger
#probe -create -shm -waveform :board:report_config_trigger
#probe -create -shm -waveform :board:c_id_o

probe -create -shm -waveform :fieldrive:rx_block:fip_frame_trigger
probe -create -shm -waveform :fieldrive:id_rp

probe -create -shm -waveform :fieldrive:rx_block:feeder:fstate
probe -create -shm -waveform :fieldrive:rx_block:feeder:fss_start
probe -create -shm -waveform :fieldrive:rx_block:feeder:fss_complete
probe -create -shm -waveform :fieldrive:rx_block:feeder:fes_start
probe -create -shm -waveform :fieldrive:rx_block:feeder:fes_complete

probe -create -shm -waveform :fieldrive:rx_block:msg_start
#probe -create -shm -waveform :fieldrive:rx_block:feeder:msg_start_dly
probe -create -shm -waveform :fieldrive:rx_block:msg_complete

probe -create -shm -waveform :fieldrive:rx_block:msg_block:msg_new_data_req

#probe -create -shm -waveform :fieldrive:rx_block:msg_block:en_count
#probe -create -shm -waveform :fieldrive:rx_block:msg_block:reset_count
#probe -create -shm -waveform :fieldrive:rx_block:msg_block:start_value
#probe -create -shm -waveform :fieldrive:rx_block:msg_block:count
#probe -create -shm -waveform :fieldrive:rx_block:msg_block:count_done

probe -create -shm -waveform :fieldrive:rx_block:msg_block:mstate
probe -create -shm -waveform :fieldrive:rx_block:msg_data
probe -create -shm -waveform :fieldrive:rx_block:msg_go
probe -create -shm -waveform :fieldrive:rx_block:mx

probe -create -shm -waveform :fieldrive:rx_block:crc_gen_start
probe -create -shm -waveform :fieldrive:rx_block:crc_gen_end

probe -create -shm -waveform :fieldrive:rx_block:fcs
probe -create -shm -waveform :fieldrive:rx_block:fcs_ready
#probe -create -shm -waveform :fieldrive:rx_block:fcs_valid
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
probe -create -shm -waveform :fieldrive:tx_block:chopper:bytes_total
#probe -create -shm -waveform :fieldrive:tx_block:chopper:current_byte
probe -create -shm -waveform :fieldrive:tx_block:chopper:frame_data

#probe -create -shm -waveform :fieldrive:tx_block:monitor:pdu_type_byte
#probe -create -shm -waveform :fieldrive:tx_block:monitor:length_byte
#probe -create -shm -waveform :fieldrive:tx_block:monitor:control_byte

#probe -create -shm -waveform :fieldrive:tx_block:chopper:control_ok
#probe -create -shm -waveform :fieldrive:tx_block:monitor:length_specs_ok
#probe -create -shm -waveform :fieldrive:tx_block:monitor:length_coherent
#probe -create -shm -waveform :fieldrive:tx_block:monitor:frame_ok
#probe -create -shm -waveform :fieldrive:tx_block:monitor:compare_data
#probe -create -shm -waveform :fieldrive:tx_block:monitor:data_contents_ok
#probe -create -shm -waveform :fieldrive:tx_block:monitor:checking_produced:mismatches

probe -create -shm -waveform :fieldrive:f_clk
probe -create -shm -waveform :fd_rstn
probe -create -shm -waveform :fx_rxa
probe -create -shm -waveform :fx_rxd
probe -create -shm -waveform :fd_txena
probe -create -shm -waveform :fx_txd
probe -create -shm -waveform :fd_txck
probe -create -shm -waveform :fd_wdgn
probe -create -shm -waveform :fd_txer

probe -create -shm -waveform :uclk
probe -create -shm -waveform :urst_from_nf
probe -create -shm -waveform :urst_to_nf
probe -create -shm -waveform :user_logic:var1_rdy_i
probe -create -shm -waveform :user_logic:var1_acc_o
probe -create -shm -waveform :user_logic:var2_rdy_i
probe -create -shm -waveform :user_logic:var2_acc_o
probe -create -shm -waveform :user_logic:var3_rdy_i
probe -create -shm -waveform :user_logic:var3_acc_o
probe -create -shm -waveform :wclk
probe -create -shm -waveform :rst
probe -create -shm -waveform :cyc
probe -create -shm -waveform :stb
probe -create -shm -waveform :ack
probe -create -shm -waveform :we
probe -create -shm -waveform :adr
probe -create -shm -waveform :dat_from_fip
probe -create -shm -waveform :dat_to_fip
#probe -create -shm -waveform :user_logic:wb_interface:valid_bus_cycle
probe -create -shm -waveform :user_logic:wb_interface:launch_wb_read
probe -create -shm -waveform :user_logic:wb_interface:launch_wb_write 
probe -create -shm -waveform :user_logic:wb_interface:wb_state
probe -create -shm -waveform :user_logic:wb_interface:nxt_wb_state
probe -create -shm -waveform :user_logic:wb_interface:clk_i

probe -create -shm -waveform :user_logic:sa_interface:launch_slone_read
probe -create -shm -waveform :user_logic:sa_interface:launch_slone_write 
#probe -create -shm -waveform :user_logic:sa_interface:slone_rd
#probe -create -shm -waveform :user_logic:sa_interface:slone_wr 
#probe -create -shm -waveform :user_logic:sa_interface:action
probe -create -shm -waveform :user_logic:sa_interface:slone_access_read
probe -create -shm -waveform :user_logic:sa_interface:slone_access_write
#probe -create -shm -waveform :user_logic:slone_output
#probe -create -shm -waveform :user_logic:memory_output

probe -create -shm -waveform :fieldrive:rx_block:msg_block:nxt_data
probe -create -shm -waveform :fieldrive:rx_block:msg_block:ind
probe -create -shm -waveform :fieldrive:rx_block:msg_block:in_consumed
probe -create -shm -waveform :fieldrive:rx_block:msg_block:in_broadcast

probe -create -shm -waveform :user_logic:wb_monitor:valid_bus_cycle
probe -create -shm -waveform :user_logic:wb_monitor:var_id
probe -create -shm -waveform :user_logic:wb_monitor:adr
probe -create -shm -waveform :user_logic:wb_monitor:in_consumed
probe -create -shm -waveform :user_logic:wb_monitor:in_broadcast

probe -create -shm -waveform :user_logic:wb_monitor:writing_produced
probe -create -shm -waveform :user_logic:wb_monitor:out_produced

probe -create -shm -waveform :fieldrive:tx_block:monitor:frame_received
probe -create -shm -waveform :fieldrive:tx_block:monitor:out_produced

probe -create -shm -waveform :user_logic:user_acc_monitor:var3_fresh
probe -create -shm -waveform :user_logic:user_acc_monitor:ucacerr
probe -create -shm -waveform :user_logic:user_acc_monitor:upacerr



run 4000 us
