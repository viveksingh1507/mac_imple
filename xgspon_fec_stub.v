module xgspon_fec_stub #(
    parameter DATA_W = 64
)(
    input  wire              clk,
    input  wire              rst_n,
    input  wire              encode,
    input  wire              in_valid,
    input  wire [DATA_W-1:0] in_data,
    input  wire              in_sop,
    input  wire              in_eop,
    output wire              in_ready,
    output reg               out_valid,
    output reg [DATA_W-1:0]  out_data,
    output reg               out_sop,
    output reg               out_eop,
    output reg [7:0]         out_parity,
    input  wire              out_ready
);
    assign in_ready = out_ready;
    wire [7:0] parity = ^in_data;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin out_valid<=0; out_data<='0; out_sop<=0; out_eop<=0; out_parity<=0; end
        else begin
            out_valid<=0; out_sop<=0; out_eop<=0;
            if(in_valid && out_ready) begin
                out_valid<=1'b1;
                out_data <= in_data;
                out_sop  <= in_sop;
                out_eop  <= in_eop;
                out_parity <= encode ? parity : 8'h00;
            end
        end
    end
endmodule
