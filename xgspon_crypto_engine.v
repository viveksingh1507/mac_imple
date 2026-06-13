module xgspon_crypto_engine #(
    parameter DATA_W = 64
)(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 enable,
    input  wire [127:0]         key,
    input  wire [63:0]          iv,
    input  wire                 in_valid,
    input  wire [DATA_W-1:0]    in_data,
    input  wire                 in_sop,
    input  wire                 in_eop,
    output wire                 in_ready,
    output reg                  out_valid,
    output reg [DATA_W-1:0]     out_data,
    output reg                  out_sop,
    output reg                  out_eop,
    input  wire                 out_ready
);
reg [127:0] state;
integer i;
reg [63:0] ks;
assign in_ready = out_ready;
always @(*) begin
    ks = state[63:0];
    for (i=0;i<4;i=i+1)
        ks = {ks[62:0], ks[63]^ks[62]^ks[60]^ks[59]};
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        state <= 128'h1;
        out_valid<=0; out_data<='0; out_sop<=0; out_eop<=0;
    end else begin
        out_valid<=0; out_sop<=0; out_eop<=0;
        if(in_valid && out_ready) begin
            if(in_sop) state <= key ^ {iv,iv};
            else state <= {state[126:0], state[127]^state[95]^state[63]^state[31]} ^ {64'd0, iv};
            out_valid <= 1'b1;
            out_sop <= in_sop;
            out_eop <= in_eop;
            out_data <= enable ? (in_data ^ ks) : in_data;
        end
    end
end
endmodule
