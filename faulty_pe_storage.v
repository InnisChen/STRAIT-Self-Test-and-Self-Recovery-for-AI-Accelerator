/*
 * CAM-Optimized Faulty PE Storage with Tree-based Counting
 * 
 * 採用類似 CAM 的兩階段架構：
 * 1. CAM-style Quick Filter: 快速排除不可能的候選者（避免衝突檢查）
 * 2. Precise Tree Counting: 使用樹狀結構並行計算匹配數
 * 3. Priority Encoding: 選擇最佳匹配
 * 
 * 優勢：
 * - 樹狀計數結構可擴展到任意大小陣列
 * - 並行計算，延遲為 O(log N)
 * - 硬體成本與線性方案相同，但時序更好
 */

module faulty_pe_storage #(
    parameter SYSTOLIC_SIZE = 8,
    parameter ADDR_WIDTH = $clog2(SYSTOLIC_SIZE)
)(
    input wire clk,
    input wire rst_n,
    
    // Write interface (from eNVM) - 接收攤平的一維向量
    input wire wr_en,
    input wire [SYSTOLIC_SIZE*SYSTOLIC_SIZE-1:0] faulty_patterns_flat,
    
    // Weight allocation interface - 已經過 zero weight detection 的結果
    input wire [SYSTOLIC_SIZE-1:0] zero_weight_flags,  // 1: zero weight, 0: non-zero weight
    input wire weight_valid,
    input wire [ADDR_WIDTH-1:0] current_row_addr,     // 當前要處理的 row 地址

    // 正常使用時，讀取錯誤資料給pe_disable
    input wire [ADDR_WIDTH-1:0] read_addr, // 需要讀取的地址
    
    // Output to Mapping Table - 配置結果
    output reg match_success,                          // 步驟2,3配置成功
    output reg match_failed,                           // 步驟2,3配置失敗，需要執行步驟4
    output reg [ADDR_WIDTH-1:0] faulty_row_addr,      // 有錯誤的 row 地址 (只在步驟2,3使用)
    
    // 輸出給 Mapping Table 的初始化資訊
    output wire [SYSTOLIC_SIZE-1:0] faulty_rows_mask,  // 哪些 row 有故障

    // 輸出錯誤資訊當作pe_disable
    output wire [SYSTOLIC_SIZE-1:0] pe_disable_out, // 每個PE是否disable
    
    // 輸出給 Recovery result check 和 Mapping Table
    output wire [SYSTOLIC_SIZE-1:0] valid_bits_out,
    output wire all_faulty_matched  // 所有錯誤都已匹配完成
);

    // Internal storage
    reg [SYSTOLIC_SIZE-1:0] faulty_storage [0:SYSTOLIC_SIZE-1];
    reg [SYSTOLIC_SIZE-1:0] valid_storage;    // Valid bit: 1=可使用, 0=已使用過
    reg [SYSTOLIC_SIZE-1:0] faulty_rows_info;        // 靜態錯誤 row 資訊
    
    // 攤平向量的解包
    wire [SYSTOLIC_SIZE-1:0] faulty_patterns [0:SYSTOLIC_SIZE-1];
    
    genvar k;
    generate
        for (k = 0; k < SYSTOLIC_SIZE; k=k+1) begin : unpack_faulty_data
            assign faulty_patterns[k] = faulty_patterns_flat[k*SYSTOLIC_SIZE +: SYSTOLIC_SIZE];
        end
    endgenerate

    // 輸出靜態錯誤 row 資訊給 Mapping Table
    assign faulty_rows_mask = faulty_rows_info;
    assign valid_bits_out = valid_storage;       // 輸出給 Recovery result check
    assign all_faulty_matched = ~(|valid_storage); // 所有錯誤都已匹配完成

    // Step 1: CAM-based quick filtering - 快速排除不可能的候選者
    wire [SYSTOLIC_SIZE-1:0] quick_candidates;
    
    generate
        for (k = 0; k < SYSTOLIC_SIZE; k=k+1) begin : cam_quick_filter
            wire [SYSTOLIC_SIZE-1:0] conflict_check;
            
            // 檢查衝突 (non-zero weight 但 faulty PE)
            assign conflict_check = (~zero_weight_flags) & faulty_storage[k];
            
            // CAM-style 快速檢查：有錯誤pattern 且沒有衝突
            assign quick_candidates[k] = valid_storage[k] & (~(|conflict_check));
        end
    endgenerate

    // Step 2: Tree-based precise matching count - 通用版本
    wire [$clog2(SYSTOLIC_SIZE+1)-1:0] match_count [0:SYSTOLIC_SIZE-1];
    
    localparam COUNT_WIDTH = $clog2(SYSTOLIC_SIZE+1);
    
    generate
        for (k = 0; k < SYSTOLIC_SIZE; k=k+1) begin : precise_tree_matching
            wire [SYSTOLIC_SIZE-1:0] match_result;
            assign match_result = zero_weight_flags & faulty_storage[k];
            
            // 通用樹狀加法計算
            reg [COUNT_WIDTH-1:0] count_result;
            integer bit_idx;
            
            always @(*) begin
                count_result = {COUNT_WIDTH{1'b0}};
                for (bit_idx = 0; bit_idx < SYSTOLIC_SIZE; bit_idx = bit_idx + 1) begin
                    count_result = count_result + match_result[bit_idx];
                end
            end
            
            assign match_count[k] = quick_candidates[k] ? count_result : {COUNT_WIDTH{1'b0}};
        end
    endgenerate

    // Step 3: CAM-style priority encoding - 選擇最佳匹配
    reg [$clog2(SYSTOLIC_SIZE+1)-1:0] max_match_count;
    reg [ADDR_WIDTH-1:0] best_match_index;
    reg match_found;
    
    // 使用 priority encoder 的概念來選擇最佳匹配
    integer i;
    always @(*) begin
        max_match_count = {COUNT_WIDTH{1'b0}};
        best_match_index = {ADDR_WIDTH{1'b0}};
        match_found = 1'b0;
        
        // Priority encoding: 尋找匹配數最多的 entry
        for (i = 0; i < SYSTOLIC_SIZE; i=i+1) begin
            if (quick_candidates[i] && (match_count[i] > max_match_count)) begin
                max_match_count = match_count[i];
                best_match_index = i;
                match_found = 1'b1;
            end
        end
    end

    // Write operation and allocation logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset: 清空所有儲存
            for (i = 0; i < SYSTOLIC_SIZE; i=i+1) begin
                faulty_storage[i] <= {SYSTOLIC_SIZE{1'b0}};
            end
            valid_storage <= {SYSTOLIC_SIZE{1'b1}}; //改成1
            faulty_rows_info <= {SYSTOLIC_SIZE{1'b0}};
            match_success <= 1'b0;
            match_failed <= 1'b0;
            faulty_row_addr <= {ADDR_WIDTH{1'b0}};
        end
        else if (wr_en) begin
            // 一次性寫入所有錯誤模式（按順序：index 0 對應 row 0）
            for (i = 0; i < SYSTOLIC_SIZE; i=i+1) begin
                faulty_storage[i] <= faulty_patterns[i];
                
                // 根據錯誤pattern自動設定valid bit和faulty_rows_info
                if (|faulty_patterns[i]) begin
                    valid_storage[i] <= 1'b1;  // 有錯誤pattern的設為可使用
                    faulty_rows_info[i] <= 1'b1;  // 標記該row有錯誤（index即為row number）
                end else begin
                    valid_storage[i] <= 1'b0;  // 全0 pattern的設為不可使用
                    faulty_rows_info[i] <= 1'b0;  // 標記該row沒有錯誤
                end
            end
            
            match_success <= 1'b0;
            match_failed <= 1'b0;
        end
        else if (weight_valid && match_found) begin
            // Step 2 & 3: 找到匹配，進行分配
            match_success <= 1'b1;
            faulty_row_addr <= best_match_index;     // 錯誤的 row（index即為row number）
            valid_storage[best_match_index] <= 1'b0;                   // 標記為已使用
            match_failed <= 1'b0;
        end
        else if (weight_valid && !match_found) begin
            // Step 2 & 3 匹配失敗，通知 Mapping Table 執行步驟4
            match_success <= 1'b0;
            match_failed <= 1'b1;  // 告知 Mapping Table 需要執行步驟4
        end
        else begin
            match_success <= 1'b0;
            match_failed <= 1'b0;
        end
    end

    assign pe_disable_out = faulty_storage[read_addr]; // 根據讀取地址輸出 PE disable 狀態

endmodule