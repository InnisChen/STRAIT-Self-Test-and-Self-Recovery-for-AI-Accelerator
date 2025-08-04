// STRAIT_PE
module STRAIT_PE (
    input clk , rst_n,
    input clk_w,
    input [7:0] weight , activation,
    input [23:0] partial_sum_in,
    input PE_disable, scan_en,
    output reg [7:0] weight_out , activation_out,
    output reg [23:0] partial_sum_out,
    output reg PE_disable_out
);

    wire [23:0] partial_sum;
    wire [23:0] MAC_result;

    MAC MAC_u1(
        .activation(activation),
        .weight(weight),
        .partial_sum(partial_sum_in),
        .result(MAC_result)
    );

    assign partial_sum = (scan_en||PE_disable) ? partial_sum_in : MAC_result;   //mux result

    //if do not use the clk_w , I need a signal to control the weight register to stay in the current value , the signal should be connect to the all PE.
    always @(posedge clk_w , negedge rst_n) begin
    // always @(posedge clk , negedge rst_n) begin
        if(rst_n == 1'b0) weight_out <= 8'b0;
        else weight_out <= weight;
    end

    always @(posedge clk , negedge rst_n) begin
        if(rst_n == 1'b0) begin
            activation_out <= 8'b0;
            partial_sum_out <= 24'b0;
            PE_disable_out <= 1'b0;
        end
        else begin
            activation_out <= activation;
            partial_sum_out <= partial_sum;
            PE_disable_out <= PE_disable;
        end
        
    end
    
endmodule

module MAC (
    input [7:0] activation,
    input [7:0] weight,
    input [23:0] partial_sum,
    output [23:0] result
);
    wire [16:0] mul_result;
    assign mul_result = weight * activation;
    assign result = mul_result + partial_sum;
    
endmodule