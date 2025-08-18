// STRAIT_PE
module STRAIT_PE #(
    parameter SYSTOLIC_SIZE = 8,
    parameter WEIGHT_WIDTH = 8,
    parameter ACTIVATION_WIDTH = 8,
    parameter PARTIAL_SUM_WIDTH = WEIGHT_WIDTH + ACTIVATION_WIDTH + $clog2(SYSTOLIC_SIZE)
)(
    input clk , rst_n,
    input clk_w,
    input [WEIGHT_WIDTH-1:0] weight,                //
    input [ACTIVATION_WIDTH-1:0] activation,        //
    input [PARTIAL_SUM_WIDTH-1:0] partial_sum_in,   //
    input PE_disable, scan_en,
    output reg [WEIGHT_WIDTH-1:0] weight_out, 
    output reg [ACTIVATION_WIDTH-1:0] activation_out,
    output reg [PARTIAL_SUM_WIDTH-1:0] partial_sum_out,
    output reg PE_disable_out
);

    wire [PARTIAL_SUM_WIDTH-1:0] partial_sum;
    wire [PARTIAL_SUM_WIDTH-1:0] MAC_result;

    MAC #(
        .SYSTOLIC_SIZE(SYSTOLIC_SIZE),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .ACTIVATION_WIDTH(ACTIVATION_WIDTH),
        .PARTIAL_SUM_WIDTH(PARTIAL_SUM_WIDTH)
    ) MAC_u1(
        .weight(weight_out),                //
        .activation(activation_out),        //                    
        .partial_sum(partial_sum_in),   //    
        .result(MAC_result)
    );

    assign partial_sum = (scan_en||PE_disable) ? partial_sum_in : MAC_result;   //mux result

    //if do not use the clk_w , I need a signal to control the weight register to stay in the current value , the signal should be connect to the all PE.
    always @(posedge clk_w or negedge rst_n) begin
    // always @(posedge clk , negedge rst_n) begin
        if(rst_n == 1'b0) begin
            weight_out <= {WEIGHT_WIDTH{1'b0}};
            PE_disable_out <= 1'b0;
        end
        else begin
            weight_out <= weight;
            PE_disable_out <= PE_disable;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if(rst_n == 1'b0) begin
            activation_out <= {ACTIVATION_WIDTH{1'b0}};
            partial_sum_out <= {PARTIAL_SUM_WIDTH{1'b0}};
            
        end
        else begin
            activation_out <= activation;
            partial_sum_out <= partial_sum;
        end
    end
endmodule

module MAC #(
    parameter SYSTOLIC_SIZE = 8,
    parameter WEIGHT_WIDTH = 8,
    parameter ACTIVATION_WIDTH = 8,
    parameter PARTIAL_SUM_WIDTH = WEIGHT_WIDTH + ACTIVATION_WIDTH + $clog2(SYSTOLIC_SIZE)
)(
    input [WEIGHT_WIDTH-1:0] weight,
    input [ACTIVATION_WIDTH-1:0] activation,
    input [PARTIAL_SUM_WIDTH-1:0] partial_sum,
    output [PARTIAL_SUM_WIDTH-1:0] result
);
    wire [ACTIVATION_WIDTH + WEIGHT_WIDTH - 1:0] mul_result;
    assign mul_result = weight * activation;
    assign result = mul_result + partial_sum;
    
endmodule