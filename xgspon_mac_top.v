`timescale 1ns/1ps

module xgspon_mac_top #(
    parameter GEM_DATA_W = 64,
    parameter TCONT_NUM  = 8,
    parameter ALLOC_ID_W = 12,
    parameter PORT_ID_W  = 12,
    parameter ONU_ID_W   = 10,
    parameter LOCAL_ALLOC_ID = 12'h100
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  ds_valid,
    input  wire [GEM_DATA_W-1:0] ds_data,
    input  wire                  ds_sop,
    input  wire                  ds_eop,
    input  wire [2:0]            ds_empty,
    output wire                  ds_ready,
    output wire                  us_valid,
    output wire [GEM_DATA_W-1:0] us_data,
    output wire                  us_sop,
    output wire                  us_eop,
    output wire [2:0]            us_empty,
    input  wire                  us_ready,
    input  wire                  cfg_wr_en,
    input  wire [15:0]           cfg_addr,
    input  wire [31:0]           cfg_wdata,
    output reg [31:0]            cfg_rdata,
    input  wire                  svc_tx_valid,
    input  wire [GEM_DATA_W-1:0] svc_tx_data,
    input  wire                  svc_tx_sop,
    input  wire                  svc_tx_eop,
    output wire                  svc_tx_ready,
    output wire                  svc_rx_valid,
    output wire [GEM_DATA_W-1:0] svc_rx_data,
    output wire                  svc_rx_sop,
    output wire                  svc_rx_eop,
    input  wire                  svc_rx_ready
);

    wire bwmap_valid; wire [ALLOC_ID_W-1:0] bwmap_alloc_id; wire [15:0] bwmap_grant_start; wire [15:0] bwmap_grant_len; wire bwmap_last;
    wire ploam_valid; wire [47:0] ploam_msg;
    wire gem_ds_valid; wire [GEM_DATA_W-1:0] gem_ds_data; wire gem_ds_sop; wire gem_ds_eop; wire [PORT_ID_W-1:0] gem_ds_port_id; wire [11:0] gem_ds_len; wire gem_ds_ready;
    wire gem_us_valid; wire [GEM_DATA_W-1:0] gem_us_data; wire gem_us_sop; wire gem_us_eop; wire [2:0] gem_us_empty; wire gem_us_ready; wire grant_active;
    wire burst_valid, burst_sop, burst_eop, burst_in_ready; wire [GEM_DATA_W-1:0] burst_data;

    reg rx_sn_req, rx_ranging_grant, rx_key_switch; reg [ONU_ID_W-1:0] rx_assigned_onu_id; reg [127:0] key_in; reg key_in_valid;
    reg [127:0] crypto_key; reg [63:0] crypto_iv;
    wire tx_sn, tx_ranging_resp, registration_ack, key_active; wire [ONU_ID_W-1:0] onu_id; wire [2:0] onu_state;
    wire onu_id_valid;
    wire ploam_accept, ploam_integrity_ok;
    wire [7:0] ploam_opcode;
    wire [31:0] ploam_payload;
    wire ploam_sn_req, ploam_assign_onu_id, ploam_ranging_grant, ploam_eqd_update, ploam_key_control;
    wire ploam_popup_request, ploam_deactivate, ploam_emergency_stop;
    wire [ONU_ID_W-1:0] ploam_target_onu_id;
    wire sn_match, sn_response_due, quiet_window_active, sn_tx_allowed;
    wire [7:0] sn_random_delay;
    wire popup_active, popup_reentry_req;
    wire [15:0] eqd_value, grant_time_adjust;
    wire sn_timeout, ranging_timeout, ploam_timeout, sync_timeout, popup_timeout;
    wire ploamu_valid, ploamu_sop, ploamu_eop;
    wire [GEM_DATA_W-1:0] ploamu_data;
    wire [31:0] ctx_serial_number;
    wire [ONU_ID_W-1:0] ctx_onu_id;
    wire [15:0] ctx_eqd, ctx_flags;
    wire [2:0] ctx_state;
    reg [15:0] tcont0_buf_occ, tcont1_buf_occ, tcont2_buf_occ, tcont3_buf_occ;
    wire [1:0] active_tcont;
    wire xgem_valid, xgem_sop, xgem_eop, xgem_idle, xgem_fragment, xgem_ready; wire [GEM_DATA_W-1:0] xgem_data;
    wire [GEM_DATA_W-1:0] enc_data, dec_data;
        wire omci_valid, omci_sop, omci_eop, oam_valid; wire [GEM_DATA_W-1:0] omci_data, oam_data;
    wire ds_scr_valid, ds_scr_sop, ds_scr_eop, ds_scr_ready; wire [GEM_DATA_W-1:0] ds_scr_data;
    wire us_scr_valid, us_scr_sop, us_scr_eop, us_scr_ready; wire [GEM_DATA_W-1:0] us_scr_data;
    wire psbd_valid, psbd_sop, psbd_eop, psbd_ready; wire [GEM_DATA_W-1:0] psbd_data;
    wire ds_fec_valid, ds_fec_sop, ds_fec_eop, ds_fec_ready; wire [GEM_DATA_W-1:0] ds_fec_data; wire [7:0] ds_fec_parity;
    wire frame_lock, frame_start, lof; wire [31:0] superframe_counter;
    wire us_fec_valid, us_fec_sop, us_fec_eop, us_fec_ready; wire [GEM_DATA_W-1:0] us_fec_data; wire [7:0] us_fec_parity;
    wire ds_fec_uncorr, us_fec_uncorr;



    xgspon_scrambler #(.DATA_W(GEM_DATA_W)) u_ds_descrambler (
        .clk(clk), .rst_n(rst_n), .enable(1'b1), .in_valid(ds_valid), .in_data(ds_data), .in_sop(ds_sop), .in_eop(ds_eop), .in_ready(ds_ready),
        .out_valid(ds_scr_valid), .out_data(ds_scr_data), .out_sop(ds_scr_sop), .out_eop(ds_scr_eop), .out_ready(ds_scr_ready)
    );

    xgspon_psbd_sync #(.DATA_W(GEM_DATA_W)) u_psbd_sync (
        .clk(clk), .rst_n(rst_n), .in_valid(ds_scr_valid), .in_data(ds_scr_data), .in_sop(ds_scr_sop), .in_eop(ds_scr_eop), .in_ready(ds_scr_ready),
        .out_valid(psbd_valid), .out_data(psbd_data), .out_sop(psbd_sop), .out_eop(psbd_eop), .out_ready(psbd_ready),
        .sync_locked(frame_lock), .frame_start(frame_start), .superframe_cnt(superframe_counter)
    );

    assign lof = ~frame_lock;
    assign ds_fec_parity = 8'd0;
    assign ds_fec_uncorr = 1'b0;

    xgspon_tc_framing_v2 #(.DATA_W(GEM_DATA_W), .ALLOC_ID_W(ALLOC_ID_W), .PORT_ID_W(PORT_ID_W)) u_tc_framing (
        .clk(clk), .rst_n(rst_n), .frame_lock(frame_lock), .frame_start(frame_start), .in_valid(psbd_valid), .in_data(psbd_data), .in_sop(psbd_sop), .in_eop(psbd_eop), .in_ready(psbd_ready),
        .bwmap_valid(bwmap_valid), .bwmap_alloc_id(bwmap_alloc_id), .bwmap_grant_start(bwmap_grant_start), .bwmap_grant_len(bwmap_grant_len),
        .bwmap_last(bwmap_last), .ploam_valid(ploam_valid), .ploam_msg(ploam_msg), .gem_valid(gem_ds_valid), .gem_data(gem_ds_data), .gem_sop(gem_ds_sop), .gem_eop(gem_ds_eop), .gem_port_id(gem_ds_port_id), .out_ready(gem_ds_ready)
    );
    xgspon_crypto_engine #(.DATA_W(GEM_DATA_W)) u_dec_crypto (
        .clk(clk), .rst_n(rst_n), .enable(key_active), .key(crypto_key), .iv(crypto_iv),
         .in_valid(gem_ds_valid), .in_data(gem_ds_data), .in_sop(gem_ds_sop), .in_eop(gem_ds_eop), .in_ready(),
        .out_valid(), .out_data(dec_data), .out_sop(), .out_eop(), .out_ready(1'b1)
    );

    xgspon_omci_oam #(.GEM_DATA_W(GEM_DATA_W), .PORT_ID_W(PORT_ID_W)) u_omci_oam (
        .clk(clk), .rst_n(rst_n), .gem_valid(gem_ds_valid), .gem_data(dec_data), .gem_sop(gem_ds_sop), .gem_eop(gem_ds_eop), .gem_port_id(gem_ds_port_id),
        .omci_valid(omci_valid), .omci_data(omci_data), .omci_sop(omci_sop), .omci_eop(omci_eop), .oam_valid(oam_valid), .oam_data(oam_data)
    );

    xgspon_gem_rx_adapt #(.GEM_DATA_W(GEM_DATA_W), .PORT_ID_W(PORT_ID_W)) u_gem_rx_adapt (
        .clk(clk), .rst_n(rst_n), .gem_valid(gem_ds_valid), .gem_data(dec_data), .gem_sop(gem_ds_sop), .gem_eop(gem_ds_eop), .gem_port_id(gem_ds_port_id), .gem_ready(gem_ds_ready),
        .svc_valid(svc_rx_valid), .svc_data(svc_rx_data), .svc_sop(svc_rx_sop), .svc_eop(svc_rx_eop), .svc_ready(svc_rx_ready)
    );

    xgspon_us_sched #(.GEM_DATA_W(GEM_DATA_W), .TCONT_NUM(TCONT_NUM), .ALLOC_ID_W(ALLOC_ID_W), .LOCAL_ALLOC_ID(LOCAL_ALLOC_ID)) u_us_sched (
        .clk(clk), .rst_n(rst_n), .bwmap_valid(bwmap_valid), .bwmap_alloc_id(bwmap_alloc_id), .bwmap_grant_start(bwmap_grant_start), .bwmap_grant_len(bwmap_grant_len), .bwmap_last(bwmap_last),
        .svc_tx_valid(svc_tx_valid), .svc_tx_data(svc_tx_data), .svc_tx_sop(svc_tx_sop), .svc_tx_eop(svc_tx_eop), .svc_tx_ready(svc_tx_ready),
        .gem_valid(gem_us_valid), .gem_data(gem_us_data), .gem_sop(gem_us_sop), .gem_eop(gem_us_eop),  .gem_empty(gem_us_empty), .gem_ready(burst_in_ready), .grant_active(grant_active), .active_tcont(active_tcont), .tcont0_buf_occ(tcont0_buf_occ), .tcont1_buf_occ(tcont1_buf_occ), .tcont2_buf_occ(tcont2_buf_occ), .tcont3_buf_occ(tcont3_buf_occ)
    );


    xgspon_xgem_engine_v2 #(.DATA_W(GEM_DATA_W), .PORT_ID_W(PORT_ID_W)) u_xgem_engine (
        .clk(clk), .rst_n(rst_n),
        .in_valid(gem_us_valid), .in_data(gem_us_data), .in_sop(gem_us_sop), .in_eop(gem_us_eop), .in_port_id(12'h100),
        .in_ready(burst_in_ready),
        .out_valid(xgem_valid), .out_data(xgem_data), .out_sop(xgem_sop), .out_eop(xgem_eop),
        .out_idle(xgem_idle), .out_fragment(xgem_fragment), .out_port_id(), .out_payload_len(), .out_hec(),
        .out_ready(xgem_ready)
    );

    xgspon_crypto_engine #(.DATA_W(GEM_DATA_W)) u_enc_crypto (
        .clk(clk), .rst_n(rst_n), .enable(key_active), .key(crypto_key), .iv(crypto_iv),
        .in_valid(xgem_valid), .in_data(xgem_data), .in_sop(xgem_sop), .in_eop(xgem_eop), .in_ready(),
        .out_valid(), .out_data(enc_data), .out_sop(), .out_eop(), .out_ready(1'b1)
    );

    xgspon_burst_timing #(.GEM_DATA_W(GEM_DATA_W)) u_burst_timing (
        .clk(clk), .rst_n(rst_n), .grant_open(grant_active),
        .eq_delay_cycles(grant_time_adjust), .guard_time_cycles(8'd4), .preamble_cycles(8'd2), .delimiter_cycles(8'd1),
        .in_valid(xgem_valid), .in_data(enc_data), .in_sop(xgem_sop), .in_eop(xgem_eop), .in_ready(xgem_ready),
        .out_valid(burst_valid), .out_data(burst_data), .out_sop(burst_sop), .out_eop(burst_eop), .out_ready(us_ready)
    );

    xgspon_scrambler #(.DATA_W(GEM_DATA_W)) u_us_scrambler (
        .clk(clk), .rst_n(rst_n), .enable(1'b1), .in_valid(burst_valid), .in_data(burst_data), .in_sop(burst_sop), .in_eop(burst_eop), .in_ready(us_ready),
        .out_valid(us_scr_valid), .out_data(us_scr_data), .out_sop(us_scr_sop), .out_eop(us_scr_eop), .out_ready(us_fec_ready)
    );

    xgspon_fec_rs #(.DATA_W(GEM_DATA_W)) u_us_fec_encode (
        .clk(clk), .rst_n(rst_n), .encode_mode(1'b1), .in_valid(us_scr_valid), .in_data(us_scr_data), .in_sop(us_scr_sop), .in_eop(us_scr_eop), .in_ready(us_fec_ready),
        .in_parity(8'h00), .out_valid(us_fec_valid), .out_data(us_fec_data), .out_sop(us_fec_sop), .out_eop(us_fec_eop), .out_parity(us_fec_parity), .uncorrectable(us_fec_uncorr), .out_ready(us_ready)
    );

    xgspon_ploam_rx #(.ONU_ID_W(ONU_ID_W), .PLOAM_W(48)) u_ploam_rx (
        .clk(clk), .rst_n(rst_n), .ploam_valid(ploam_valid), .ploam_msg(ploam_msg), .local_onu_id(onu_id), .onu_id_valid(onu_id_valid),
        .msg_accept(ploam_accept), .integrity_ok(ploam_integrity_ok), .opcode(ploam_opcode), .payload(ploam_payload),
        .sn_req(ploam_sn_req), .assign_onu_id(ploam_assign_onu_id), .ranging_grant(ploam_ranging_grant), .eqd_update(ploam_eqd_update),
        .key_control(ploam_key_control), .popup_request(ploam_popup_request), .deactivate(ploam_deactivate), .emergency_stop(ploam_emergency_stop),
        .target_onu_id(ploam_target_onu_id)
    );

    xgspon_onuid_manager #(.ONU_ID_W(ONU_ID_W)) u_onuid_manager (
        .clk(clk), .rst_n(rst_n), .allocate(ploam_assign_onu_id), .invalidate(ploam_deactivate | ploam_emergency_stop), .deactivate(ploam_deactivate),
        .reassign(ploam_assign_onu_id & onu_id_valid), .new_onu_id(ploam_payload[ONU_ID_W-1:0]), .onu_id(onu_id), .onu_id_valid(onu_id_valid)
    );

    xgspon_sn_filter u_sn_filter (
        .clk(clk), .rst_n(rst_n), .sn_req(ploam_sn_req), .vendor_mask(32'hFFFF_FFFF), .sn_mask(32'hFFFF_FFFF), .random_seed(ploam_payload[7:0]),
        .sn_match(sn_match), .sn_response_due(sn_response_due), .random_delay(sn_random_delay)
    );

    xgspon_quiet_window u_quiet_window (
        .clk(clk), .rst_n(rst_n), .window_start(ploam_sn_req), .window_len(ploam_payload[23:8]), .sn_response_due(sn_response_due),
        .window_active(quiet_window_active), .sn_tx_allowed(sn_tx_allowed)
    );

    xgspon_popup_controller u_popup_controller (
        .clk(clk), .rst_n(rst_n), .loss_of_sync(lof), .popup_request(ploam_popup_request), .ranging_done(ploam_eqd_update),
        .popup_active(popup_active), .reentry_req(popup_reentry_req)
    );

    xgspon_eqd_engine u_eqd_engine (
        .clk(clk), .rst_n(rst_n), .update_valid(ploam_eqd_update), .coarse_eqd(ploam_payload[15:0]), .fine_corr(ploam_payload[23:16]),
        .eqd_value(eqd_value), .grant_time_adjust(grant_time_adjust)
    );

    xgspon_activation_timers u_activation_timers (
        .clk(clk), .rst_n(rst_n), .start_sn(onu_state == 3'd2), .start_ranging(onu_state == 3'd3), .start_ploam(frame_lock), .start_sync(!frame_lock), .start_popup(popup_active),
        .clear_sn(ploam_assign_onu_id), .clear_ranging(ploam_eqd_update), .clear_ploam(ploam_accept), .clear_sync(frame_lock), .clear_popup(!popup_active),
        .sn_timeout(sn_timeout), .ranging_timeout(ranging_timeout), .ploam_timeout(ploam_timeout), .sync_timeout(sync_timeout), .popup_timeout(popup_timeout)
    );

    xgspon_ploamu_tx #(.DATA_W(GEM_DATA_W), .ONU_ID_W(ONU_ID_W)) u_ploamu_tx (
        .clk(clk), .rst_n(rst_n), .send_sn(tx_sn), .send_reg_ack(registration_ack), .send_ranging_resp(tx_ranging_resp), .send_dbru(1'b0), .send_alarm(1'b0), .send_dying_gasp(ploam_emergency_stop),
        .onu_id(onu_id), .serial_number(ctx_serial_number), .dbru_value(16'd0), .valid(ploamu_valid), .data(ploamu_data), .sop(ploamu_sop), .eop(ploamu_eop), .ready(1'b1)
    );

    xgspon_activation_context #(.ONU_ID_W(ONU_ID_W)) u_activation_context (
        .clk(clk), .rst_n(rst_n), .serial_number_in(32'h00000001), .serial_load(1'b0), .onu_id_in(onu_id), .onu_id_load(onu_id_valid),
        .eqd_in(eqd_value), .eqd_load(ploam_eqd_update), .state_in(onu_state), .state_load(1'b1),
        .flags_in({8'd0, popup_active, quiet_window_active, sn_match, ploam_integrity_ok, onu_id_valid, frame_lock, key_active, ploam_accept}), .flags_load(1'b1),
        .serial_number(ctx_serial_number), .onu_id(ctx_onu_id), .eqd(ctx_eqd), .state(ctx_state), .activation_flags(ctx_flags)
    );

    xgspon_onu_ctrl #(.ONU_ID_W(ONU_ID_W)) u_onu_ctrl (
        .clk(clk), .rst_n(rst_n), .frame_lock(frame_lock), .sn_request(ploam_sn_req | rx_sn_req), .sn_tx_allowed(sn_tx_allowed),
        .onu_id_assigned(ploam_assign_onu_id), .ranging_grant(ploam_ranging_grant | rx_ranging_grant), .eqd_valid(ploam_eqd_update),
        .key_switch(ploam_key_control | rx_key_switch), .popup_request(popup_reentry_req), .deactivate(ploam_deactivate), .emergency_stop(ploam_emergency_stop),
        .sn_timeout(sn_timeout), .ranging_timeout(ranging_timeout), .ploam_timeout(ploam_timeout), .popup_timeout(popup_timeout),
        .tx_sn(tx_sn), .tx_ranging_resp(tx_ranging_resp), .registration_ack(registration_ack), .key_active(key_active), .onu_state(onu_state)
    );

    assign us_valid = us_fec_valid; assign us_data = us_fec_data; assign us_sop = us_fec_sop; assign us_eop = us_fec_eop; assign us_empty = gem_us_empty; assign gem_us_ready = us_ready;

    always @(*) begin
        rx_sn_req = 1'b0; rx_ranging_grant = 1'b0; rx_key_switch = 1'b0; rx_assigned_onu_id = {ONU_ID_W{1'b0}}; key_in = 128'd0; key_in_valid = 1'b0; crypto_key = 128'h0; crypto_iv = 64'h1;
        tcont0_buf_occ = 16'd32; tcont1_buf_occ = 16'd32; tcont2_buf_occ = 16'd32; tcont3_buf_occ = 16'd32;
        if (cfg_wr_en) begin
            case (cfg_addr)
                16'h0100: rx_sn_req = cfg_wdata[0];
                16'h0104: rx_ranging_grant = cfg_wdata[0];
                16'h0108: rx_key_switch = cfg_wdata[0];
                16'h010C: rx_assigned_onu_id = cfg_wdata[ONU_ID_W-1:0];
                16'h0110: begin key_in[31:0] = cfg_wdata; key_in_valid = 1'b1; end
                16'h0120: tcont0_buf_occ = cfg_wdata[15:0];
                16'h0124: tcont1_buf_occ = cfg_wdata[15:0];
                16'h0128: tcont2_buf_occ = cfg_wdata[15:0];
                16'h012C: tcont3_buf_occ = cfg_wdata[15:0];
                16'h0130: crypto_key[31:0] = cfg_wdata;
                16'h0134: crypto_key[63:32] = cfg_wdata;
                16'h0138: crypto_key[95:64] = cfg_wdata;
                16'h013C: crypto_key[127:96] = cfg_wdata;
                16'h0140: crypto_iv[31:0] = cfg_wdata;
                16'h0144: crypto_iv[63:32] = cfg_wdata;
                default: ;
            endcase
        end
    end

    always @(*) begin
        case (cfg_addr)
            16'h0000: cfg_rdata = {31'd0, ploam_valid};
            16'h0004: cfg_rdata = {16'd0, bwmap_alloc_id, bwmap_valid, 3'd0};
            16'h0008: cfg_rdata = {bwmap_grant_start, bwmap_grant_len};
            16'h000C: cfg_rdata = {16'd0, ploam_msg[47:32]};
            16'h0010: cfg_rdata = ploam_msg[31:0];
            16'h0014: cfg_rdata = {21'd0, onu_id, key_active, tx_ranging_resp, tx_sn, onu_state};
            16'h0018: cfg_rdata = {30'd0, active_tcont};
            16'h001C: cfg_rdata = {tcont0_buf_occ, tcont1_buf_occ};
            16'h0020: cfg_rdata = {tcont2_buf_occ, tcont3_buf_occ};
            16'h0024: cfg_rdata = {29'd0, oam_valid, omci_eop, omci_sop, omci_valid};
            16'h0028: cfg_rdata = crypto_key[31:0];
            16'h002C: cfg_rdata = crypto_iv[31:0];
            16'h0030: cfg_rdata = {14'd0, us_fec_uncorr, ds_fec_uncorr, ds_fec_parity, us_fec_parity};
            16'h0034: cfg_rdata = {30'd0, lof, frame_lock};
            16'h0038: cfg_rdata = superframe_counter;
            16'h003C: cfg_rdata = {20'd0, onu_id, onu_id_valid, ploam_accept};
            16'h0040: cfg_rdata = {24'd0, ploam_opcode};
            16'h0044: cfg_rdata = {16'd0, eqd_value};
            16'h0048: cfg_rdata = {16'd0, ctx_flags};
            default:  cfg_rdata = 32'h0000_0000;
        endcase
    end

endmodule
