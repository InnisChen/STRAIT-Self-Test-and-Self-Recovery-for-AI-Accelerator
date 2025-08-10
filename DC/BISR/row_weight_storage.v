module row_weight_storage #(
    parameter SYSTOLIC_SIZE = 8,
    parameter WEIGHT_WIDTH = 8,
    parameter ADDR_WIDTH = $clog2(SYSTOLIC_SIZE)
)(
    input wire clk,
    input wire rst_n,
    
    // Write interface (初始化權重資料)
    input wire wr_en,
    input wire [ADDR_WIDTH-1:0] wr_addr,
    input wire [SYSTOLIC_SIZE*WEIGHT_WIDTH-1:0] wr_data,
    
    // Read interface (給 systolic array)
    input wire [ADDR_WIDTH-1:0] rd_addr,
    output wire [SYSTOLIC_SIZE*WEIGHT_WIDTH-1:0] rd_data
);

    // Internal memory storage
    reg [SYSTOLIC_SIZE*WEIGHT_WIDTH-1:0] weight_memory [0:SYSTOLIC_SIZE-1];
    
    // Write operation
    always @(posedge clk) begin
        if (wr_en) begin
            weight_memory[wr_addr] <= wr_data;
        end
        else;
    end
    
    // Read operation
    assign rd_data = weight_memory[rd_addr];

endmodule