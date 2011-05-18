probe -create -shm -waveform :fieldrive:f_clk
probe -create -shm -waveform :fieldrive:fd_reset

#probe -create -shm -waveform :board:read_config_trigger
#probe -create -shm -waveform :board:report_config_trigger
#probe -create -shm -waveform :board:c_id_o

probe -create -shm -waveform :fieldrive:rx_block:fip_frame_trigger
probe -create -shm -waveform :fieldrive:id_rp

probe -create -shm -waveform :fieldrive:rx_block:feeder:fstate
probe -create -shm -waveform :fieldrive:rx_block:feeder:fss_start
#probe -create -shm -waveform :fieldrive:rx_block:feeder:fss_dly
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
probe -create -shm -waveform :fieldrive:rx_block:jitter
probe -create -shm -waveform :fieldrive:rx_block:meddler:jitter_value
#probe -create -shm -waveform :fieldrive:rx_block:meddler:jitter_active
probe -create -shm -waveform :fieldrive:rx_block:clamp
probe -create -shm -waveform :fieldrive:rx_block:meddler:v_minus_err
probe -create -shm -waveform :fieldrive:rx_block:meddler:v_plus_err
#probe -create -shm -waveform :fieldrive:rx_block:meddler:insert_violation
#probe -create -shm -waveform :fieldrive:rx_block:meddler:insertion_pending
#probe -create -shm -waveform :fieldrive:rx_block:meddler:violation_positive

#probe -create -shm -waveform :fieldrive:rx_block:fss_block:fss_value
#probe -create -shm -waveform :fieldrive:rx_block:fss_block:s_fss_value
#probe -create -shm -waveform :fieldrive:rx_block:fss_block:i


#probe -create -shm -waveform :dut:production:production_serializer:start_prod_p_i
#probe -create -shm -waveform :dut:production:production_serializer:s_sending_fss
#probe -create -shm -waveform :dut:production:production_serializer:s_bit_index_top
#probe -create -shm -waveform :dut:production:production_serializer:s_bit_index_load
#probe -create -shm -waveform :dut:production:production_serializer:s_decr_index_p
#probe -create -shm -waveform :dut:production:production_serializer:tx_clk_p_buff_i
#probe -create -shm -waveform :dut:production:production_serializer:s_bit_index
#probe -create -shm -waveform :dut:production:production_serializer:tx_state
#probe -create -shm -waveform :dut:fieldrive_receiver:fieldrive_receiver_deglitcher:s_fd_rxd_synch
#probe -create -shm -waveform :dut:fieldrive_receiver:fieldrive_receiver_deglitcher:s_deglitch_c
probe -create -shm -waveform :dut:fieldrive_receiver:fieldrive_receiver_deserializer:fd_rxd_i
probe -create -shm -waveform :dut:fieldrive_receiver:fieldrive_receiver_deserializer:signif_edge_window_i
probe -create -shm -waveform :dut:fieldrive_receiver:fieldrive_receiver_deserializer:sample_manch_bit_p_i
#probe -create -shm -waveform :dut:fieldrive_receiver:fieldrive_receiver_deserializer:sample_bit_p_i
probe -create -shm -waveform :dut:fieldrive_receiver:fieldrive_receiver_deserializer:rx_st

probe -create -shm -waveform :dut:engine_control:control_st
probe -create -shm -waveform :dut:engine_control:rx_byte_i
probe -create -shm -waveform :dut:engine_control:rx_byte_ready_p_i

#probe -create -shm -waveform :dut:consumption:consumption_outcome:rx_fss_crc_fes_manch_ok_p_i
#probe -create -shm -waveform :dut:fieldrive_receiver:fieldrive_receiver_deserializer:s_arriving_fes
#probe -create -shm -waveform :dut:fieldrive_receiver:fieldrive_receiver_deserializer:s_fes_detected_p
#probe -create -shm -waveform :dut:fieldrive_receiver:fieldrive_receiver_deserializer:s_byte_ready_p_d1
#probe -create -shm -waveform :dut:fieldrive_receiver:fieldrive_receiver_deserializer:s_crc_ok_p_d
#probe -create -shm -waveform :dut:fieldrive_receiver:fieldrive_receiver_deserializer:s_manch_not_ok
#probe -create -shm -waveform :dut:fieldrive_receiver:fieldrive_receiver_deserializer:manch_code_viol_p_i

#probe -create -shm -waveform :dut:fieldrive_receiver:fieldrive_receiver_oscillator:fd_rxd_edge_p_i
#probe -create -shm -waveform :dut:fieldrive_receiver:fieldrive_receiver_oscillator:s_period_c
#probe -create -shm -waveform :dut:fieldrive_receiver:fieldrive_receiver_oscillator:s_manch_clk
#probe -create -shm -waveform :dut:fieldrive_receiver:fieldrive_receiver_oscillator:s_manch_clk_d1

#probe -create -shm -waveform :dut:consumption:consumption_outcome:rx_crc_or_manch_wrong_p_i
#probe -create -shm -waveform :dut:consumption:consumption_outcome:cons_ctrl_byte_i
#probe -create -shm -waveform :dut:consumption:consumption_outcome:cons_pdu_byte_i
#probe -create -shm -waveform :dut:consumption:consumption_outcome:rx_byte_index_i
#probe -create -shm -waveform :dut:consumption:consumption_outcome:cons_lgth_byte_i

#probe -create -shm -waveform :fieldrive:tx_block:decoder:offset1
#probe -create -shm -waveform :fieldrive:tx_block:decoder:offset2
#probe -create -shm -waveform :fieldrive:tx_block:decoder:shift
#probe -create -shm -waveform :fieldrive:tx_block:decoder:clk1
#probe -create -shm -waveform :fieldrive:tx_block:decoder:clk2
#probe -create -shm -waveform :fieldrive:tx_block:decoder:clk3
#probe -create -shm -waveform :fieldrive:tx_block:decoder:clk4
#probe -create -shm -waveform :fieldrive:tx_block:decoder:count_for_clk3
#probe -create -shm -waveform :fieldrive:tx_block:decoder:count_for_clk4
#probe -create -shm -waveform :fieldrive:tx_block:decoder:sel
probe -create -shm -waveform :fieldrive:tx_block:decoder:extracted_clk
#probe -create -shm -waveform :fieldrive:tx_block:decoder:locked
#probe -create -shm -waveform :fieldrive:tx_block:decoder:locking
probe -create -shm -waveform :fieldrive:tx_block:decoder:extracted_bits
probe -create -shm -waveform :fieldrive:tx_block:decoder:violation

probe -create -shm -waveform :fieldrive:tx_block:chopper:vx
probe -create -shm -waveform :fieldrive:tx_block:detector:sof_detected
probe -create -shm -waveform :fieldrive:tx_block:chopper:sof
probe -create -shm -waveform :fieldrive:tx_block:chopper:eof

#probe -create -shm -waveform :fieldrive:fip_bus_monitor:ba_responded
#probe -create -shm -waveform :fieldrive:fip_bus_monitor:nanofip_responded
#probe -create -shm -waveform :fieldrive:fip_bus_monitor:silence_time_reached
#probe -create -shm -waveform :fieldrive:fip_bus_monitor:start_turn_around
#probe -create -shm -waveform :fieldrive:fip_bus_monitor:end_turn_around

probe -create -shm -waveform :fieldrive:tx_block:fcs_check
probe -create -shm -waveform :fieldrive:tx_block:fcs_ok

#probe -create -shm -waveform :fieldrive:tx_block:chopper:chopping_counter:value
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

#probe -create -shm -waveform :dut:reset_unit:rstin_st
#probe -create -shm -waveform :dut:reset_unit:var_rst_st
#probe -create -shm -waveform :dut:reset_unit:s_rstin_c

probe -create -shm -waveform :fieldrive:f_clk
probe -create -shm -waveform :fd_rstn
probe -create -shm -waveform :fd_rxcdn
probe -create -shm -waveform :fd_rxd
probe -create -shm -waveform :fd_txena
probe -create -shm -waveform :fd_txd
probe -create -shm -waveform :fd_txck
probe -create -shm -waveform :fd_wdgn
probe -create -shm -waveform :fd_txer

probe -create -shm -waveform :fieldrive:rx_block:msg_serializer:nb_truncated_bits
probe -create -shm -waveform :fieldrive:rx_block:msg_serializer:i

#probe -create -shm -waveform :fieldrive:fip_bus_monitor:fd_reset_asserted
#probe -create -shm -waveform :fieldrive:fip_bus_monitor:rst_latency_reached
#probe -create -shm -waveform :fieldrive:fip_bus_monitor:fd_reset_assertion
#probe -create -shm -waveform :fieldrive:fip_bus_monitor:previous_preset_time
#probe -create -shm -waveform :fieldrive:fip_bus_monitor:preset_time
#probe -create -shm -waveform :fieldrive:fip_bus_monitor:previous_ureset_time
#probe -create -shm -waveform :fieldrive:fip_bus_monitor:ureset_time
#probe -create -shm -waveform :fieldrive:fip_bus_monitor:ureset_hist_opened_ok
#probe -create -shm -waveform :fieldrive:fip_bus_monitor:previous_vreset_time
#probe -create -shm -waveform :fieldrive:fip_bus_monitor:vreset_time
#probe -create -shm -waveform :fieldrive:fip_bus_monitor:f_clk_period

probe -create -shm -waveform :rstpon
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

probe -create -shm -waveform :dut:r_fcser_o
probe -create -shm -waveform :dut:r_tler_o 
probe -create -shm -waveform :dut:u_cacer_o
probe -create -shm -waveform :dut:u_pacer_o

probe -create -shm -waveform :user_logic:user_acc_monitor:var3_fresh
probe -create -shm -waveform :user_logic:user_acc_monitor:ucacerr
probe -create -shm -waveform :user_logic:user_acc_monitor:upacerr


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

#probe -create -shm -waveform :fieldrive:rx_block:msg_block:nxt_data
#probe -create -shm -waveform :fieldrive:rx_block:msg_block:ind
#probe -create -shm -waveform :fieldrive:rx_block:msg_block:in_consumed
#probe -create -shm -waveform :fieldrive:rx_block:msg_block:in_broadcast

probe -create -shm -waveform :user_logic:wb_monitor:valid_bus_cycle
probe -create -shm -waveform :user_logic:wb_monitor:var_id
probe -create -shm -waveform :user_logic:wb_monitor:adr
#probe -create -shm -waveform :user_logic:wb_monitor:errct
#probe -create -shm -waveform :user_logic:wb_monitor:errct_trig
#probe -create -shm -waveform :user_logic:wb_monitor:in_consumed
#probe -create -shm -waveform :user_logic:wb_monitor:in_broadcast

#probe -create -shm -waveform :user_logic:wb_monitor:writing_produced
#probe -create -shm -waveform :user_logic:wb_monitor:out_produced

#probe -create -shm -waveform :fieldrive:tx_block:monitor:frame_received
#probe -create -shm -waveform :fieldrive:tx_block:monitor:out_produced
#probe -create -shm -waveform :fieldrive:tx_block:monitor:checking_produced:mismatches
#probe -create -shm -waveform :fieldrive:tx_block:monitor:last_data


run 3 ms

