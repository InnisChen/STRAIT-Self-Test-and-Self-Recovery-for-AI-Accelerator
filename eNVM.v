//eNVM.v

module eNVM #(
    parameter SYSTOLIC_SIZE = 8,
    parameter WEIGHT_WIDTH = 8,
    parameter ACTIVATION_WIDTH = 8,
    parameter ADDR_WIDTH = $clog2(SYSTOLIC_SIZE),
    parameter PARTIAL_SUM_WIDTH = WEIGHT_WIDTH + ACTIVATION_WIDTH + $clog2(SYSTOLIC_SIZE),

    parameter SA_TEST_PATTERN_DEPTH = 12,
    parameter TD_TEST_PATTERN_DEPTH = 18,
    // parameter SA_PATTERN_ADDR_WIDTH = $clog2(SA_TEST_PATTERN_DEPTH),
    // parameter TD_PATTERN_ADDR_WIDTH = $clog2(TD_TEST_PATTERN_DEPTH),

    parameter MAX_ADDR_WIDTH = (SA_TEST_PATTERN_DEPTH > TD_TEST_PATTERN_DEPTH) ? $clog2(SA_TEST_PATTERN_DEPTH) : $clog2(TD_TEST_PATTERN_DEPTH)
) (
    input clk,
    // input rst_n,
    input test_type, // 0: SA , 1: TD
    input [MAX_ADDR_WIDTH-1:0] test_counter, // 需要第幾個test_pattern
    input detection_en,
    input [ADDR_WIDTH-1:0] counter,
    input [SYSTOLIC_SIZE-1:0] single_pe_detection,
    input row_fault_detection,      //每次1bit 傳n次
    input column_fault_detection,   //....

    output [SYSTOLIC_SIZE*SYSTOLIC_SIZE-1:0] envm_faulty_patterns_flat,
    output [WEIGHT_WIDTH-1:0] Scan_data_weight,
    output [ACTIVATION_WIDTH-1:0] Scan_data_activation,
    output [PARTIAL_SUM_WIDTH-1:0] Scan_data_answer
);
    //Scan data (test_bench 直接送)
    reg [WEIGHT_WIDTH-1:0] SA_Scan_data_weight_reg [0:SA_TEST_PATTERN_DEPTH-1];
    reg [ACTIVATION_WIDTH-1:0] SA_Scan_data_activation_reg [0:SA_TEST_PATTERN_DEPTH-1];
    reg [PARTIAL_SUM_WIDTH-1:0] SA_Scan_data_answer_reg [0:SA_TEST_PATTERN_DEPTH-1];

    reg [WEIGHT_WIDTH-1:0] TD_Scan_data_weight_reg [0:TD_TEST_PATTERN_DEPTH-1];
    reg [ACTIVATION_WIDTH-1:0] TD_Scan_data_activation_reg [0:TD_TEST_PATTERN_DEPTH-1];
    reg [PARTIAL_SUM_WIDTH-1:0] TD_Scan_data_answer_reg [0:TD_TEST_PATTERN_DEPTH-1];

    assign Scan_data_weight = test_type ? TD_Scan_data_weight_reg[test_counter] : SA_Scan_data_weight_reg[test_counter];
    assign Scan_data_activation = test_type ? TD_Scan_data_activation_reg[test_counter] : SA_Scan_data_activation_reg[test_counter];
    assign Scan_data_answer = test_type ? TD_Scan_data_answer_reg[test_counter] : SA_Scan_data_answer_reg[test_counter];



    // Faulty PE Storage
    reg [SYSTOLIC_SIZE-1:0] faulty_row_storage;
    reg [SYSTOLIC_SIZE-1:0] faulty_column_storage;
    reg [SYSTOLIC_SIZE-1:0] faulty_pe_storage [SYSTOLIC_SIZE-1:0];


    always @(posedge clk ) begin
        if(detection_en) begin
            faulty_row_storage[counter] <= row_fault_detection;
            faulty_column_storage[counter] <= column_fault_detection;
            faulty_pe_storage[counter] <= single_pe_detection;
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