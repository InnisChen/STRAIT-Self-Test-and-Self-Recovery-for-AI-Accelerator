// Systolic_array.v
// 輸入先攤平
`include "PE_STRAIT_ERROR.v"

module Systolic_array #(
    parameter SYSTOLIC_SIZE = 8,
    parameter WEIGHT_WIDTH = 8,
    parameter ACTIVATION_WIDTH = 8,
    parameter PARTIAL_SUM_WIDTH = WEIGHT_WIDTH + ACTIVATION_WIDTH + $clog2(SYSTOLIC_SIZE)
)(
    input clk,
    input clk_w,
    input rst_n,
    input scan_en,
    input [SYSTOLIC_SIZE-1:0] PE_disable,
    input [SYSTOLIC_SIZE*WEIGHT_WIDTH-1:0] weight_flat,
    input [SYSTOLIC_SIZE*ACTIVATION_WIDTH-1:0] activation_flat,
    input [SYSTOLIC_SIZE*PARTIAL_SUM_WIDTH-1:0] partial_sum_in_flat,
    output [SYSTOLIC_SIZE*PARTIAL_SUM_WIDTH-1:0] partial_sum_out_flat
);

    // 中間訊號陣列 - 用於攤平向量和內部邏輯之間的轉換
    wire [WEIGHT_WIDTH-1:0] weight [0:SYSTOLIC_SIZE-1];
    wire [ACTIVATION_WIDTH-1:0] activation [0:SYSTOLIC_SIZE-1];
    wire [PARTIAL_SUM_WIDTH-1:0] partial_sum_in [0:SYSTOLIC_SIZE-1];
    wire [PARTIAL_SUM_WIDTH-1:0] partial_sum_out [0:SYSTOLIC_SIZE-1];

    // 內部連接線陣列
    wire [SYSTOLIC_SIZE-1:0] PE_disable_internal [SYSTOLIC_SIZE:0];
    wire [WEIGHT_WIDTH-1:0] weight_internal [SYSTOLIC_SIZE:0][SYSTOLIC_SIZE-1:0];
    wire [ACTIVATION_WIDTH-1:0] activation_internal [SYSTOLIC_SIZE-1:0][SYSTOLIC_SIZE:0];
    wire [PARTIAL_SUM_WIDTH-1:0] partial_sum_internal [SYSTOLIC_SIZE:0][SYSTOLIC_SIZE-1:0];

    // 輸入輸出轉換邏輯
    genvar i, j;
    generate
        for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin : io_conversion
            // 輸入解包 - 將攤平向量轉換為陣列
            assign weight[i] = weight_flat[i*WEIGHT_WIDTH +: WEIGHT_WIDTH];
            assign activation[i] = activation_flat[i*ACTIVATION_WIDTH +: ACTIVATION_WIDTH];
            assign partial_sum_in[i] = partial_sum_in_flat[i*PARTIAL_SUM_WIDTH +: PARTIAL_SUM_WIDTH];
            
            // 輸出打包 - 將陣列轉換為攤平向量
            assign partial_sum_out_flat[i*PARTIAL_SUM_WIDTH +: PARTIAL_SUM_WIDTH] = partial_sum_out[i];
        end
    endgenerate

    // 輸入連接邏輯
    generate
        for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin : input_connections
            assign PE_disable_internal[0][i] = PE_disable[i];
            assign weight_internal[0][i] = weight[i];
            assign activation_internal[i][0] = activation[i];
            assign partial_sum_internal[0][i] = partial_sum_in[i];
        end
    endgenerate
        
    // 輸出連接邏輯
    generate
        for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin : output_connections
            assign partial_sum_out[i] = partial_sum_internal[SYSTOLIC_SIZE][i];
        end
    endgenerate

    // 生成PE陣列
    generate
        for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin : row_gen
            for (j = 0; j < SYSTOLIC_SIZE; j = j + 1) begin : col_gen
                if( (i == 7 && j == 7) || (i == 0 && j == 0) ) begin
                    PE_STRAIT_ERROR #(      // 錯誤PE
                        .SYSTOLIC_SIZE(SYSTOLIC_SIZE),
                        .WEIGHT_WIDTH(WEIGHT_WIDTH),
                        .ACTIVATION_WIDTH(ACTIVATION_WIDTH),
                        .PARTIAL_SUM_WIDTH(PARTIAL_SUM_WIDTH)
                    ) PE_error (
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
                else begin
                    PE_STRAIT #(
                        .SYSTOLIC_SIZE(SYSTOLIC_SIZE),
                        .WEIGHT_WIDTH(WEIGHT_WIDTH),
                        .ACTIVATION_WIDTH(ACTIVATION_WIDTH),
                        .PARTIAL_SUM_WIDTH(PARTIAL_SUM_WIDTH)
                    ) PE_normal (
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
        end
    endgenerate

endmodule

// module Systolic_array #(
//     parameter SYSTOLIC_SIZE = 8,
//     parameter WEIGHT_WIDTH = 8,
//     parameter ACTIVATION_WIDTH = 8,
//     parameter PARTIAL_SUM_WIDTH = 24
// )(
//     input clk, rst_n, scan_en,
//     input clk_w,
//     input [SYSTOLIC_SIZE-1:0] PE_disable,
//     input [WEIGHT_WIDTH-1:0] weight [0:SYSTOLIC_SIZE-1],
//     input [ACTIVATION_WIDTH-1:0] activation [0:SYSTOLIC_SIZE-1],
//     input [PARTIAL_SUM_WIDTH-1:0] partial_sum_in [0:SYSTOLIC_SIZE-1],
//     output [PARTIAL_SUM_WIDTH-1:0] partial_sum_out [0:SYSTOLIC_SIZE-1]
// );

//     // 內部連接線陣列
//     wire [SYSTOLIC_SIZE-1:0] PE_disable_internal [SYSTOLIC_SIZE:0];
//     wire [WEIGHT_WIDTH-1:0] weight_internal [SYSTOLIC_SIZE:0][SYSTOLIC_SIZE-1:0];
//     wire [ACTIVATION_WIDTH-1:0] activation_internal [SYSTOLIC_SIZE-1:0][SYSTOLIC_SIZE:0];
//     wire [PARTIAL_SUM_WIDTH-1:0] partial_sum_internal [SYSTOLIC_SIZE:0][SYSTOLIC_SIZE-1:0];

//     // 輸入連接
//     genvar i, j;
//     generate
//         // 連接輸入
//         for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin : input_connections
//             assign PE_disable_internal[0][i] = PE_disable[i];
//             assign weight_internal[0][i] = weight[i];
//             assign activation_internal[i][0] = activation[i];
//             assign partial_sum_internal[0][i] = partial_sum_in[i];
//         end
        
//         // 連接輸出
//         for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin : output_connections
//             assign partial_sum_out[i] = partial_sum_internal[SYSTOLIC_SIZE][i];
//         end
//     endgenerate

//     // 生成PE陣列
//     generate
//         for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin : row_gen
//             for (j = 0; j < SYSTOLIC_SIZE; j = j + 1) begin : col_gen
//                 PE_STRAIT PE_inst (
//                     // 基本控制信號
//                     .clk(clk),
//                     .clk_w(clk_w),
//                     .rst_n(rst_n),
//                     .scan_en(scan_en),
                    
//                     // 數據輸入
//                     .weight(weight_internal[i][j]),
//                     .activation(activation_internal[i][j]),
//                     .partial_sum_in(partial_sum_internal[i][j]),
//                     .PE_disable(PE_disable_internal[i][j]),
                    
//                     // 數據輸出
//                     .weight_out(weight_internal[i+1][j]),
//                     .activation_out(activation_internal[i][j+1]),
//                     .partial_sum_out(partial_sum_internal[i+1][j]),
//                     .PE_disable_out(PE_disable_internal[i+1][j])
//                 );
//             end
//         end
//     endgenerate

// endmodule