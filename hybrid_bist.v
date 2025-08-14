// hybrid_bist.v
// Enhanced version with proper Weight Stationary architecture and TD error separation
// 重要修改：
// 1. 修正診斷時機：SA 最後一個pattern開啟 detection_en
// 2. TD 錯誤分離：不送到 DLC，利用 TD_error_flag 判斷TD測試是否有錯誤產生
// 
// 要修改:
// - acc_wr_en訊號，正常運作時要知道甚麼時候需要寫入記憶體(目前正常運作時沒有控制acc_wr_en訊號)
// 
//
// MBIST 流程說明：
// - Pipeline 式 March 算法：同時進行寫入和讀取比較
// - MBIST_WRITE: 第一個 cycle，純寫入 pattern0 到 addr0
// - MBIST_READ: 準備讀取階段（1 cycle 過渡）
// - MBIST_CHECK: 並行讀寫比較，任何錯誤立即進入 FAIL 狀態

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
    output test_type,                                       // 0: SA, 1: TD
    output reg [MAX_PATTERN_ADDR_WIDTH-1:0] test_counter,   // eNVM pattern 索引
    output TD_answer_choose,                                // TD測試答案選擇 (0: launch, 1: capture)
    output detection_en,                                    // 告知 eNVM 可以開始讀取診斷資料
    output reg [ADDR_WIDTH-1:0] detection_addr,             // 診斷地址
    
    // 控制 Systolic Array 的信號 - outputs
    output clk_w,
    output scan_en,                                     // 掃描使能信號
    
    // 給 BISR 的控制信號 - outputs
    output envm_wr_en_bist_bisr,                            // eNVM 寫入使能
    output allocation_start,                                // 開始權重配置信號
    output reg [ADDR_WIDTH-1:0] read_addr,                  // BISR 讀取地址
    
    // 給 Weight_partialsum_buffer 的控制信號 - outputs
    output reg [SYSTOLIC_SIZE*WEIGHT_WIDTH-1:0] weight_in_test_flat,            // 測試權重
    output reg [SYSTOLIC_SIZE*PARTIAL_SUM_WIDTH-1:0] partial_sum_test_flat,     // 測試部分和
    
    // 給 Activation_buffer 的激活控制信號 - outputs
    output reg [SYSTOLIC_SIZE*ACTIVATION_WIDTH-1:0] activation_in_test_flat,    // 測試激活
    
    // 診斷電路控制信號 - outputs
    output diagnosis_start_en,                          // 診斷使能信號
    output [SYSTOLIC_SIZE-1:0] compared_results,            // 比較結果
    
    // Accumulator 控制信號 (MBIST + LBIST 共用) - outputs
    output acc_wr_en,                                       // Accumulator 寫使能  
    output reg [ADDR_WIDTH-1:0] acc_wr_addr,                // Accumulator 寫地址
    output reg [PARTIAL_SUM_WIDTH*SYSTOLIC_SIZE-1:0] acc_wr_data, // Accumulator 寫資料
    output reg [ADDR_WIDTH-1:0] acc_rd_addr,                // Accumulator 讀地址
    
    // Activation_mem 控制信號 - outputs
    output reg activation_mem_wr_en,                        // Activation memory 寫使能
    output reg [ADDR_WIDTH-1:0] activation_mem_wr_addr,     // Activation memory 寫地址
    
    // 測試結果 - outputs
    output test_done,                                       // 測試完成
    output reg TD_error_flag,                               // TD 錯誤標記
    output MBIST_FAIL                                       // MBIST是否有錯誤產生
);

    // 內部計數器
    reg [MAX_PATTERN_ADDR_WIDTH-1:0] pattern_counter;       // pattern 計數器
    reg [ADDR_WIDTH-1:0] memory_addr;                       // 記憶體地址計數器
    reg [1:0] td_pe_counter;                                // TD 測試 PE 計數器 (0-3)
    reg [1:0] td_pe_select;                                 // 當前使用的 PE 選擇
    reg [2:0] shift_counter;                                // Shift 計數器 (0-7，8個cycle)     改成3bit
    reg [2:0] shift_out_counter;                            // Shift Out 計數器 (0-7)           改成3bit    
    
    // Weight Stationary 專用計數器
    // 後續可以考慮合併weight_allocation_counter , weight_load_counter
    reg [2:0] weight_allocation_counter;                    // 權重配置計數器 (0-7)
    reg [2:0] weight_load_counter;                          // 權重載入計數器 (0-6)
    
    // 正常運作時的地址計數器
    reg [ADDR_WIDTH-1:0] normal_addr_counter;               // 正常運作地址計數器
    
    // 重複使用的暫存器
    reg [PARTIAL_SUM_WIDTH-1:0] expected_data_reg;          // 通用預期資料暫存器
    reg [PARTIAL_SUM_WIDTH-1:0] launch_expected_reg;        // TD Launch 預期結果
    reg [PARTIAL_SUM_WIDTH-1:0] capture_expected_reg;       // TD Capture 預期結果
    reg next_pattern_loading;                               // 下一個 pattern 載入標記
    
    // Memory Data Generator 的輸出
    wire [PARTIAL_SUM_WIDTH-1:0] mbist_data;
    
    parameter   IDLE                = 5'b00000,
                MBIST_START         = 5'b00001,
                MBIST_WRITE         = 5'b00010,
                MBIST_READ          = 5'b00011,
                MBIST_CHECK         = 5'b00100,
                LBIST_START         = 5'b00101,
                SA_SHIFT            = 5'b00110,  // SA pattern shift in + previous result shift out
                SA_CAPTURE          = 5'b00111,  // SA MAC operation
                SA_FINAL_SHIFT      = 5'b01000,  // SA final result shift out
                TD_SHIFT            = 5'b01001,
                TD_LAUNCH           = 5'b01010,  // 1 cycle
                TD_CAPTURE          = 5'b01011,  // 1 cycle
                TD_FINAL_SHIFT      = 5'b01100,         // TD_SHIFT_OUT 改為 TD_FINAL_SHIFT 
                TEST_COMPLETE       = 5'b01101,
                FAIL                = 5'b01110,
                WEIGHT_ALLOCATION   = 5'b01111,  // 權重配置階段
                WEIGHT_LOAD         = 5'b10000,  // 權重載入階段  
                NORMAL_OPERATION    = 5'b10001;  // 正常運算階段
    
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
        case (current_state)
            IDLE: begin
                if (START && test_mode) begin
                    if (!BIST_mode) begin  // MBIST 模式
                        next_state = MBIST_START;
                    end else begin         // LBIST 模式
                        next_state = LBIST_START;
                    end
                end else if (!test_mode) begin
                    next_state = WEIGHT_ALLOCATION;  // 正常運作從權重配置開始
                end
            end
            
            // MBIST 狀態 - Pipeline 式 March 算法
            MBIST_START: begin
                next_state = MBIST_WRITE;
            end
            
            MBIST_WRITE: begin
                // 第一個 cycle：純寫入 pattern0 到 addr0
                // 後續由 MBIST_CHECK 處理並行讀寫比較
                if (memory_addr == SYSTOLIC_SIZE-1 && pattern_counter == MBIST_PATTERN_DEPTH-1) begin
                    next_state = MBIST_READ;
                end
            end
            
            MBIST_READ: begin
                // 準備讀取階段（1 cycle 過渡）
                next_state = MBIST_CHECK;
            end
            
            MBIST_CHECK: begin
                // 並行讀寫比較：
                // 寫入當前位置，同時讀取並比較前一個位置
                if (|compared_results) begin  // 任何錯誤立即失敗
                    next_state = FAIL;
                end else if (memory_addr == SYSTOLIC_SIZE-1 && pattern_counter == MBIST_PATTERN_DEPTH-1) begin
                    next_state = TEST_COMPLETE;  // 所有測試完成
                end else begin
                    next_state = MBIST_READ;  // 繼續下個地址/pattern
                end
            end
            
            // LBIST 狀態
            LBIST_START: begin
                next_state = SA_SHIFT;
            end
            
            SA_SHIFT: begin
                if (shift_counter == 3'd7) begin  // 8 cycles完成
                    next_state = SA_CAPTURE;
                end
            end
            
            SA_CAPTURE: begin
                if (pattern_counter == SA_TEST_PATTERN_DEPTH-1) begin
                    next_state = SA_FINAL_SHIFT;  // 最後一個pattern，進入最後shift
                end else begin
                    next_state = SA_SHIFT;        // 繼續下個pattern
                end
            end
            
            SA_FINAL_SHIFT: begin
                if (shift_counter == 3'd7) begin  // 8 cycles完成
                    next_state = TD_SHIFT;        // 進入TD測試
                end
            end
            
            TD_SHIFT: begin
                if (shift_counter == 3'd7) begin  // 8 cycles shift 完成
                    next_state = TD_LAUNCH;
                end
            end
            
            TD_LAUNCH: begin
                next_state = TD_CAPTURE;  // Launch 後立即 Capture
            end
            
            TD_CAPTURE: begin
                // next_state = TD_FINAL_SHIFT;  // 開始 Shift Out
                if ((pattern_counter == TD_TEST_PATTERN_DEPTH-1) & (td_pe_counter == 2'b11)) begin
                    next_state = TD_FINAL_SHIFT;  // 最後一個pattern，進入最後shift   
                end 
                else begin
                    next_state = TD_SHIFT;        // 繼續下個pattern
                end
            end
            
            TD_FINAL_SHIFT: begin
                if (shift_counter == 3'd7) begin  // 最後一組pattern 且 td_pe_counter == 2'b11(前state以確認才會進到該state) 都已經shift且比較完成
                    next_state = TEST_COMPLETE;        // 進入TD測試
                end
            end
            
            WEIGHT_ALLOCATION: begin
                if (weight_allocation_counter == 3'd7) begin
                    next_state = WEIGHT_LOAD;
                end
            end
            
            WEIGHT_LOAD: begin
                if (weight_load_counter == 3'd6) begin  // 7個cycle後轉換
                    next_state = NORMAL_OPERATION;
                end
            end
            
            NORMAL_OPERATION: begin
                if (test_mode) begin
                    next_state = IDLE;
                end
            end
            
            TEST_COMPLETE: begin
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
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pattern_counter <= {MAX_PATTERN_ADDR_WIDTH{1'b0}};
            memory_addr <= {ADDR_WIDTH{1'b0}};
            td_pe_counter <= 2'b00;
            detection_addr <= {ADDR_WIDTH{1'b0}};
            normal_addr_counter <= {ADDR_WIDTH{1'b0}};
            weight_allocation_counter <= 3'b000;
            weight_load_counter <= 3'b000;
        end
        else if (START && test_mode) begin
            pattern_counter <= {MAX_PATTERN_ADDR_WIDTH{1'b0}};
            memory_addr <= {ADDR_WIDTH{1'b0}};
            td_pe_counter <= 2'b00;
            detection_addr <= {ADDR_WIDTH{1'b0}};
            shift_counter <= 3'b000;
            shift_out_counter <= 3'b000;
            next_pattern_loading <= 1'b0;
            weight_allocation_counter <= 3'b000;
            weight_load_counter <= 3'b000;
        end
        else begin
            case (current_state)
                MBIST_START: begin
                    pattern_counter <= {MAX_PATTERN_ADDR_WIDTH{1'b0}};
                    memory_addr <= {ADDR_WIDTH{1'b0}};
                end
                
                MBIST_WRITE: begin
                    // Pipeline 式寫入：每個 cycle 寫入一個位置
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
                    // Pipeline 式比較：寫入當前位置，比較前一個位置
                    if (~(|compared_results)) begin  // 當前測試通過才繼續
                        if (memory_addr == SYSTOLIC_SIZE-1) begin
                            memory_addr <= {ADDR_WIDTH{1'b0}};
                            if (pattern_counter != MBIST_PATTERN_DEPTH-1) begin
                                pattern_counter <= pattern_counter + 1;
                            end
                        end else begin
                            memory_addr <= memory_addr + 1;
                        end
                    end
                    // 如果有錯誤，停止計數器更新，保持在錯誤狀態
                end
                
                LBIST_START: begin
                    pattern_counter <= {MAX_PATTERN_ADDR_WIDTH{1'b0}};
                    td_pe_counter <= 2'b00;
                    detection_addr <= SYSTOLIC_SIZE - 1;  // 初始化為最大值（最後一個 ROW）
                    shift_counter <= 3'b000;
                    shift_out_counter <= 3'b000;
                    next_pattern_loading <= 1'b0;
                end
                
                SA_SHIFT: begin
                    if (shift_counter < 3'd7) begin
                        shift_counter <= shift_counter + 1;
                    end else begin
                        shift_counter <= 3'b000;  // 重置準備capture
                    end
                end
                
                SA_CAPTURE: begin
                    if (pattern_counter < SA_TEST_PATTERN_DEPTH-1) begin
                        pattern_counter <= pattern_counter + 1;
                    end
                    // pattern_counter會在TD測試開始時重置
                end
                
                SA_FINAL_SHIFT: begin
                    if (shift_counter == 3'd7) begin
                        shift_counter <= 3'b000;  // 重置準備TD測試
                        // 準備TD測試的初始化
                        pattern_counter <= {MAX_PATTERN_ADDR_WIDTH{1'b0}};
                        td_pe_counter <= 2'b00;
                    end 
                    else begin
                        shift_counter <= shift_counter + 1;
                    end
                end
                
                TD_SHIFT: begin
                    if (shift_counter == 3'd7) begin
                        shift_counter <= 3'b000;  // 重置準備下次使用
                    end 
                    else begin
                        shift_counter <= shift_counter + 1;
                    end
                end
                
                TD_FINAL_SHIFT: begin
                    if (shift_out_counter < 3'd7) begin
                        shift_out_counter <= shift_out_counter + 1;
                    end else begin
                        shift_out_counter <= 3'b000;  // 重置
                        
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
                    if (shift_out_counter >= 3'd2) begin
                        next_pattern_loading <= 1'b1;
                    end
                    
                    // 診斷地址遞減邏輯 - 在最後一個 pattern 時執行
                    if (td_pe_counter == 2'b11 && pattern_counter == TD_TEST_PATTERN_DEPTH-1) begin
                        if (detection_addr > {ADDR_WIDTH{1'b0}}) begin
                            detection_addr <= detection_addr - 1;  // 遞減計數
                        end
                    end
                end
                
                WEIGHT_ALLOCATION: begin
                    if (weight_allocation_counter < 3'd7) begin
                        weight_allocation_counter <= weight_allocation_counter + 1;
                    end else begin
                        weight_allocation_counter <= 3'b000;  // 重置準備下個階段
                        weight_load_counter <= 3'b000;        // 初始化載入計數器
                    end
                end
                
                WEIGHT_LOAD: begin
                    if (weight_load_counter < 3'd6) begin
                        weight_load_counter <= weight_load_counter + 1;
                    end else begin
                        weight_load_counter <= 3'b000;        // 重置
                        normal_addr_counter <= {ADDR_WIDTH{1'b0}}; // 準備正常運作
                    end
                end
                
                NORMAL_OPERATION: begin
                    if (activation_valid) begin
                        if (normal_addr_counter == SYSTOLIC_SIZE-1) begin
                            normal_addr_counter <= {ADDR_WIDTH{1'b0}};
                        end 
                        else begin
                            normal_addr_counter <= normal_addr_counter + 1;
                        end
                    end
                end
            endcase
        end
    end
    
    // TD_error_flag
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            TD_error_flag <= 1'b0;
        end
        else if (START && test_mode) begin
            TD_error_flag <= 1'b0;  // 測試開始時重置
        end
        else if (current_state == TD_FINAL_SHIFT && |compared_results) begin
            TD_error_flag <= 1'b1;  // 記錄 TD 錯誤
        end
        else;
    end
    
    // 測試向量產生 - 維持原有邏輯
    integer i;
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
                    for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin
                        if (i[0] == 1'b0) begin  // 偶數 columns (0,2,4,6)
                            weight_in_test_flat[i*WEIGHT_WIDTH +: WEIGHT_WIDTH] = envm_weight;
                            partial_sum_test_flat[i*PARTIAL_SUM_WIDTH +: PARTIAL_SUM_WIDTH] = envm_partial_sum_in;
                        end
                        if (i[0] == 1'b0) begin  // 偶數 rows (0,2,4,6)
                            activation_in_test_flat[i*ACTIVATION_WIDTH +: ACTIVATION_WIDTH] = envm_activation;
                        end            
                    end
                end
                
                2'b01: begin  // 測試右上 PE (0,1)
                    for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin
                        if (i[0] == 1'b1) begin  // 奇數 columns (1,3,5,7)
                            weight_in_test_flat[i*WEIGHT_WIDTH +: WEIGHT_WIDTH] = envm_weight;
                            partial_sum_test_flat[i*PARTIAL_SUM_WIDTH +: PARTIAL_SUM_WIDTH] = envm_partial_sum_in;
                        end
                        if (i[0] == 1'b0) begin  // 偶數 rows (0,2,4,6)
                            activation_in_test_flat[i*ACTIVATION_WIDTH +: ACTIVATION_WIDTH] = envm_activation;
                        end
                    end
                end
                
                2'b10: begin  // 測試左下 PE (1,0)
                    for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin
                        if (i[0] == 1'b0) begin  // 偶數 columns (0,2,4,6)
                            weight_in_test_flat[i*WEIGHT_WIDTH +: WEIGHT_WIDTH] = envm_weight;
                            partial_sum_test_flat[i*PARTIAL_SUM_WIDTH +: PARTIAL_SUM_WIDTH] = envm_partial_sum_in;
                        end
                        if (i[0] == 1'b1) begin  // 奇數 rows (1,3,5,7)
                            activation_in_test_flat[i*ACTIVATION_WIDTH +: ACTIVATION_WIDTH] = envm_activation;
                        end
                    end
                end
                
                2'b11: begin  // 測試右下 PE (1,1)
                    for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin
                        if (i[0] == 1'b1) begin  // 奇數 columns (1,3,5,7)
                            weight_in_test_flat[i*WEIGHT_WIDTH +: WEIGHT_WIDTH] = envm_weight;
                            partial_sum_test_flat[i*PARTIAL_SUM_WIDTH +: PARTIAL_SUM_WIDTH] = envm_partial_sum_in;
                        end
                        if (i[0] == 1'b1) begin  // 奇數 rows (1,3,5,7)
                            activation_in_test_flat[i*ACTIVATION_WIDTH +: ACTIVATION_WIDTH] = envm_activation;
                        end
                    end
                end
            endcase
        end
    end
    
    always @(*) begin
        // 預設值
        test_counter = pattern_counter;
        td_pe_select = td_pe_counter;
        acc_wr_addr = memory_addr;
        acc_rd_addr = memory_addr;
        acc_wr_data = {SYSTOLIC_SIZE{mbist_data}};
        
        // BISR 控制信號預設值
        read_addr = normal_addr_counter;  // 預設使用正常地址
        
        // Activation memory 控制信號預設值
        activation_mem_wr_en = 1'b0;
        activation_mem_wr_addr = normal_addr_counter;
        
        case (current_state)
            
            MBIST_READ: begin
                // 準備讀取地址
                acc_rd_addr = memory_addr;
            end
            
            MBIST_CHECK: begin         
                // 準備下個讀取地址（除非測試完成或失敗）
                if (~(|compared_results) && 
                   !(memory_addr == SYSTOLIC_SIZE-1 && pattern_counter == MBIST_PATTERN_DEPTH-1)) begin
                    if (memory_addr == SYSTOLIC_SIZE-1) begin
                        acc_rd_addr = {ADDR_WIDTH{1'b0}};
                    end else begin
                        acc_rd_addr = memory_addr + 1;
                    end
                end
            end
            
            SA_CAPTURE: begin
                acc_rd_addr = {ADDR_WIDTH{1'b0}};
            end

            TD_FINAL_SHIFT: begin
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
            end
            
            WEIGHT_ALLOCATION: begin
                activation_mem_wr_addr = weight_allocation_counter;
                if (activation_valid) begin
                    activation_mem_wr_en = 1'b1;  // 準備 activation 資料
                end
            end
            
            WEIGHT_LOAD: begin
                read_addr = weight_load_counter;  // 0→6，載入權重
                activation_mem_wr_en = 1'b0;      // 暫停 activation 寫入
                
                if (weight_load_counter == 3'd6) begin
                    // 最後一個權重 + 第一個 activation 開始
                    read_addr = 3'd7;
                end
                else;
            end
            
            NORMAL_OPERATION: begin
                // Weight Stationary：權重固定，activation 45度送入
                read_addr = normal_addr_counter;
                activation_mem_wr_addr = normal_addr_counter;
                if (activation_valid) begin
                    activation_mem_wr_en = 1'b1;
                end
                else;
            end
        endcase
    end
    
    // 暫存器更新邏輯
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            expected_data_reg <= {PARTIAL_SUM_WIDTH{1'b0}};
            launch_expected_reg <= {PARTIAL_SUM_WIDTH{1'b0}};
            capture_expected_reg <= {PARTIAL_SUM_WIDTH{1'b0}};
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
                    if (shift_counter == 3'd0 && td_pe_counter == 2'b00) begin  // 每一組pattern送第一次的時候就存期望結果
                        launch_expected_reg <= envm_answer;  // 儲存 Launch 預期結果
                    end
                    else;
                end
                
                TD_CAPTURE: begin
                    if (shift_counter == 3'd1 && td_pe_counter == 2'b00) begin  // 每一組pattern送第一次的時候就存期望結果
                        capture_expected_reg <= envm_answer;  // 儲存 Capture 預期結果
                    end
                    else;
                end
                
                TD_FINAL_SHIFT: begin
                    // 根據當前比較的是 Launch 還是 Capture 來設定預期值
                    if (shift_out_counter[0] == 1'b0) begin
                        expected_data_reg <= launch_expected_reg;  // Launch 比較
                    end 
                    else begin
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
        .addr(pattern_counter[MEMORY_PATTERN_ADDR_WIDTH-1:0]),  // pattern_counter有MAX_PATTERN_ADDR_WIDTH bit ，抓後面MEMORY_PATTERN_ADDR_WIDTH bit 來用
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

    // test_type ( 0: SA, 1: TD )
    assign test_type = (current_state == TD_SHIFT) || (current_state == TD_LAUNCH) || (current_state == TD_CAPTURE)|| (current_state == TD_FINAL_SHIFT);
    
    // DLC控制：除了第一個pattern外，SA_SHIFT和SA_FINAL_SHIFT時啟動
    assign diagnosis_start_en = ((current_state == SA_SHIFT) && (pattern_counter != 0)) || (current_state == SA_FINAL_SHIFT);
    
    // 掃描模式訊號
    assign scan_en = (current_state == SA_SHIFT) || (current_state == SA_FINAL_SHIFT) || (current_state == TD_SHIFT) || (current_state == TD_FINAL_SHIFT);

    // detection_en 只有在SA的最後一個pattenr時觸發為1，目的是讓SA的錯誤資訊從DLC電路傳到eNVM
    assign detection_en = (current_state == SA_FINAL_SHIFT);

    // MBIST 失敗標記組合邏輯
    assign MBIST_FAIL = (current_state == FAIL);

    // TD_answer_choose TD錯誤選擇
    // 可能要修改
    assign TD_answer_choose = (current_state == TD_FINAL_SHIFT) && shift_out_counter[0];

    // 啟動權重配置
    assign allocation_start = (current_state == WEIGHT_ALLOCATION);

    // accumulator 寫入訊號
    assign acc_wr_en = (current_state == MBIST_WRITE) || (current_state == MBIST_CHECK);    // 第一個 cycle：純寫入，後續 cycles 由 MBIST_CHECK 處理

    // 測試結束訊號
    assign test_done = (current_state == TEST_COMPLETE) || (current_state == FAIL);

    // envm_wr_en_bist_bisr 告知bisr可以從envm索取錯誤pattenr 資訊
    assign envm_wr_en_bist_bisr = (next_state == WEIGHT_ALLOCATION);

    //clk_w
    assign clk_w = (current_state == SA_SHIFT) || (current_state == TD_SHIFT) ? clk : 1'b0;
    
endmodule