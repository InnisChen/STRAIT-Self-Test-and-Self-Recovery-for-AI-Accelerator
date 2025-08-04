// Accumulator_mem.v
//test_mode 讀取時，rd_addr 都一樣(平行讀出)
//正常運作讀取時，rd_addr 45度的讀

module Accumulator_mem #(
    parameter SYSTOLIC_SIZE = 8,
    parameter WEIGHT_WIDTH = 8,
    parameter ACTIVATION_WIDTH = 8,
    parameter PARTIAL_SUM_WIDTH = WEIGHT_WIDTH + ACTIVATION_WIDTH + $clog2(SYSTOLIC_SIZE),
    parameter PATTERN_NUMBER = 1,
    parameter ADDR_WIDTH = $clog2(PATTERN_NUMBER * SYSTOLIC_SIZE)
)(
    input clk,
    input wr_en,
    input [ADDR_WIDTH-1:0] wr_addr,  // 寫入地址
    input [PARTIAL_SUM_WIDTH-1:0] partial_sum_inputs,  // 輸入部分和
    input [ADDR_WIDTH-1:0] rd_addr,  // 讀取地址
    output [PARTIAL_SUM_WIDTH-1:0] partial_sum_outputs  // 輸出部分和
);

    reg [PARTIAL_SUM_WIDTH-1:0] accumulator_memory [0:PATTERN_NUMBER*SYSTOLIC_SIZE-1];

    always @(posedge clk) begin
        if (wr_en) begin
            accumulator_memory[wr_addr] <= partial_sum_inputs;
        end
        else;
    end

    assign partial_sum_outputs = accumulator_memory[rd_addr];
    
endmodule