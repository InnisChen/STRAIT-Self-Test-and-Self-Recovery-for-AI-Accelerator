//eNVM.v

module eNVM #(
    parameter SYSTOLIC_SIZE = 8,
    parameter WEIGHT_WIDTH = 8,
    parameter ACTIVATION_WIDTH = 8,
    parameter ADDR_WIDTH = $clog2(SYSTOLIC_SIZE),
    parameter PARTIAL_SUM_WIDTH = WEIGHT_WIDTH + ACTIVATION_WIDTH + $clog2(SYSTOLIC_SIZE),
    parameter SA_TEST_PATTERN_DEPTH = 12,
    parameter TD_TEST_PATTERN_DEPTH = 18,
    parameter MAX_PATTERN_ADDR_WIDTH = (SA_TEST_PATTERN_DEPTH > TD_TEST_PATTERN_DEPTH) ? $clog2(SA_TEST_PATTERN_DEPTH) : $clog2(TD_TEST_PATTERN_DEPTH)
) (
    input clk,
    // input rst_n,
    input test_type, // 0: SA , 1: TD
    input TD_answer_choose , // TD測試下，選擇要launch還是capture answer( 0: launch answer , 1: capture answer )
    input [MAX_PATTERN_ADDR_WIDTH-1:0] pattern_counter, // 需要第幾個test_pattern
    input detection_en,     // 診斷結果送到envm儲存訊號
    input [ADDR_WIDTH-1:0] detection_addr,
    input [SYSTOLIC_SIZE-1:0] single_pe_detection,
    input [SYSTOLIC_SIZE-1:0] column_fault_detection,   //一次傳全部
    input [SYSTOLIC_SIZE-1:0] row_fault_detection,      //...
    
    output [SYSTOLIC_SIZE*SYSTOLIC_SIZE-1:0] envm_faulty_patterns_flat,
    output [WEIGHT_WIDTH-1:0] Scan_data_weight,
    output [ACTIVATION_WIDTH-1:0] Scan_data_activation,
    output [PARTIAL_SUM_WIDTH-1:0] Scan_data_partial_sum_in,
    output [PARTIAL_SUM_WIDTH-1:0] Scan_data_answer
);
    //Scan data (test_bench 直接送)
    reg [WEIGHT_WIDTH-1:0] SA_weight_reg [0:SA_TEST_PATTERN_DEPTH-1];
    reg [ACTIVATION_WIDTH-1:0] SA_activation_reg [0:SA_TEST_PATTERN_DEPTH-1];
    reg [PARTIAL_SUM_WIDTH-1:0] SA_partial_sum_in_reg [0:SA_TEST_PATTERN_DEPTH-1];
    reg [PARTIAL_SUM_WIDTH-1:0] SA_answer_reg [0:SA_TEST_PATTERN_DEPTH-1];

    reg [WEIGHT_WIDTH-1:0] TD_weight_1_reg [0:TD_TEST_PATTERN_DEPTH-1];
    reg [WEIGHT_WIDTH-1:0] TD_weight_2_reg [0:TD_TEST_PATTERN_DEPTH-1];
    reg [ACTIVATION_WIDTH-1:0] TD_activation_1_reg [0:TD_TEST_PATTERN_DEPTH-1];
    reg [ACTIVATION_WIDTH-1:0] TD_activation_2_reg [0:TD_TEST_PATTERN_DEPTH-1];
    reg [PARTIAL_SUM_WIDTH-1:0] TD_partial_sum_in_1_reg [0:TD_TEST_PATTERN_DEPTH-1];
    reg [PARTIAL_SUM_WIDTH-1:0] TD_partial_sum_in_2_reg [0:TD_TEST_PATTERN_DEPTH-1];
    reg [PARTIAL_SUM_WIDTH-1:0] TD_launch_answer_reg [0:TD_TEST_PATTERN_DEPTH-1];
    reg [PARTIAL_SUM_WIDTH-1:0] TD_capture_answer_reg [0:TD_TEST_PATTERN_DEPTH-1];

    // test_type  0: SA , 1: TD
    assign Scan_data_weight = test_type ? TD_weight_2_reg[pattern_counter] : SA_weight_reg[pattern_counter];
    assign Scan_data_activation = test_type ? (TD_answer_choose ? TD_activation_1_reg[pattern_counter] : TD_activation_2_reg[pattern_counter]) : SA_activation_reg[pattern_counter];
    assign Scan_data_partial_sum_in = test_type ? (TD_answer_choose ? TD_partial_sum_in_1_reg[pattern_counter] : TD_partial_sum_in_2_reg[pattern_counter]) : SA_partial_sum_in_reg[pattern_counter];
    assign Scan_data_answer = test_type ? (TD_answer_choose ? TD_capture_answer_reg[pattern_counter] : TD_launch_answer_reg[pattern_counter]) : SA_answer_reg[pattern_counter];


    // Faulty PE Storage
    reg [SYSTOLIC_SIZE-1:0] faulty_row_storage;
    reg [SYSTOLIC_SIZE-1:0] faulty_column_storage;
    reg [SYSTOLIC_SIZE-1:0] faulty_pe_storage [SYSTOLIC_SIZE-1:0];


    always @(posedge clk ) begin
        if(detection_en) begin
            faulty_row_storage <= row_fault_detection;
            faulty_column_storage <= column_fault_detection;
            // faulty_row_storage[detection_addr] <= row_fault_detection;
            // faulty_column_storage[detection_addr] <= column_fault_detection;

            faulty_pe_storage[detection_addr] <= single_pe_detection;
        end
        else;
    end


    // faulty_pe_storage 攤平
    genvar i;
    generate
        for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin : flatten_faulty_patterns
            assign envm_faulty_patterns_flat[i*SYSTOLIC_SIZE +: SYSTOLIC_SIZE] = faulty_pe_storage[i];
        end
    endgenerate


    
endmodule