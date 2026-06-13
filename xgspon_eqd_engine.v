module xgspon_eqd_engine(
    input wire clk, input wire rst_n,
    input wire update_valid,
    input wire [15:0] coarse_eqd,
    input wire signed [7:0] fine_corr,
    output reg [15:0] eqd_value,
    output wire [15:0] grant_time_adjust
);
    assign grant_time_adjust = eqd_value;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) eqd_value <= 16'd0;
        else if(update_valid) eqd_value <= coarse_eqd + {{8{fine_corr[7]}}, fine_corr};
    end
endmodule
