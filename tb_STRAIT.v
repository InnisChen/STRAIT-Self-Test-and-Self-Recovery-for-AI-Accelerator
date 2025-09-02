`timescale 1ns / 1ps
`define CYCLE      10.0  

// 定義檔案路徑
`define MBIST_FILE	"C:/Project/STRAIT/input_data/MBIST_test_pattern.dat"
`define SA_FILE		"C:/Project/STRAIT/input_data/LBIST_SA_test_pattern.dat"
`define TD_FILE		"C:/Project/STRAIT/input_data/LBIST_TD_test_pattern.dat"
`define ACTIVATION_FILE     "C:/Project/STRAIT/input_data/activation.dat"
`define WEIGHT_FILE         "C:/Project/STRAIT/input_data/weight.dat"

// 定義狀態用於控制
`define LOW  1'b0
`define HIGH 1'b1

module tb_STRAIT;

    // Parameters
    parameter SYSTOLIC_SIZE = 8;
    parameter WEIGHT_WIDTH = 8;
    parameter ACTIVATION_WIDTH = 8;
    parameter PARTIAL_SUM_WIDTH = WEIGHT_WIDTH + ACTIVATION_WIDTH + $clog2(SYSTOLIC_SIZE);
    parameter ADDR_WIDTH = $clog2(SYSTOLIC_SIZE);
    parameter SA_TEST_PATTERN_DEPTH = 12;
    parameter TD_TEST_PATTERN_DEPTH = 18;  // 修正為18
    parameter MBIST_PATTERN_DEPTH = 8;
    parameter MAX_PATTERN_ADDR_WIDTH = (SA_TEST_PATTERN_DEPTH > TD_TEST_PATTERN_DEPTH) ? 
                                       $clog2(SA_TEST_PATTERN_DEPTH) : $clog2(TD_TEST_PATTERN_DEPTH);
    parameter MEMORY_PATTERN_ADDR_WIDTH = $clog2(MBIST_PATTERN_DEPTH);
    
    // Clock and reset
    reg clk;
    reg rst_n;
    
    // DUT inputs
    reg START;
    reg test_mode;
    reg BIST_mode;
    reg weight_valid;
    reg [SYSTOLIC_SIZE*WEIGHT_WIDTH-1:0] input_weight_flat;
    reg [SYSTOLIC_SIZE*ACTIVATION_WIDTH-1:0] input_activation_flat;
    reg [SYSTOLIC_SIZE*PARTIAL_SUM_WIDTH-1:0] input_partial_sum_flat;
    reg activation_valid;
    reg [ADDR_WIDTH-1:0] rd_addr;
    
    // DUT outputs
    wire [SYSTOLIC_SIZE*PARTIAL_SUM_WIDTH-1:0] partial_sum_outputs_flat_outside;
    wire test_done;
    wire TD_error_flag;
    wire MBIST_FAIL;
    wire recovery_success;
    wire recovery_done;

    // 測試資料陣列
    reg [PARTIAL_SUM_WIDTH-1:0] Memory_test_data [0:MBIST_PATTERN_DEPTH-1];

    // SA測試資料陣列 - 分別儲存
    reg [WEIGHT_WIDTH-1:0] SA_weight_reg [0:SA_TEST_PATTERN_DEPTH-1];
    reg [ACTIVATION_WIDTH-1:0] SA_activation_reg [0:SA_TEST_PATTERN_DEPTH-1];
    reg [PARTIAL_SUM_WIDTH-1:0] SA_partial_sum_in_reg [0:SA_TEST_PATTERN_DEPTH-1];
    reg [PARTIAL_SUM_WIDTH-1:0] SA_answer_reg [0:SA_TEST_PATTERN_DEPTH-1];

    // TD測試資料陣列 - 分別儲存
    reg [WEIGHT_WIDTH-1:0] TD_weight_1_reg [0:TD_TEST_PATTERN_DEPTH-1];
    reg [WEIGHT_WIDTH-1:0] TD_weight_2_reg [0:TD_TEST_PATTERN_DEPTH-1];
    reg [ACTIVATION_WIDTH-1:0] TD_activation_1_reg [0:TD_TEST_PATTERN_DEPTH-1];
    reg [ACTIVATION_WIDTH-1:0] TD_activation_2_reg [0:TD_TEST_PATTERN_DEPTH-1];
    reg [PARTIAL_SUM_WIDTH-1:0] TD_partial_sum_in_1_reg [0:TD_TEST_PATTERN_DEPTH-1];
    reg [PARTIAL_SUM_WIDTH-1:0] TD_partial_sum_in_2_reg [0:TD_TEST_PATTERN_DEPTH-1];
    reg [PARTIAL_SUM_WIDTH-1:0] TD_launch_answer_reg [0:TD_TEST_PATTERN_DEPTH-1];
    reg [PARTIAL_SUM_WIDTH-1:0] TD_capture_answer_reg [0:TD_TEST_PATTERN_DEPTH-1];

    // 文件讀取相關變數
    integer sa_file, td_file;
    integer sa_scan_result, td_scan_result;
    reg [10*100:1] line_buffer;  // 用於讀取一行文字
    reg [WEIGHT_WIDTH-1:0] temp_weight1, temp_weight2;
    reg [ACTIVATION_WIDTH-1:0] temp_activation1, temp_activation2;
    reg [PARTIAL_SUM_WIDTH-1:0] temp_partial_sum1, temp_partial_sum2;
    reg [PARTIAL_SUM_WIDTH-1:0] temp_answer1, temp_answer2;
    
    integer i, j;

    // Clock generation
    always begin 
        #(`CYCLE/2) clk = ~clk; 
    end

    // DUT instantiation
    STRAIT #(
        .SYSTOLIC_SIZE(SYSTOLIC_SIZE),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .ACTIVATION_WIDTH(ACTIVATION_WIDTH),
        .PARTIAL_SUM_WIDTH(PARTIAL_SUM_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .SA_TEST_PATTERN_DEPTH(SA_TEST_PATTERN_DEPTH),
        .TD_TEST_PATTERN_DEPTH(TD_TEST_PATTERN_DEPTH),
        .MBIST_PATTERN_DEPTH(MBIST_PATTERN_DEPTH),
        .MAX_PATTERN_ADDR_WIDTH(MAX_PATTERN_ADDR_WIDTH),
        .MEMORY_PATTERN_ADDR_WIDTH(MEMORY_PATTERN_ADDR_WIDTH)
    ) UUT (
        .clk(clk),
        .rst_n(rst_n),
        .START(START),
        .test_mode(test_mode),
        .BIST_mode(BIST_mode),
        .weight_valid(weight_valid),
        .input_weight_flat(input_weight_flat),
        .input_activation_flat(input_activation_flat),
        .input_partial_sum_flat(input_partial_sum_flat),
        .activation_valid(activation_valid),
        .rd_addr(rd_addr),
        .partial_sum_outputs_flat_outside(partial_sum_outputs_flat_outside),
        .test_done(test_done),
        .TD_error_flag(TD_error_flag),
        .MBIST_FAIL(MBIST_FAIL),
        .recovery_success(recovery_success),
        .recovery_done(recovery_done)
    );

    // 初始化和資料載入
    initial begin : Preprocess
        // 初始化輸入信號
        clk = `LOW;
        START = `LOW;
        test_mode = `LOW;
        BIST_mode = `LOW;
        weight_valid = `LOW;
        input_weight_flat = {SYSTOLIC_SIZE*WEIGHT_WIDTH{1'b0}};
        input_activation_flat = {SYSTOLIC_SIZE*ACTIVATION_WIDTH{1'b0}};
        input_partial_sum_flat = {SYSTOLIC_SIZE*PARTIAL_SUM_WIDTH{1'b0}};
        activation_valid = `LOW;
        rd_addr = {ADDR_WIDTH{1'b0}};

        $display("----------------------");
        $display("-- Simulation Start --");
        $display("-- Array Size: %0dx%0d --", SYSTOLIC_SIZE, SYSTOLIC_SIZE);
        $display("----------------------");

        // 載入測試檔案
        $display("Loading test patterns...");
        
        // 載入MBIST測試資料
        $readmemb(`MBIST_FILE, Memory_test_data);
        $display("MBIST patterns loaded: %0d patterns", MBIST_PATTERN_DEPTH);
        
        // 載入SA測試資料 - 手動解析空格分隔的格式
        sa_file = $fopen(`SA_FILE, "r");
        if (sa_file == 0) begin
            $display("Error: Could not open SA test file");
            $finish;
        end
        
        $display("Loading SA test patterns...");
        i = 0;
        while (!$feof(sa_file) && i < SA_TEST_PATTERN_DEPTH) begin
            // 跳過註解行
            if ($fgets(line_buffer, sa_file)) begin
                // if (line_buffer[8*100:8*98] == "//") begin
                //     continue;  // 跳過註解行
                // end
                
                // 解析格式: Weight(8-bit) Activation(8-bit) Partial_Sum_In(19-bit) Expected_Answer(19-bit)
                sa_scan_result = $sscanf(line_buffer, "%b %b %b %b", 
                    temp_weight1, temp_activation1, temp_partial_sum1, temp_answer1);
                
                if (sa_scan_result == 4) begin
                    SA_weight_reg[i] = temp_weight1;
                    SA_activation_reg[i] = temp_activation1;
                    SA_partial_sum_in_reg[i] = temp_partial_sum1;
                    SA_answer_reg[i] = temp_answer1;
                    $display("SA Pattern %0d: W=%b A=%b P=%b Ans=%b", 
                             i, temp_weight1, temp_activation1, temp_partial_sum1, temp_answer1);
                    i = i + 1;
                end
            end
        end
        $fclose(sa_file);
        $display("SA patterns loaded: %0d patterns", i);
        
        // 載入TD測試資料 - 手動解析空格分隔的格式
        td_file = $fopen(`TD_FILE, "r");
        if (td_file == 0) begin
            $display("Error: Could not open TD test file");
            $finish;
        end
        
        $display("Loading TD test patterns...");
        i = 0;
        while (!$feof(td_file) && i < TD_TEST_PATTERN_DEPTH) begin
            // 跳過註解行
            if ($fgets(line_buffer, td_file)) begin
                // if (line_buffer[8*100:8*98] == "//") begin
                //     continue;  // 跳過註解行
                // end
                
                // 解析TD格式: W1(8-bit) W2(8-bit) A1(8-bit) A2(8-bit) P1(19-bit) P2(19-bit) Launch_Answer(19-bit) Capture_Answer(19-bit)
                td_scan_result = $sscanf(line_buffer, "%b %b %b %b %b %b %b %b", 
                    temp_weight1, temp_weight2, temp_activation1, temp_activation2, 
                    temp_partial_sum1, temp_partial_sum2, temp_answer1, temp_answer2);
                
                if (td_scan_result == 8) begin
                    TD_weight_1_reg[i] = temp_weight1;
                    TD_weight_2_reg[i] = temp_weight2;
                    TD_activation_1_reg[i] = temp_activation1;
                    TD_activation_2_reg[i] = temp_activation2;
                    TD_partial_sum_in_1_reg[i] = temp_partial_sum1;
                    TD_partial_sum_in_2_reg[i] = temp_partial_sum2;
                    TD_launch_answer_reg[i] = temp_answer1;
                    TD_capture_answer_reg[i] = temp_answer2;
                    $display("TD Pattern %0d: W1=%b W2=%b A1=%b A2=%b P1=%b P2=%b L=%b C=%b", 
                             i, temp_weight1, temp_weight2, temp_activation1, temp_activation2,
                             temp_partial_sum1, temp_partial_sum2, temp_answer1, temp_answer2);
                    i = i + 1;
                end
            end
        end
        $fclose(td_file);
        $display("TD patterns loaded: %0d patterns", i);

        // 將資料載入DUT的記憶體中
        $display("Loading data into DUT memory...");
        
        // 載入MBIST測試資料到Memory_data_generator
        for (i = 0; i < MBIST_PATTERN_DEPTH; i = i + 1) begin
            UUT.hybrid_bist_inst.memory_data_gen_inst.Memory_test_data[i] = Memory_test_data[i];
        end

        // 載入SA測試資料到eNVM
        for (i = 0; i < SA_TEST_PATTERN_DEPTH; i = i + 1) begin
            UUT.eNVM_inst.SA_weight_reg[i] = SA_weight_reg[i];
            UUT.eNVM_inst.SA_activation_reg[i] = SA_activation_reg[i];
            UUT.eNVM_inst.SA_partial_sum_in_reg[i] = SA_partial_sum_in_reg[i];
            UUT.eNVM_inst.SA_answer_reg[i] = SA_answer_reg[i];
        end

        // 載入TD測試資料到eNVM
        for (i = 0; i < TD_TEST_PATTERN_DEPTH; i = i + 1) begin
            UUT.eNVM_inst.TD_weight_1_reg[i] = TD_weight_1_reg[i];
            UUT.eNVM_inst.TD_weight_2_reg[i] = TD_weight_2_reg[i];
            UUT.eNVM_inst.TD_activation_1_reg[i] = TD_activation_1_reg[i];
            UUT.eNVM_inst.TD_activation_2_reg[i] = TD_activation_2_reg[i];
            UUT.eNVM_inst.TD_partial_sum_in_1_reg[i] = TD_partial_sum_in_1_reg[i];
            UUT.eNVM_inst.TD_partial_sum_in_2_reg[i] = TD_partial_sum_in_2_reg[i];
            UUT.eNVM_inst.TD_launch_answer_reg[i] = TD_launch_answer_reg[i];
            UUT.eNVM_inst.TD_capture_answer_reg[i] = TD_capture_answer_reg[i];
        end

        $display("All test data loaded successfully!");
        
        // wait some cycle
        #(`CYCLE);
        
        // 開始測試
        test_mode = `HIGH;
        START = `HIGH;
        BIST_mode = 1'b0;  // 先進行MBIST測試   
        #(`CYCLE) START = `LOW;

        $display("Starting MBIST test at time %0t", $time);
        
        // 等待MBIST測試完成
        wait(test_done);
        $display("MBIST test completed at time %0t", $time);
        if (MBIST_FAIL) begin
            $display("MBIST FAILED!");
        end else begin
            $display("MBIST PASSED!");
        end
        
        #(`CYCLE*2);

        #(`CYCLE/2);    //等半個cycle讓START 訊號在cycle之間
        
        // 開始LBIST測試 (SA + TD)
        BIST_mode = 1'b1;  // LBIST模式
        START = `HIGH;
        #(`CYCLE) START = `LOW;
        $display("Starting LBIST test at time %0t", $time);
        
        // 等待LBIST測試完成
        wait(test_done);
        $display("LBIST test completed at time %0t", $time);
        if (TD_error_flag) begin
            $display("TD test FAILED!");
        end else begin
            $display("LBIST PASSED!");
        end
        
        #(`CYCLE*5);
        $display("Simulation completed successfully!");
        $finish;
    end

    // reset signal
    initial begin
        rst_n = 1'b1;
        @(posedge clk);
        #2 rst_n = 1'b0;
        #(`CYCLE/2);  
        rst_n = 1'b1;
    end



    // 監控信號變化
    always @(posedge clk) begin
        if (test_mode && START) begin
            if (BIST_mode == 0) begin
                // MBIST監控
                if (UUT.hybrid_bist_inst.current_state != UUT.hybrid_bist_inst.IDLE) begin
                    $display("Time: %0t, MBIST State: %0d, Pattern: %0d", 
                             $time, UUT.hybrid_bist_inst.current_state, 
                             UUT.hybrid_bist_inst.pattern_counter);
                end
            end else begin
                // LBIST監控
                if (UUT.hybrid_bist_inst.current_state != UUT.hybrid_bist_inst.IDLE) begin
                    $display("Time: %0t, LBIST State: %0d, Test Type: %0d, Pattern: %0d", 
                             $time, UUT.hybrid_bist_inst.current_state, 
                             UUT.hybrid_bist_inst.test_type, UUT.hybrid_bist_inst.pattern_counter);
                end
            end
        end
    end

endmodule