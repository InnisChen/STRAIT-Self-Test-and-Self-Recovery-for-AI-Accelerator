//eNVM.v

module eNVM #(
    parameter SYSTOLIC_SIZE = 8,
    parameter WEIGHT_WIDTH = 8,
    parameter ACTIVATION_WIDTH = 8,
    // parameter FAULTY_STORAGE_DEPTH = 8,
    parameter ADDR_WIDTH = $clog2(SYSTOLIC_SIZE),
    // parameter STORAGE_ADDR_WIDTH = $clog2(FAULTY_STORAGE_DEPTH)
    parameter PARTIAL_SUM_WIDTH = WEIGHT_WIDTH + ACTIVATION_WIDTH + $clog2(SYSTOLIC_SIZE),
) (
    input clk,
    // input rst_n,
    input detection_en,
    input [ADDR_WIDTH-1:0] count,
    input [SYSTOLIC_SIZE-1:0] pe_detection,
    input row_fault_detection,      //每次1bit 傳n次
    input column_fault_detection,   //....

    output [SYSTOLIC_SIZE*SYSTOLIC_SIZE-1:0] envm_faulty_patterns_flat,
    output [SYSTOLIC_SIZE*ADDR_WIDTH-1:0] envm_faulty_row_addrs_flat,
    output [SYSTOLIC_SIZE-1:0] envm_faulty_valid_mask,

    output [] Scan_data
);

    reg [SYSTOLIC_SIZE-1:0] faulty_row_storage;
    reg [SYSTOLIC_SIZE-1:0] faulty_column_storage;
    reg [SYSTOLIC_SIZE-1:0] faulty_pe_storage [SYSTOLIC_SIZE-1:0];


    always @(posedge clk ) begin
        if(detection_en) begin
            faulty_row_storage[count] <= row_fault_detection;
            faulty_column_storage[count] <= column_fault_detection;
            faulty_pe_storage[count] <= pe_detection;
        end
        else;
    end



    
endmodule