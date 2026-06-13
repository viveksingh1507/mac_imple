module xgspon_popup_controller(
    input wire clk, input wire rst_n,
    input wire loss_of_sync,
    input wire popup_request,
    input wire ranging_done,
    output reg popup_active,
    output reg reentry_req
);
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin popup_active<=0; reentry_req<=0; end
        else begin
            reentry_req <= 1'b0;
            if(loss_of_sync || popup_request) begin popup_active<=1'b1; reentry_req<=1'b1; end
            else if(ranging_done) popup_active<=1'b0;
        end
    end
endmodule
