module xgspon_burst_timing #(
    parameter GEM_DATA_W = 64
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  grant_open,
    input  wire [15:0]           eq_delay_cycles,
    input  wire [7:0]            guard_time_cycles,
    input  wire [7:0]            preamble_cycles,
    input  wire [7:0]            delimiter_cycles,
    input  wire                  in_valid,
    input  wire [GEM_DATA_W-1:0] in_data,
    input  wire                  in_sop,
    input  wire                  in_eop,
    output wire                  in_ready,
    output reg                   out_valid,
    output reg [GEM_DATA_W-1:0]  out_data,
    output reg                   out_sop,
    output reg                   out_eop,
    input  wire                  out_ready
);

    localparam [2:0] ST_IDLE=3'd0, ST_EQ=3'd1, ST_GUARD=3'd2, ST_PREAMBLE=3'd3, ST_DELIM=3'd4, ST_DATA=3'd5;
    reg [2:0] state;
    reg [15:0] cnt;

    assign in_ready = (state == ST_DATA) && out_ready;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE; cnt <= 16'd0; out_valid <= 1'b0; out_data <= '0; out_sop <= 1'b0; out_eop <= 1'b0;
        end else begin
            out_valid <= 1'b0; out_sop <= 1'b0; out_eop <= 1'b0;
            case (state)
                ST_IDLE: if (grant_open) begin state <= ST_EQ; cnt <= eq_delay_cycles; end
                ST_EQ: begin if (cnt==0) begin state<=ST_GUARD; cnt<=guard_time_cycles; end else cnt<=cnt-16'd1; end
                ST_GUARD: begin if (cnt==0) begin state<=ST_PREAMBLE; cnt<=preamble_cycles; end else cnt<=cnt-16'd1; end
                ST_PREAMBLE: begin
                    if (out_ready) begin out_valid<=1'b1; out_data<={GEM_DATA_W/8{8'h55}}; if (cnt==0) begin state<=ST_DELIM; cnt<=delimiter_cycles; end else cnt<=cnt-16'd1; end
                end
                ST_DELIM: begin
                    if (out_ready) begin out_valid<=1'b1; out_data<={56'h0,8'hD5}; if (cnt==0) state<=ST_DATA; else cnt<=cnt-16'd1; end
                end
                ST_DATA: begin
                    if (in_valid && out_ready) begin out_valid<=1'b1; out_data<=in_data; out_sop<=in_sop; out_eop<=in_eop; if (in_eop) state<=ST_IDLE; end
                end
                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule
