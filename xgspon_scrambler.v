module xgspon_scrambler #(
    parameter DATA_W = 64,
    parameter SEED   = 58'h3
)(
    input  wire              clk,
    input  wire              rst_n,
    input  wire              enable,
    input  wire              in_valid,
    input  wire [DATA_W-1:0] in_data,
    input  wire              in_sop,
    input  wire              in_eop,
    output wire              in_ready,
    output reg               out_valid,
    output reg [DATA_W-1:0]  out_data,
    output reg               out_sop,
    output reg               out_eop,
    input  wire              out_ready
);
    reg [57:0] lfsr;
    integer i;
    reg [57:0] n_lfsr;
    reg [DATA_W-1:0] pn;

    assign in_ready = out_ready;

    always @(*) begin
        n_lfsr = lfsr;
        pn = {DATA_W{1'b0}};
        for (i=0; i<DATA_W; i=i+1) begin
            pn[i] = n_lfsr[0];
            n_lfsr = {n_lfsr[56:0], n_lfsr[57]^n_lfsr[38]};
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            lfsr<=SEED; out_valid<=0; out_data<='0; out_sop<=0; out_eop<=0;
        end else begin
            out_valid<=0; out_sop<=0; out_eop<=0;
            if(in_valid && out_ready) begin
                if(in_sop) lfsr <= SEED; else lfsr <= n_lfsr;
                out_valid <= 1'b1;
                out_data  <= enable ? (in_data ^ pn) : in_data;
                out_sop   <= in_sop;
                out_eop   <= in_eop;
            end
        end
    end
endmodule
