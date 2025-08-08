// hybrid_bist.v

module hybrid_bist #(
    parameter SYSTOLIC_SIZE = 8,
    parameter WEIGHT_WIDTH = 8,
    parameter ACTIVATION_WIDTH = 8,
    parameter PARTIAL_SUM_WIDTH = WEIGHT_WIDTH + ACTIVATION_WIDTH + $clog2(SYSTOLIC_SIZE),
    parameter ADDR_WIDTH = $clog2(SYSTOLIC_SIZE),
    parameter SA_TEST_PATTERN_DEPTH = 12,
    parameter TD_TEST_PATTERN_DEPTH = 18,
    parameter MBIST_PATTERN_DEPTH = 8,
    parameter MAX_PATTERN_ADDR_WIDTH = $clog2(TD_TEST_PATTERN_DEPTH)
)(
    // 基本控制信號
    input clk,
    input rst_n,
    input START,
    input test_mode,    // 是否在測試模式
    input BIST_mode,    // 0: MBIST, 1: LBIST
    
    // 與 eNVM 的介面
    output reg test_type,                                   // 0: SA, 1: TD
    output reg [MAX_PATTERN_ADDR_WIDTH-1:0] test_counter,   // eNVM pattern 索引
    output reg [1:0] td_pe_select,                          // TD 測試時的 PE 選擇 (0-3)
    input [WEIGHT_WIDTH-1:0] envm_weight,                   // 從 eNVM 來的權重
    input [ACTIVATION_WIDTH-1:0] envm_activation,           // 從 eNVM 來的激活
    input [PARTIAL_SUM_WIDTH-1:0] envm_answer,              // 從 eNVM 來的預期結果
    
    // 控制 Systolic Array 的信號
    output reg scan_en,                                     // 掃描使能信號
    output reg [SYSTOLIC_SIZE-1:0] PE_disable,             // PE 禁用信號
    
    // Accumulator 控制信號 (MBIST + LBIST 共用)
    output reg acc_wr_en,                                   // Accumulator 寫使能  
    output reg [ADDR_WIDTH-1:0] acc_wr_addr,               // Accumulator 寫地址
    output reg [PARTIAL_SUM_WIDTH*SYSTOLIC_SIZE-1:0] acc_wr_data, // Accumulator 寫資料
    output reg acc_test_mode,                               // Accumulator test mode
    output reg [ADDR_WIDTH-1:0] acc_rd_addr,               // Accumulator 讀地址
    input [PARTIAL_SUM_WIDTH*SYSTOLIC_SIZE-1:0] acc_rd_data, // Accumulator 讀資料
    
    // 測試結果
    output reg test_done,                                   // 測試完成
    output reg test_pass,                                   // 測試通過
    output reg [SYSTOLIC_SIZE-1:0] fault_detected           // 檢測到的故障
);

    // 內部計數器
    reg [MAX_PATTERN_ADDR_WIDTH-1:0] pattern_counter;      // pattern 計數器
    reg [ADDR_WIDTH-1:0] memory_addr;                      // 記憶體地址計數器
    reg [1:0] td_pe_counter;                               // TD 測試 PE 計數器 (0-3)
    reg check_phase;                                       // TD 測試檢查階段 (0: L, 1: C)
    
    // 重複使用的暫存器
    reg [PARTIAL_SUM_WIDTH-1:0] expected_data_reg;         // 通用預期資料暫存器
    reg [PARTIAL_SUM_WIDTH-1:0] backup_data_reg;           // 備用暫存器 (TD測試用)
    
    // Memory Data Generator 的輸出
    wire [PARTIAL_SUM_WIDTH-1:0] mbist_data;
    
    // Comparator 的輸出
    wire [SYSTOLIC_SIZE-1:0] compared_results;
    
    // 狀態機定義
    typedef enum logic [3:0] {
        IDLE            = 4'b0000,
        MBIST_START     = 4'b0001,
        MBIST_WRITE     = 4'b0010,
        MBIST_READ      = 4'b0011,
        MBIST_CHECK     = 4'b0100,
        LBIST_START     = 4'b0101,
        SA_SHIFT        = 4'b0110,
        SA_CAPTURE      = 4'b0111,
        SA_CHECK        = 4'b1000,
        TD_SHIFT        = 4'b1001,
        TD_LAUNCH       = 4'b1010,
        TD_PROPAGATE    = 4'b1011,
        TD_CAPTURE      = 4'b1100,
        TD_CHECK        = 4'b1101,
        COMPLETE        = 4'b1110,
        FAIL            = 4'b1111
    } test_state_t;
    
    test_state_t current_state, next_state;
    
    // 狀態機 - 目前狀態更新
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end
    
    // 狀態機 - 下一狀態邏輯
    always @(*) begin
        next_state = current_state;
        
        case (current_state)
            IDLE: begin
                if (START && test_mode) begin
                    if (!BIST_mode) begin  // MBIST 模式
                        next_state = MBIST_START;
                    end else begin         // LBIST 模式
                        next_state = LBIST_START;
                    end
                end
            end
            
            MBIST_START: begin
                next_state = MBIST_WRITE;
            end
            
            MBIST_WRITE: begin
                if (memory_addr == SYSTOLIC_SIZE-1 && pattern_counter == MBIST_PATTERN_DEPTH-1) begin
                    next_state = MBIST_READ;
                end
            end
            
            MBIST_READ: begin
                // Pipeline 設計：總是進入 CHECK 狀態
                next_state = MBIST_CHECK;
            end
            
            MBIST_CHECK: begin
                if (|compared_results) begin  // 測試失敗
                    next_state = FAIL;
                end else if (memory_addr == SYSTOLIC_SIZE-1 && pattern_counter == MBIST_PATTERN_DEPTH-1) begin
                    next_state = COMPLETE;  // 所有MBIST測試完成
                end else begin
                    next_state = MBIST_READ;  // 繼續下個地址/pattern
                end
            end
            
            LBIST_START: begin
                next_state = SA_SHIFT;
            end
            
            SA_SHIFT: begin
                next_state = SA_CAPTURE;
            end
            
            SA_CAPTURE: begin
                // Pipeline 設計：總是進入 CHECK 狀態
                next_state = SA_CHECK;
            end
            
            SA_CHECK: begin
                if (|compared_results) begin  // 有錯誤
                    next_state = FAIL;
                end else if (pattern_counter == SA_TEST_PATTERN_DEPTH-1) begin
                    next_state = TD_SHIFT;  // SA 測試完成，開始 TD 測試
                end else begin
                    next_state = SA_SHIFT;  // 下一個 SA pattern
                end
            end
            
            TD_SHIFT: begin
                next_state = TD_LAUNCH;
            end
            
            TD_LAUNCH: begin
                // Pipeline 設計：總是進入 PROPAGATE 狀態
                next_state = TD_PROPAGATE;
            end
            
            TD_PROPAGATE: begin
                // 檢查 Launch 結果，同時進行 at-speed propagation
                if (|compared_results) begin  // Launch 階段有錯誤
                    next_state = FAIL;
                end else begin
                    next_state = TD_CAPTURE;
                end
            end
            
            TD_CAPTURE: begin
                // Pipeline 設計：總是進入 CHECK 狀態
                next_state = TD_CHECK;
            end
            
            TD_CHECK: begin
                if (|compared_results) begin  // Capture 階段有錯誤
                    next_state = FAIL;
                end else begin
                    // TD 測試完成
                    if (td_pe_counter == 2'b11) begin  // 4個PE位置都測完
                        if (pattern_counter == TD_TEST_PATTERN_DEPTH-1) begin  // 所有pattern都測完
                            next_state = COMPLETE;
                        end else begin
                            next_state = TD_SHIFT;  // 下一個 TD pattern
                        end
                    end else begin
                        next_state = TD_SHIFT;  // 同一pattern，下一個PE位置
                    end
                end
            end
            
            COMPLETE: begin
                if (!START) begin
                    next_state = IDLE;
                end
            end
            
            FAIL: begin
                if (!START) begin
                    next_state = IDLE;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // 計數器更新邏輯
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pattern_counter <= {MAX_PATTERN_ADDR_WIDTH{1'b0}};
            memory_addr <= {ADDR_WIDTH{1'b0}};
            td_pe_counter <= 2'b00;
            check_phase <= 1'b0;
        end
        else if (START) begin
            pattern_counter <= {MAX_PATTERN_ADDR_WIDTH{1'b0}};
            memory_addr <= {ADDR_WIDTH{1'b0}};
            td_pe_counter <= 2'b00;
            check_phase <= 1'b0;
        end
        else begin
            case (current_state)
                MBIST_START: begin
                    pattern_counter <= {MAX_PATTERN_ADDR_WIDTH{1'b0}};
                    memory_addr <= {ADDR_WIDTH{1'b0}};
                end
                
                MBIST_WRITE: begin
                    if (memory_addr == SYSTOLIC_SIZE-1 && pattern_counter == MBIST_PATTERN_DEPTH-1) begin
                        // 準備進入讀取階段，重置地址
                        memory_addr <= {ADDR_WIDTH{1'b0}};
                        pattern_counter <= {MAX_PATTERN_ADDR_WIDTH{1'b0}};
                    end else if (memory_addr == SYSTOLIC_SIZE-1) begin
                        memory_addr <= {ADDR_WIDTH{1'b0}};
                        pattern_counter <= pattern_counter + 1;
                    end else begin
                        memory_addr <= memory_addr + 1;
                    end
                end
                
                MBIST_CHECK: begin
                    // Pipeline 優化：在檢查當前結果的同時準備下個地址
                    if (~(|compared_results)) begin  // 當前測試通過
                        if (memory_addr == SYSTOLIC_SIZE-1 && pattern_counter == MBIST_PATTERN_DEPTH-1) begin
                            // 所有測試完成，保持當前值
                        end else if (memory_addr == SYSTOLIC_SIZE-1) begin
                            memory_addr <= {ADDR_WIDTH{1'b0}};
                            pattern_counter <= pattern_counter + 1;
                        end else begin
                            memory_addr <= memory_addr + 1;
                        end
                    end
                end
                
                LBIST_START: begin
                    pattern_counter <= {MAX_PATTERN_ADDR_WIDTH{1'b0}};
                    td_pe_counter <= 2'b00;
                    check_phase <= 1'b0;
                end
                
                SA_CHECK: begin
                    if (~(|compared_results)) begin  // SA 測試通過
                        if (pattern_counter < SA_TEST_PATTERN_DEPTH-1) begin
                            pattern_counter <= pattern_counter + 1;
                        end else if (pattern_counter == SA_TEST_PATTERN_DEPTH-1) begin
                            // SA 測試完成，準備 TD 測試
                            pattern_counter <= {MAX_PATTERN_ADDR_WIDTH{1'b0}};
                            td_pe_counter <= 2'b00;
                        end
                    end
                end
                
                TD_CHECK: begin
                    if (~(|compared_results)) begin  // TD 測試通過
                        if (td_pe_counter == 2'b11) begin
                            td_pe_counter <= 2'b00;
                            if (pattern_counter < TD_TEST_PATTERN_DEPTH-1) begin
                                pattern_counter <= pattern_counter + 1;
                            end
                        end else begin
                            td_pe_counter <= td_pe_counter + 1;
                        end
                    end
                end
            endcase
        end
    end
    
    // 輸出邏輯
    always @(*) begin
        // 預設值
        scan_en = 1'b0;
        acc_wr_en = 1'b0;
        acc_test_mode = 1'b0;
        test_done = 1'b0;
        test_pass = 1'b0;
        PE_disable = {SYSTOLIC_SIZE{1'b0}};
        test_type = 1'b0;
        test_counter = pattern_counter;
        td_pe_select = td_pe_counter;
        acc_wr_addr = memory_addr;
        acc_rd_addr = memory_addr;
        acc_wr_data = {SYSTOLIC_SIZE{mbist_data}};  // 複製相同資料到所有位置
        fault_detected = compared_results;
        
        case (current_state)
            MBIST_WRITE: begin
                acc_wr_en = 1'b1;
                acc_test_mode = 1'b1;
            end
            
            MBIST_READ: begin
                acc_wr_en = 1'b0;
                acc_test_mode = 1'b1;
                acc_rd_addr = memory_addr;  // Pipeline: 設定讀取地址
            end
            
            MBIST_CHECK: begin
                acc_test_mode = 1'b1;
                // Pipeline: 檢查上個cycle設定地址的結果
                test_pass = ~(|compared_results);
                
                // 同時準備下個讀取地址
                if (~(|compared_results) && 
                   !(memory_addr == SYSTOLIC_SIZE-1 && pattern_counter == MBIST_PATTERN_DEPTH-1)) begin
                    if (memory_addr == SYSTOLIC_SIZE-1) begin
                        acc_rd_addr = {ADDR_WIDTH{1'b0}};  // 下個pattern的第一個地址
                    end else begin
                        acc_rd_addr = memory_addr + 1;     // 下個地址
                    end
                end
            end
            
            SA_SHIFT: begin
                scan_en = 1'b1;
                test_type = 1'b0;  // SA 測試
                acc_test_mode = 1'b1;
            end
            
            SA_CAPTURE: begin
                scan_en = 1'b0;
                test_type = 1'b0;
                acc_test_mode = 1'b1;
                acc_rd_addr = {ADDR_WIDTH{1'b0}};  // Pipeline: 設定讀取地址
            end
            
            SA_CHECK: begin
                acc_test_mode = 1'b1;
                // Pipeline: 檢查上個cycle設定地址的結果
                test_pass = ~(|compared_results);
                
                // 準備下個pattern的讀取（如果需要的話）
                if (~(|compared_results) && pattern_counter < SA_TEST_PATTERN_DEPTH-1) begin
                    acc_rd_addr = {ADDR_WIDTH{1'b0}};
                end
            end
            
            TD_SHIFT: begin
                scan_en = 1'b1;
                test_type = 1'b1;  // TD 測試
                acc_test_mode = 1'b1;
            end
            
            TD_LAUNCH: begin
                scan_en = 1'b0;
                test_type = 1'b1;
                acc_test_mode = 1'b1;
                acc_rd_addr = {ADDR_WIDTH{1'b0}};  // Pipeline: 設定讀取地址 (for L)
            end
            
            TD_PROPAGATE: begin
                test_type = 1'b1;
                acc_test_mode = 1'b1;
                // Pipeline: 檢查 Launch (L) 的結果
                test_pass = ~(|compared_results);
            end
            
            TD_CAPTURE: begin
                test_type = 1'b1;
                acc_test_mode = 1'b1;
                acc_rd_addr = {ADDR_WIDTH{1'b0}};  // Pipeline: 設定讀取地址 (for C)
            end
            
            TD_CHECK: begin
                acc_test_mode = 1'b1;
                // Pipeline: 檢查 Capture (C) 的結果
                test_pass = ~(|compared_results);
                
                // 準備下個測試的讀取地址
                if (~(|compared_results)) begin
                    acc_rd_addr = {ADDR_WIDTH{1'b0}};
                end
            end
            
            COMPLETE: begin
                test_done = 1'b1;
                test_pass = 1'b1;
            end
            
            FAIL: begin
                test_done = 1'b1;
                test_pass = 1'b0;
            end
        endcase
    end
    
    // 暫存器更新邏輯
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            expected_data_reg <= {PARTIAL_SUM_WIDTH{1'b0}};
            backup_data_reg <= {PARTIAL_SUM_WIDTH{1'b0}};
        end
        else begin
            case (current_state)
                MBIST_WRITE: begin
                    expected_data_reg <= mbist_data;  // 儲存 MBIST 預期資料
                end
                
                SA_SHIFT: begin
                    expected_data_reg <= envm_answer;  // 儲存 SA 預期結果
                end
                
                TD_SHIFT: begin
                    expected_data_reg <= envm_answer;  // 儲存 L 的預期結果
                    // 注意：如果 eNVM 支援分別提供 L 和 C 的結果，可以加上：
                    // backup_data_reg <= envm_C_answer;  // 儲存 C 的預期結果
                end
                
                TD_LAUNCH: begin
                    // TD 測試中，L 的預期結果已經在 TD_SHIFT 時載入
                    // 這裡可以載入 C 的預期結果（如果有的話）
                    backup_data_reg <= envm_answer;  // 假設這是 C 的預期結果
                end
            endcase
        end
    end

    // Memory Data Generator 實例化
    Memory_data_generator #(
        .SYSTOLIC_SIZE(SYSTOLIC_SIZE),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .ACTIVATION_WIDTH(ACTIVATION_WIDTH),
        .PARTIAL_SUM_WIDTH(PARTIAL_SUM_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .MBIST_PATTERN_DEPTH(MBIST_PATTERN_DEPTH)
    ) memory_data_gen_inst (
        .addr(pattern_counter[ADDR_WIDTH-1:0]),  // 使用 pattern_counter 的低位
        .MBIST_data(mbist_data)
    );

    // Comparator 實例化 - 純組合邏輯
    Comparator #(
        .SYSTOLIC_SIZE(SYSTOLIC_SIZE),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .ACTIVATION_WIDTH(ACTIVATION_WIDTH),
        .PARTIAL_SUM_WIDTH(PARTIAL_SUM_WIDTH)
    ) comparator_inst (
        .correct_answer(expected_data_reg),      // 預期結果
        .partial_sum_flat(acc_rd_data),         // 從 Accumulator 讀取的資料
        .comparaed_results(compared_results)
    );

endmodule