// Memory_data_generator.v

module Memory_data_generator #(
    parameter SYSTOLIC_SIZE = 8,
    parameter WEIGHT_WIDTH = 8,
    parameter ACTIVATION_WIDTH = 8,
    parameter PARTIAL_SUM_WIDTH = WEIGHT_WIDTH + ACTIVATION_WIDTH + $clog2(SYSTOLIC_SIZE),
    parameter ADDR_WIDTH = $clog2(SYSTOLIC_SIZE),
    parameter MBIST_PATTERN_DEPTH = 8,  // March算法步驟數
    parameter MEMORY_PATTERN_ADDR_WIDTH = $clog2(MBIST_PATTERN_DEPTH)
) (
    input [MEMORY_PATTERN_ADDR_WIDTH-1:0] addr,
    output [PARTIAL_SUM_WIDTH-1:0] MBIST_data
);

    // 8組不同的測試資料，分別送進每一個記憶體裡面
    reg [PARTIAL_SUM_WIDTH-1:0] Memory_test_data [0:MBIST_PATTERN_DEPTH-1];
    assign MBIST_data = Memory_test_data[addr]; 

endmodule

    // 每個mem位置個別有測試資料
    // reg [SYSTOLIC_SIZE*PARTIAL_SUM_WIDTH-1:0] Memory_test_date [0:SYSTOLIC_SIZE-1];  
    // assign MBIST_data = Memory_test_date[addr];

    // 全部都用同一筆data測試存進去的結果跟出來的結果是否正確
    // reg [PARTIAL_SUM_WIDTH-1:0] Memory_test_date ;  
    // assign MBIST_data = Memory_test_date;




/*
// MBIST Test Patterns for Memory Data Generator
// Based on March C- Algorithm
// Format: 19-bit binary data (PARTIAL_SUM_WIDTH)
// Pattern Index | Description | Binary Pattern

// Pattern 0: All zeros (Background)
0000000000000000000

// Pattern 1: All ones (Inverted background)
1111111111111111111

// Pattern 2: Alternating pattern 01010... (Coupling faults)
0101010101010101010

// Pattern 3: Alternating pattern 10101... (Inverted coupling)
1010101010101010101

// Pattern 4: All zeros (Repeated for march algorithm)
0000000000000000000

// Pattern 5: All ones (Repeated for march algorithm)
1111111111111111111

// Pattern 6: Walking 1s pattern (Address-based pattern)
0000000000000000001

// Pattern 7: Walking 0s pattern (Inverted address-based)
1111111111111111110

*/