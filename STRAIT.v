// STRAIT.v

module STRAIT #(
    parameter SYSTOLIC_SIZE = 8,
    parameter WEIGHT_WIDTH = 8,
    parameter ACTIVATION_WIDTH = 8,
    parameter PARTIAL_SUM_WIDTH = WEIGHT_WIDTH + ACTIVATION_WIDTH + $clog2(SYSTOLIC_SIZE),
    parameter ADDR_WIDTH = $clog2(SYSTOLIC_SIZE),
    parameter SA_TEST_PATTERN_DEPTH = 12,
    parameter TD_TEST_PATTERN_DEPTH = 16,
    parameter MBIST_PATTERN_DEPTH = 8,
    parameter MAX_PATTERN_ADDR_WIDTH = $clog2(TD_TEST_PATTERN_DEPTH)
) (
    // input 
    input clk,
    input clk_w,
    input rst_n,
    input START,
    input test_mode,    // 是否在測試模式
    input BIST_mode,    // 0: MBIST, 1: LBIST
    
    // 正常使用systolic array 時的data
    input weight_valid, // 送給bisr
    input [SYSTOLIC_SIZE*WEIGHT_WIDTH-1:0] input_weight_flat, // 送給bisr
    input [SYSTOLIC_SIZE*ACTIVATION_WIDTH-1:0] input_activation_flat,
    input [SYSTOLIC_SIZE*PARTIAL_SUM_WIDTH-1:0] input_partial_sum_in_flat,
    
    // output
    output [SYSTOLIC_SIZE*PARTIAL_SUM_WIDTH-1:0] partial_sum_out_flat,
    output MBIST_test_result,
    output LBIST_test_result
);

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
        .test_type(test_type), // 0: SA , 1: TD
        .test_counter(test_counter), // 需要第幾個test_pattern
        .detection_en(detection_en),
        .counter(counter_dlc_envm),
        .single_pe_detection(single_pe_detection),
        .row_fault_detection(row_fault_detection),      //每次1bit 傳n次
        .column_fault_detection(column_fault_detection_dlc_envm),

        // output
        .envm_faulty_patterns_flat(envm_faulty_patterns_flat),
        .Scan_data_weight(Scan_data_weight),
        .Scan_data_activation(Scan_data_activation),
        .Scan_data_answer(Scan_data_answer)
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
        .envm_wr_en(envm_wr_en),
        .envm_faulty_patterns_flat(envm_faulty_patterns_flat),
        .weight_start(weight_start),                                    // 開始權重配置的信號
        .input_weights(input_weight_flat),
        .weight_valid(weight_valid),
        .read_addr(read_addr),

        // output
        .output_weights_flat(output_weights_flat_bisr_array),   //from bisr to systolic array
        .output_mapped_addr(output_mapped_addr_bisr_activationmem),  //from bisr to activation_mem
        .recovery_success(recovery_success),
        .recovery_done(recovery_done)
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
        .scan_en(scan_en),
        .PE_disable(PE_disable),
        .weight_flat(output_weights_flat_bisr_array),
        .activation_flat(activation_data_flat_activationmem_buffer),
        .partial_sum_in_flat(partial_sum_in),

        // output
        .partial_sum_out_flat(partial_sum_out_flat)
    );


    // Accumulator
    Accumulator #(
        .SYSTOLIC_SIZE(SYSTOLIC_SIZE),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .ACTIVATION_WIDTH(ACTIVATION_WIDTH),
        .PARTIAL_SUM_WIDTH(PARTIAL_SUM_WIDTH),
        .PATTERN_NUMBER(SA_TEST_PATTERN_DEPTH), // 或 TD_TEST_PATTERN_DEPTH
        .ADDR_WIDTH(ADDR_WIDTH)
    ) Accumulator_inst (
        // input 
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .test_mode(test_mode),
        .wr_addr(wr_addr),
        .partial_sum_inputs_flat(partial_sum_inputs_flat),
        .rd_addr(rd_addr),

        // output
        .partial_sum_outputs_flat(partial_sum_outputs_flat)
    );


    // Activation_mem
    Activation_mem #(
        .SYSTOLIC_SIZE(SYSTOLIC_SIZE),
        .ACTIVATION_WIDTH(ACTIVATION_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) Activation_mem_inst (
        // input
        .clk(clk),
        .wr_en(wr_en),
        .wr_addr(wr_addr),
        .activation_inputs_flat(input_activation_flat),  // 從外部輸入激活值
        .rd_addr(output_mapped_addr_bisr_activationmem),    // from bisr to activation_mem

        // output
        .activation_outputs_flat(activation_data_flat_activationmem_buffer)   // from activation_mem to systolic array
    );  


    // Buffer (Activation buffer)
    Buffer #(
        .SYSTOLIC_SIZE(SYSTOLIC_SIZE),
        .ACTIVATION_WIDTH(ACTIVATION_WIDTH)
    ) Activation_Buffer_inst (
        // input 
        .clk(clk),
        .rst_n(rst_n),
        .test_mode(test_mode),    // 0: 正常模式45度, 1: 測試模式平行送入
        .activation_in_flat(activation_data_flat_activationmem_buffer),   // from activation_mem to buffer

        // output
        .activation_out_flat(activation_data_flat_buffer_array)  // from buffer to systolic array
    );

    // hybrid_bist (comparator)
    hybrid_bist #(
        .SYSTOLIC_SIZE(SYSTOLIC_SIZE),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .ACTIVATION_WIDTH(ACTIVATION_WIDTH),
        .PARTIAL_SUM_WIDTH(PARTIAL_SUM_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .SA_TEST_PATTERN_DEPTH(SA_TEST_PATTERN_DEPTH),
        .TD_TEST_PATTERN_DEPTH(TD_TEST_PATTERN_DEPTH),
        .MBIST_PATTERN_DEPTH(MBIST_PATTERN_DEPTH),
        .MAX_PATTERN_ADDR_WIDTH(MAX_PATTERN_ADDR_WIDTH)
    ) hybrid_bist_inst (
        .clk(clk),
        .rst_n(rst_n),
        .BIST_mode(BIST_mode),    // 0: MBIST, 1: LBIST
        .test_type(test_type),                                   // 0: SA, 1: TD
        .test_counter(test_counter),                             // eNVM pattern 索引
        .td_pe_select(td_pe_select),                             // TD 測試時的 PE 選擇 (0-3)
        .envm_weight(envm_weight),                               // 從 eNVM 來的權重
        .envm_activation(envm_activation),                       // 從 eNVM 來的激活
        .envm_answer(envm_answer),                               // 從 eNVM 來的預期結果
        .scan_en(scan_en),                                       // 掃描使能信號
        .MBIST_test_result(MBIST_test_result),
        .LBIST_test_result(LBIST_test_result)
    );


    // Diagnosis_loop_chains
    Diagnostic_loop_chains #(
        .SYSTOLIC_SIZE(SYSTOLIC_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) Diagnostic_loop_chains_inst (
        // input
        .clk(clk),
        .rst_n(rst_n),
        .start_en(start_en),    // 送到accumulator後啟動
        .col_inputs(col_inputs),

        // output
        .column_fault_detection(column_fault_detection_dlc_envm),
        .row_fault_detection(row_fault_detection),
        .single_pe_detection(single_pe_detection),
        .counter(counter_dlc_envm)   //輸出給envm讀取第幾個row的錯誤資訊，因envm 沒有rst沒辦法rst counter 訊號
    );
    
endmodule