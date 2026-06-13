module xgspon_activation_context #(
    parameter ONU_ID_W=10
)(
    input wire clk, input wire rst_n,
    input wire [31:0] serial_number_in,
    input wire serial_load,
    input wire [ONU_ID_W-1:0] onu_id_in,
    input wire onu_id_load,
    input wire [15:0] eqd_in,
    input wire eqd_load,
    input wire [2:0] state_in,
    input wire state_load,
    input wire [15:0] flags_in,
    input wire flags_load,
    output reg [31:0] serial_number,
    output reg [ONU_ID_W-1:0] onu_id,
    output reg [15:0] eqd,
    output reg [2:0] state,
    output reg [15:0] activation_flags
);
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin serial_number<=32'h00000001; onu_id<={ONU_ID_W{1'b0}}; eqd<=0; state<=0; activation_flags<=0; end
        else begin
            if(serial_load) serial_number<=serial_number_in;
            if(onu_id_load) onu_id<=onu_id_in;
            if(eqd_load) eqd<=eqd_in;
            if(state_load) state<=state_in;
            if(flags_load) activation_flags<=flags_in;
        end
    end
endmodule
