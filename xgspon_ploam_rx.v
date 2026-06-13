module xgspon_ploam_rx #(
    parameter ONU_ID_W = 10,
    parameter PLOAM_W  = 48
)(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 ploam_valid,
    input  wire [PLOAM_W-1:0]   ploam_msg,
    input  wire [ONU_ID_W-1:0]  local_onu_id,
    input  wire                 onu_id_valid,
    output reg                  msg_accept,
    output reg                  integrity_ok,
    output reg [7:0]            opcode,
    output reg [31:0]           payload,
    output reg                  sn_req,
    output reg                  assign_onu_id,
    output reg                  ranging_grant,
    output reg                  eqd_update,
    output reg                  key_control,
    output reg                  popup_request,
    output reg                  deactivate,
    output reg                  emergency_stop,
    output reg [ONU_ID_W-1:0]   target_onu_id
);
    localparam [ONU_ID_W-1:0] ONU_ID_BCAST = {ONU_ID_W{1'b1}};

    wire [ONU_ID_W-1:0] msg_onu_id = ploam_msg[47 -: ONU_ID_W];
    wire [7:0]          msg_opcode = ploam_msg[37:30];
    wire [31:0]         msg_payload = ploam_msg[31:0];
    wire [7:0]          msg_check = ploam_msg[7:0];
    wire [7:0]          calc_check = ^ploam_msg[PLOAM_W-1:8] ? 8'hA5 : 8'h5A;
    wire                id_match = (msg_onu_id == ONU_ID_BCAST) || (onu_id_valid && (msg_onu_id == local_onu_id));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            msg_accept <= 1'b0; integrity_ok <= 1'b0; opcode <= 8'd0; payload <= 32'd0;
            sn_req <= 1'b0; assign_onu_id <= 1'b0; ranging_grant <= 1'b0; eqd_update <= 1'b0;
            key_control <= 1'b0; popup_request <= 1'b0; deactivate <= 1'b0; emergency_stop <= 1'b0;
            target_onu_id <= {ONU_ID_W{1'b0}};
        end else begin
            msg_accept <= 1'b0; sn_req <= 1'b0; assign_onu_id <= 1'b0; ranging_grant <= 1'b0;
            eqd_update <= 1'b0; key_control <= 1'b0; popup_request <= 1'b0; deactivate <= 1'b0; emergency_stop <= 1'b0;
            if (ploam_valid) begin
                integrity_ok <= (msg_check == calc_check);
                opcode <= msg_opcode;
                payload <= msg_payload;
                target_onu_id <= msg_onu_id;
                msg_accept <= id_match && (msg_check == calc_check);
                if (id_match && (msg_check == calc_check)) begin
                    case (msg_opcode)
                        8'h01: sn_req <= 1'b1;
                        8'h02: assign_onu_id <= 1'b1;
                        8'h03: ranging_grant <= 1'b1;
                        8'h04: eqd_update <= 1'b1;
                        8'h05: key_control <= 1'b1;
                        8'h06: popup_request <= 1'b1;
                        8'h07: deactivate <= 1'b1;
                        8'h08: emergency_stop <= 1'b1;
                        default: ;
                    endcase
                end
            end
        end
    end
endmodule
