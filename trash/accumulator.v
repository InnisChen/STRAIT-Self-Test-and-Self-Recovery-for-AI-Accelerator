module accumulator_8 #(
    parameter ARRAY_SIZE = 8,
    parameter DATA_SIZE = 24
)(
    input clk, rst_n,
    input rd_en_0, rd_en_1, rd_en_2, rd_en_3, rd_en_4, rd_en_5, rd_en_6, rd_en_7, 
    input wr_en_0, wr_en_1, wr_en_2, wr_en_3, wr_en_4, wr_en_5, wr_en_6, wr_en_7, 
    input ac_en_0, ac_en_1, ac_en_2, ac_en_3, ac_en_4, ac_en_5, ac_en_6, ac_en_7, 
    input [23:0] data_in_0,  data_in_1,  data_in_2,  data_in_3,  data_in_4,  data_in_5,  data_in_6,  data_in_7,  
    output empty_0, empty_1, empty_2, empty_3, empty_4, empty_5, empty_6, empty_7, 
    output full_0, full_1, full_2, full_3, full_4, full_5, full_6, full_7, 
    output [23:0] data_out_0, data_out_1, data_out_2, data_out_3, data_out_4, data_out_5, data_out_6, data_out_7
);
    wire [23:0] fifo_in_data_0, fifo_in_data_1, fifo_in_data_2, fifo_in_data_3, fifo_in_data_4, fifo_in_data_5, fifo_in_data_6, fifo_in_data_7;

    assign fifo_in_data_0 = ac_en_0 ? (data_out_0 + data_in_0) : data_in_0;
    fifo_1 #(
        .FIFO_SIZE(ARRAY_SIZE),
        .DATA_SIZE(DATA_SIZE)
    ) f0 (
        .clk(clk), 
        .rst_n(rst_n),
        .rd_en(rd_en_0), 
        .wr_en(wr_en_0),
        .input_data(fifo_in_data_0),
        .empty(empty_0), 
        .full(full_0),
        .output_data(data_out_0)
    );

    assign fifo_in_data_1 = ac_en_1 ? (data_out_1 + data_in_1) : data_in_1;
    fifo_1 #(
        .FIFO_SIZE(ARRAY_SIZE),
        .DATA_SIZE(DATA_SIZE)
    ) f1 (
        .clk(clk), 
        .rst_n(rst_n),
        .rd_en(rd_en_1), 
        .wr_en(wr_en_1),
        .input_data(fifo_in_data_1),
        .empty(empty_1), 
        .full(full_1),
        .output_data(data_out_1)
    );

    assign fifo_in_data_2 = ac_en_2 ? (data_out_2 + data_in_2) : data_in_2;
    fifo_1 #(
        .FIFO_SIZE(ARRAY_SIZE),
        .DATA_SIZE(DATA_SIZE)
    ) f2 (
        .clk(clk), 
        .rst_n(rst_n),
        .rd_en(rd_en_2), 
        .wr_en(wr_en_2),
        .input_data(fifo_in_data_2),
        .empty(empty_2), 
        .full(full_2),
        .output_data(data_out_2)
    );

    assign fifo_in_data_3 = ac_en_3 ? (data_out_3 + data_in_3) : data_in_3;
    fifo_1 #(
        .FIFO_SIZE(ARRAY_SIZE),
        .DATA_SIZE(DATA_SIZE)
    ) f3 (
        .clk(clk), 
        .rst_n(rst_n),
        .rd_en(rd_en_3), 
        .wr_en(wr_en_3),
        .input_data(fifo_in_data_3),
        .empty(empty_3), 
        .full(full_3),
        .output_data(data_out_3)
    );

    assign fifo_in_data_4 = ac_en_4 ? (data_out_4 + data_in_4) : data_in_4;
    fifo_1 #(
        .FIFO_SIZE(ARRAY_SIZE),
        .DATA_SIZE(DATA_SIZE)
    ) f4 (
        .clk(clk), 
        .rst_n(rst_n),
        .rd_en(rd_en_4), 
        .wr_en(wr_en_4),
        .input_data(fifo_in_data_4),
        .empty(empty_4), 
        .full(full_4),
        .output_data(data_out_4)
    );

    assign fifo_in_data_5 = ac_en_5 ? (data_out_5 + data_in_5) : data_in_5;
    fifo_1 #(
        .FIFO_SIZE(ARRAY_SIZE),
        .DATA_SIZE(DATA_SIZE)
    ) f5 (
        .clk(clk), 
        .rst_n(rst_n),
        .rd_en(rd_en_5), 
        .wr_en(wr_en_5),
        .input_data(fifo_in_data_5),
        .empty(empty_5), 
        .full(full_5),
        .output_data(data_out_5)
    );

    assign fifo_in_data_6 = ac_en_6 ? (data_out_6 + data_in_6) : data_in_6;
    fifo_1 #(
        .FIFO_SIZE(ARRAY_SIZE),
        .DATA_SIZE(DATA_SIZE)
    ) f6 (
        .clk(clk), 
        .rst_n(rst_n),
        .rd_en(rd_en_6), 
        .wr_en(wr_en_6),
        .input_data(fifo_in_data_6),
        .empty(empty_6), 
        .full(full_6),
        .output_data(data_out_6)
    );

    assign fifo_in_data_7 = ac_en_7 ? (data_out_7 + data_in_7) : data_in_7;
    fifo_1 #(
        .FIFO_SIZE(ARRAY_SIZE),
        .DATA_SIZE(DATA_SIZE)
    ) f7 (
        .clk(clk), 
        .rst_n(rst_n),
        .rd_en(rd_en_7), 
        .wr_en(wr_en_7),
        .input_data(fifo_in_data_7),
        .empty(empty_7), 
        .full(full_7),
        .output_data(data_out_7)
    );

endmodule

module fifo_1 #(
    parameter FIFO_SIZE = 8,
    parameter DATA_SIZE = 24
)(
    input clk, rst_n,
    input rd_en, wr_en,
    input [DATA_SIZE-1:0] input_data,
    output reg empty, full,
    output reg [DATA_SIZE-1:0] output_data
);
    parameter ADDR_WIDTH = $clog2(FIFO_SIZE);
    
    reg [DATA_SIZE-1:0] fifo_memory [0:FIFO_SIZE-1];
    reg [ADDR_WIDTH-1:0] rd_addr, wr_addr;

    assign flag_full = (((wr_addr+1)==rd_addr)|((wr_addr==(FIFO_SIZE-1))&&(rd_addr==0)));
    assign flag_empty = (((rd_addr+1)==wr_addr)|(((rd_addr==(FIFO_SIZE-1))&&(wr_addr==0))));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_addr <= 0;
            wr_addr <= 0;
            empty <= 1;
            full <= 0;
            output_data <= 24'd0;
        end else if (wr_en && rd_en) begin //reading and writing
            if (empty) begin //when empty (like a reg)
                output_data <= input_data;
            end else begin //just write and read, but don`t change empty and full
                fifo_memory[wr_addr] <= input_data;
                output_data <= fifo_memory[rd_addr];
                wr_addr <= wr_addr + 1;
                rd_addr <= rd_addr + 1;
            end
        end else if (wr_en && !full) begin //writing
            //write
            fifo_memory[wr_addr] <= input_data;
            //next addr
            wr_addr <= wr_addr + 1;
            //if after write is full
            if (flag_full) full <= 1;
            else full <= 0;
            //there is something in memory
            empty <= 0;
        end else if (rd_en && !empty) begin //reading
            //read and clean
            output_data <= fifo_memory[rd_addr];
            fifo_memory[rd_addr] <= 24'd0;
            //next addr
            rd_addr <= rd_addr + 1;
            //if after read is empty
            if (flag_empty) empty <= 1;
            else empty <= 0;
            //there is something output memory
            full <= 0;
        end
    end
    
endmodule