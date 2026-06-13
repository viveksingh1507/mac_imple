module xgspon_ploamu_tx #(
    parameter DATA_W=64,
    parameter ONU_ID_W=10
)(
    input wire clk, input wire rst_n,
    input wire send_sn, input wire send_reg_ack, input wire send_ranging_resp, input wire send_dbru, input wire send_alarm, input wire send_dying_gasp,
    input wire [ONU_ID_W-1:0] onu_id,
    input wire [31:0] serial_number,
    input wire [15:0] dbru_value,
    output reg valid,
    output reg [DATA_W-1:0] data,
    output reg sop,
    output reg eop,
    input wire ready
);
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin valid<=0; data<={DATA_W{1'b0}}; sop<=0; eop<=0; end
        else begin
            valid<=0; sop<=0; eop<=0;
            if(ready) begin
                if(send_sn) begin valid<=1; sop<=1; eop<=1; data<={onu_id,8'h11,serial_number,14'd0}; end
                else if(send_reg_ack) begin valid<=1; sop<=1; eop<=1; data<={onu_id,8'h12,46'd0}; end
                else if(send_ranging_resp) begin valid<=1; sop<=1; eop<=1; data<={onu_id,8'h13,46'd0}; end
                else if(send_dbru) begin valid<=1; sop<=1; eop<=1; data<={onu_id,8'h14,dbru_value,30'd0}; end
                else if(send_alarm) begin valid<=1; sop<=1; eop<=1; data<={onu_id,8'h15,46'd0}; end
                else if(send_dying_gasp) begin valid<=1; sop<=1; eop<=1; data<={onu_id,8'h16,46'd0}; end
            end
        end
    end
endmodule
