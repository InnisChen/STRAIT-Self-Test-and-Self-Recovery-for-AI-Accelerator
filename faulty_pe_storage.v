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
    parameter FAULTY_STORAGE_DEPTH = 8,
    parameter STORAGE_ADDR_WIDTH = $clog2(FAULTY_STORAGE_DEPTH),
    parameter ADDR_WIDTH = $clog2(SYSTOLIC_SIZE)
)(
    input wire clk,
    input wire rst_n,
    
    // Write interface (from eNVM) - 接收攤平的一維向量
    input wire wr_en,
    input wire [FAULTY_STORAGE_DEPTH*SYSTOLIC_SIZE-1:0] faulty_patterns_flat,
    input wire [FAULTY_STORAGE_DEPTH*ADDR_WIDTH-1:0] faulty_row_addrs_flat,
    input wire [FAULTY_STORAGE_DEPTH-1:0] faulty_valid_mask, // 哪些 entry 是有效的
    
    // Weight allocation interface - 已經過 zero weight detection 的結果
    input wire [SYSTOLIC_SIZE-1:0] zero_weight_flags,  // 1: zero weight, 0: non-zero weight
    input wire weight_valid,
    input wire [ADDR_WIDTH-1:0] current_row_addr,     // 當前要處理的 row 地址
    
    // Output to Mapping Table - 配置結果
    output reg match_success,                          // 步驟2,3配置成功
    output reg match_failed,                           // 步驟2,3配置失敗，需要執行步驟4
    output reg [ADDR_WIDTH-1:0] faulty_row_addr,      // 有錯誤的 row 地址 (只在步驟2,3使用)
    
    // 輸出給 Mapping Table 的初始化資訊
    output wire [SYSTOLIC_SIZE-1:0] faulty_rows_mask,  // 哪些 row 有故障
    
    // 輸出給 Recovery result check 和 Mapping Table
    output wire [FAULTY_STORAGE_DEPTH-1:0] valid_bits_out,
    output wire all_faulty_matched  // 所有錯誤都已匹配完成
);

    // Internal storage
    reg [SYSTOLIC_SIZE-1:0] faulty_storage [0:FAULTY_STORAGE_DEPTH-1];
    reg [ADDR_WIDTH-1:0] row_addr_storage [0:FAULTY_STORAGE_DEPTH-1]; // 儲存錯誤的 row 地址
    reg [FAULTY_STORAGE_DEPTH-1:0] valid_storage;    // Valid bit: 1=可使用, 0=已使用過
    reg [SYSTOLIC_SIZE-1:0] faulty_rows_info;        // 靜態錯誤 row 資訊
    
    // 攤平向量的解包
    wire [SYSTOLIC_SIZE-1:0] faulty_patterns [0:FAULTY_STORAGE_DEPTH-1];
    wire [ADDR_WIDTH-1:0] faulty_row_addrs [0:FAULTY_STORAGE_DEPTH-1];
    
    genvar i;
    generate
        for (i = 0; i < FAULTY_STORAGE_DEPTH; i=i+1) begin : unpack_faulty_data
            assign faulty_patterns[i] = faulty_patterns_flat[i*SYSTOLIC_SIZE +: SYSTOLIC_SIZE];
            assign faulty_row_addrs[i] = faulty_row_addrs_flat[i*ADDR_WIDTH +: ADDR_WIDTH];
        end
    endgenerate

    // 輸出靜態錯誤 row 資訊給 Mapping Table
    assign faulty_rows_mask = faulty_rows_info;
    assign valid_bits_out = valid_storage;       // 輸出給 Recovery result check
    assign all_faulty_matched = ~(|valid_storage); // 所有錯誤都已匹配完成

    // Step 1: CAM-based quick filtering - 快速排除不可能的候選者
    wire [FAULTY_STORAGE_DEPTH-1:0] quick_candidates;
    
    generate
        for (i = 0; i < FAULTY_STORAGE_DEPTH; i=i+1) begin : cam_quick_filter
            wire [SYSTOLIC_SIZE-1:0] conflict_check;
            
            // 檢查衝突 (non-zero weight 但 faulty PE)
            assign conflict_check = (~zero_weight_flags) & faulty_storage[i];
            
            // CAM-style 快速檢查：valid 且沒有衝突
            assign quick_candidates[i] = valid_storage[i] & (~(|conflict_check));
        end
    endgenerate

    // Step 2: Tree-based precise matching count
    wire [$clog2(SYSTOLIC_SIZE+1)-1:0] match_count [0:FAULTY_STORAGE_DEPTH-1];
    
    // 在模組級別計算常數，避免在generate中使用localparam
    localparam COUNT_WIDTH = $clog2(SYSTOLIC_SIZE+1);
    
    // 針對SYSTOLIC_SIZE=8特化的樹狀加法（可根據需要修改）
    generate
        if (SYSTOLIC_SIZE == 8) begin : tree_8bit
            for (i = 0; i < FAULTY_STORAGE_DEPTH; i=i+1) begin : precise_tree_matching
                wire [SYSTOLIC_SIZE-1:0] match_result;
                
                // 精確匹配計算 (zero weight 且 faulty PE)
                assign match_result = zero_weight_flags & faulty_storage[i];
                
                // 8-bit樹狀加法結構 - 3層
                // Level 1: 4個2-bit加法器 (並行)
                wire [1:0] level1_0, level1_1, level1_2, level1_3;
                assign level1_0 = {1'b0, match_result[0]} + {1'b0, match_result[1]};
                assign level1_1 = {1'b0, match_result[2]} + {1'b0, match_result[3]};
                assign level1_2 = {1'b0, match_result[4]} + {1'b0, match_result[5]};
                assign level1_3 = {1'b0, match_result[6]} + {1'b0, match_result[7]};
                
                // Level 2: 2個3-bit加法器 (並行)
                wire [2:0] level2_0, level2_1;
                assign level2_0 = {1'b0, level1_0} + {1'b0, level1_1};
                assign level2_1 = {1'b0, level1_2} + {1'b0, level1_3};
                
                // Level 3: 1個4-bit加法器
                wire [3:0] level3_result;
                assign level3_result = {1'b0, level2_0} + {1'b0, level2_1};
                
                // 只對通過快速過濾的候選者輸出匹配數
                assign match_count[i] = quick_candidates[i] ? level3_result[COUNT_WIDTH-1:0] : {COUNT_WIDTH{1'b0}};
            end
        end else if (SYSTOLIC_SIZE == 16) begin : tree_16bit
            for (i = 0; i < FAULTY_STORAGE_DEPTH; i=i+1) begin : precise_tree_matching
                wire [SYSTOLIC_SIZE-1:0] match_result;
                assign match_result = zero_weight_flags & faulty_storage[i];
                
                // 16-bit樹狀加法結構 - 4層
                // Level 1: 8個2-bit加法器
                wire [1:0] level1 [0:7];
                genvar j;
                for (j = 0; j < 8; j = j + 1) begin : level1_add
                    assign level1[j] = {1'b0, match_result[j*2]} + {1'b0, match_result[j*2+1]};
                end
                
                // Level 2: 4個3-bit加法器
                wire [2:0] level2 [0:3];
                for (j = 0; j < 4; j = j + 1) begin : level2_add
                    assign level2[j] = {1'b0, level1[j*2]} + {1'b0, level1[j*2+1]};
                end
                
                // Level 3: 2個4-bit加法器
                wire [3:0] level3 [0:1];
                for (j = 0; j < 2; j = j + 1) begin : level3_add
                    assign level3[j] = {1'b0, level2[j*2]} + {1'b0, level2[j*2+1]};
                end
                
                // Level 4: 1個5-bit加法器
                wire [4:0] level4_result;
                assign level4_result = {1'b0, level3[0]} + {1'b0, level3[1]};
                
                assign match_count[i] = quick_candidates[i] ? level4_result[COUNT_WIDTH-1:0] : {COUNT_WIDTH{1'b0}};
            end
        end else begin : tree_general
            // 通用版本：對於其他大小，回退到函數實現
            for (i = 0; i < FAULTY_STORAGE_DEPTH; i=i+1) begin : precise_general_matching
                wire [SYSTOLIC_SIZE-1:0] match_result;
                assign match_result = zero_weight_flags & faulty_storage[i];
                
                // 使用組合邏輯函數計算
                reg [COUNT_WIDTH-1:0] count_result;
                integer bit_idx;
                
                always @(*) begin
                    count_result = {COUNT_WIDTH{1'b0}};
                    for (bit_idx = 0; bit_idx < SYSTOLIC_SIZE; bit_idx = bit_idx + 1) begin
                        count_result = count_result + match_result[bit_idx];
                    end
                end
                
                assign match_count[i] = quick_candidates[i] ? count_result : {COUNT_WIDTH{1'b0}};
            end
        end
    endgenerate

    // Step 3: CAM-style priority encoding - 選擇最佳匹配
    reg [$clog2(SYSTOLIC_SIZE+1)-1:0] max_match_count;
    reg [STORAGE_ADDR_WIDTH-1:0] best_match_index;
    reg match_found;
    
    // 使用 priority encoder 的概念來選擇最佳匹配
    integer j, m;
    always @(*) begin
        max_match_count = {COUNT_WIDTH{1'b0}};
        best_match_index = {STORAGE_ADDR_WIDTH{1'b0}};
        match_found = 1'b0;
        
        // Priority encoding: 尋找匹配數最多的 entry
        for (j = 0; j < FAULTY_STORAGE_DEPTH; j=j+1) begin
            if (quick_candidates[j] && (match_count[j] > max_match_count)) begin
                max_match_count = match_count[j];
                best_match_index = j;
                match_found = 1'b1;
            end
        end
    end

    // Write operation and allocation logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset: 清空所有儲存
            for (m = 0; m < FAULTY_STORAGE_DEPTH; m=m+1) begin
                faulty_storage[m] <= {SYSTOLIC_SIZE{1'b0}};
                row_addr_storage[m] <= {ADDR_WIDTH{1'b0}};
            end
            valid_storage <= {FAULTY_STORAGE_DEPTH{1'b0}};
            faulty_rows_info <= {SYSTOLIC_SIZE{1'b0}};
            match_success <= 1'b0;
            match_failed <= 1'b0;
            faulty_row_addr <= {ADDR_WIDTH{1'b0}};
        end
        else if (wr_en) begin
            // 一次性寫入所有錯誤模式
            for (m = 0; m < FAULTY_STORAGE_DEPTH; m=m+1) begin
                faulty_storage[m] <= faulty_patterns[m];
                row_addr_storage[m] <= faulty_row_addrs[m];
            end
            valid_storage <= faulty_valid_mask;  // 初始化 valid bit (1=可使用)
            
            // 計算哪些 row 有錯誤（靜態資訊，一次性設定）
            faulty_rows_info <= {SYSTOLIC_SIZE{1'b0}};
            for (m = 0; m < FAULTY_STORAGE_DEPTH; m=m+1) begin
                if (faulty_valid_mask[m]) begin
                    faulty_rows_info[faulty_row_addrs[m]] <= 1'b1;
                end
            end
            
            match_success <= 1'b0;
            match_failed <= 1'b0;
        end
        else if (weight_valid && match_found) begin
            // Step 2 & 3: 找到匹配，進行分配
            match_success <= 1'b1;
            faulty_row_addr <= row_addr_storage[best_match_index];     // 錯誤的 row
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

endmodule