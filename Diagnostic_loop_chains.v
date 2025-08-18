//Parameterized Diagnostic_loop_chains

module Diagnostic_loop_chains #(
    parameter SYSTOLIC_SIZE = 8,  // 可設定的脈動陣列大小，預設為8x8
    parameter ADDR_WIDTH = $clog2(SYSTOLIC_SIZE)    //counter的位寬
)(
    input clk,
    input rst_n,
    input start_en,
    input [SYSTOLIC_SIZE-1:0] col_inputs,
    output [SYSTOLIC_SIZE-1:0] single_pe_detection, //單row pe輸出
    output [SYSTOLIC_SIZE-1:0] column_fault_detection,  // 每個column的fault檢測輸出
    output [SYSTOLIC_SIZE-1:0] row_fault_detection  // 每個row的fault檢測輸出
    // output reg [ADDR_WIDTH-1:0] counter //輸出給envm讀取第幾個row的錯誤資訊，因envm 沒有rst沒辦法rst counter 訊號
    // 改由bist送addr
);
    // 動態宣告線路和暫存器
    wire [SYSTOLIC_SIZE-1:0] col_0;  // 每個column的第0級輸出
    reg [SYSTOLIC_SIZE-1:0] col_reg [0:SYSTOLIC_SIZE-1];  // 二維陣列儲存所有暫存器

    // 產生各個column的第0級信號 (輸入信號 or 最後一級的回饋)
    genvar i;
    generate
        for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin : col_input_gen
            assign col_0[i] = col_inputs[i] || col_reg[SYSTOLIC_SIZE-1][i];
        end
    endgenerate

    integer k;
    // 產生各個column的診斷迴路鏈
    generate
        for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin : col_chain_gen
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    // 重置所有該column的暫存器
                    for (k = 0; k < SYSTOLIC_SIZE; k = k + 1) begin
                        col_reg[k][i] <= 1'b0;
                    end
                end
                else if(start_en) begin
                    // 建立移位暫存器鏈
                    // col_reg[0][i] <= col_0[i];
                    col_reg[0][i] <= col_inputs[i] || col_reg[SYSTOLIC_SIZE-1][i];
                    
                    for (k = 1; k < SYSTOLIC_SIZE; k = k + 1) begin
                        col_reg[k][i] <= col_reg[k-1][i];
                    end
                end
                else;
            end
        end
    endgenerate


    //----------------------- Row fault detector -----------------------
    wire row_and_result;
    wire row_detect_0;
    reg [SYSTOLIC_SIZE-1:0] row_detect_reg;

    // 對最後3個columns的第0級進行AND運算 (從最上面取值)
    assign row_and_result = col_0[SYSTOLIC_SIZE-1] && col_0[SYSTOLIC_SIZE-2] && col_0[SYSTOLIC_SIZE-3];

    assign row_detect_0 = row_and_result || row_detect_reg[SYSTOLIC_SIZE-1];

    // Row detector的移位暫存器鏈
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (k = 0; k < SYSTOLIC_SIZE; k = k + 1) begin
                row_detect_reg[k] <= 1'b0;
            end
        end
        else if(start_en) begin
            row_detect_reg[0] <= row_detect_0;
            for (k = 1; k < SYSTOLIC_SIZE; k = k + 1) begin
                row_detect_reg[k] <= row_detect_reg[k-1];
            end
        end
        else;
    end


    //----------------------- Column fault detector -----------------------
    wire [SYSTOLIC_SIZE-1:0] col_and_result;
    reg [SYSTOLIC_SIZE-1:0] column_detect;

    // 對每個column的最後3個stage進行AND運算 (從最下面取值)
    generate
        for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin : col_detect_gen
            assign col_and_result[i] = col_reg[SYSTOLIC_SIZE-1][i] && col_reg[SYSTOLIC_SIZE-2][i] && col_reg[SYSTOLIC_SIZE-3][i];
        end
    endgenerate

    // Column detector的暫存器
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (k = 0; k < SYSTOLIC_SIZE; k = k + 1) begin
                column_detect[k] <= 1'b0;
            end
        end
        else if(start_en) begin
            for (k = 0; k < SYSTOLIC_SIZE; k = k + 1) begin
                column_detect[k] <= col_and_result[k];
            end
        end
        else;
    end

    // always @(posedge clk or negedge rst_n) begin
    //     if(!rst_n) begin
    //         counter <= {ADDR_WIDTH{1'b0}};
    //     end
    //     else if(start_en) begin
    //         if(counter == SYSTOLIC_SIZE - 1) begin
    //             counter <= {ADDR_WIDTH{1'b0}}; // Reset counter to 0
    //         end
    //         else begin
    //             counter <= counter + 1; // Increment counter
    //         end
    //     end
    //     else;
    // end

    // 輸出信號連接
    assign column_fault_detection = column_detect;
    assign row_fault_detection = row_detect_reg;


    //看cycle修正要輸出哪一列的PE(or gate後面 或 第一個reg後)
    assign single_pe_detection = col_0;

endmodule