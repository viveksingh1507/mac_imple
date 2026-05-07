module xgspon_ds_parser #(
    parameter GEM_DATA_W = 64,
    parameter PORT_ID_W  = 12,
    parameter ALLOC_ID_W = 12,
    parameter WORDS_PER_DS_FRAME = 64
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   ds_valid,
    input  wire [GEM_DATA_W-1:0]  ds_data,
    input  wire                   ds_sop,
    input  wire                   ds_eop,
    input  wire [2:0]             ds_empty,
    output wire                   ds_ready,

    output reg                    bwmap_valid,
    output reg [ALLOC_ID_W-1:0]   bwmap_alloc_id,
    output reg [15:0]             bwmap_grant_start,
    output reg [15:0]             bwmap_grant_len,
    output reg                    bwmap_last,

    output reg                    gem_valid,
    output reg [GEM_DATA_W-1:0]   gem_data,
    output reg                    gem_sop,
    output reg                    gem_eop,
    output reg [PORT_ID_W-1:0]    gem_port_id,
    output reg [11:0]             gem_len,
    input  wire                   gem_ready,

    output reg                    ploam_valid,
    output reg [47:0]             ploam_msg
);

    localparam [1:0] ST_HDR   = 2'd0;
    localparam [1:0] ST_BWMAP = 2'd1;
    localparam [1:0] ST_PLOAM = 2'd2;
    localparam [1:0] ST_GEM   = 2'd3;

    reg [1:0] state;
    reg [7:0] bwmap_words_left;
    reg [7:0] gem_words_left;

    wire [1:0] frame_type = ds_data[63:62];

    assign ds_ready = (state != ST_GEM) ? 1'b1 : gem_ready;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state            <= ST_HDR;
            bwmap_words_left <= 8'd0;
            gem_words_left   <= 8'd0;
            bwmap_valid      <= 1'b0;
            bwmap_alloc_id   <= '0;
            bwmap_grant_start<= '0;
            bwmap_grant_len  <= '0;
            bwmap_last       <= 1'b0;
            gem_valid        <= 1'b0;
            gem_data         <= '0;
            gem_sop          <= 1'b0;
            gem_eop          <= 1'b0;
            gem_port_id      <= '0;
            gem_len          <= '0;
            ploam_valid      <= 1'b0;
            ploam_msg        <= '0;
        end else begin
            bwmap_valid <= 1'b0;
            gem_valid   <= 1'b0;
            gem_sop     <= 1'b0;
            gem_eop     <= 1'b0;
            ploam_valid <= 1'b0;

            if (ds_valid && ds_ready) begin
                if (ds_sop) begin
                    state <= ST_HDR;
                end

                case (state)
                    ST_HDR: begin
                        // Simplified framing marker:
                        // [63:62] type: 00=GEM only, 01=BWmap, 10=PLOAM, 11=mixed
                        bwmap_words_left <= ds_data[55:48];
                        gem_words_left   <= ds_data[47:40];

                        if (frame_type == 2'b01) state <= ST_BWMAP;
                        else if (frame_type == 2'b10) state <= ST_PLOAM;
                        else if (frame_type == 2'b00) state <= ST_GEM;
                        else state <= ST_BWMAP;
                    end

                    ST_BWMAP: begin
                        bwmap_valid       <= 1'b1;
                        bwmap_alloc_id    <= ds_data[63 -: ALLOC_ID_W];
                        bwmap_grant_start <= ds_data[47:32];
                        bwmap_grant_len   <= ds_data[31:16];
                        bwmap_last        <= (bwmap_words_left == 8'd1);

                        if (bwmap_words_left != 0)
                            bwmap_words_left <= bwmap_words_left - 8'd1;

                        if (bwmap_words_left == 8'd1) begin
                            if (gem_words_left != 0)
                                state <= ST_GEM;
                            else
                                state <= ST_HDR;
                        end
                    end

                    ST_PLOAM: begin
                        ploam_valid <= 1'b1;
                        ploam_msg   <= ds_data[47:0];
                        state       <= (gem_words_left != 0) ? ST_GEM : ST_HDR;
                    end

                    ST_GEM: begin
                        if (gem_ready) begin
                            gem_valid   <= 1'b1;
                            gem_data    <= ds_data;
                            gem_sop     <= (gem_words_left == ds_data[47:40]);
                            gem_eop     <= (gem_words_left == 8'd1) || ds_eop;
                            gem_port_id <= ds_data[59 -: PORT_ID_W];
                            gem_len     <= ds_data[11:0];

                            if (gem_words_left != 0)
                                gem_words_left <= gem_words_left - 8'd1;

                            if ((gem_words_left == 8'd1) || ds_eop)
                                state <= ST_HDR;
                        end
                    end
                endcase
            end
        end
    end

endmodule
