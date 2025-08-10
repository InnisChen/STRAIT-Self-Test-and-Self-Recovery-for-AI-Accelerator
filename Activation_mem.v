// Activation_mem.v
// 內部存的資訊是正常的資訊
// 謝入地址透過bist送
// 讀取地址根據BISR中的mapping_table來決定



module Activation_mem #(
    parameter SYSTOLIC_SIZE = 8,  // 可設定的脈動陣列大小，預設為8x8
    parameter ACTIVATION_WIDTH = 8,
    parameter ADDR_WIDTH = $clog2(SYSTOLIC_SIZE)
)(
    input clk,
    input wr_en,
    input [ADDR_WIDTH-1:0] wr_addr,  // 寫入地址
    input [SYSTOLIC_SIZE*ACTIVATION_WIDTH-1:0] activation_inputs_flat,  // 輸入激活值
    input [ADDR_WIDTH-1:0] rd_addr,  // 讀取地址
    output [SYSTOLIC_SIZE*ACTIVATION_WIDTH-1:0] activation_outputs_flat   // 輸出激活值
);

    reg [SYSTOLIC_SIZE*ACTIVATION_WIDTH-1:0] activation_memory [0:SYSTOLIC_SIZE-1];
    
    always @(posedge clk ) begin
        if(wr_en) begin
            activation_memory[wr_addr] <= activation_inputs_flat;
        end
    end

    assign activation_outputs_flat = activation_memory[rd_addr];
    
endmodule