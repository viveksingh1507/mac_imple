module xgspon_xgem_engine_v2 #(
    parameter DATA_W        = 64,
    parameter PORT_ID_W     = 12,
    parameter MAX_FRAME_LEN = 4096,
    parameter MAX_FRAGMENT  = 2048
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  in_valid,
    input  wire [DATA_W-1:0]     in_data,
    input  wire                  in_sop,
    input  wire                  in_eop,
    input  wire [PORT_ID_W-1:0]  in_port_id,
    output wire                  in_ready,
    output reg                   out_valid,
    output reg [DATA_W-1:0]      out_data,
    output reg                   out_sop,
    output reg                   out_eop,
    output reg                   out_idle,
    output reg                   out_fragment,
    output reg [PORT_ID_W-1:0]   out_port_id,
    output reg [15:0]            out_payload_len,
    output reg [12:0]            out_hec,
    input  wire                  out_ready
);
localparam [2:0] ST_IDLE=3'd0, ST_HEADER=3'd1, ST_PAYLD=3'd2, ST_IDLEPKT=3'd3;
reg [2:0] state;
reg [15:0] payload_count, fragment_count;
reg fragment_active;
reg [31:0] xgem_header;
assign in_ready = out_ready;

function [12:0] calc_hec;
    input [31:0] hdr;
    integer i;
    reg [12:0] crc;
    begin
        crc = 13'h1FFF;
        for (i=31;i>=0;i=i-1) begin
            if (crc[12] ^ hdr[i]) crc = {crc[11:0],1'b0} ^ 13'h1CF5;
            else crc = {crc[11:0],1'b0};
        end
        calc_hec = crc;
    end
endfunction

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= ST_IDLE;
        out_valid <= 1'b0; out_data <= {DATA_W{1'b0}}; out_sop <= 1'b0; out_eop <= 1'b0;
        out_idle <= 1'b0; out_fragment <= 1'b0; out_port_id <= {PORT_ID_W{1'b0}};
        out_payload_len <= 16'd0; out_hec <= 13'd0; payload_count <= 16'd0; fragment_count <= 16'd0;
        fragment_active <= 1'b0; xgem_header <= 32'd0;
    end else begin
        out_valid <= 1'b0; out_sop <= 1'b0; out_eop <= 1'b0; out_idle <= 1'b0; out_fragment <= 1'b0;
        case(state)
            ST_IDLE: begin
                payload_count <= 16'd0;
                if (in_valid && in_sop && out_ready) begin
                    out_port_id <= in_port_id;
                    fragment_active <= 1'b0;
                    state <= ST_HEADER;
                end else if (!in_valid && out_ready) begin
                    state <= ST_IDLEPKT;
                end
            end
            ST_HEADER: begin
                xgem_header <= {in_port_id, fragment_active, 3'b001, payload_count};
                out_hec <= calc_hec(xgem_header);
                out_valid <= 1'b1;
                out_data <= {xgem_header, calc_hec(xgem_header), 19'd0};
                out_sop <= 1'b1;
                state <= ST_PAYLD;
            end
            ST_PAYLD: begin
                if (in_valid && out_ready) begin
                    out_valid <= 1'b1;
                    out_data <= in_data;
                    payload_count <= payload_count + (DATA_W/8);
                    out_payload_len <= payload_count;
                    fragment_count <= fragment_count + (DATA_W/8);
                    if (fragment_count >= MAX_FRAGMENT) begin
                        out_fragment <= 1'b1;
                        fragment_active <= 1'b1;
                        fragment_count <= 16'd0;
                    end
                    if (in_eop) begin
                        out_eop <= 1'b1;
                        fragment_active <= 1'b0;
                        state <= ST_IDLE;
                    end else if (payload_count >= MAX_FRAME_LEN) begin
                        out_fragment <= 1'b1;
                        fragment_active <= 1'b1;
                        payload_count <= 16'd0;
                        state <= ST_HEADER;
                    end
                end
            end
            ST_IDLEPKT: begin
                if (out_ready) begin
                    out_valid <= 1'b1;
                    out_idle <= 1'b1;
                    out_data <= {12'hFFF,1'b0,3'b000,16'd0,13'd0,19'd0};
                    out_sop <= 1'b1; out_eop <= 1'b1;
                    state <= ST_IDLE;
                end
            end
            default: state <= ST_IDLE;
        endcase
    end
end
endmodule
