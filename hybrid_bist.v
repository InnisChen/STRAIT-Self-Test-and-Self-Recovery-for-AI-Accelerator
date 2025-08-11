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
    parameter MAX_PATTERN_ADDR_WIDTH = (SA_TEST_PATTERN_DEPTH > TD_TEST_PATTERN_DEPTH) ? $clog2(SA_TEST_PATTERN_DEPTH) : $clog2(TD_TEST_PATTERN_DEPTH),
    parameter MEMORY_PATTERN_ADDR_WIDTH = $clog2(MBIST_PATTERN_DEPTH)
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
    input [PARTIAL_SUM_WIDTH-1:0] envm_partial_sum_in,      // 從 eNVM 來的部分和
    input [PARTIAL_SUM_WIDTH-1:0] envm_answer,              // 從 eNVM 來的預期結果
    
    // Accumulator 回饋信號 - inputs
    input [PARTIAL_SUM_WIDTH*SYSTOLIC_SIZE-1:0] partial_sum_flat, // Accumulator 讀資料
    
    // 與 eNVM 的介面 - outputs
    output reg test_type,                                   // 0: SA, 1: TD
    output reg [MAX_PATTERN_ADDR_WIDTH-1:0] test_counter,   // eNVM pattern 索引
    output reg TD_answer_choose,                            // TD測試答案選擇 (0: launch, 1: capture)
    output reg detection_en,                                // 告知 eNVM 可以開始讀取診斷資料
    output reg [ADDR_WIDTH-1:0] detection_addr,             // 診斷地址
    
    // 控制 Systolic Array 的信號 - outputs
    output reg scan_en,                                     // 掃描使能信號
    
    // 給 BISR 的控制信號 - outputs
    output reg envm_wr_en,                                  // eNVM 寫入使能
    output reg allocation_start,                            // 開始權重配置信號
    output reg [ADDR_WIDTH-1:0] read_addr,                  // BISR 讀取地址
    
    // 給 Weight_partialsum_buffer 的控制信號 - outputs
    output reg [SYSTOLIC_SIZE*WEIGHT_WIDTH-1:0] weight_in_test_flat,            // 測試權重
    output reg [SYSTOLIC_SIZE*PARTIAL_SUM_WIDTH-1:0] partial_sum_test_flat,     // 測試部分和
    
    // 給 Activation_buffer 的激活控制信號 - outputs
    output reg [SYSTOLIC_SIZE*ACTIVATION_WIDTH-1:0] activation_in_test_flat,    // 測試激活
    
    // 診斷電路控制信號 - outputs
    output reg diagnosis_start_en,                          // 診斷使能信號
    output [SYSTOLIC_SIZE-1:0] compared_results,            // 比較結果
    
    // Accumulator 控制信號 (MBIST + LBIST 共用) - outputs
    output reg acc_wr_en,                                   // Accumulator 寫使能  
    output reg [ADDR_WIDTH-1:0] acc_wr_addr,                // Accumulator 寫地址
    output reg [PARTIAL_SUM_WIDTH*SYSTOLIC_SIZE-1:0] acc_wr_data, // Accumulator 寫資料
    output reg [ADDR_WIDTH-1:0] acc_rd_addr,                // Accumulator 讀地址
    
    // Activation_mem 控制信號 - outputs
    output reg activation_mem_wr_en,                        // Activation memory 寫使能
    output reg [ADDR_WIDTH-1:0] activation_mem_wr_addr,     // Activation memory 寫地址
    
    // 測試結果 - outputs
    output reg test_done,                                   // 測試完成
    output reg MBIST_test_result,                           // MBIST 測試結果
    output reg LBIST_test_result                            // LBIST 測試結果
);

    // 內部計數器
    reg [MAX_PATTERN_ADDR_WIDTH-1:0] pattern_counter;       // pattern 計數器
    reg [ADDR_WIDTH-1:0] memory_addr;                       // 記憶體地址計數器
    reg [1:0] td_pe_counter;                                // TD 測試 PE 計數器 (0-3)
    reg [1:0] td_pe_select;                                 // 當前使用的 PE 選擇
    reg [ADDR_WIDTH-1:0] diagnosis_row_counter;             // 診斷行計數器
    reg [3:0] shift_counter;                                // Shift 計數器 (0-7，8個cycle)
    reg [3:0] shift_out_counter;                            // Shift Out 計數器 (0-7)
    
    // 正常運作時的地址計數器
    reg [ADDR_WIDTH-1:0] normal_addr_counter;               // 正常運作地址計數器
    
    // 重複使用的暫存器
    reg [PARTIAL_SUM_WIDTH-1:0] expected_data_reg;          // 通用預期資料暫存器
    reg [PARTIAL_SUM_WIDTH-1:0] launch_expected_reg;        // TD Launch 預期結果
    reg [PARTIAL_SUM_WIDTH-1:0] capture_expected_reg;       // TD Capture 預期結果
    reg next_pattern_loading;                               // 下一個 pattern 載入標記
    
    // Memory Data Generator 的輸出
    wire [PARTIAL_SUM_WIDTH-1:0] mbist_data;
    
    // 狀態機定義
    parameter   IDLE                = 5'b00000,
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
                TD_CAPTURE          = 5'b01011,
                TD_SHIFT_OUT        = 5'b01100,
                DIAGNOSIS           = 5'b01101,
                DIAGNOSIS_STORE     = 5'b01110,
                COMPLETE            = 5'b01111,
                FAIL                = 5'b10000,
                NORMAL_OPERATION    = 5'b10001;
    
    reg [4:0] current_state, next_state;
    
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
                if (shift_counter == 4'd7) begin  // 8 cycles shift 完成
                    next_state = TD_LAUNCH;
                end
            end
            
            TD_LAUNCH: begin
                next_state = TD_CAPTURE;  // Launch 後立即 Capture
            end
            
            TD_CAPTURE: begin
                next_state = TD_SHIFT_OUT;  // 開始 Shift Out
            end
            
            TD_SHIFT_OUT: begin
                if (shift_out_counter == 4'd7) begin  // 8 cycles shift out 完成
                    // 檢查是否有錯誤需要診斷
                    if (|compared_results) begin  // 在 shift out 過程中發現錯誤
                        next_state = DIAGNOSIS;
                    end
                    // 檢查是否完成所有測試
                    else if (td_pe_counter == 2'b11) begin  // 4個PE位置都測完
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
            shift_counter <= 4'b0000;
            shift_out_counter <= 4'b0000;
            next_pattern_loading <= 1'b0;
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
                    shift_counter <= 4'b0000;
                    shift_out_counter <= 4'b0000;
                    next_pattern_loading <= 1'b0;
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
                
                TD_SHIFT: begin
                    if (shift_counter < 4'd7) begin
                        shift_counter <= shift_counter + 1;
                    end else begin
                        shift_counter <= 4'b0000;  // 重置準備下次使用
                    end
                end
                
                TD_SHIFT_OUT: begin
                    if (shift_out_counter < 4'd7) begin
                        shift_out_counter <= shift_out_counter + 1;
                    end else begin
                        shift_out_counter <= 4'b0000;  // 重置
                        
                        // 更新測試計數器
                        if (td_pe_counter == 2'b11) begin
                            td_pe_counter <= 2'b00;
                            if (pattern_counter < TD_TEST_PATTERN_DEPTH-1) begin
                                pattern_counter <= pattern_counter + 1;
                            end
                        end else begin
                            td_pe_counter <= td_pe_counter + 1;
                        end
                        
                        // 重置檢查階段標記
                        next_pattern_loading <= 1'b0;
                    end
                    
                    // Pipeline: 從 cycle 3 開始載入下一個 pattern
                    if (shift_out_counter >= 4'd2) begin
                        next_pattern_loading <= 1'b1;
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
    
// 測試向量產生 - 修正版本
    always @(*) begin
        // 預設值：所有輸出為 0
        weight_in_test_flat = {SYSTOLIC_SIZE*WEIGHT_WIDTH{1'b0}};
        activation_in_test_flat = {SYSTOLIC_SIZE*ACTIVATION_WIDTH{1'b0}};
        partial_sum_test_flat = {SYSTOLIC_SIZE*PARTIAL_SUM_WIDTH{1'b0}};
        
        if (current_state == SA_SHIFT) begin
            // SA 測試：所有 PE 使用相同資料
            weight_in_test_flat = {SYSTOLIC_SIZE{envm_weight}};
            activation_in_test_flat = {SYSTOLIC_SIZE{envm_activation}};
            partial_sum_test_flat = {SYSTOLIC_SIZE{envm_partial_sum_in}};
        end
        else if (current_state == TD_SHIFT) begin
            // TD 測試：根據 td_pe_select 選擇性分佈資料
            case (td_pe_select)
                2'b00: begin  // 測試左上 PE (0,0)
                    // Weight: 1,3,5,7 columns 送 0，0,2,4,6 columns 送 weight
                    // Activation: 1,3,5,7 rows 送 0，0,2,4,6 rows 送 activation
                    // Partial Sum: 所有位置都送 partial_sum_in
                    for (int i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin
                        if (i[0] == 1'b0) begin  // 偶數 columns (0,2,4,6)
                            weight_in_test_flat[i*WEIGHT_WIDTH +: WEIGHT_WIDTH] = envm_weight;
                        end
                        if (i[0] == 1'b0) begin  // 偶數 rows (0,2,4,6)
                            activation_in_test_flat[i*ACTIVATION_WIDTH +: ACTIVATION_WIDTH] = envm_activation;
                        end
                        partial_sum_test_flat[i*PARTIAL_SUM_WIDTH +: PARTIAL_SUM_WIDTH] = envm_partial_sum_in;
                    end
                end
                
                2'b01: begin  // 測試右上 PE (0,1)
                    // Weight: 0,2,4,6 columns 送 0，1,3,5,7 columns 送 weight
                    // Activation: 1,3,5,7 rows 送 0，0,2,4,6 rows 送 activation
                    for (int i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin
                        if (i[0] == 1'b1) begin  // 奇數 columns (1,3,5,7)
                            weight_in_test_flat[i*WEIGHT_WIDTH +: WEIGHT_WIDTH] = envm_weight;
                        end
                        if (i[0] == 1'b0) begin  // 偶數 rows (0,2,4,6)
                            activation_in_test_flat[i*ACTIVATION_WIDTH +: ACTIVATION_WIDTH] = envm_activation;
                        end
                        partial_sum_test_flat[i*PARTIAL_SUM_WIDTH +: PARTIAL_SUM_WIDTH] = envm_partial_sum_in;
                    end
                end
                
                2'b10: begin  // 測試左下 PE (1,0)
                    // Weight: 1,3,5,7 columns 送 0，0,2,4,6 columns 送 weight
                    // Activation: 0,2,4,6 rows 送 0，1,3,5,7 rows 送 activation
                    for (int i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin
                        if (i[0] == 1'b0) begin  // 偶數 columns (0,2,4,6)
                            weight_in_test_flat[i*WEIGHT_WIDTH +: WEIGHT_WIDTH] = envm_weight;
                        end
                        if (i[0] == 1'b1) begin  // 奇數 rows (1,3,5,7)
                            activation_in_test_flat[i*ACTIVATION_WIDTH +: ACTIVATION_WIDTH] = envm_activation;
                        end
                        partial_sum_test_flat[i*PARTIAL_SUM_WIDTH +: PARTIAL_SUM_WIDTH] = envm_partial_sum_in;
                    end
                end
                
                2'b11: begin  // 測試右下 PE (1,1)
                    // Weight: 0,2,4,6 columns 送 0，1,3,5,7 columns 送 weight
                    // Activation: 0,2,4,6 rows 送 0，1,3,5,7 rows 送 activation
                    for (int i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin
                        if (i[0] == 1'b1) begin  // 奇數 columns (1,3,5,7)
                            weight_in_test_flat[i*WEIGHT_WIDTH +: WEIGHT_WIDTH] = envm_weight;
                        end
                        if (i[0] == 1'b1) begin  // 奇數 rows (1,3,5,7)
                            activation_in_test_flat[i*ACTIVATION_WIDTH +: ACTIVATION_WIDTH] = envm_activation;
                        end
                        partial_sum_test_flat[i*PARTIAL_SUM_WIDTH +: PARTIAL_SUM_WIDTH] = envm_partial_sum_in;
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
            end
            
            MBIST_READ: begin
                acc_rd_addr = memory_addr;
            end
            
            MBIST_CHECK: begin
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
            end
            
            SA_CAPTURE: begin
                scan_en = 1'b0;
                test_type = 1'b0;
                acc_rd_addr = {ADDR_WIDTH{1'b0}};
            end
            
            SA_CHECK: begin
                LBIST_test_result = ~(|compared_results);
                
                if (~(|compared_results) && pattern_counter < SA_TEST_PATTERN_DEPTH-1) begin
                    acc_rd_addr = {ADDR_WIDTH{1'b0}};
                end
            end
            
            TD_SHIFT: begin
                scan_en = 1'b1;
                test_type = 1'b1;  // TD 測試
                TD_answer_choose = 1'b0;  // 準備讀取 Launch 答案
            end
            
            TD_LAUNCH: begin
                scan_en = 1'b0;
                test_type = 1'b1;
                TD_answer_choose = 1'b0;  // 使用 Launch 預期答案
            end
            
            TD_CAPTURE: begin
                scan_en = 1'b0;
                test_type = 1'b1;
                TD_answer_choose = 1'b1;  // 切換到 Capture 預期答案
            end
            
            TD_SHIFT_OUT: begin
                scan_en = 1'b1;  // 開啟掃描輸出模式
                test_type = 1'b1;
                acc_rd_addr = {ADDR_WIDTH{1'b0}};  // 固定讀取第一個位置
                
                // Pipeline 控制：從 cycle 3 開始準備下一個 pattern
                if (next_pattern_loading) begin
                    // 根據將要更新的計數器設定下一個測試的參數
                    if (td_pe_counter == 2'b11 && pattern_counter < TD_TEST_PATTERN_DEPTH-1) begin
                        test_counter = pattern_counter + 1;  // 下一個 pattern
                        td_pe_select = 2'b00;  // 重置到第一個 PE
                    end else if (td_pe_counter < 2'b11) begin
                        test_counter = pattern_counter;  // 同一個 pattern
                        td_pe_select = td_pe_counter + 1;  // 下一個 PE
                    end
                end else begin
                    test_counter = pattern_counter;
                    td_pe_select = td_pe_counter;
                end
                
                // 根據 shift_out_counter 的奇偶數決定比較 Launch 或 Capture
                if (shift_out_counter[0] == 1'b0) begin
                    TD_answer_choose = 1'b0;  // 偶數 cycle: Launch
                end else begin
                    TD_answer_choose = 1'b1;  // 奇數 cycle: Capture
                end
                
                // 即時比較結果並判定測試狀態
                LBIST_test_result = ~(|compared_results);
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
                    launch_expected_reg <= envm_answer;  // 儲存 Launch 預期結果
                end
                
                TD_CAPTURE: begin
                    capture_expected_reg <= envm_answer;  // 儲存 Capture 預期結果
                end
                
                TD_SHIFT_OUT: begin
                    // 根據當前比較的是 Launch 還是 Capture 來設定預期值
                    if (shift_out_counter[0] == 1'b0) begin
                        expected_data_reg <= launch_expected_reg;  // Launch 比較
                    end else begin
                        expected_data_reg <= capture_expected_reg;  // Capture 比較
                    end
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
        .MBIST_PATTERN_DEPTH(MBIST_PATTERN_DEPTH),
        .MEMORY_PATTERN_ADDR_WIDTH(MEMORY_PATTERN_ADDR_WIDTH)
    ) memory_data_gen_inst (
        .addr(pattern_counter[MEMORY_PATTERN_ADDR_WIDTH-1:0]),
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