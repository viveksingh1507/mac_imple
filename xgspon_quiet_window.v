module xgspon_quiet_window(
    input wire clk, input wire rst_n,
    input wire window_start,
    input wire [15:0] window_len,
    input wire sn_response_due,
    output reg window_active,
    output wire sn_tx_allowed
);
    reg [15:0] cnt;
    assign sn_tx_allowed = window_active && sn_response_due;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin window_active<=0; cnt<=0; end
        else begin
            if(window_start) begin window_active<=1'b1; cnt<=window_len; end
            else if(window_active) begin
                if(cnt==0) window_active<=1'b0;
                else cnt<=cnt-16'd1;
            end
        end
    end
endmodule
