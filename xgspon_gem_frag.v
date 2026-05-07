module xgspon_gem_frag #(
    parameter GEM_DATA_W = 64,
    parameter MAX_PAYLOAD_BYTES = 48
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  in_valid,
    input  wire [GEM_DATA_W-1:0] in_data,
    input  wire                  in_sop,
    input  wire                  in_eop,
    output wire                  in_ready,
    output reg                   out_valid,
    output reg [GEM_DATA_W-1:0]  out_data,
    output reg                   out_sop,
    output reg                   out_eop,
    output reg                   out_frag,
    input  wire                  out_ready
);
    reg [7:0] word_count;
    assign in_ready = out_ready;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin out_valid<=0; out_data<='0; out_sop<=0; out_eop<=0; out_frag<=0; word_count<=0; end
        else begin
            out_valid<=0; out_sop<=0; out_eop<=0; out_frag<=0;
            if(in_valid && out_ready) begin
                out_valid<=1; out_data<=in_data; out_sop<=in_sop;
                if(in_sop) word_count<=0; else word_count<=word_count+1;
                out_frag <= (word_count >= (MAX_PAYLOAD_BYTES/(GEM_DATA_W/8))-1) && !in_eop;
                out_eop  <= in_eop || out_frag;
            end
        end
    end
endmodule
