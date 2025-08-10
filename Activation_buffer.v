// Buffer.v
// use generate
// input from activation_mem and BIST 
// use test_mode signal to choose input source

module Activation_buffer #(
    parameter SYSTOLIC_SIZE = 8,
    parameter ACTIVATION_WIDTH = 8
) (
    input clk,
    input rst_n,
    input test_mode,    // 0: 正常模式45度, 1: 測試模式 送出bist給的data

    // from scan data
    input [SYSTOLIC_SIZE*ACTIVATION_WIDTH-1:0] activation_in_test_flat, // 考慮輸入是否縮減成 [ACTIVATION_WIDTH-1:0] ，在bist內部複製訊號成flat就好。 因測試activation都是相同的

    // from activation_mem  (由外部先送到activation_mem再到buffer)
    input [SYSTOLIC_SIZE*ACTIVATION_WIDTH-1:0] activation_in_activationmem_flat,  // from outside to activation_mem to buffer

    output [SYSTOLIC_SIZE*ACTIVATION_WIDTH-1:0] activation_out_flat // 送到systolic array
);

    // 動態分解輸入數據
    wire [ACTIVATION_WIDTH-1:0] activation_in_test [0:SYSTOLIC_SIZE-1];
    wire [ACTIVATION_WIDTH-1:0] activation_in_activationmem [0:SYSTOLIC_SIZE-1];
    wire [ACTIVATION_WIDTH-1:0] activation_out [0:SYSTOLIC_SIZE-1];
    
    genvar i;
    generate
        for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin : in_out_split
            assign activation_in_test[i] = activation_in_test_flat[i*ACTIVATION_WIDTH +: ACTIVATION_WIDTH];
            assign activation_in_activationmem[i] = activation_in_activationmem_flat[i*ACTIVATION_WIDTH +: ACTIVATION_WIDTH];

            assign activation_out_flat[i*ACTIVATION_WIDTH +: ACTIVATION_WIDTH] = activation_out[i];
        end
    endgenerate


    // Row 1 到 Row (SYSTOLIC_SIZE-1): 每行宣告所需數量的registers
    integer j;
    generate
        for (i = 1; i < SYSTOLIC_SIZE; i = i + 1) begin : row_gen
            // 第i行需要i個registers
            reg [ACTIVATION_WIDTH-1:0] shift_regs [0:i-1];
            
            // Shift register邏輯
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    // 重置該行的所有registers
                    for (j = 0; j < i; j = j + 1) begin
                        shift_regs[j] <= {ACTIVATION_WIDTH{1'b0}};
                    end
                end 
                else begin
                    // 輸入到該row的第一個register
                    shift_regs[0] <= activation_in_activationmem[i];
                    
                    // Shift register操作：從第二個開始
                    for (j = 1; j < i; j = j + 1) begin
                        shift_regs[j] <= shift_regs[j-1];
                    end
                end
            end
        end
    endgenerate


    // Row 0
    assign activation_out[0] = test_mode ? activation_in_test[0] : activation_in_activationmem[0];

    // Row 1 to Row (SYSTOLIC_SIZE-1)
    generate
        for (i = 1; i < SYSTOLIC_SIZE; i = i + 1) begin : activation_out_gen
            // 輸出選擇：根據test_mode決定
            assign activation_out[i] = test_mode ? activation_in_test[i] : shift_regs[i-1];
        end
    endgenerate

endmodule

// // Buffer.v
// // use generate
// // only input from activation_mem
// module Buffer #(
//     parameter SYSTOLIC_SIZE = 8,
//     parameter ACTIVATION_WIDTH = 8
// ) (
//     input clk,
//     input rst_n,
//     input test_mode,    // 0: 正常模式45度, 1: 測試模式平行送入
//     input [SYSTOLIC_SIZE*ACTIVATION_WIDTH-1:0] activation_in_flat,

//     output [SYSTOLIC_SIZE*ACTIVATION_WIDTH-1:0] activation_out_flat
// );

//     // 動態分解輸入數據
//     wire [ACTIVATION_WIDTH-1:0] activation_in [0:SYSTOLIC_SIZE-1];
//     wire [ACTIVATION_WIDTH-1:0] activation_out [0:SYSTOLIC_SIZE-1];
    
//     genvar k;
//     generate
//         for (k = 0; k < SYSTOLIC_SIZE; k = k + 1) begin : in_out_split
//             assign activation_in[k] = activation_in_flat[k*ACTIVATION_WIDTH +: ACTIVATION_WIDTH];
//             assign activation_out_flat[k*ACTIVATION_WIDTH +: ACTIVATION_WIDTH] = activation_out[k];
//         end
//     endgenerate

//     // Row 0: 直接輸出，沒有registers
//     assign activation_out[0] = activation_in[0];

//     // Row 1 到 Row (SYSTOLIC_SIZE-1): 每行宣告所需數量的registers
//     genvar i;
//     integer j;
//     generate
//         for (i = 1; i < SYSTOLIC_SIZE; i = i + 1) begin : row_gen
//             // 第i行需要i個registers
//             reg [ACTIVATION_WIDTH-1:0] shift_regs [0:i-1];
            
//             // Shift register邏輯
//             always @(posedge clk or negedge rst_n) begin
//                 if (!rst_n) begin
//                     // 重置該行的所有registers
//                     for (j = 0; j < i; j = j + 1) begin
//                         shift_regs[j] <= {ACTIVATION_WIDTH{1'b0}};
//                     end
//                 end else begin
//                     // 輸入到第一個register
//                     shift_regs[0] <= activation_in[i];
                    
//                     // Shift register操作：從第二個開始
//                     for (j = 1; j < i; j = j + 1) begin
//                         shift_regs[j] <= shift_regs[j-1];
//                     end
//                 end
//             end
            
//             // 輸出選擇：根據test_mode決定
//             assign activation_out[i] = test_mode ? activation_in[i] : shift_regs[i-1];
//         end
//     endgenerate

// endmodule




// // Buffer.v
// // 爆開

// module Buffer #(
//     parameter SYSTOLIC_SIZE = 8,  // 可設定的脈動陣列大小，預設為8x8
//     parameter ACTIVATION_WIDTH = 8
// ) (
//     input clk,
//     input rst_n,
//     input test_mode,    // 0: 正常模式45度, 1: 測試模式平行送入
//     input [SYSTOLIC_SIZE*ACTIVATION_WIDTH-1:0] activation_in_flat,
//     output [ACTIVATION_WIDTH-1:0] activation_out [0:SYSTOLIC_SIZE-1]
// );

//     wire [ACTIVATION_WIDTH-1:0] activation_in [0:SYSTOLIC_SIZE-1];

//     assign activation_in[0] = activation_in_flat[0*ACTIVATION_WIDTH +: ACTIVATION_WIDTH];
//     assign activation_in[1] = activation_in_flat[1*ACTIVATION_WIDTH +: ACTIVATION_WIDTH];
//     assign activation_in[2] = activation_in_flat[2*ACTIVATION_WIDTH +: ACTIVATION_WIDTH];
//     assign activation_in[3] = activation_in_flat[3*ACTIVATION_WIDTH +: ACTIVATION_WIDTH];
//     assign activation_in[4] = activation_in_flat[4*ACTIVATION_WIDTH +: ACTIVATION_WIDTH];
//     assign activation_in[5] = activation_in_flat[5*ACTIVATION_WIDTH +: ACTIVATION_WIDTH];
//     assign activation_in[6] = activation_in_flat[6*ACTIVATION_WIDTH +: ACTIVATION_WIDTH];
//     assign activation_in[7] = activation_in_flat[7*ACTIVATION_WIDTH +: ACTIVATION_WIDTH];

//     reg [ACTIVATION_WIDTH-1:0] reg_row1_0;
//     reg [ACTIVATION_WIDTH-1:0] reg_row2_0,reg_row2_1;
//     reg [ACTIVATION_WIDTH-1:0] reg_row3_0,reg_row3_1,reg_row3_2;
//     reg [ACTIVATION_WIDTH-1:0] reg_row4_0,reg_row4_1,reg_row4_2,reg_row4_3;
//     reg [ACTIVATION_WIDTH-1:0] reg_row5_0,reg_row5_1,reg_row5_2,reg_row5_3,reg_row5_4;
//     reg [ACTIVATION_WIDTH-1:0] reg_row6_0,reg_row6_1,reg_row6_2,reg_row6_3,reg_row6_4,reg_row6_5;
//     reg [ACTIVATION_WIDTH-1:0] reg_row7_0,reg_row7_1,reg_row7_2,reg_row7_3,reg_row7_4,reg_row7_5,reg_row7_6;


//     always @(posedge clk or negedge rst_n) begin
//         if (!rst_n) begin
//             reg_row1_0 <= {ACTIVATION_WIDTH{1'b0}};
//             reg_row2_0 <= {ACTIVATION_WIDTH{1'b0}}; reg_row2_1 <= {ACTIVATION_WIDTH{1'b0}};
//             reg_row3_0 <= {ACTIVATION_WIDTH{1'b0}}; reg_row3_1 <= {ACTIVATION_WIDTH{1'b0}}; reg_row3_2 <= {ACTIVATION_WIDTH{1'b0}};
//             reg_row4_0 <= {ACTIVATION_WIDTH{1'b0}}; reg_row4_1 <= {ACTIVATION_WIDTH{1'b0}}; reg_row4_2 <= {ACTIVATION_WIDTH{1'b0}}; reg_row4_3 <= {ACTIVATION_WIDTH{1'b0}};
//             reg_row5_0 <= {ACTIVATION_WIDTH{1'b0}}; reg_row5_1 <= {ACTIVATION_WIDTH{1'b0}}; reg_row5_2 <= {ACTIVATION_WIDTH{1'b0}}; reg_row5_3 <= {ACTIVATION_WIDTH{1'b0}}; reg_row5_4 <= {ACTIVATION_WIDTH{1'b0}};
//             reg_row6_0 <= {ACTIVATION_WIDTH{1'b0}}; reg_row6_1 <= {ACTIVATION_WIDTH{1'b0}}; reg_row6_2 <= {ACTIVATION_WIDTH{1'b0}}; reg_row6_3 <= {ACTIVATION_WIDTH{1'b0}}; reg_row6_4 <= {ACTIVATION_WIDTH{1'b0}}; reg_row6_5 <= {ACTIVATION_WIDTH{1'b0}};
//             reg_row7_0 <= {ACTIVATION_WIDTH{1'b0}}; reg_row7_1 <= {ACTIVATION_WIDTH{1'b0}}; reg_row7_2 <= {ACTIVATION_WIDTH{1'b0}}; reg_row7_3 <= {ACTIVATION_WIDTH{1'b0}}; reg_row7_4 <= {ACTIVATION_WIDTH{1'b0}}; reg_row7_5 <= {ACTIVATION_WIDTH{1'b0}}; reg_row7_6 <= {ACTIVATION_WIDTH{1'b0}};
//         end else begin
//             reg_row1_0 <= activation_in[1];
//             reg_row2_0 <= activation_in[2]; reg_row2_1 <= reg_row2_0;
//             reg_row3_0 <= activation_in[3]; reg_row3_1 <= reg_row3_0; reg_row3_2 <= reg_row3_1;
//             reg_row4_0 <= activation_in[4]; reg_row4_1 <= reg_row4_0; reg_row4_2 <= reg_row4_1; reg_row4_3 <= reg_row4_2;
//             reg_row5_0 <= activation_in[5]; reg_row5_1 <= reg_row5_0; reg_row5_2 <= reg_row5_1; reg_row5_3 <= reg_row5_2; reg_row5_4 <= reg_row5_3;
//             reg_row6_0 <= activation_in[6]; reg_row6_1 <= reg_row6_0; reg_row6_2 <= reg_row6_1; reg_row6_3 <= reg_row6_2; reg_row6_4 <= reg_row6_3; reg_row6_5 <= reg_row6_4;
//             reg_row7_0 <= activation_in[7]; reg_row7_1 <= reg_row7_0; reg_row7_2 <= reg_row7_1; reg_row7_3 <= reg_row7_2; reg_row7_4 <= reg_row7_3; reg_row7_5 <= reg_row7_4; reg_row7_6 <= reg_row7_5;
//         end
//     end
    
//     assign activation_out[0] = activation_in[0];
//     assign activation_out[1] = test_mode ? activation_in[1] : reg_row1_0 ;
//     assign activation_out[2] = test_mode ? activation_in[2] : reg_row2_1 ;    
//     assign activation_out[3] = test_mode ? activation_in[3] : reg_row3_2 ;
//     assign activation_out[4] = test_mode ? activation_in[4] : reg_row4_3 ;
//     assign activation_out[5] = test_mode ? activation_in[5] : reg_row5_4 ;
//     assign activation_out[6] = test_mode ? activation_in[6] : reg_row6_5 ;
//     assign activation_out[7] = test_mode ? activation_in[7] : reg_row7_6 ;    

// endmodule