module mapping_table #(
    parameter SYSTOLIC_SIZE = 8,
    parameter ADDR_WIDTH = $clog2(SYSTOLIC_SIZE)
)(
    input wire clk,
    input wire rst_n,
    
    // 從 Faulty PE Storage 接收初始化資訊
    input wire [SYSTOLIC_SIZE-1:0] faulty_rows_mask,    // 從 Faulty PE Storage 來
    
    // Update interface (從 Faulty PE Storage 來的分配結果)
    input wire match_success,                      // 步驟2,3配置成功
    input wire match_failed,                       // 步驟2,3配置失敗，需要步驟4
    input wire [ADDR_WIDTH-1:0] faulty_addr,      // 錯誤的原始地址 (只在步驟2,3使用)
    input wire [ADDR_WIDTH-1:0] current_row_addr, // 當前處理的row地址 (兩種情況都使用)
    input wire all_faulty_matched,                // 所有錯誤都已匹配完成
    input wire wr_en,                         // eNVM 寫入信號，用於初始化時機
    
    // Query interface (地址轉換)
    input wire [ADDR_WIDTH-1:0] read_addr,
    output wire [ADDR_WIDTH-1:0] mapped_addr,
    
    // Allocation status output
    output wire allocation_failed                  // 無法找到合適的 row 進行配置
);

    // Internal state
    reg [SYSTOLIC_SIZE-1:0] faulty_checker;      // 1: 該row有故障, 0: 無故障
    reg [SYSTOLIC_SIZE-1:0] allocation_checker;  // 1: 已被重新配置, 0: 未配置
    reg [ADDR_WIDTH-1:0] mapping_table_reg [0:SYSTOLIC_SIZE-1]; // 映射表
    reg faulty_checker_initialized;              // 追蹤是否已經初始化過
    reg allocation_failed_reg;                   // 配置失敗標記
    reg envm_wr_en_delayed;                      // 延遲一個 cycle 的 eNVM 寫入信號
    
    // 組合邏輯：尋找可用的 row
    reg [ADDR_WIDTH-1:0] selected_healthy_row;
    reg [ADDR_WIDTH-1:0] selected_faulty_row;
    reg found_healthy_row;
    reg found_faulty_row;
    
    // 搜尋邏輯（組合邏輯）
    integer i;
    always @(*) begin
        selected_healthy_row = {ADDR_WIDTH{1'b0}};
        selected_faulty_row = {ADDR_WIDTH{1'b0}};
        found_healthy_row = 1'b0;
        found_faulty_row = 1'b0;
        
        // 優先尋找健康且未配置的 row
        for (i = 0; i < SYSTOLIC_SIZE; i=i+1) begin
            if (!faulty_checker[i] && !allocation_checker[i]) begin
                if (!found_healthy_row) begin  // 分離條件檢查
                    selected_healthy_row = i;
                    found_healthy_row = 1'b1;
                end
            end
        end
        
        // 尋找錯誤但未配置的 row (只用於步驟4的最後手段)
        for (i = 0; i < SYSTOLIC_SIZE; i=i+1) begin
            if (faulty_checker[i] && !allocation_checker[i]) begin
                if (!found_faulty_row) begin  // 分離條件檢查
                    selected_faulty_row = i;
                    found_faulty_row = 1'b1;
                end
            end
        end
    end
    
    assign allocation_failed = allocation_failed_reg;

    // 初始化和配置邏輯
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            faulty_checker <= {SYSTOLIC_SIZE{1'b0}};
            allocation_checker <= {SYSTOLIC_SIZE{1'b0}};
            faulty_checker_initialized <= 1'b0;
            allocation_failed_reg <= 1'b0;
            envm_wr_en_delayed <= 1'b0;
            
            for (i = 0; i < SYSTOLIC_SIZE; i=i+1) begin
                // mapping_table_reg[i] <= i; // 初始映射為自己
            end
        end
        else begin
            // 延遲 eNVM 寫入信號
            envm_wr_en_delayed <= wr_en;
            
            if (envm_wr_en_delayed && !faulty_checker_initialized) begin
                // 使用延遲信號進行初始化，此時 faulty_rows_mask 已穩定
                faulty_checker <= faulty_rows_mask;  // 使用靜態錯誤資訊初始化
                faulty_checker_initialized <= 1'b1;
            end
            else if (match_success) begin
                // 步驟2,3的分配結果：用當前row替代錯誤row
                mapping_table_reg[faulty_addr] <= current_row_addr;        // 錯誤row映射到當前row
                allocation_checker[faulty_addr] <= 1'b1;                   // 錯誤row被標記為已配置
                allocation_failed_reg <= 1'b0;                             // 清除失敗標記
            end
            else if (all_faulty_matched) begin
                // 所有錯誤已處理完，直接分配到健康row
                if (found_healthy_row) begin
                    mapping_table_reg[selected_healthy_row] <= current_row_addr;
                    allocation_checker[selected_healthy_row] <= 1'b1;
                    allocation_failed_reg <= 1'b0;
                end
                else begin
                    // 連健康的都沒有了，這是異常情況
                    allocation_failed_reg <= 1'b1;
                end
            end
            else if (match_failed) begin
                // 還有未匹配的錯誤，執行步驟4
                if (found_healthy_row) begin
                    // 找到健康且未配置的 row
                    mapping_table_reg[selected_healthy_row] <= current_row_addr;
                    allocation_checker[selected_healthy_row] <= 1'b1;
                    allocation_failed_reg <= 1'b0;
                end
                else if (found_faulty_row) begin
                    // 被迫分配給錯誤但未配置的 row
                    mapping_table_reg[selected_faulty_row] <= current_row_addr;
                    allocation_checker[selected_faulty_row] <= 1'b1;
                    allocation_failed_reg <= 1'b1;  // 標記為失敗
                end
                else begin
                    // 完全沒有可用的 row，保持原映射
                    allocation_failed_reg <= 1'b1;
                end
            end
            else begin
                // 清除失敗標記（在非配置狀態下）
                allocation_failed_reg <= 1'b0;
            end
        end
    end

    // Query logic - 地址轉換（純組合邏輯）
    assign mapped_addr = mapping_table_reg[read_addr];

endmodule