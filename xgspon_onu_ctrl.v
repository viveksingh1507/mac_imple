module xgspon_onu_ctrl #(
    parameter ONU_ID_W = 10
)(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 frame_lock,
    input  wire                 sn_request,
    input  wire                 sn_tx_allowed,
    input  wire                 onu_id_assigned,
    input  wire                 ranging_grant,
    input  wire                 eqd_valid,
    input  wire                 key_switch,
    input  wire                 popup_request,
    input  wire                 deactivate,
    input  wire                 emergency_stop,
    input  wire                 sn_timeout,
    input  wire                 ranging_timeout,
    input  wire                 ploam_timeout,
    input  wire                 popup_timeout,
    output reg                  tx_sn,
    output reg                  tx_ranging_resp,
    output reg                  registration_ack,
    output reg                  key_active,
    output reg [2:0]            onu_state
);
    localparam [2:0] O1_INITIAL=3'd0, O2_STANDBY=3'd1, O3_SERIAL=3'd2, O4_RANGING=3'd3,
                     O5_OPERATION=3'd4, O6_POPUP=3'd5, O7_EMERGENCY=3'd6;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            onu_state <= O1_INITIAL;
            tx_sn <= 1'b0; tx_ranging_resp <= 1'b0; registration_ack <= 1'b0; key_active <= 1'b0;
        end else begin
            tx_sn <= 1'b0; tx_ranging_resp <= 1'b0; registration_ack <= 1'b0;
            if (emergency_stop) begin
                onu_state <= O7_EMERGENCY;
                key_active <= 1'b0;
            end else if (deactivate) begin
                onu_state <= O2_STANDBY;
                key_active <= 1'b0;
            end else begin
                case (onu_state)
                    O1_INITIAL: begin
                        key_active <= 1'b0;
                        if (frame_lock) onu_state <= O2_STANDBY;
                    end
                    O2_STANDBY: begin
                        if (!frame_lock || ploam_timeout) onu_state <= O1_INITIAL;
                        else if (popup_request) onu_state <= O6_POPUP;
                        else if (sn_request) onu_state <= O3_SERIAL;
                    end
                    O3_SERIAL: begin
                        if (sn_tx_allowed) tx_sn <= 1'b1;
                        if (sn_timeout) onu_state <= O2_STANDBY;
                        else if (onu_id_assigned) begin
                            registration_ack <= 1'b1;
                            onu_state <= O4_RANGING;
                        end
                    end
                    O4_RANGING: begin
                        if (ranging_grant) tx_ranging_resp <= 1'b1;
                        if (ranging_timeout) onu_state <= O2_STANDBY;
                        else if (eqd_valid) onu_state <= O5_OPERATION;
                    end
                    O5_OPERATION: begin
                        if (!frame_lock) onu_state <= O6_POPUP;
                        else if (popup_request) onu_state <= O6_POPUP;
                        else if (key_switch) key_active <= 1'b1;
                    end
                    O6_POPUP: begin
                        key_active <= 1'b0;
                        if (popup_timeout) onu_state <= O2_STANDBY;
                        else if (frame_lock && sn_request) onu_state <= O3_SERIAL;
                    end
                    O7_EMERGENCY: begin
                        key_active <= 1'b0;
                        if (frame_lock && !emergency_stop) onu_state <= O2_STANDBY;
                    end
                    default: onu_state <= O1_INITIAL;
                endcase
            end
        end
    end
endmodule
