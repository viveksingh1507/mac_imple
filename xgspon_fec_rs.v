module xgspon_fec_rs #(
    parameter DATA_W = 64
)(
    input  wire              clk,
    input  wire              rst_n,
    input  wire              encode_mode,
    input  wire              in_valid,
    input  wire [DATA_W-1:0] in_data,
    input  wire              in_sop,
    input  wire              in_eop,
    input  wire [7:0]        in_parity,
    output wire              in_ready,
    output reg               out_valid,
    output reg [DATA_W-1:0]  out_data,
    output reg               out_sop,
    output reg               out_eop,
    output reg [7:0]         out_parity,
    output reg               uncorrectable,
    input  wire              out_ready
);
wire [7:0] calc_p;
assign calc_p = {^in_data[63:56],^in_data[55:48],^in_data[47:40],^in_data[39:32],^in_data[31:24],^in_data[23:16],^in_data[15:8],^in_data[7:0]};
assign in_ready = out_ready;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin out_valid<=0; out_data<='0; out_sop<=0; out_eop<=0; out_parity<=0; uncorrectable<=0; end
    else begin
        out_valid<=0; out_sop<=0; out_eop<=0; uncorrectable<=0;
        if(in_valid && out_ready) begin
            out_valid<=1'b1; out_sop<=in_sop; out_eop<=in_eop;
            out_data<=in_data;
            if(encode_mode) begin
                out_parity<=calc_p;
            end else begin
                out_parity<=in_parity;
                uncorrectable <= (calc_p != in_parity);
            end
        end
    end
end
endmodule
