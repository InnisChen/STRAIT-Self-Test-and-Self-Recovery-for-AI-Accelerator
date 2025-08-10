// Weight_buffer.v

module Weight_partialsum_buffer #(
    parameter SYSTOLIC_SIZE = 8,
    parameter WEIGHT_WIDTH = 8,
    parameter ACTIVATION_WIDTH = 8,
    parameter PARTIAL_SUM_WIDTH = WEIGHT_WIDTH + ACTIVATION_WIDTH + $clog2(SYSTOLIC_SIZE),

) (
    input test_mode,    // 0: 正常模式45度, 1: 測試模式平行送入
    input [SYSTOLIC_SIZE*WEIGHT_WIDTH-1:0] weight_in_test_flat, // 考慮輸入是否縮減成 [WEIGHT_WIDTH-1:0] ，在bist內部複製訊號成flat就好。 因測試權重都是相同的
    input [SYSTOLIC_SIZE*WEIGHT_WIDTH-1:0] weight_in_bisr_flat, // 從bisr送入的權重
    input [SYSTOLIC_SIZE*PARTIAL_SUM_WIDTH-1:0] partial_sum_in_test_flat,
    input [SYSTOLIC_SIZE*PARTIAL_SUM_WIDTH-1:0] partial_sum_in_outside_flat, // 從bist送入測試的資料
    input [SYSTOLIC_SIZE-1:0] pe_disable_in, // 正常使用時，每個PE是否disable，從bisr的faulty_pe_storage送入

    output [SYSTOLIC_SIZE*WEIGHT_WIDTH-1:0] weight_out_flat, // 輸出到systolic array
    output [SYSTOLIC_SIZE*PARTIAL_SUM_WIDTH-1:0] partial_sum_out_flat,
    output [SYSTOLIC_SIZE-1:0] pe_disable_out // 每個PE是否disable
);

    assign weight_out_flat = test_mode ? weight_in_test_flat : weight_in_bisr_flat;
    assign partial_sum_out_flat = test_mode ? partial_sum_in_test_flat : partial_sum_in_outside_flat;
    assign pe_disable_out = test_mode ? {SYSTOLIC_SIZE{1'b0}} : pe_disable_in; // 測試模式下，disable都0，由scan_en訊號控制是否要執行運算
    
endmodule