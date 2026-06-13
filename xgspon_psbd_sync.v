module xgspon_psbd_sync #(
    parameter DATA_W = 64,
    parameter PSBD_PATTERN = 64'hB6AB31E0543F9D21,
    parameter LOCK_THRESHOLD = 4,
    parameter LOSS_THRESHOLD = 4
)(
    input  wire                  clk,
    input  wire                  rst_n,

    input  wire                  in_valid,
    input  wire [DATA_W-1:0]     in_data,
    input  wire                  in_sop,
    input  wire                  in_eop,

    output wire                  in_ready,

    output reg                   sync_locked,
    output reg                   frame_start,
    output reg [31:0]            superframe_cnt,

    output reg                   out_valid,
    output reg [DATA_W-1:0]      out_data,
    output reg                   out_sop,
    output reg                   out_eop,

    input  wire                  out_ready
);

    localparam [1:0]
        ST_HUNT = 2'd0,
        ST_PRELOCK = 2'd1,
        ST_LOCKED = 2'd2;

    reg [1:0] state;

    reg [3:0] lock_cnt;
    reg [3:0] loss_cnt;

    wire psbd_match;

    assign psbd_match = (in_data == PSBD_PATTERN);

    assign in_ready = out_ready;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin

            state           <= ST_HUNT;

            sync_locked     <= 1'b0;
            frame_start     <= 1'b0;

            lock_cnt        <= 4'd0;
            loss_cnt        <= 4'd0;

            superframe_cnt  <= 32'd0;

            out_valid       <= 1'b0;
            out_data        <= {DATA_W{1'b0}};
            out_sop         <= 1'b0;
            out_eop         <= 1'b0;

        end else begin

            frame_start <= 1'b0;

            out_valid <= 1'b0;
            out_sop   <= 1'b0;
            out_eop   <= 1'b0;

            if (in_valid && out_ready) begin

                case (state)

                    ST_HUNT: begin

                        sync_locked <= 1'b0;

                        if (psbd_match) begin
                            lock_cnt <= 4'd1;
                            state <= ST_PRELOCK;
                        end
                    end

                    ST_PRELOCK: begin

                        if (psbd_match) begin

                            if (lock_cnt == LOCK_THRESHOLD-1) begin

                                sync_locked <= 1'b1;
                                frame_start <= 1'b1;

                                state <= ST_LOCKED;

                                superframe_cnt <= superframe_cnt + 1'b1;

                            end else begin
                                lock_cnt <= lock_cnt + 1'b1;
                            end

                        end else begin

                            lock_cnt <= 4'd0;
                            state <= ST_HUNT;

                        end
                    end

                    ST_LOCKED: begin

                        if (psbd_match) begin

                            frame_start <= 1'b1;

                            loss_cnt <= 4'd0;

                            superframe_cnt <= superframe_cnt + 1'b1;

                        end else begin

                            if (loss_cnt == LOSS_THRESHOLD-1) begin

                                sync_locked <= 1'b0;
                                state <= ST_HUNT;

                            end else begin
                                loss_cnt <= loss_cnt + 1'b1;
                            end
                        end

                        out_valid <= 1'b1;
                        out_data  <= in_data;
                        out_sop   <= in_sop;
                        out_eop   <= in_eop;

                    end

                    default: begin
                        state <= ST_HUNT;
                    end

                endcase
            end
        end
    end

endmodule
