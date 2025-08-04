module Systolic_array #(
    parameter SYSTOLIC_SIZE = 8,
    parameter WEIGHT_WIDTH = 8,
    parameter ACTIVATION_WIDTH = 8,
    parameter PARTIAL_SUM_WIDTH = WEIGHT_WIDTH + ACTIVATION_WIDTH + $clog2(SYSTOLIC_SIZE)
)(
    input clk, rst_n, scan_en,
    input clk_w,
    input [SYSTOLIC_SIZE-1:0] PE_disable,
    input [SYSTOLIC_SIZE*WEIGHT_WIDTH-1:0] weight_flat,
    input [SYSTOLIC_SIZE*ACTIVATION_WIDTH-1:0] activation_flat,
    input [SYSTOLIC_SIZE*PARTIAL_SUM_WIDTH-1:0] partial_sum_in_flat,
    output [SYSTOLIC_SIZE*PARTIAL_SUM_WIDTH-1:0] partial_sum_flat
);

    // 內部連接線陣列
    wire [SYSTOLIC_SIZE-1:0] PE_disable_internal [SYSTOLIC_SIZE:0];
    wire [WEIGHT_WIDTH-1:0] weight_internal [SYSTOLIC_SIZE:0][SYSTOLIC_SIZE-1:0];
    wire [ACTIVATION_WIDTH-1:0] activation_internal [SYSTOLIC_SIZE-1:0][SYSTOLIC_SIZE:0];
    wire [PARTIAL_SUM_WIDTH-1:0] partial_sum_internal [SYSTOLIC_SIZE:0][SYSTOLIC_SIZE-1:0];

    // 輸入輸出連接
    genvar i, j;
    generate
        // 連接輸入 - 直接從攤平向量連接到內部陣列
        for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin : input_connections
            assign PE_disable_internal[0][i] = PE_disable[i];
            assign weight_internal[0][i] = weight_flat[i*WEIGHT_WIDTH +: WEIGHT_WIDTH];
            assign activation_internal[i][0] = activation_flat[i*ACTIVATION_WIDTH +: ACTIVATION_WIDTH];
            assign partial_sum_internal[0][i] = partial_sum_in_flat[i*PARTIAL_SUM_WIDTH +: PARTIAL_SUM_WIDTH];
        end
        
        // 連接輸出 - 直接從內部陣列連接到攤平向量
        for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin : output_connections
            assign partial_sum_flat[i*PARTIAL_SUM_WIDTH +: PARTIAL_SUM_WIDTH] = partial_sum_internal[SYSTOLIC_SIZE][i];
        end
    endgenerate

    // 生成PE陣列
    generate
        for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin : row_gen
            for (j = 0; j < SYSTOLIC_SIZE; j = j + 1) begin : col_gen
                STRAIT_PE #(
                    .SYSTOLIC_SIZE(SYSTOLIC_SIZE),
                    .WEIGHT_WIDTH(WEIGHT_WIDTH),
                    .ACTIVATION_WIDTH(ACTIVATION_WIDTH),
                    .PARTIAL_SUM_WIDTH(PARTIAL_SUM_WIDTH)
                ) PE_inst (
                    // 基本控制信號
                    .clk(clk),
                    .clk_w(clk_w),
                    .rst_n(rst_n),
                    .scan_en(scan_en),
                    
                    // 數據輸入
                    .weight(weight_internal[i][j]),
                    .activation(activation_internal[i][j]),
                    .partial_sum_in(partial_sum_internal[i][j]),
                    .PE_disable(PE_disable_internal[i][j]),
                    
                    // 數據輸出
                    .weight_out(weight_internal[i+1][j]),
                    .activation_out(activation_internal[i][j+1]),
                    .partial_sum_out(partial_sum_internal[i+1][j]),
                    .PE_disable_out(PE_disable_internal[i+1][j])
                );
            end
        end
    endgenerate

endmodule