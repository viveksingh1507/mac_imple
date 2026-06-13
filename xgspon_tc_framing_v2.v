module xgspon_tc_framing_v2 #(
    parameter DATA_W       = 64,
    parameter ALLOC_ID_W   = 12,
    parameter PORT_ID_W    = 12
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  frame_lock,
    input  wire                  frame_start,
    input  wire                  in_valid,
    input  wire [DATA_W-1:0]     in_data,
    input  wire                  in_sop,
    input  wire                  in_eop,
    output wire                  in_ready,
    output reg                   bwmap_valid,
    output reg [ALLOC_ID_W-1:0]  bwmap_alloc_id,
    output reg [15:0]            bwmap_grant_start,
    output reg [15:0]            bwmap_grant_len,
    output reg                   bwmap_last,
    output reg                   ploam_valid,
    output reg [47:0]            ploam_msg,
    output reg                   gem_valid,
    output reg [DATA_W-1:0]      gem_data,
    output reg                   gem_sop,
    output reg                   gem_eop,
    output reg [PORT_ID_W-1:0]   gem_port_id,
    input  wire                  out_ready
);
    localparam [2:0] ST_IDLE=3'd0, ST_HLEND=3'd1, ST_BWMAP=3'd2, ST_PLOAM=3'd3, ST_XGEM=3'd4;
    reg [2:0] state;
    reg [7:0] bwmap_words, ploam_words, gem_words;
    reg [7:0] bwmap_count, ploam_count, gem_count;
    assign in_ready = out_ready;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            bwmap_valid <= 1'b0; ploam_valid <= 1'b0; gem_valid <= 1'b0;
            gem_sop <= 1'b0; gem_eop <= 1'b0;
            bwmap_alloc_id <= {ALLOC_ID_W{1'b0}}; bwmap_grant_start<=16'd0; bwmap_grant_len<=16'd0; bwmap_last<=1'b0;
            ploam_msg <= 48'd0; gem_data <= {DATA_W{1'b0}}; gem_port_id <= {PORT_ID_W{1'b0}};
            bwmap_words<=8'd0; ploam_words<=8'd0; gem_words<=8'd0;
            bwmap_count<=8'd0; ploam_count<=8'd0; gem_count<=8'd0;
        end else begin
            bwmap_valid <= 1'b0; ploam_valid <= 1'b0; gem_valid <= 1'b0;
            gem_sop <= 1'b0; gem_eop <= 1'b0; bwmap_last <= 1'b0;

            if (frame_start) state <= ST_HLEND;

            if (frame_lock && in_valid && out_ready) begin
                case (state)
                    ST_HLEND: begin
                        bwmap_words <= in_data[63:56];
                        ploam_words <= in_data[55:48];
                        gem_words   <= in_data[47:40];
                        bwmap_count <= 8'd0; ploam_count <= 8'd0; gem_count <= 8'd0;
                        if (in_data[63:56] != 8'd0) state <= ST_BWMAP;
                        else if (in_data[55:48] != 8'd0) state <= ST_PLOAM;
                        else state <= ST_XGEM;
                    end
                    ST_BWMAP: begin
                        bwmap_valid <= 1'b1;
                        bwmap_alloc_id <= in_data[63:52];
                        bwmap_grant_start <= in_data[47:32];
                        bwmap_grant_len <= in_data[31:16];
                        bwmap_count <= bwmap_count + 8'd1;
                        if ((bwmap_count + 8'd1) >= bwmap_words) begin
                            bwmap_last <= 1'b1;
                            if (ploam_words != 8'd0) state <= ST_PLOAM;
                            else state <= ST_XGEM;
                        end
                    end
                    ST_PLOAM: begin
                        ploam_valid <= 1'b1;
                        ploam_msg <= in_data[47:0];
                        ploam_count <= ploam_count + 8'd1;
                        if ((ploam_count + 8'd1) >= ploam_words) state <= ST_XGEM;
                    end
                    ST_XGEM: begin
                        gem_valid <= 1'b1;
                        gem_data <= in_data;
                        gem_port_id <= in_data[63:52];
                        gem_sop <= (gem_count == 8'd0);
                        gem_count <= gem_count + 8'd1;
                        if ((gem_count + 8'd1) >= gem_words || in_eop) begin
                            gem_eop <= 1'b1;
                            state <= ST_IDLE;
                        end
                    end
                    default: state <= ST_IDLE;
                endcase
            end
        end
    end
endmodule
