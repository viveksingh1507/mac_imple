module xgspon_omci_oam #(
    parameter GEM_DATA_W = 64,
    parameter PORT_ID_W  = 12,
    parameter OMCI_PORT  = 12'h00A
)(
    input wire clk,input wire rst_n,
    input wire gem_valid,input wire [GEM_DATA_W-1:0] gem_data,input wire gem_sop,input wire gem_eop,input wire [PORT_ID_W-1:0] gem_port_id,
    output reg omci_valid,output reg [GEM_DATA_W-1:0] omci_data,output reg omci_sop,output reg omci_eop,
    output reg oam_valid, output reg [GEM_DATA_W-1:0] oam_data
);
always @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin omci_valid<=0;omci_data<='0;omci_sop<=0;omci_eop<=0;oam_valid<=0;oam_data<='0; end
 else begin omci_valid<=0;omci_sop<=0;omci_eop<=0;oam_valid<=0;
  if(gem_valid) begin
   if(gem_port_id==OMCI_PORT) begin omci_valid<=1; omci_data<=gem_data; omci_sop<=gem_sop; omci_eop<=gem_eop; end
   else if(gem_port_id==12'h001) begin oam_valid<=1; oam_data<=gem_data; end
  end
 end
end
endmodule
