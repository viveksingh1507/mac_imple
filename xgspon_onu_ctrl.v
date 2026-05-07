module xgspon_onu_ctrl #(
    parameter ONU_ID_W = 10,
    parameter SERIAL_W = 32
)(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 ploam_valid,
    input  wire [47:0]          ploam_msg,
    input  wire                 rx_sn_req,
    input  wire                 rx_ranging_grant,
    input  wire                 rx_key_switch,
    input  wire [ONU_ID_W-1:0]  rx_assigned_onu_id,
    input  wire [127:0]         key_in,
    input  wire                 key_in_valid,
    output reg                  tx_sn,
    output reg                  tx_ranging_resp,
    output reg                  key_active,
    output reg [ONU_ID_W-1:0]   onu_id,
    output reg [2:0]            onu_state
);

    localparam [2:0] ST_O1_INIT       = 3'd0;
    localparam [2:0] ST_O2_STANDBY    = 3'd1;
    localparam [2:0] ST_O3_SERIAL_TX  = 3'd2;
    localparam [2:0] ST_O4_RANGING    = 3'd3;
    localparam [2:0] ST_O5_OPERATION  = 3'd4;

    reg [127:0] active_key;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            onu_state        <= ST_O1_INIT;
            tx_sn            <= 1'b0;
            tx_ranging_resp  <= 1'b0;
            key_active       <= 1'b0;
            onu_id           <= {ONU_ID_W{1'b0}};
            active_key       <= 128'd0;
        end else begin
            tx_sn           <= 1'b0;
            tx_ranging_resp <= 1'b0;

            case (onu_state)
                ST_O1_INIT: begin
                    onu_state <= ST_O2_STANDBY;
                end

                ST_O2_STANDBY: begin
                    if (rx_sn_req || (ploam_valid && ploam_msg[47:40] == 8'h01)) begin
                        tx_sn    <= 1'b1;
                        onu_state <= ST_O3_SERIAL_TX;
                    end
                end

                ST_O3_SERIAL_TX: begin
                    if (rx_ranging_grant || (ploam_valid && ploam_msg[47:40] == 8'h02)) begin
                        tx_ranging_resp <= 1'b1;
                        onu_state       <= ST_O4_RANGING;
                    end
                end

                ST_O4_RANGING: begin
                    onu_id <= rx_assigned_onu_id;
                    if (key_in_valid) begin
                        active_key <= key_in;
                        key_active <= 1'b1;
                    end
                    onu_state <= ST_O5_OPERATION;
                end

                ST_O5_OPERATION: begin
                    if (rx_key_switch || (ploam_valid && ploam_msg[47:40] == 8'h03)) begin
                        if (key_in_valid) begin
                            active_key <= key_in;
                            key_active <= 1'b1;
                        end
                    end
                end

                default: onu_state <= ST_O1_INIT;
            endcase
        end
    end

endmodule
