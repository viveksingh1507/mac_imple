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
    wire tx_sn, tx_ranging_resp, key_active; wire [ONU_ID_W-1:0] onu_id; wire [2:0] onu_state;
    reg [15:0] tcont0_buf_occ, tcont1_buf_occ, tcont2_buf_occ, tcont3_buf_occ;
    wire [1:0] active_tcont;
    wire frag_valid, frag_sop, frag_eop, frag_flag, frag_ready; wire [GEM_DATA_W-1:0] frag_data;
    wire [GEM_DATA_W-1:0] enc_data, dec_data;
    wire reasm_valid, reasm_sop, reasm_eop, reasm_ready; wire [GEM_DATA_W-1:0] reasm_data;
    wire omci_valid, omci_sop, omci_eop, oam_valid; wire [GEM_DATA_W-1:0] omci_data, oam_data;
    wire ds_scr_valid, ds_scr_sop, ds_scr_eop, ds_scr_ready; wire [GEM_DATA_W-1:0] ds_scr_data;
    wire us_scr_valid, us_scr_sop, us_scr_eop, us_scr_ready; wire [GEM_DATA_W-1:0] us_scr_data;
    wire ds_fec_valid, ds_fec_sop, ds_fec_eop, ds_fec_ready; wire [GEM_DATA_W-1:0] ds_fec_data; wire [7:0] ds_fec_parity;
    wire us_fec_valid, us_fec_sop, us_fec_eop, us_fec_ready; wire [GEM_DATA_W-1:0] us_fec_data; wire [7:0] us_fec_parity;


    xgspon_fec_stub #(.DATA_W(GEM_DATA_W)) u_ds_fec_decode (
        .clk(clk), .rst_n(rst_n), .encode(1'b0), .in_valid(ds_valid), .in_data(ds_data), .in_sop(ds_sop), .in_eop(ds_eop), .in_ready(ds_ready),
        .out_valid(ds_fec_valid), .out_data(ds_fec_data), .out_sop(ds_fec_sop), .out_eop(ds_fec_eop), .out_parity(ds_fec_parity), .out_ready(ds_fec_ready)
    );

    xgspon_scrambler #(.DATA_W(GEM_DATA_W)) u_ds_descrambler (
        .clk(clk), .rst_n(rst_n), .enable(1'b1), .in_valid(ds_fec_valid), .in_data(ds_fec_data), .in_sop(ds_fec_sop), .in_eop(ds_fec_eop), .in_ready(ds_ready),
        .out_valid(ds_scr_valid), .out_data(ds_scr_data), .out_sop(ds_scr_sop), .out_eop(ds_scr_eop), .out_ready(ds_scr_ready)
    );

    xgspon_ds_parser #(.GEM_DATA_W(GEM_DATA_W), .PORT_ID_W(PORT_ID_W), .ALLOC_ID_W(ALLOC_ID_W)) u_ds_parser (
        .clk(clk), .rst_n(rst_n), .ds_valid(ds_scr_valid), .ds_data(ds_scr_data), .ds_sop(ds_scr_sop), .ds_eop(ds_scr_eop), .ds_empty(ds_empty), .ds_ready(ds_scr_ready),
        .bwmap_valid(bwmap_valid), .bwmap_alloc_id(bwmap_alloc_id), .bwmap_grant_start(bwmap_grant_start), .bwmap_grant_len(bwmap_grant_len), .bwmap_last(bwmap_last),
        .gem_valid(gem_ds_valid), .gem_data(gem_ds_data), .gem_sop(gem_ds_sop), .gem_eop(gem_ds_eop), .gem_port_id(gem_ds_port_id), .gem_len(gem_ds_len), .gem_ready(gem_ds_ready),
        .ploam_valid(ploam_valid), .ploam_msg(ploam_msg)
    );

    xgspon_crypto_stub #(.GEM_DATA_W(GEM_DATA_W)) u_dec_crypto (
        .clk(clk), .rst_n(rst_n), .enable(key_active), .key(crypto_key), .iv(crypto_iv),
        .in_valid(gem_ds_valid), .din(gem_ds_data), .in_sop(gem_ds_sop), .in_eop(gem_ds_eop), .in_ready(),
        .out_valid(), .dout(dec_data), .out_sop(), .out_eop(), .out_ready(1'b1)
    );

    xgspon_omci_oam #(.GEM_DATA_W(GEM_DATA_W), .PORT_ID_W(PORT_ID_W)) u_omci_oam (
        .clk(clk), .rst_n(rst_n), .gem_valid(gem_ds_valid), .gem_data(dec_data), .gem_sop(gem_ds_sop), .gem_eop(gem_ds_eop), .gem_port_id(gem_ds_port_id),
        .omci_valid(omci_valid), .omci_data(omci_data), .omci_sop(omci_sop), .omci_eop(omci_eop), .oam_valid(oam_valid), .oam_data(oam_data)
    );

    xgspon_gem_reasm #(.GEM_DATA_W(GEM_DATA_W)) u_gem_reasm (
        .clk(clk), .rst_n(rst_n), .in_valid(gem_ds_valid), .in_data(dec_data), .in_sop(gem_ds_sop), .in_eop(gem_ds_eop), .in_frag(1'b0), .in_ready(gem_ds_ready),
        .out_valid(reasm_valid), .out_data(reasm_data), .out_sop(reasm_sop), .out_eop(reasm_eop), .out_ready(reasm_ready)
    );

    xgspon_gem_rx_adapt #(.GEM_DATA_W(GEM_DATA_W), .PORT_ID_W(PORT_ID_W)) u_gem_rx_adapt (
        .clk(clk), .rst_n(rst_n), .gem_valid(reasm_valid), .gem_data(reasm_data), .gem_sop(reasm_sop), .gem_eop(reasm_eop), .gem_port_id(gem_ds_port_id), .gem_ready(reasm_ready),
        .svc_valid(svc_rx_valid), .svc_data(svc_rx_data), .svc_sop(svc_rx_sop), .svc_eop(svc_rx_eop), .svc_ready(svc_rx_ready)
    );

    xgspon_us_sched #(.GEM_DATA_W(GEM_DATA_W), .TCONT_NUM(TCONT_NUM), .ALLOC_ID_W(ALLOC_ID_W), .LOCAL_ALLOC_ID(LOCAL_ALLOC_ID)) u_us_sched (
        .clk(clk), .rst_n(rst_n), .bwmap_valid(bwmap_valid), .bwmap_alloc_id(bwmap_alloc_id), .bwmap_grant_start(bwmap_grant_start), .bwmap_grant_len(bwmap_grant_len), .bwmap_last(bwmap_last),
        .svc_tx_valid(svc_tx_valid), .svc_tx_data(svc_tx_data), .svc_tx_sop(svc_tx_sop), .svc_tx_eop(svc_tx_eop), .svc_tx_ready(svc_tx_ready),
        .gem_valid(gem_us_valid), .gem_data(gem_us_data), .gem_sop(gem_us_sop), .gem_eop(gem_us_eop),  .gem_empty(gem_us_empty), .gem_ready(burst_in_ready), .grant_active(grant_active), .active_tcont(active_tcont), .tcont0_buf_occ(tcont0_buf_occ), .tcont1_buf_occ(tcont1_buf_occ), .tcont2_buf_occ(tcont2_buf_occ), .tcont3_buf_occ(tcont3_buf_occ)
    );


    xgspon_gem_frag #(.GEM_DATA_W(GEM_DATA_W)) u_gem_frag (
        .clk(clk), .rst_n(rst_n), .in_valid(gem_us_valid), .in_data(gem_us_data), .in_sop(gem_us_sop), .in_eop(gem_us_eop), .in_ready(burst_in_ready),
        .out_valid(frag_valid), .out_data(frag_data), .out_sop(frag_sop), .out_eop(frag_eop), .out_frag(frag_flag), .out_ready(frag_ready)
    );

    xgspon_crypto_stub #(.GEM_DATA_W(GEM_DATA_W)) u_enc_crypto (
        .clk(clk), .rst_n(rst_n), .enable(key_active), .key(crypto_key), .iv(crypto_iv),
        .in_valid(frag_valid), .din(frag_data), .in_sop(frag_sop), .in_eop(frag_eop), .in_ready(),
        .out_valid(), .dout(enc_data), .out_sop(), .out_eop(), .out_ready(1'b1)
    );

    xgspon_burst_timing #(.GEM_DATA_W(GEM_DATA_W)) u_burst_timing (
        .clk(clk), .rst_n(rst_n), .grant_open(grant_active),
        .eq_delay_cycles(16'd8), .guard_time_cycles(8'd4), .preamble_cycles(8'd2), .delimiter_cycles(8'd1),
        .in_valid(frag_valid), .in_data(enc_data), .in_sop(frag_sop), .in_eop(frag_eop), .in_ready(frag_ready),
        .out_valid(burst_valid), .out_data(burst_data), .out_sop(burst_sop), .out_eop(burst_eop), .out_ready(us_ready)
    );

    xgspon_scrambler #(.DATA_W(GEM_DATA_W)) u_us_scrambler (
        .clk(clk), .rst_n(rst_n), .enable(1'b1), .in_valid(burst_valid), .in_data(burst_data), .in_sop(burst_sop), .in_eop(burst_eop), .in_ready(us_ready),
        .out_valid(us_scr_valid), .out_data(us_scr_data), .out_sop(us_scr_sop), .out_eop(us_scr_eop), .out_ready(us_fec_ready)
    );

    xgspon_fec_stub #(.DATA_W(GEM_DATA_W)) u_us_fec_encode (
        .clk(clk), .rst_n(rst_n), .encode(1'b1), .in_valid(us_scr_valid), .in_data(us_scr_data), .in_sop(us_scr_sop), .in_eop(us_scr_eop), .in_ready(us_fec_ready),
        .out_valid(us_fec_valid), .out_data(us_fec_data), .out_sop(us_fec_sop), .out_eop(us_fec_eop), .out_parity(us_fec_parity), .out_ready(us_ready)
    );

    xgspon_onu_ctrl #(.ONU_ID_W(ONU_ID_W)) u_onu_ctrl (
        .clk(clk), .rst_n(rst_n), .ploam_valid(ploam_valid), .ploam_msg(ploam_msg), .rx_sn_req(rx_sn_req), .rx_ranging_grant(rx_ranging_grant),
        .rx_key_switch(rx_key_switch), .rx_assigned_onu_id(rx_assigned_onu_id), .key_in(key_in), .key_in_valid(key_in_valid),
        .tx_sn(tx_sn), .tx_ranging_resp(tx_ranging_resp), .key_active(key_active), .onu_id(onu_id), .onu_state(onu_state)
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
            16'h0030: cfg_rdata = {16'd0, ds_fec_parity, us_fec_parity};
            default:  cfg_rdata = 32'h0000_0000;
        endcase
    end

endmodule
