// Accumulator.v
// combine the wr_addr and wr_en signal to mux, reg

module Accumulator #(
    parameter SYSTOLIC_SIZE = 8,
    parameter WEIGHT_WIDTH = 8,
    parameter ACTIVATION_WIDTH = 8,
    parameter PARTIAL_SUM_WIDTH = WEIGHT_WIDTH + ACTIVATION_WIDTH + $clog2(SYSTOLIC_SIZE),
    parameter PATTERN_NUMBER = 1,
    parameter ADDR_WIDTH = $clog2(PATTERN_NUMBER * SYSTOLIC_SIZE)
) (
    input clk,
    input rst_n,
    input test_mode,
    input BIST_mode, // 0: MBIST, 1: LBIST      memory BIST測試下資料從BIST送
    input wr_en,
    input [ADDR_WIDTH-1:0] wr_addr,  // 寫入地址
    input [PARTIAL_SUM_WIDTH*SYSTOLIC_SIZE-1:0] partial_sum_inputs_array_flat,  // 輸入部分和，從systolic array來的
    input [PARTIAL_SUM_WIDTH*SYSTOLIC_SIZE-1:0] partial_sum_inputs_test_flat, // 測試模式下的輸入部分和
    input [ADDR_WIDTH-1:0] rd_addr_bist,  // 讀取地址
    input [ADDR_WIDTH-1:0] rd_addr_outside,  // 測試時用bist給讀取地址
    output [PARTIAL_SUM_WIDTH*SYSTOLIC_SIZE-1:0] partial_sum_outputs_flat  // 輸出部分和
);

    // MBIST測試下，accumulator的輸入部分和從bist送入
    // test_mode為1，且BIST_mode為0(MBIST) 才使用BIST來的資料
    wire [PARTIAL_SUM_WIDTH*SYSTOLIC_SIZE-1:0] partial_sum_inputs_flat;
    assign partial_sum_inputs_flat = (test_mode && ~BIST_mode) ? partial_sum_inputs_test_flat : partial_sum_inputs_array_flat;

    // 讀取地址選擇
    wire [ADDR_WIDTH-1:0] rd_addr;
    assign rd_addr = test_mode ? rd_addr_bist : rd_addr_outside; // 根據test_mode選擇讀取地址

    reg [ADDR_WIDTH:0] wr_addr_en_reg [0:SYSTOLIC_SIZE-2];  //wr_addr , wr_en 合併訊號
    wire [ADDR_WIDTH:0] wr_addr_en_inputs [0:SYSTOLIC_SIZE-1];


    ////////////////////////
    wire [PARTIAL_SUM_WIDTH-1:0] partial_sum_inputs [0:SYSTOLIC_SIZE-1]; 
    wire [PARTIAL_SUM_WIDTH-1:0] partial_sum_outputs [0:SYSTOLIC_SIZE-1];

    genvar i;
    generate
        for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin : partial_sum_i_conversion
            assign partial_sum_inputs[i] = partial_sum_inputs_flat[i*PARTIAL_SUM_WIDTH +: PARTIAL_SUM_WIDTH];
            assign partial_sum_outputs_flat[i*PARTIAL_SUM_WIDTH +: PARTIAL_SUM_WIDTH] = partial_sum_outputs[i];
        end
    endgenerate
    ////////////////////////

    //wr_addr 的registers
    integer k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (k = 0; k < SYSTOLIC_SIZE-1; k = k + 1) begin
                wr_addr_en_reg[k] <= { {ADDR_WIDTH{1'b0}}, 1'b0};
            end
        end
        else begin
            wr_addr_en_reg[0] <= {wr_en , wr_addr}; // 第一個寫入地址直接使用
            for (k = 1; k < SYSTOLIC_SIZE-1; k = k + 1 ) begin
                wr_addr_en_reg[k] <= wr_addr_en_reg[k-1];
            end
        end
    end

    //wr_addr_en_inputs
    generate
        assign wr_addr_en_inputs[0] = {wr_en , wr_addr};
        for (i = 1; i < SYSTOLIC_SIZE; i = i + 1) begin : wr_addr_inputs_gen
            assign wr_addr_en_inputs[i] = test_mode ? {wr_en , wr_addr} : wr_addr_en_reg[i-1];    //mux
        end
    endgenerate

    Accumulator_mem #(
        .SYSTOLIC_SIZE(SYSTOLIC_SIZE),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .ACTIVATION_WIDTH(ACTIVATION_WIDTH),
        .PARTIAL_SUM_WIDTH(PARTIAL_SUM_WIDTH),
        .PATTERN_NUMBER(PATTERN_NUMBER),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) accumulator_mem_0 (
        .clk(clk),
        .wr_en(wr_en),
        .wr_addr(wr_addr),
        .partial_sum_inputs(partial_sum_inputs[0]),
        .rd_addr(rd_addr),
        .partial_sum_outputs(partial_sum_outputs[0])
    );

    generate
        for (i = 1; i < SYSTOLIC_SIZE; i = i + 1) begin : accumulator_mem_gen
            Accumulator_mem #(
                .SYSTOLIC_SIZE(SYSTOLIC_SIZE),
                .WEIGHT_WIDTH(WEIGHT_WIDTH),
                .ACTIVATION_WIDTH(ACTIVATION_WIDTH),
                .PARTIAL_SUM_WIDTH(PARTIAL_SUM_WIDTH),
                .PATTERN_NUMBER(PATTERN_NUMBER),
                .ADDR_WIDTH(ADDR_WIDTH)
            ) Accumulator_mem_inst (
                .clk(clk),
                .wr_en(wr_addr_en_inputs[i][ADDR_WIDTH]),
                .wr_addr(wr_addr_en_inputs[i][ADDR_WIDTH-1:0]),
                .partial_sum_inputs(partial_sum_inputs[i]),
                .rd_addr(rd_addr),
                .partial_sum_outputs(partial_sum_outputs[i])
            );
        end
    endgenerate

    
endmodule


/*
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
*/