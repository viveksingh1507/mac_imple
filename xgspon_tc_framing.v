module xgspon_tc_framing #(
    parameter DATA_W = 64,
    parameter ALLOC_ID_W = 12
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  in_valid,
    input  wire [DATA_W-1:0]     in_data,
    input  wire                  in_sop,
    input  wire                  in_eop,
    output wire                  in_ready,
    output reg                   bwmap_valid,
    output reg [ALLOC_ID_W-1:0]  bwmap_alloc_id,
    output reg [15:0]            bwmap_grant_start,
    output reg [15:0]            bwmap_grant_len,
    output reg                   ploam_valid,
    output reg [47:0]            ploam_msg,
    output reg                   gem_valid,
    output reg [DATA_W-1:0]      gem_data,
    output reg                   gem_sop,
    output reg                   gem_eop,
    input  wire                  out_ready
);
    localparam [2:0] S_PSB=0,S_HLEND=1,S_BWMAP=2,S_PLOAM=3,S_XGEM=4;
    reg [2:0] st;
    reg [7:0] bw_left, gem_left;
    assign in_ready = out_ready;

    always @(posedge clk or negedge rst_n) begin
      if(!rst_n) begin st<=S_PSB; bw_left<=0; gem_left<=0; bwmap_valid<=0; ploam_valid<=0; gem_valid<=0; gem_sop<=0; gem_eop<=0; end
      else begin
        bwmap_valid<=0; ploam_valid<=0; gem_valid<=0; gem_sop<=0; gem_eop<=0;
        if(in_valid && out_ready) begin
          case(st)
            S_PSB: begin
              // placeholder PSBd marker check (full CRC/HEC omitted)
              if(in_sop) st <= S_HLEND;
            end
            S_HLEND: begin
              // HLend abstraction: word packs section lengths
              bw_left  <= in_data[55:48];
              gem_left <= in_data[47:40];
              st <= (in_data[63]) ? S_BWMAP : S_XGEM;
            end
            S_BWMAP: begin
              bwmap_valid <= 1'b1;
              bwmap_alloc_id <= in_data[63 -: ALLOC_ID_W];
              bwmap_grant_start <= in_data[47:32];
              bwmap_grant_len   <= in_data[31:16];
              if(bw_left!=0) bw_left <= bw_left-1;
              if(bw_left==1) st <= (gem_left!=0)?S_XGEM:S_PLOAM;
            end
            S_PLOAM: begin
              ploam_valid <= 1'b1;
              ploam_msg   <= in_data[47:0];
              st <= (gem_left!=0)?S_XGEM:S_PSB;
            end
            S_XGEM: begin
              gem_valid <= 1'b1;
              gem_data  <= in_data;
              gem_sop   <= (gem_left==in_data[47:40]);
              gem_eop   <= (gem_left==1) || in_eop;
              if(gem_left!=0) gem_left <= gem_left-1;
              if((gem_left==1)||in_eop) st <= S_PSB;
            end
          endcase
        end
      end
    end
endmodule
