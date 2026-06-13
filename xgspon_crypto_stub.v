module xgspon_crypto_stub #(
    parameter GEM_DATA_W = 64
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  enable,
    input  wire [127:0]          key,
    input  wire [63:0]           iv,
    input  wire                  in_valid,
    input  wire [GEM_DATA_W-1:0] din,
    input  wire                  in_sop,
    input  wire                  in_eop,
    output wire                  in_ready,
    output reg                   out_valid,
    output reg [GEM_DATA_W-1:0]  dout,
    output reg                   out_sop,
    output reg                   out_eop,
    input  wire                  out_ready
);

    reg [63:0] ctr;
    wire [63:0] ks64;

    assign ks64 = (ctr ^ key[63:0]) + {key[127:96], key[95:64]} ^ (ctr << 7) ^ (ctr >> 3);
    assign in_ready = out_ready;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ctr <= 64'd0;
            out_valid <= 1'b0;
            dout <= '0;
            out_sop <= 1'b0;
            out_eop <= 1'b0;
        end else begin
            out_valid <= 1'b0;
            out_sop   <= 1'b0;
            out_eop   <= 1'b0;

            if (in_valid && out_ready) begin
                if (in_sop)
                    ctr <= iv;
                else
                    ctr <= ctr + 64'd1;

                out_valid <= 1'b1;
                out_sop   <= in_sop;
                out_eop   <= in_eop;
                dout      <= enable ? (din ^ ks64) : din;
            end
        end
    end

endmodule
