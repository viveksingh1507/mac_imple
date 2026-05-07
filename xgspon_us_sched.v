module xgspon_us_sched #(
    parameter GEM_DATA_W = 64,
    parameter TCONT_NUM  = 4,
    parameter ALLOC_ID_W = 12,
    parameter LOCAL_ALLOC_ID0 = 12'h100,
    parameter LOCAL_ALLOC_ID1 = 12'h101,
    parameter LOCAL_ALLOC_ID2 = 12'h102,
    parameter LOCAL_ALLOC_ID3 = 12'h103
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   bwmap_valid,
    input  wire [ALLOC_ID_W-1:0]  bwmap_alloc_id,
    input  wire [15:0]            bwmap_grant_start,
    input  wire [15:0]            bwmap_grant_len,
    input  wire                   bwmap_last,
    input  wire                   svc_tx_valid,
    input  wire [GEM_DATA_W-1:0]  svc_tx_data,
    input  wire                   svc_tx_sop,
    input  wire                   svc_tx_eop,
    output wire                   svc_tx_ready,
    output reg                    gem_valid,
    output reg [GEM_DATA_W-1:0]   gem_data,
    output reg                    gem_sop,
    output reg                    gem_eop,
    output reg [2:0]              gem_empty,
    input  wire                   gem_ready,
    output wire                   grant_active,
    output reg [1:0]              active_tcont,
    input  wire [15:0]            tcont0_buf_occ,
    input  wire [15:0]            tcont1_buf_occ,
    input  wire [15:0]            tcont2_buf_occ,
    input  wire [15:0]            tcont3_buf_occ
);

    reg [15:0] grant_words_left;
    reg [15:0] start_countdown;
    reg        grant_open;
    reg [15:0] dba_credit [0:3];
    integer i;
    localparam integer WORD_BYTES = (GEM_DATA_W/8);

    assign svc_tx_ready = grant_open && (start_countdown == 16'd0) && gem_ready && (dba_credit[active_tcont] != 0);
    assign grant_active = grant_open;

    function [1:0] alloc_to_tcont;
        input [ALLOC_ID_W-1:0] aid;
        begin
            if (aid == LOCAL_ALLOC_ID0) alloc_to_tcont = 2'd0;
            else if (aid == LOCAL_ALLOC_ID1) alloc_to_tcont = 2'd1;
            else if (aid == LOCAL_ALLOC_ID2) alloc_to_tcont = 2'd2;
            else alloc_to_tcont = 2'd3;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            grant_words_left <= 16'd0;
            start_countdown  <= 16'd0;
            grant_open       <= 1'b0;
            active_tcont     <= 2'd0;
            gem_valid        <= 1'b0;
            gem_data         <= '0;
            gem_sop          <= 1'b0;
            gem_eop          <= 1'b0;
            gem_empty        <= 3'd0;
            for (i=0;i<4;i=i+1) dba_credit[i] <= 16'd0;
        end else begin
            gem_valid <= 1'b0; gem_sop <= 1'b0; gem_eop <= 1'b0; gem_empty <= 3'd0;

            // update DBA credits from current queue occupancy snapshot
            dba_credit[0] <= tcont0_buf_occ;
            dba_credit[1] <= tcont1_buf_occ;
            dba_credit[2] <= tcont2_buf_occ;
            dba_credit[3] <= tcont3_buf_occ;

            if (bwmap_valid) begin
                active_tcont     <= alloc_to_tcont(bwmap_alloc_id);
                grant_open       <= 1'b1;
                start_countdown  <= bwmap_grant_start;
                grant_words_left <= (bwmap_grant_len / WORD_BYTES);
            end

            if (grant_open && (start_countdown != 16'd0))
                start_countdown <= start_countdown - 16'd1;

            if (grant_open && (start_countdown == 16'd0) && svc_tx_valid && gem_ready && (grant_words_left != 0) && (dba_credit[active_tcont] != 0)) begin
                gem_valid <= 1'b1;
                gem_data  <= svc_tx_data;
                gem_sop   <= svc_tx_sop;
                gem_eop   <= svc_tx_eop || (grant_words_left == 16'd1);

                grant_words_left <= grant_words_left - 16'd1;
                dba_credit[active_tcont] <= dba_credit[active_tcont] - 16'd1;
                if ((grant_words_left == 16'd1) || svc_tx_eop || (dba_credit[active_tcont] == 16'd1))
                    grant_open <= 1'b0;
            end
        end
    end

endmodule
