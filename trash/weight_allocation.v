// Weight Allocation 模組，實現 STRAIT 論文中的 Algorithm 2
module weight_allocation #(
    parameter ARRAY_SIZE = 8,         // 脈動陣列大小 (8x8)
    parameter WEIGHT_WIDTH = 8,       // 權重位寬 (8-bit)
    parameter NUM_FAULTY_ROWS = 2,    // 故障行數
    parameter ROW_ADDR_WIDTH = 3,     // 行地址位寬 (支援 2^3=8 行)
    parameter NUM_WEIGHT_ROWS = 8     // 權重行數
) (
    input wire clk,                   // 時鐘
    input wire rst_n,                 // 低電平有效重置
    input wire start,                 // 啟動信號
    input wire [WEIGHT_WIDTH-1:0] weight_row_in [0:ARRAY_SIZE-1], // 輸入權重行
    input wire [ROW_ADDR_WIDTH-1:0] faulty_row_addr [0:NUM_FAULTY_ROWS-1], // 故障行地址
    input wire [ARRAY_SIZE-1:0] faulty_pe_vector [0:NUM_FAULTY_ROWS-1],   // 故障 PE 向量
    output reg [ROW_ADDR_WIDTH-1:0] mapping_table [0:NUM_WEIGHT_ROWS-1],  // 映射表
    output reg done,                  // 完成信號
    output reg success                // 恢復成功標誌
);

// 內部寄存器和線網
reg [ARRAY_SIZE-1:0] weight_binary;        // 權重行轉換後的二進位向量
reg [NUM_FAULTY_ROWS-1:0] tcam_match;      // TCAM 匹配結果
reg [ROW_ADDR_WIDTH-1:0] best_match_addr;  // 最佳匹配行地址
reg [31:0] max_faulty_pes;                 // 最佳匹配的故障 PE 數
reg [NUM_FAULTY_ROWS-1:0] recov_flag;      // 恢復標誌
reg [ROW_ADDR_WIDTH-1:0] weight_idx;       // 當前權重行索引
reg [1:0] state;                          // 狀態機狀態
localparam IDLE = 2'd0,                   // 空閒狀態
           PROCESS = 2'd1,                // 處理權重行
           CHECK = 2'd2,                  // 檢查恢復結果
           DONE = 2'd3;                   // 完成

// TCAM 模擬模組
genvar i;
generate
    for (i = 0; i < NUM_FAULTY_ROWS; i = i + 1) begin : tcam_loop
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                tcam_match[i] <= 1'b0;
            end else if (state == PROCESS) begin
                // TCAM 匹配：檢查權重行是否覆蓋故障 PE 位置
                integer j;
                reg match;
                match = 1'b1;
                for (j = 0; j < ARRAY_SIZE; j = j + 1) begin
                    if (faulty_pe_vector[i][j] == 1'b1 && weight_binary[j] != 1'b1) begin
                        match = 1'b0;
                    end
                end
                tcam_match[i] <= match;
            end
        end
    end
endgenerate

// NOR 閘：將權重行轉換為二進位向量
integer k;
always @(*) begin
    for (k = 0; k < ARRAY_SIZE; k = k + 1) begin
        weight_binary[k] = (weight_row_in[k] == 0) ? 1'b1 : 1'b0;
    end
end

// 計算故障 PE 數量並選擇最佳匹配
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        best_match_addr <= 0;
        max_faulty_pes <= 0;
    end else if (state == PROCESS) begin
        best_match_addr <= 0;
        max_faulty_pes <= 0;
        for (integer i = 0; i < NUM_FAULTY_ROWS; i = i + 1) begin
            if (tcam_match[i] && recov_flag[i] == 1'b0) begin
                integer count = 0;
                for (integer j = 0; j < ARRAY_SIZE; j = j + 1) begin
                    count = count + faulty_pe_vector[i][j];
                end
                if (count > max_faulty_pes) begin
                    max_faulty_pes <= count;
                    best_match_addr <= faulty_row_addr[i];
                end
            end
        end
    end
end

// 狀態機
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        weight_idx <= 0;
        done <= 1'b0;
        success <= 1'b0;
        for (integer i = 0; i < NUM_FAULTY_ROWS; i = i + 1) begin
            recov_flag[i] <= 1'b0;
        end
        for (integer i = 0; i < NUM_WEIGHT_ROWS; i = i + 1) begin
            mapping_table[i] <= 0;
        end
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= PROCESS;
                    weight_idx <= 0;
                end
            end
            PROCESS: begin
                if (weight_idx < NUM_WEIGHT_ROWS) begin
                    // 更新映射表
                    if (max_faulty_pes > 0) begin
                        mapping_table[weight_idx] <= best_match_addr;
                        for (integer i = 0; i < NUM_FAULTY_ROWS; i = i + 1) begin
                            if (faulty_row_addr[i] == best_match_addr) begin
                                recov_flag[i] <= 1'b1;
                            end
                        end
                    end else begin
                        mapping_table[weight_idx] <= weight_idx; // 分配到非故障行
                    end
                    weight_idx <= weight_idx + 1;
                end else begin
                    state <= CHECK;
                end
            end
            CHECK: begin
                // 檢查是否所有故障行都已恢復
                success <= 1'b1;
                for (integer i = 0; i < NUM_FAULTY_ROWS; i = i + 1) begin
                    if (recov_flag[i] == 1'b0) begin
                        success <= 1'b0;
                    end
                end
                state <= DONE;
            end
            DONE: begin
                done <= 1'b1;
                state <= IDLE;
            end
        endcase
    end
end

endmodule