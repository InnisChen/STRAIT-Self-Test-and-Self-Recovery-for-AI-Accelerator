// Activation_mem.v

module Activation_mem #(
    parameter SYSTOLIC_SIZE = 8,  // 可設定的脈動陣列大小，預設為8x8
    parameter ACTIVATION_WIDTH = 8,
    parameter ADDR_WIDTH = $clog2(SYSTOLIC_SIZE)
)(
    input clk,
    input wr_en,
    input [ADDR_WIDTH-1:0] wr_addr,  // 寫入地址
    input [SYSTOLIC_SIZE*ACTIVATION_WIDTH-1:0] activation_inputs,  // 輸入激活值
    input [ADDR_WIDTH-1:0] rd_addr,  // 讀取地址
    output [SYSTOLIC_SIZE*ACTIVATION_WIDTH-1:0] activation_outputs   // 輸出激活值
);

    reg [SYSTOLIC_SIZE*ACTIVATION_WIDTH-1:0] activation_memory [0:SYSTOLIC_SIZE-1];
    
    always @(posedge clk ) begin
        if(wr_en) begin
            activation_memory[wr_addr] <= activation_inputs;
        end
    end

    assign activation_outputs = activation_memory[rd_addr];
    
endmodule
