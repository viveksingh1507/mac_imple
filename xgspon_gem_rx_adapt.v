module xgspon_gem_rx_adapt #(
    parameter GEM_DATA_W = 64,
    parameter PORT_ID_W  = 12
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  gem_valid,
    input  wire [GEM_DATA_W-1:0] gem_data,
    input  wire                  gem_sop,
    input  wire                  gem_eop,
    input  wire [PORT_ID_W-1:0]  gem_port_id,
    output wire                  gem_ready,
    output reg                   svc_valid,
    output reg [GEM_DATA_W-1:0]  svc_data,
    output reg                   svc_sop,
    output reg                   svc_eop,
    input  wire                  svc_ready
);

    assign gem_ready = svc_ready;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            svc_valid <= 1'b0;
            svc_data  <= '0;
            svc_sop   <= 1'b0;
            svc_eop   <= 1'b0;
        end else begin
            svc_valid <= 1'b0;
            svc_sop   <= 1'b0;
            svc_eop   <= 1'b0;

            if (gem_valid && svc_ready) begin
                svc_valid <= 1'b1;
                svc_data  <= gem_data;
                svc_sop   <= gem_sop;
                svc_eop   <= gem_eop;
            end
        end
    end

endmodule
