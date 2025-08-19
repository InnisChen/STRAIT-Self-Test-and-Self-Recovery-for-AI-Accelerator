// STRAIT.v

module STRAIT #(
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
    // input 
    input clk,
    // input clk_w,
    input rst_n,
    input START,
    input test_mode,    // 是否在測試模式
    input BIST_mode,    // 0: MBIST, 1: LBIST
    
    // 正常使用systolic array 時的data
    input weight_valid, // 送給bisr
    input [SYSTOLIC_SIZE*WEIGHT_WIDTH-1:0] input_weight_flat, // 給bisr
    input [SYSTOLIC_SIZE*ACTIVATION_WIDTH-1:0] input_activation_flat, // 給activation_mem),
    input [SYSTOLIC_SIZE*PARTIAL_SUM_WIDTH-1:0] input_partial_sum_flat, // 給 Weight_partialsum_buffer

    input activation_valid, // 送給bist開始計數地址，再送給activation_mem當寫入地址

    // 外部送入要讀取accumulator的地址
    input [ADDR_WIDTH-1:0] rd_addr, // 從外部送入讀取地址，讀取accumulator的部分和輸出
    
    // output
    output [SYSTOLIC_SIZE*PARTIAL_SUM_WIDTH-1:0] partial_sum_outputs_flat_outside,
    output test_done,  // 測試完成信號，MBIST , SA , TD 測試完都會拉高1cycle
    output TD_error_flag,
    output MBIST_FAIL,

    output recovery_success,    // 從bisr送出
    output recovery_done        // 從bisr送出
);

////////////////////////////////////////////////////////////////////////////////////////////////////

wire [SYSTOLIC_SIZE*SYSTOLIC_SIZE-1:0] envm_faulty_patterns_flat_envm_bisr;
wire [WEIGHT_WIDTH-1:0] Scan_data_weight_envm_bist;
wire [ACTIVATION_WIDTH-1:0] Scan_data_activation_envm_bist;
wire [PARTIAL_SUM_WIDTH-1:0] Scan_data_partial_sum_in_envm_bist;
wire [PARTIAL_SUM_WIDTH-1:0] Scan_data_answer_envm_bist;

////////////////////////////////////////////////////////////////////////////////////////////////////

wire [SYSTOLIC_SIZE*WEIGHT_WIDTH-1:0] weights_flat_bisr_buffer;
wire [SYSTOLIC_SIZE-1:0] pe_disable_in_bisr_buffer;
wire [ADDR_WIDTH-1:0] output_mapped_addr_bisr_activationmem;

////////////////////////////////////////////////////////////////////////////////////////////////////

wire [SYSTOLIC_SIZE*WEIGHT_WIDTH-1:0] weight_out_flat_buffer_array;
wire [SYSTOLIC_SIZE*PARTIAL_SUM_WIDTH-1:0] partial_sum_flat_buffer_array;
wire [SYSTOLIC_SIZE-1:0] pe_disable_buffer_array;

////////////////////////////////////////////////////////////////////////////////////////////////////

wire [PARTIAL_SUM_WIDTH*SYSTOLIC_SIZE-1:0] partial_sum_flat_array_accumulator;

////////////////////////////////////////////////////////////////////////////////////////////////////

wire [SYSTOLIC_SIZE*PARTIAL_SUM_WIDTH-1:0] partial_sum_outputs_flat;

////////////////////////////////////////////////////////////////////////////////////////////////////

wire [SYSTOLIC_SIZE*ACTIVATION_WIDTH-1:0] activation_flat_activationmem_buffer;

////////////////////////////////////////////////////////////////////////////////////////////////////

wire [SYSTOLIC_SIZE*ACTIVATION_WIDTH-1:0] activation_data_flat_buffer_array;

////////////////////////////////////////////////////////////////////////////////////////////////////

wire test_type;
wire [MAX_PATTERN_ADDR_WIDTH-1:0] pattern_counter_bist_envm;
wire TD_answer_choose_bist_envm;
wire detection_en_bist_envm;
wire [ADDR_WIDTH-1:0] detection_addr_bist_envm;
wire clk_w;
wire scan_en_bist_array;
wire envm_wr_en_bist_bisr;
wire allocation_start_bist_bisr;
wire [ADDR_WIDTH-1:0] read_addr_bist_bisr;
wire [SYSTOLIC_SIZE*WEIGHT_WIDTH-1:0] weight_in_test_flat_bist_buffer;
wire [SYSTOLIC_SIZE*PARTIAL_SUM_WIDTH-1:0] partial_sum_test_flat_bist_buffer;
wire [SYSTOLIC_SIZE*ACTIVATION_WIDTH-1:0] activation_in_test_flat_bist_buffer;
wire start_en_bist_dlc;
wire [SYSTOLIC_SIZE-1:0] compared_results_bist_dlc;
wire wr_en_bist_accumulator;
wire [ADDR_WIDTH-1:0] wr_addr_bist_accumulator;
wire [PARTIAL_SUM_WIDTH*SYSTOLIC_SIZE-1:0] partial_sum_flat_bist_accumulator;
wire [ADDR_WIDTH-1:0] rd_addr_bist_accumulator;
wire wr_en_bist_activationmem;
wire [ADDR_WIDTH-1:0] wr_addr_bist_activationmem;

////////////////////////////////////////////////////////////////////////////////////////////////////

wire [SYSTOLIC_SIZE-1:0] single_pe_detection_dlc_envm;
wire [SYSTOLIC_SIZE-1:0] column_fault_detection_dlc_envm;
wire [SYSTOLIC_SIZE-1:0] row_fault_detection_dlc_envm;

////////////////////////////////////////////////////////////////////////////////////////////////////


    // eNVM 
    eNVM #(
        .SYSTOLIC_SIZE(SYSTOLIC_SIZE),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .ACTIVATION_WIDTH(ACTIVATION_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .PARTIAL_SUM_WIDTH(PARTIAL_SUM_WIDTH),
        .SA_TEST_PATTERN_DEPTH(SA_TEST_PATTERN_DEPTH),
        .TD_TEST_PATTERN_DEPTH(TD_TEST_PATTERN_DEPTH)
    ) eNVM_inst (
        // input 
        .clk(clk),
        .test_type(test_type), // 0: SA , 1: TD    from hybrid_bist
        .TD_answer_choose(TD_answer_choose_bist_envm), // TD測試下，選擇要launch還是capture answer( 0: launch answer , 1: capture answer )
        .pattern_counter(pattern_counter_bist_envm),      // 需要第幾個test_pattern
        .detection_en(detection_en_bist_envm),      // bist告知envm可以開始讀DLC的資料
        .detection_addr(detection_addr_bist_envm),      // 需要讀取第幾個row的錯誤資訊

        .single_pe_detection(single_pe_detection_dlc_envm),
        .column_fault_detection(column_fault_detection_dlc_envm),   
        .row_fault_detection(row_fault_detection_dlc_envm),     //每次1bit 傳n次
        
        // output
        .envm_faulty_patterns_flat(envm_faulty_patterns_flat_envm_bisr),

        // test_data 先送到bist再分配給weight 或 activation 的 buffer ，波形比較好觀察
        .Scan_data_weight(Scan_data_weight_envm_bist),
        .Scan_data_activation(Scan_data_activation_envm_bist),
        .Scan_data_partial_sum_in(Scan_data_partial_sum_in_envm_bist),
        .Scan_data_answer(Scan_data_answer_envm_bist) 
    );


    // BISR (faulty_pe_storage , mapping_table , row_weight_storage)
    bisr_weight_allocation #(
        .SYSTOLIC_SIZE(SYSTOLIC_SIZE),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .ACTIVATION_WIDTH(ACTIVATION_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) bisr_weight_allocation_inst (
        // input 
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(envm_wr_en_bist_bisr),
        .envm_faulty_patterns_flat(envm_faulty_patterns_flat_envm_bisr),    // from envm to bisr
        .allocation_start(allocation_start_bist_bisr),                      // 開始權重配置的信號，從bist送
        .input_weights(input_weight_flat),  // from outside
        .weight_valid(weight_valid),    // from outside
        .read_addr(read_addr_bist_bisr),    // 從bist的address generator 給，正常配置時使用

        // output
        .output_weights_flat(weights_flat_bisr_buffer),   // from bisr to systolic array
        .pe_disable_out(pe_disable_in_bisr_buffer),
        .output_mapped_addr(output_mapped_addr_bisr_activationmem),  //from bisr to activation_mem
        .recovery_success(recovery_success),    // 送到外部
        .recovery_done(recovery_done)           // 送到外部
    );

    // Weight_buffer
    Weight_partialsum_buffer #(
        .SYSTOLIC_SIZE(SYSTOLIC_SIZE),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .ACTIVATION_WIDTH(ACTIVATION_WIDTH),
        .PARTIAL_SUM_WIDTH(PARTIAL_SUM_WIDTH)
    ) Weight_partialsum_buffer_inst (
        // input 
        .test_mode(test_mode),    // 0: 正常模式45度, 1: 測試模式平行送入
        .weight_in_test_flat(weight_in_test_flat_bist_buffer), // 考慮輸入是否縮減成 [WEIGHT_WIDTH-1:0] ，在bist內部複製訊號成flat就好。 因測試權重都是相同的
        .weight_in_bisr_flat(weights_flat_bisr_buffer), // 從bisr送入的權重
        .partial_sum_in_test_flat(partial_sum_test_flat_bist_buffer),   // 從bist送入測試的資料
        .partial_sum_in_outside_flat(input_partial_sum_flat),   // 從外部送入
        .pe_disable_in(pe_disable_in_bisr_buffer), // 正常使用時，每個PE是否disable，從bisr的faulty_pe_storage送入

        // output
        .weight_out_flat(weight_out_flat_buffer_array), // 輸出到systolic array
        .partial_sum_out_flat(partial_sum_flat_buffer_array),
        .pe_disable_out(pe_disable_buffer_array) // 每個PE是否disable
    );

    // Systolic Array (PE_STRAIT)
    Systolic_array #(
        .SYSTOLIC_SIZE(SYSTOLIC_SIZE),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .ACTIVATION_WIDTH(ACTIVATION_WIDTH),
        .PARTIAL_SUM_WIDTH(PARTIAL_SUM_WIDTH)
    ) Systolic_array_inst (
        // input 
        .clk(clk),
        .clk_w(clk_w),
        .rst_n(rst_n),
        .scan_en(scan_en_bist_array),
        .PE_disable(pe_disable_buffer_array),
        .weight_flat(weight_out_flat_buffer_array),   // 正常使用從bisr，要考慮測試時權重是否依樣要從bisr，或是從bist再加多工器選擇
        .activation_flat(activation_data_flat_buffer_array),
        .partial_sum_in_flat(partial_sum_flat_buffer_array),  // 跟權重一起

        // output
        .partial_sum_out_flat(partial_sum_flat_array_accumulator)   // from systolic array to accumulator
    );


    // Accumulator (Accumulator_mem)
    // 記憶體組成，需要讀寫記憶體
    assign partial_sum_outputs_flat_outside = test_mode ? {SYSTOLIC_SIZE*PARTIAL_SUM_WIDTH{1'b0}} : partial_sum_outputs_flat; // 正常使用時，從accumulator輸出部分和，測試模式時輸出0

    Accumulator #(
        .SYSTOLIC_SIZE(SYSTOLIC_SIZE),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .ACTIVATION_WIDTH(ACTIVATION_WIDTH),
        .PARTIAL_SUM_WIDTH(PARTIAL_SUM_WIDTH),
        // .PATTERN_NUMBER(),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) Accumulator_inst (
        // input 
        .clk(clk),
        .rst_n(rst_n),
        .test_mode(test_mode),
        .BIST_mode(BIST_mode),    // 0: MBIST, 1: LBIST
        .wr_en(wr_en_bist_accumulator),
        .wr_addr(wr_addr_bist_accumulator),  // 正常使用時，可能要需要從bist的address generator 給
        .partial_sum_inputs_array_flat(partial_sum_flat_array_accumulator),   // from systolic array to accumulator
        .partial_sum_inputs_test_flat(partial_sum_flat_bist_accumulator), // MBIST 測試模式下的輸入部分和，從BIST送入
        .rd_addr_bist(rd_addr_bist_accumulator),  // 測試時用bist給讀取地址
        .rd_addr_outside(rd_addr),  // 正常使用從外面送讀取地址

        // output
        .partial_sum_outputs_flat(partial_sum_outputs_flat) // 1. 給bist的比較器 2. 給外部輸出計算結果
    );

    // Activation_mem
    Activation_mem #(
        .SYSTOLIC_SIZE(SYSTOLIC_SIZE),
        .ACTIVATION_WIDTH(ACTIVATION_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) Activation_mem_inst (
        // input
        .clk(clk),
        .wr_en(wr_en_bist_activationmem),
        .wr_addr(wr_addr_bist_activationmem),
        .activation_inputs_flat(input_activation_flat),  // 1. 從外部輸入激活值  (2. 從bist送入激活值 ， 在buffer選擇)
        .rd_addr(output_mapped_addr_bisr_activationmem),    // from bisr的mapping_table 根據配置後的位置送到activation_mem

        // output
        .activation_outputs_flat(activation_flat_activationmem_buffer)   // from activation_mem to systolic array
    );  


    // Activation_buffer
    Activation_buffer #(
        .SYSTOLIC_SIZE(SYSTOLIC_SIZE),
        .ACTIVATION_WIDTH(ACTIVATION_WIDTH)
    ) Activation_buffer_inst (
        // input 
        .clk(clk),
        .rst_n(rst_n),
        .test_mode(test_mode),    // 0: 正常模式45度, 1: 測試模式 送出bist給的data
        .activation_in_test_flat(activation_in_test_flat_bist_buffer), // from bist to buffer
        .activation_in_activationmem_flat(activation_flat_activationmem_buffer),  // from activation_mem to buffer

        // output
        .activation_out_flat(activation_data_flat_buffer_array)  // from buffer to systolic array
    );

    hybrid_bist #(
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
    ) hybrid_bist_inst (
        // input 
        // 基本控制信號 - inputs
        .clk(clk),
        .rst_n(rst_n),
        .START(START),
        .test_mode(test_mode),
        .BIST_mode(BIST_mode),
        .activation_valid(activation_valid),
        
        // 與 eNVM 的介面 - inputs
        .envm_weight(Scan_data_weight_envm_bist),
        .envm_activation(Scan_data_activation_envm_bist),
        .envm_partial_sum_in(Scan_data_partial_sum_in_envm_bist),
        .envm_answer(Scan_data_answer_envm_bist),
        
        // Accumulator 回饋信號 - inputs
        // partial_sum_outputs_flat 1. 給bist的比較器 2. 給外部輸出計算結果
        .partial_sum_flat(partial_sum_outputs_flat),
        
        // output
        // 與 eNVM 的介面 - outputs
        .test_type(test_type),      // 0: SA, 1: TD
        .pattern_counter(pattern_counter_bist_envm),
        .TD_answer_choose(TD_answer_choose_bist_envm),
        .detection_en(detection_en_bist_envm),
        .detection_addr(detection_addr_bist_envm),
        
        // 控制 Systolic Array 的信號 - outputs
        .clk_w(clk_w),
        .scan_en(scan_en_bist_array),
        
        // 給 BISR 的控制信號 - outputs
        .envm_wr_en_bist_bisr(envm_wr_en_bist_bisr),
        .allocation_start(allocation_start_bist_bisr),
        .read_addr(read_addr_bist_bisr),
        
        // 給 Weight_partialsum_buffer 的控制信號 - outputs
        .weight_in_test_flat(weight_in_test_flat_bist_buffer),
        .partial_sum_test_flat(partial_sum_test_flat_bist_buffer),
        
        // 給 Activation_buffer 的激活控制信號 - outputs
        .activation_in_test_flat(activation_in_test_flat_bist_buffer),
        
        // 診斷電路控制信號 - outputs
        .diagnosis_start_en(start_en_bist_dlc),
        .compared_results(compared_results_bist_dlc), // 連接到 DLC
        
        // Accumulator 控制信號 (MBIST + LBIST 共用) - outputs
        .acc_wr_en(wr_en_bist_accumulator),
        .acc_wr_addr(wr_addr_bist_accumulator),
        .acc_wr_data(partial_sum_flat_bist_accumulator),  // 連接到已存在的測試資料信號
        .acc_rd_addr(rd_addr_bist_accumulator),
        
        // Activation_mem 控制信號 - outputs
        .activation_mem_wr_en(wr_en_bist_activationmem),
        .activation_mem_wr_addr(wr_addr_bist_activationmem),
        
        // 測試結果 - outputs
        .test_done(test_done),  // 測試完成信號，通知 test_bench
        .TD_error_flag(TD_error_flag),
        .MBIST_FAIL(MBIST_FAIL)
    );


    // Diagnosis_loop_chains
    Diagnostic_loop_chains #(
        .SYSTOLIC_SIZE(SYSTOLIC_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) Diagnostic_loop_chains_inst (
        // input
        .clk(clk),
        .rst_n(rst_n),
        .start_en(start_en_bist_dlc),    // 送到accumulator後啟動
        .col_inputs(compared_results_bist_dlc),   // from bist 的comparator

        // output
        .single_pe_detection(single_pe_detection_dlc_envm),
        .column_fault_detection(column_fault_detection_dlc_envm),
        .row_fault_detection(row_fault_detection_dlc_envm)
    );
    
endmodule