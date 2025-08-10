// ORI_PE
module ORI_PE (
    input clk , rst_n,
    input clk_w,
    input [7:0] weight , activation,
    input [23:0] partial_sum_in,
    output reg [7:0] weight_out , activation_out,
    output reg [23:0] partial_sum_out
);

    wire [23:0] MAC_result;

    MAC MAC_u1(
        .activation(activation),
        .weight(weight),
        .partial_sum(partial_sum_in),
        .result(MAC_result)
    );

    always @(posedge clk_w , negedge rst_n) begin
    // always @(posedge clk , negedge rst_n) begin
        if(rst_n == 1'b0) 
            weight_out <= 8'b0;
        else
        weight_out <= weight;
    end

    always @(posedge clk , negedge rst_n) begin
        if(rst_n == 1'b0) begin
            activation_out <= 8'b0;
            partial_sum_out <= 24'b0;
        end
        else begin
            activation_out <= activation;
            partial_sum_out <= MAC_result;
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