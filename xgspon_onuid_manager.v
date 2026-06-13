module xgspon_onuid_manager #(
    parameter ONU_ID_W=10
)(
    input wire clk, input wire rst_n,
    input wire allocate, input wire invalidate, input wire deactivate, input wire reassign,
    input wire [ONU_ID_W-1:0] new_onu_id,
    output reg [ONU_ID_W-1:0] onu_id,
    output reg onu_id_valid
);
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin onu_id<={ONU_ID_W{1'b0}}; onu_id_valid<=0; end
        else if(invalidate || deactivate) begin onu_id_valid<=0; onu_id<={ONU_ID_W{1'b0}}; end
        else if(allocate || reassign) begin onu_id<=new_onu_id; onu_id_valid<=1'b1; end
    end
endmodule
