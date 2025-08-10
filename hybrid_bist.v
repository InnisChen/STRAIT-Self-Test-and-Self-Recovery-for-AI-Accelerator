// hybrid_bist.v
// Enhanced version with proper TD testing strategy

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
    // 基本控制信號 - inputs
    input clk,
    input rst_n,
    input START,
    input test_mode,    // 是否在測試模式
    input BIST_mode,    // 0: MBIST, 1: LBIST
    input activation_valid, // 外部送入，用於正常運作時的地址計數
    
    // 與 eNVM 的介面 - inputs
    input [WEIGHT_WIDTH-1:0] envm_weight,                   // 從 eNVM 來的權重
    input [ACTIVATION_WIDTH-1:0] envm_activation,           // 從 eNVM 來的激活
    input [PARTIAL_SUM_WIDTH-1:0] envm_answer,             // 從 eNVM 來的預期結果
    
    // 診斷電路回饋信號 - inputs
    input [SYSTOLIC_SIZE-1:0] single_pe_detection,         // 單個PE的錯誤檢測結果
    input row_fault_detection,                             // 行錯誤檢測結果
    input column_fault_detection,                          // 列錯誤檢測結果
    
    // Accumulator 回饋信號 - inputs
    input [PARTIAL_SUM_WIDTH*SYSTOLIC_SIZE-1:0] partial_sum_flat, // Accumulator 讀資料
    
    // 與 eNVM 的介面 - outputs
    output reg test_type,                                    // 0: SA, 1: TD
    output reg [MAX_PATTERN_ADDR_WIDTH-1:0] test_counter,   // eNVM pattern 索引
    output reg [1:0] td_pe_select,                          // TD 測試時的 PE 選擇 (0-3)
    output reg detection_en,                                // 告知 eNVM 可以開始讀取診斷資料
    output reg [ADDR_WIDTH-1:0] detection_addr,            // 診斷地址
    
    // 控制 Systolic Array 的信號 - outputs
    output reg scan_en,                                     // 掃描使能信號
    
    // 給 BISR 的控制信號 - outputs
    output reg envm_wr_en,                                  // eNVM 寫入使能
    output reg allocation_start,                            // 開始權重配置信號
    output reg [ADDR_WIDTH-1:0] read_addr,                 // BISR 讀取地址
    
    // 給 Weight_partialsum_buffer 的控制信號 - outputs
    output reg [SYSTOLIC_SIZE*WEIGHT_WIDTH-1:0] weight_in_test_flat,        // 測試權重
    output reg [SYSTOLIC_SIZE*PARTIAL_SUM_WIDTH-1:0] partial_sum_test_flat,  // 測試部分和
    
    // 給 Activation_buffer 的激活控制信號 - outputs
    output reg [SYSTOLIC_SIZE*ACTIVATION_WIDTH-1:0] activation_in_test_flat, // 測試激活
    
    // 診斷電路控制信號 - outputs
    output reg diagnosis_start_en,                          // 診斷使能信號
    
    // Accumulator 控制信號 (MBIST + LBIST 共用) - outputs
    output reg acc_wr_en,                                   // Accumulator 寫使能  
    output reg [ADDR_WIDTH-1:0] acc_wr_addr,               // Accumulator 寫地址
    output reg [PARTIAL_SUM_WIDTH*SYSTOLIC_SIZE-1:0] acc_wr_data, // Accumulator 寫資料
    output reg acc_test_mode,                               // Accumulator test mode
    output reg [ADDR_WIDTH-1:0] acc_rd_addr,               // Accumulator 讀地址
    
    // Activation_mem 控制信號 - outputs
    output reg activation_mem_wr_en,                        // Activation memory 寫使能
    output reg [ADDR_WIDTH-1:0] activation_mem_wr_addr,    // Activation memory 寫地址
    
    // 測試結果 - outputs
    output reg test_done,                                   // 測試完成
    output reg MBIST_test_result,                          // MBIST 測試結果
    output reg LBIST_test_result,                          // LBIST 測試結果
    output [SYSTOLIC_SIZE-1:0] compared_results             // 比較結果
);

    // 內部計數器
    reg [MAX_PATTERN_ADDR_WIDTH-1:0] pattern_counter;      // pattern 計數器
    reg [ADDR_WIDTH-1:0] memory_addr;                      // 記憶體地址計數器
    reg [1:0] td_pe_counter;                               // TD 測試 PE 計數器 (0-3)
    reg [ADDR_WIDTH-1:0] diagnosis_row_counter;            // 診斷行計數器
    
    // 正常運作時的地址計數器
    reg [ADDR_WIDTH-1:0] normal_addr_counter;              // 正常運作地址計數器
    
    // 重複使用的暫存器
    reg [PARTIAL_SUM_WIDTH-1:0] expected_data_reg;         // 通用預期資料暫存器
    
    // Memory Data Generator 的輸出
    wire [PARTIAL_SUM_WIDTH-1:0] mbist_data;
    
    // 狀態機定義
    typedef enum logic [4:0] {
        IDLE                = 5'b00000,
        MBIST_START         = 5'b00001,
        MBIST_WRITE         = 5'b00010,
        MBIST_READ          = 5'b00011,
        MBIST_CHECK         = 5'b00100,
        LBIST_START         = 5'b00101,
        SA_SHIFT            = 5'b00110,
        SA_CAPTURE          = 5'b00111,
        SA_CHECK            = 5'b01000,
        TD_SHIFT            = 5'b01001,
        TD_LAUNCH           = 5'b01010,
        TD_PROPAGATE        = 5'b01011,
        TD_CAPTURE          = 5'b01100,
        TD_CHECK            = 5'b01101,
        DIAGNOSIS           = 5'b01110,
        DIAGNOSIS_STORE     = 5'b01111,
        COMPLETE            = 5'b10000,
        FAIL                = 5'b10001,
        NORMAL_OPERATION    = 5'b10010
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
                end else if (!test_mode) begin
                    next_state = NORMAL_OPERATION;  // 正常運作模式
                end
            end
            
            // MBIST 狀態
            MBIST_START: begin
                next_state = MBIST_WRITE;
            end
            
            MBIST_WRITE: begin
                if (memory_addr == SYSTOLIC_SIZE-1 && pattern_counter == MBIST_PATTERN_DEPTH-1) begin
                    next_state = MBIST_READ;
                end
            end
            
            MBIST_READ: begin
                next_state = MBIST_CHECK;
            end
            
            MBIST_CHECK: begin
                if (|compared_results) begin  // 測試失敗
                    next_state = FAIL;
                end else if (memory_addr == SYSTOLIC_SIZE-1 && pattern_counter == MBIST_PATTERN_DEPTH-1) begin
                    next_state = COMPLETE;  // MBIST測試完成
                end else begin
                    next_state = MBIST_READ;  // 繼續下個地址/pattern
                end
            end
            
            // LBIST 狀態
            LBIST_START: begin
                next_state = SA_SHIFT;
            end
            
            SA_SHIFT: begin
                next_state = SA_CAPTURE;
            end
            
            SA_CAPTURE: begin
                next_state = SA_CHECK;
            end
            
            SA_CHECK: begin
                if (|compared_results) begin  // 有錯誤，啟動診斷
                    next_state = DIAGNOSIS;
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
                next_state = TD_PROPAGATE;
            end
            
            TD_PROPAGATE: begin
                if (|compared_results) begin  // Launch 階段有錯誤
                    next_state = DIAGNOSIS;
                end else begin
                    next_state = TD_CAPTURE;
                end
            end
            
            TD_CAPTURE: begin
                next_state = TD_CHECK;
            end
            
            TD_CHECK: begin
                if (|compared_results) begin  // Capture 階段有錯誤
                    next_state = DIAGNOSIS;
                end else begin
                    // TD 測試完成條件檢查
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
            
            DIAGNOSIS: begin
                next_state = DIAGNOSIS_STORE;
            end
            
            DIAGNOSIS_STORE: begin
                if (diagnosis_row_counter == SYSTOLIC_SIZE-1) begin
                    next_state = FAIL;  // 診斷完成，測試失敗
                end else begin
                    next_state = DIAGNOSIS;
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
            
            NORMAL_OPERATION: begin
                if (test_mode) begin
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
            diagnosis_row_counter <= {ADDR_WIDTH{1'b0}};
            normal_addr_counter <= {ADDR_WIDTH{1'b0}};
        end
        else if (START && test_mode) begin
            pattern_counter <= {MAX_PATTERN_ADDR_WIDTH{1'b0}};
            memory_addr <= {ADDR_WIDTH{1'b0}};
            td_pe_counter <= 2'b00;
            diagnosis_row_counter <= {ADDR_WIDTH{1'b0}};
        end
        else begin
            case (current_state)
                MBIST_START: begin
                    pattern_counter <= {MAX_PATTERN_ADDR_WIDTH{1'b0}};
                    memory_addr <= {ADDR_WIDTH{1'b0}};
                end
                
                MBIST_WRITE: begin
                    if (memory_addr == SYSTOLIC_SIZE-1) begin
                        memory_addr <= {ADDR_WIDTH{1'b0}};
                        if (pattern_counter == MBIST_PATTERN_DEPTH-1) begin
                            pattern_counter <= {MAX_PATTERN_ADDR_WIDTH{1'b0}};
                        end else begin
                            pattern_counter <= pattern_counter + 1;
                        end
                    end else begin
                        memory_addr <= memory_addr + 1;
                    end
                end
                
                MBIST_CHECK: begin
                    if (~(|compared_results)) begin  // 當前測試通過
                        if (memory_addr == SYSTOLIC_SIZE-1) begin
                            memory_addr <= {ADDR_WIDTH{1'b0}};
                            if (pattern_counter != MBIST_PATTERN_DEPTH-1) begin
                                pattern_counter <= pattern_counter + 1;
                            end
                        end else begin
                            memory_addr <= memory_addr + 1;
                        end
                    end
                end
                
                LBIST_START: begin
                    pattern_counter <= {MAX_PATTERN_ADDR_WIDTH{1'b0}};
                    td_pe_counter <= 2'b00;
                    diagnosis_row_counter <= {ADDR_WIDTH{1'b0}};
                end
                
                SA_CHECK: begin
                    if (~(|compared_results)) begin  // SA 測試通過
                        if (pattern_counter < SA_TEST_PATTERN_DEPTH-1) begin
                            pattern_counter <= pattern_counter + 1;
                        end else begin
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
                
                DIAGNOSIS_STORE: begin
                    if (diagnosis_row_counter < SYSTOLIC_SIZE-1) begin
                        diagnosis_row_counter <= diagnosis_row_counter + 1;
                    end
                end
                
                NORMAL_OPERATION: begin
                    if (activation_valid) begin
                        if (normal_addr_counter == SYSTOLIC_SIZE-1) begin
                            normal_addr_counter <= {ADDR_WIDTH{1'b0}};
                        end else begin
                            normal_addr_counter <= normal_addr_counter + 1;
                        end
                    end
                end
            endcase
        end
    end
    
    // 測試向量產生
    always @(*) begin
        // 預設值
        weight_in_test_flat = {SYSTOLIC_SIZE{envm_weight}};           // 所有PE使用相同權重
        activation_in_test_flat = {SYSTOLIC_SIZE{envm_activation}};   // 所有PE使用相同激活
        partial_sum_test_flat = {SYSTOLIC_SIZE*PARTIAL_SUM_WIDTH{1'b0}}; // 測試時部分和為0
    end
    
    // 輸出邏輯
    always @(*) begin
        // 預設值
        scan_en = 1'b0;
        acc_wr_en = 1'b0;
        acc_test_mode = 1'b0;
        test_done = 1'b0;
        MBIST_test_result = 1'b0;
        LBIST_test_result = 1'b0;
        test_type = 1'b0;
        test_counter = pattern_counter;
        td_pe_select = td_pe_counter;
        acc_wr_addr = memory_addr;
        acc_rd_addr = memory_addr;
        acc_wr_data = {SYSTOLIC_SIZE{mbist_data}};
        
        // BISR 控制信號預設值
        envm_wr_en = 1'b0;
        allocation_start = 1'b0;
        read_addr = normal_addr_counter;  // 正常運作時使用
        
        // 診斷電路控制信號預設值
        diagnosis_start_en = 1'b0;
        detection_en = 1'b0;
        detection_addr = diagnosis_row_counter;
        
        // Activation memory 控制信號預設值
        activation_mem_wr_en = 1'b0;
        activation_mem_wr_addr = normal_addr_counter;
        
        case (current_state)
            MBIST_WRITE: begin
                acc_wr_en = 1'b1;
                acc_test_mode = 1'b1;
            end
            
            MBIST_READ: begin
                acc_test_mode = 1'b1;
                acc_rd_addr = memory_addr;
            end
            
            MBIST_CHECK: begin
                acc_test_mode = 1'b1;
                MBIST_test_result = ~(|compared_results);
                
                // 準備下個讀取地址
                if (~(|compared_results) && 
                   !(memory_addr == SYSTOLIC_SIZE-1 && pattern_counter == MBIST_PATTERN_DEPTH-1)) begin
                    if (memory_addr == SYSTOLIC_SIZE-1) begin
                        acc_rd_addr = {ADDR_WIDTH{1'b0}};
                    end else begin
                        acc_rd_addr = memory_addr + 1;
                    end
                end
            end
            
            LBIST_START: begin
                allocation_start = 1'b1;  // 啟動權重配置
                envm_wr_en = 1'b1;        // 啟動eNVM寫入
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
                acc_rd_addr = {ADDR_WIDTH{1'b0}};
            end
            
            SA_CHECK: begin
                acc_test_mode = 1'b1;
                LBIST_test_result = ~(|compared_results);
                
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
                acc_rd_addr = {ADDR_WIDTH{1'b0}};
            end
            
            TD_PROPAGATE: begin
                test_type = 1'b1;
                acc_test_mode = 1'b1;
                LBIST_test_result = ~(|compared_results);
            end
            
            TD_CAPTURE: begin
                test_type = 1'b1;
                acc_test_mode = 1'b1;
                acc_rd_addr = {ADDR_WIDTH{1'b0}};
            end
            
            TD_CHECK: begin
                acc_test_mode = 1'b1;
                LBIST_test_result = ~(|compared_results);
                
                if (~(|compared_results)) begin
                    acc_rd_addr = {ADDR_WIDTH{1'b0}};
                end
            end
            
            DIAGNOSIS: begin
                diagnosis_start_en = 1'b1;
            end
            
            DIAGNOSIS_STORE: begin
                detection_en = 1'b1;
                detection_addr = diagnosis_row_counter;
            end
            
            COMPLETE: begin
                test_done = 1'b1;
                if (!BIST_mode) begin
                    MBIST_test_result = 1'b1;
                end else begin
                    LBIST_test_result = 1'b1;
                end
            end
            
            FAIL: begin
                test_done = 1'b1;
                if (!BIST_mode) begin
                    MBIST_test_result = 1'b0;
                end else begin
                    LBIST_test_result = 1'b0;
                end
            end
            
            NORMAL_OPERATION: begin
                // 正常運作時的地址控制
                read_addr = normal_addr_counter;
                activation_mem_wr_addr = normal_addr_counter;
                if (activation_valid) begin
                    activation_mem_wr_en = 1'b1;
                end
            end
        endcase
    end
    
    // 暫存器更新邏輯
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            expected_data_reg <= {PARTIAL_SUM_WIDTH{1'b0}};
        end
        else begin
            case (current_state)
                MBIST_WRITE: begin
                    expected_data_reg <= mbist_data;
                end
                
                SA_SHIFT: begin
                    expected_data_reg <= envm_answer;
                end
                
                TD_SHIFT: begin
                    expected_data_reg <= envm_answer;
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
        .addr(pattern_counter[ADDR_WIDTH-1:0]),
        .MBIST_data(mbist_data)
    );

    // Comparator 實例化
    Comparator #(
        .SYSTOLIC_SIZE(SYSTOLIC_SIZE),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .ACTIVATION_WIDTH(ACTIVATION_WIDTH),
        .PARTIAL_SUM_WIDTH(PARTIAL_SUM_WIDTH)
    ) comparator_inst (
        .correct_answer(expected_data_reg),
        .partial_sum_flat(partial_sum_flat),
        .compared_results(compared_results)
    );

endmodule