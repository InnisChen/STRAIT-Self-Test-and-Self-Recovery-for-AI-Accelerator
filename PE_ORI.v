// ORI_PE
module ORI_PE #(
    parameter SYSTOLIC_SIZE = 8,
    parameter WEIGHT_WIDTH = 8,
    parameter ACTIVATION_WIDTH = 8,
    parameter PARTIAL_SUM_WIDTH = WEIGHT_WIDTH + ACTIVATION_WIDTH + $clog2(SYSTOLIC_SIZE)
)(
    input clk , rst_n,
    input clk_w,
    input [WEIGHT_WIDTH-1:0] weight,
    input [ACTIVATION_WIDTH-1:0] activation,
    input [PARTIAL_SUM_WIDTH-1:0] partial_sum_in,
    output reg [WEIGHT_WIDTH-1:0] weight_out, 
    output reg [ACTIVATION_WIDTH-1:0] activation_out,
    output reg [PARTIAL_SUM_WIDTH-1:0] partial_sum_out,
);

    wire [PARTIAL_SUM_WIDTH-1:0] MAC_result;

    MAC MAC_u1(
        .activation(activation),
        .weight(weight),
        .partial_sum(partial_sum_in),
        .result(MAC_result)
    );

    always @(posedge clk_w , negedge rst_n) begin
    // always @(posedge clk , negedge rst_n) begin
        if(rst_n == 1'b0) 
            weight_out <= {WEIGHT_WIDTH{1'b0}};
        else
        weight_out <= weight;
    end

    always @(posedge clk , negedge rst_n) begin
        if(rst_n == 1'b0) begin
            activation_out <= {ACTIVATION_WIDTH{1'b0}};
            partial_sum_out <= {PARTIAL_SUM_WIDTH{1'b0}};
        end
        else begin
            activation_out <= activation;
            partial_sum_out <= MAC_result;
        end
    end
    
endmodule

module MAC (
    input [ACTIVATION_WIDTH-1:0] activation,
    input [WEIGHT_WIDTH-1:0] weight,
    input [PARTIAL_SUM_WIDTH-1:0] partial_sum,
    output [PARTIAL_SUM_WIDTH-1:0] result
);
    wire [ACTIVATION_WIDTH + WEIGHT_WIDTH - 1:0] mul_result;
    assign mul_result = weight * activation;
    assign result = mul_result + partial_sum;
    
endmodule