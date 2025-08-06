module tb_bisr_weight_allocation;

// Parameters - 使用4x4陣列進行測試
parameter SYSTOLIC_SIZE = 4;
parameter WEIGHT_WIDTH = 8;
parameter ACTIVATION_WIDTH = 8;
parameter ADDR_WIDTH = $clog2(SYSTOLIC_SIZE);

// ===============================================
// 測試Pattern設定區域 - 可在此修改測試內容
// ===============================================

// 錯誤資訊設定 - 使用攤平的一維向量
// 格式: {Row3_pattern, Row2_pattern, Row1_pattern, Row0_pattern}
parameter [SYSTOLIC_SIZE*SYSTOLIC_SIZE-1:0] TEST_FAULTY_PATTERNS_FLAT = {
    4'b1010,  // Row 3
    4'b0000,  // Row 2
    4'b0010,  // Row 1
    4'b0100   // Row 0
};

// 權重矩陣設定 (使用十進制，格式: {PE[3], PE[2], PE[1], PE[0]})
parameter [SYSTOLIC_SIZE*WEIGHT_WIDTH-1:0] TEST_WEIGHT_ROW_0 = {8'd0, 8'd22, 8'd0, 8'd42};      // Row 0
parameter [SYSTOLIC_SIZE*WEIGHT_WIDTH-1:0] TEST_WEIGHT_ROW_1 = {8'd13, 8'd23, 8'd0, 8'd43};     // Row 1
parameter [SYSTOLIC_SIZE*WEIGHT_WIDTH-1:0] TEST_WEIGHT_ROW_2 = {8'd14, 8'd24, 8'd34, 8'd44};    // Row 2
parameter [SYSTOLIC_SIZE*WEIGHT_WIDTH-1:0] TEST_WEIGHT_ROW_3 = {8'd15, 8'd0, 8'd35, 8'd45};     // Row 3

// ===============================================
// 以下為測試邏輯，一般不需要修改
// ===============================================

// Clock and Reset
reg clk;
reg rst_n;

// eNVM Interface - 簡化為單一攤平向量
reg envm_wr_en;
reg [SYSTOLIC_SIZE*SYSTOLIC_SIZE-1:0] envm_faulty_patterns_flat;

// Weight Input Interface
reg weight_start;
reg [SYSTOLIC_SIZE*WEIGHT_WIDTH-1:0] input_weights;
reg weight_valid;

// Address Counter Interface
reg [ADDR_WIDTH-1:0] read_addr;

// Outputs
wire [SYSTOLIC_SIZE*WEIGHT_WIDTH-1:0] output_weights;
wire [ADDR_WIDTH-1:0] output_mapped_addr;
wire recovery_success;
wire recovery_done;

// Test data storage
reg [SYSTOLIC_SIZE*WEIGHT_WIDTH-1:0] test_weights [SYSTOLIC_SIZE-1:0];
integer i, j;

// Clock generation
initial begin
    clk = 0;
    forever #5 clk = ~clk;  // 100MHz clock
end

// DUT instantiation
bisr_weight_allocation #(
    .SYSTOLIC_SIZE(SYSTOLIC_SIZE),
    .WEIGHT_WIDTH(WEIGHT_WIDTH),
    .ACTIVATION_WIDTH(ACTIVATION_WIDTH)
) dut (
    .clk(clk),
    .rst_n(rst_n),
    .envm_wr_en(envm_wr_en),
    .envm_faulty_patterns_flat(envm_faulty_patterns_flat),
    .weight_start(weight_start),
    .input_weights(input_weights),
    .weight_valid(weight_valid),
    .read_addr(read_addr),
    .output_weights(output_weights),
    .output_mapped_addr(output_mapped_addr),
    .recovery_success(recovery_success),
    .recovery_done(recovery_done)
);

// 載入測試pattern
initial begin
    // 載入權重矩陣
    test_weights[0] = TEST_WEIGHT_ROW_0;
    test_weights[1] = TEST_WEIGHT_ROW_1;
    test_weights[2] = TEST_WEIGHT_ROW_2;
    test_weights[3] = TEST_WEIGHT_ROW_3;
    
    // 載入錯誤資訊 - 使用攤平向量
    envm_faulty_patterns_flat = TEST_FAULTY_PATTERNS_FLAT;
end

// Main test sequence
initial begin
    $dumpfile("tb_bisr_weight_allocation.vcd");
    $dumpvars(0, tb_bisr_weight_allocation);
    
    // Initialize signals
    rst_n = 1;
    envm_wr_en = 0;
    // envm_faulty_patterns_flat = 0;
    weight_start = 0;
    weight_valid = 0;
    input_weights = 0;
    read_addr = 0;
    
    // Reset sequence
    $display("=====================================");
    $display("BISR Weight Allocation Testbench");
    $display("SYSTOLIC_SIZE = %0d", SYSTOLIC_SIZE);
    $display("=====================================");
    
    #10;      // Half cycle delay
    rst_n = 0; // Assert reset (active low)
    #10;       // Hold reset for one cycle
    rst_n = 1; // Deassert reset
    
    // 顯示測試設定
    display_test_setup();
    
    // 執行單一測試pattern
    execute_test_pattern();
    
    @(posedge clk);
    @(posedge clk);
    
    $display("");
    $display("=====================================");
    $display("Test Completed");
    $display("=====================================");
    $finish;
end

// 顯示測試設定
task display_test_setup;
begin
    $display("");
    $display("=== Test Pattern Setup ===");
    
    // 顯示權重矩陣
    $display("Weight Matrix:");
    for (i = 0; i < SYSTOLIC_SIZE; i++) begin
        $display("  Row %0d: PE[3]=%0d, PE[2]=%0d, PE[1]=%0d, PE[0]=%0d", 
                i, test_weights[i][31:24], test_weights[i][23:16], test_weights[i][15:8], test_weights[i][7:0]);
    end
    
    // 顯示錯誤資訊
    $display("");
    $display("Faulty Information:");
    $display("Faulty Patterns Flat: %b", envm_faulty_patterns_flat);
    for (i = 0; i < SYSTOLIC_SIZE; i++) begin
        $display("  Row %0d Pattern: %b (PE[3]=%b, PE[2]=%b, PE[1]=%b, PE[0]=%b)", 
                i, envm_faulty_patterns_flat[i*SYSTOLIC_SIZE +: SYSTOLIC_SIZE],
                envm_faulty_patterns_flat[i*SYSTOLIC_SIZE + 3], 
                envm_faulty_patterns_flat[i*SYSTOLIC_SIZE + 2],
                envm_faulty_patterns_flat[i*SYSTOLIC_SIZE + 1], 
                envm_faulty_patterns_flat[i*SYSTOLIC_SIZE + 0]);
    end
end
endtask

// 執行測試pattern
task execute_test_pattern;
begin
    // Phase 1: eNVM初始化
    execute_envm_initialization();
    
    // Phase 2: 權重配置
    execute_weight_allocation();
    
    // Phase 3: 讀取測試
    execute_read_test();
    
    // 結果檢查
    check_results();
end
endtask

// 執行eNVM初始化
task execute_envm_initialization;
begin
    $display("");
    $display("=== Phase 1: eNVM Initialization ===");
    
    envm_wr_en = 1;        // 提早1個clk，直接設定
    @(posedge clk);        // 等一個完整的clock cycle
    @(negedge clk);        // 到negedge拉低
    envm_wr_en = 0;
    
    $display("eNVM initialization completed");
end
endtask

// 執行權重配置
task execute_weight_allocation;
begin
    $display("");
    $display("=== Phase 2: Weight Allocation ===");
    
    weight_start = 1;
    @(negedge clk);
    weight_start = 0;
    
    // 連續4個cycle送權重，weight_valid保持高電平
    weight_valid = 1;  // 拉高 weight_valid，保持4個cycle
    
    // 逐一輸入4個權重row
    for (i = 0; i < SYSTOLIC_SIZE; i++) begin
        input_weights = test_weights[i];  // 在 negedge 更新權重資料
        
        $display("");
        $display("Input Row %0d weights: PE[3]=%0d, PE[2]=%0d, PE[1]=%0d, PE[0]=%0d", 
                i, test_weights[i][31:24], test_weights[i][23:16], test_weights[i][15:8], test_weights[i][7:0]);
        
        // 顯示零權重位置
        $display("  Zero weight positions: PE[3]=%b, PE[2]=%b, PE[1]=%b, PE[0]=%b",
                (test_weights[i][31:24] == 0), (test_weights[i][23:16] == 0),
                (test_weights[i][15:8] == 0), (test_weights[i][7:0] == 0));
        
        @(posedge clk);  // 等待這個 cycle 的處理完成
        #1;              // 小延遲等待組合邏輯穩定
        
        if (dut.match_success) begin
            $display("  -> Match Success! Faulty Row %0d mapped to current Row %0d", dut.faulty_row_addr, i);
        end else if (dut.match_failed) begin
            $display("  -> Match Failed, execute step 4 allocation to healthy row");
        end else if (dut.all_faulty_matched) begin
            $display("  -> All faults processed, allocate to healthy row");
        end else begin
            $display("  -> No special match, normal allocation");
        end
        
        if (i < SYSTOLIC_SIZE - 1) begin
            @(negedge clk);  // 準備下一筆資料 (除了最後一筆)
        end
    end
    
    // 4個cycle後拉低 weight_valid
    @(negedge clk);
    weight_valid = 0;
    
    // 等待配置完成
    @(posedge clk);
    @(posedge clk);
    
    $display("");
    $display("Weight allocation phase completed:");
    $display("  recovery_done = %b", recovery_done);
    $display("  recovery_success = %b", recovery_success);
    
    // 顯示內部狀態
    display_internal_status();
end
endtask

// 執行讀取測試
task execute_read_test;
begin
    $display("");
    $display("=== Phase 3: Read Test ===");
    $display("Address mapping results:");
    
    for (i = 0; i < SYSTOLIC_SIZE; i++) begin
        @(negedge clk);  // 在 negedge 送讀取地址
        read_addr = i;
        
        @(posedge clk);  // 等待地址映射和資料讀取完成
        #1;              // 小延遲等待組合邏輯穩定
        
        $display("  Logic Addr %0d -> Physical Addr %0d, Weights: PE[3]=%0d, PE[2]=%0d, PE[1]=%0d, PE[0]=%0d", 
                read_addr, output_mapped_addr,
                output_weights[31:24], output_weights[23:16], output_weights[15:8], output_weights[7:0]);
    end
end
endtask

// 顯示內部狀態
task display_internal_status;
begin
    $display("");
    $display("--- Internal Status ---");
    $display("Faulty PE Storage valid bits: %b", dut.valid_bits_out);
    $display("All faulty matched: %b", dut.all_faulty_matched);
    if (dut.allocation_failed) begin
        $display("WARNING: Allocation Failed detected");
    end
end
endtask

// 結果檢查
task check_results;
begin
    $display("");
    $display("=== Final Results ===");
    
    if (recovery_success && recovery_done) begin
        $display("PASS: Weight allocation successful, all faulty PEs recovered");
    end else if (recovery_done && !recovery_success) begin
        $display("PARTIAL: Allocation completed but some faulty PEs not fully recovered");
    end else begin
        $display("FAIL: Allocation not completed or error occurred");
    end
    
    $display("Final Status: recovery_done=%b, recovery_success=%b", recovery_done, recovery_success);
end
endtask

// // 監控關鍵信號變化
// always @(posedge clk) begin
//     if (rst_n && dut.match_success) begin
//         $display("    [%0t] Match Success: faulty_row=%0d -> current_row=%0d", 
//                 $time, dut.faulty_row_addr, dut.faulty_pe_addr);
//     end
    
//     if (rst_n && dut.match_failed) begin
//         $display("    [%0t] Match Failed for current_row=%0d", 
//                 $time, dut.faulty_pe_addr);
//     end
// end

endmodule