module xgspon_sn_filter #(
    parameter VENDOR_ID = 32'h4F50454E,
    parameter ONU_SN    = 32'h00000001
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        sn_req,
    input  wire [31:0] vendor_mask,
    input  wire [31:0] sn_mask,
    input  wire [7:0]  random_seed,
    output reg         sn_match,
    output reg         sn_response_due,
    output reg [7:0]   random_delay
);
    reg [7:0] delay_cnt;
    wire match_now = ((VENDOR_ID & vendor_mask) == (VENDOR_ID & vendor_mask)) && ((ONU_SN & sn_mask) == (ONU_SN & sn_mask));
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin sn_match<=0; sn_response_due<=0; random_delay<=0; delay_cnt<=0; end
        else begin
            sn_response_due <= 1'b0;
            if (sn_req && match_now) begin
                sn_match <= 1'b1;
                random_delay <= random_seed ^ ONU_SN[7:0] ^ VENDOR_ID[7:0];
                delay_cnt <= random_seed ^ ONU_SN[7:0] ^ VENDOR_ID[7:0];
            end else if (sn_match) begin
                if (delay_cnt == 8'd0) begin sn_response_due <= 1'b1; sn_match <= 1'b0; end
                else delay_cnt <= delay_cnt - 8'd1;
            end
        end
    end
endmodule
