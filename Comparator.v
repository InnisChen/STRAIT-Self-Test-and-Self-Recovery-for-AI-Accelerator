// Comparator.v

module Comparator #(
    parameter SYSTOLIC_SIZE = 8,
    parameter WEIGHT_WIDTH = 8,
    parameter ACTIVATION_WIDTH = 8,
    parameter PARTIAL_SUM_WIDTH = WEIGHT_WIDTH + ACTIVATION_WIDTH + $clog2(SYSTOLIC_SIZE)
) (
    input [PARTIAL_SUM_WIDTH-1:0] correct_answer,
    input [PARTIAL_SUM_WIDTH*SYSTOLIC_SIZE-1:0] partial_sum_flat,
    output [SYSTOLIC_SIZE-1:0] compared_results
);
    // reg [PARTIAL_SUM_WIDTH-1:0] compare_xor [0:SYSTOLIC_SIZE-1];
    wire [PARTIAL_SUM_WIDTH-1:0] partial_sum [0:SYSTOLIC_SIZE-1];

    genvar i;

    // 解攤平
    generate
        for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin : partial_sum_io_conversion
            assign partial_sum[i] = partial_sum_flat[i*PARTIAL_SUM_WIDTH +: PARTIAL_SUM_WIDTH];
        end
    endgenerate

    generate
        for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin : comparaed_results_gen
            assign compared_results[i] = |(correct_answer ^ partial_sum[i]);
        end
    endgenerate
    
endmodule



/*

module Comparator #(
    parameter SYSTOLIC_SIZE = 8,
    parameter WEIGHT_WIDTH = 8,
    parameter ACTIVATION_WIDTH = 8,
    parameter PARTIAL_SUM_WIDTH = WEIGHT_WIDTH + ACTIVATION_WIDTH + $clog2(SYSTOLIC_SIZE),
) (
    input clk,
    input rst_n,
    input [PARTIAL_SUM_WIDTH-1:0] correct_answer,
    input [PARTIAL_SUM_WIDTH*SYSTOLIC_SIZE-1:0] partial_sum_flat,
    output [SYSTOLIC_SIZE-1:0] compared_results
);
    reg [PARTIAL_SUM_WIDTH-1:0] compare_xor [0:SYSTOLIC_SIZE-1];
    reg [PARTIAL_SUM_WIDTH-1:0] partial_sum [0:SYSTOLIC_SIZE-1];

    genvar i;
    integer k;

    // 解攤平
    generate    
        for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin : partial_sum_io_conversion
            assign partial_sum[i] = partial_sum_flat[i*PARTIAL_SUM_WIDTH +: PARTIAL_SUM_WIDTH];
        end
    endgenerate
    
    //可以考慮是否要clk，還是純組合邏輯
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (k = 0; k < SYSTOLIC_SIZE; k = k + 1) begin
                compare_xor[k] <= 0;
            end
        end 
        else begin
            for (k = 0; k < SYSTOLIC_SIZE; k = k + 1) begin
                compare_xor[k] <= correct_answer ^ partial_sum[k];
            end
        end
    end

    generate
        for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin : comparaed_results_gen
            assign compared_results[i] = |compare_xor[i];  // 每個 partial sum 的比較結果
        end
    endgenerate
    
endmodule

*/