`timescale 1ns / 1ps

module tb_fifo_1;

    // Parameters
    parameter FIFO_SIZE = 8;
    parameter DATA_SIZE = 24;

    // Signals
    reg clk;
    reg rst;
    reg rd_en;
    reg wr_en;
    reg [DATA_SIZE-1:0] input_data;
    wire empty;
    wire full;
    wire [DATA_SIZE-1:0] output_data;

    integer i;

    // Instantiate FIFO
    fifo_1 #(
        .FIFO_SIZE(FIFO_SIZE),
        .DATA_SIZE(DATA_SIZE)
    ) uut (
        .clk(clk),
        .rst(rst),
        .rd_en(rd_en),
        .wr_en(wr_en),
        .input_data(input_data),
        .empty(empty),
        .full(full),
        .output_data(output_data)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 10ns period
    end

    // Test procedure
    initial begin
        // Initialize
        rst = 0;
        rd_en = 0;
        wr_en = 0;
        input_data = 0;

        // Reset
        #12;
        rst = 1;
        @(negedge clk);


        // Write 8 values
        $display("---- Writing 8 values ----");
        for (i = 0; i < 8; i = i + 1) begin
            input_data = i + 100;  // Arbitrary test values
            wr_en = 1;
            rd_en = 0;
            @(negedge clk);
            $display("Write: %d", input_data);
        end

        // Stop writing
        wr_en = 0;
        @(negedge clk);

        //test full read and write
        $display("---- reading and writing at same time when full ----");
        rd_en = 1;
        wr_en = 1;
        input_data = 150;
        @(negedge clk);
        $display("Write: %d  Read: %d", input_data, output_data);

        // Read 8 values
        $display("---- Reading 8 values ----");
        for (i = 0; i < 8; i = i + 1) begin
            rd_en = 1;
            wr_en = 0;
            @(negedge clk);
            $display("Read: %d", output_data);
        end

        // Stop reading
        rd_en = 0;
        @(negedge clk);

        //test empty read and write
        $display("---- reading and writing at same time when empty ----");
        rd_en = 1;
        wr_en = 1;
        input_data = 170;
        @(negedge clk);
        $display("Write: %d  Read: %d", input_data, output_data);

        // 交錯讀寫三次
        $display("---- Alternating 3 write/read ----");
        for (i = 0; i < 3; i = i + 1) begin
            // Write
            wr_en = 1;
            rd_en = 0;
            input_data = i + 200;
            @(negedge clk);
            $display("Write: %d", input_data);

            // Read
            wr_en = 0;
            rd_en = 1;
            @(negedge clk);
            $display("Read: %d", output_data);
        end

        $display("---- Alternating 2 write -> 1 write and read -> 2 read ----");
        for (i = 0; i < 5; i = i + 1) begin
            // Write
            if (i < 2) begin
                wr_en = 1;
                rd_en = 0;
                input_data = i + 150;
                @(negedge clk);
                $display("Write: %d", input_data);
            end else if (i == 2) begin
                rd_en = 1;
                wr_en = 1;
                input_data = i + 150;
                @(negedge clk);
                $display("Write: %d  Read: %d", input_data, output_data);
            end else begin
                // Read
                wr_en = 0;
                rd_en = 1;
                @(negedge clk);
                $display("Read: %d", output_data);
            end
        end

        // 結束
        wr_en = 0;
        rd_en = 0;
        @(negedge clk);

        $display("---- Simulation Finished ----");
        #20;
        $finish;
    end

endmodule
