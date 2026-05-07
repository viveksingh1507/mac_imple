module xgspon_gem_reasm #(
    parameter GEM_DATA_W = 64
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  in_valid,
    input  wire [GEM_DATA_W-1:0] in_data,
    input  wire                  in_sop,
    input  wire                  in_eop,
    input  wire                  in_frag,
    output wire                  in_ready,
    output reg                   out_valid,
    output reg [GEM_DATA_W-1:0]  out_data,
    output reg                   out_sop,
    output reg                   out_eop,
    input  wire                  out_ready
);
    reg in_frame;
    assign in_ready = out_ready;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin out_valid<=0; out_data<='0; out_sop<=0; out_eop<=0; in_frame<=0; end
        else begin
            out_valid<=0; out_sop<=0; out_eop<=0;
            if(in_valid && out_ready) begin
                out_valid <= 1'b1;
                out_data  <= in_data;
                out_sop   <= in_sop && !in_frame;
                out_eop   <= in_eop && !in_frag;
                if(in_sop) in_frame <= 1'b1;
                if(in_eop && !in_frag) in_frame <= 1'b0;
            end
        end
    end
endmodule
