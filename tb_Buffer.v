`timescale 1ns / 1ps

module tb_Buffer;

    // 參數定義
    parameter SYSTOLIC_SIZE = 8;
    parameter ACTIVATION_WIDTH = 8;
    parameter CLK_PERIOD = 10;

    // Test signals
    reg clk;
    reg rst_n;
    reg test_mode;
    reg [SYSTOLIC_SIZE*ACTIVATION_WIDTH-1:0] activation_in_flat;
    wire [SYSTOLIC_SIZE*ACTIVATION_WIDTH-1:0] activation_out_flat;

    // Helper signals for testing
    reg [ACTIVATION_WIDTH-1:0] test_data [0:SYSTOLIC_SIZE-1];
    wire [ACTIVATION_WIDTH-1:0] output_data [0:SYSTOLIC_SIZE-1];
    
    // Split output flat signal into array for observation
    genvar k;
    generate
        for (k = 0; k < SYSTOLIC_SIZE; k = k + 1) begin : output_split
            assign output_data[k] = activation_out_flat[k*ACTIVATION_WIDTH +: ACTIVATION_WIDTH];
        end
    endgenerate

    // Instantiate the device under test
    Buffer #(
        .SYSTOLIC_SIZE(SYSTOLIC_SIZE),
        .ACTIVATION_WIDTH(ACTIVATION_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .test_mode(test_mode),
        .activation_in_flat(activation_in_flat),
        .activation_out_flat(activation_out_flat)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Task to prepare test data
    task prepare_test_data;
        input [7:0] base_value;
        integer i;
        begin
            for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin
                test_data[i] = base_value + i;
            end
            
            // Pack test data into flat signal
            for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin
                activation_in_flat[i*ACTIVATION_WIDTH +: ACTIVATION_WIDTH] = test_data[i];
            end
        end
    endtask

    // Task to display output results
    task display_outputs;
        input [255:0] test_name;
        integer i;
        begin
            $display("\n=== %s ===", test_name);
            $display("Time: %0t", $time);
            for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin
                $display("Row[%0d]: Input=0x%02h, Output=0x%02h", 
                        i, test_data[i], output_data[i]);
            end
            $display("");
        end
    endtask

    // Task to verify test mode output
    task verify_test_mode;
        integer i;
        reg error_found;
        begin
            error_found = 0;
            $display("=== Verifying Test Mode (Parallel Output) ===");
            for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin
                if (output_data[i] !== test_data[i]) begin
                    $display("ERROR: Row[%0d] - Expected: 0x%02h, Got: 0x%02h", 
                            i, test_data[i], output_data[i]);
                    error_found = 1;
                end
            end
            if (!error_found) begin
                $display("PASS: Test mode verification passed");
            end
            $display("");
        end
    endtask

    // Task to verify normal mode delays
    task verify_normal_mode_delays;
        integer i, expected_cycles;
        begin
            $display("=== Verifying Normal Mode Delays ===");
            
            // Row 0 should output immediately
            if (output_data[0] !== test_data[0]) begin
                $display("ERROR: Row[0] - Expected immediate output: 0x%02h, Got: 0x%02h", 
                        test_data[0], output_data[0]);
            end else begin
                $display("PASS: Row[0] immediate output correct");
            end
            
            // Other rows should show delayed data or 0 (if delay time hasn't been reached)
            for (i = 1; i < SYSTOLIC_SIZE; i = i + 1) begin
                $display("Row[%0d]: Output=0x%02h (Delayed by %0d cycles)", 
                        i, output_data[i], i);
            end
            $display("");
        end
    endtask

    // Main test procedure
    initial begin
        // Initialize signals
        rst_n = 0;
        test_mode = 0;
        activation_in_flat = 0;
        
        $display("==========================================");
        $display("Starting Buffer Module Test");
        $display("SYSTOLIC_SIZE = %0d", SYSTOLIC_SIZE);
        $display("ACTIVATION_WIDTH = %0d", ACTIVATION_WIDTH);
        $display("==========================================");

        // Reset
        #(CLK_PERIOD * 2);
        rst_n = 1;
        #(CLK_PERIOD);

        // ===== Test 1: Test Mode (Parallel Output) =====
        $display("\n>>>>> Test 1: Test Mode (Parallel Output) <<<<<");
        test_mode = 1;
        
        // Test data 1
        prepare_test_data(8'h10);
        #(CLK_PERIOD);
        display_outputs("Test Mode - Data Set 1");
        verify_test_mode();
        
        // Test data 2
        prepare_test_data(8'hA0);
        #(CLK_PERIOD);
        display_outputs("Test Mode - Data Set 2");
        verify_test_mode();

        // ===== Test 2: Normal Mode (45-degree Delay) =====
        $display("\n>>>>> Test 2: Normal Mode (45-degree Delay) <<<<<");
        test_mode = 0;
        
        // Reset to clear previous data
        rst_n = 0;
        #(CLK_PERIOD);
        rst_n = 1;
        #(CLK_PERIOD);
        
        // Send first data set
        prepare_test_data(8'h20);
        #(CLK_PERIOD);
        display_outputs("Normal Mode - Cycle 1");
        verify_normal_mode_delays();
        
        // Send second data set
        prepare_test_data(8'h30);
        #(CLK_PERIOD);
        display_outputs("Normal Mode - Cycle 2");
        
        // Send third data set
        prepare_test_data(8'h40);
        #(CLK_PERIOD);
        display_outputs("Normal Mode - Cycle 3");
        
        // Continue for several cycles to observe delay effects
        prepare_test_data(8'h50);
        #(CLK_PERIOD);
        display_outputs("Normal Mode - Cycle 4");
        
        prepare_test_data(8'h60);
        #(CLK_PERIOD);
        display_outputs("Normal Mode - Cycle 5");
        
        prepare_test_data(8'h70);
        #(CLK_PERIOD);
        display_outputs("Normal Mode - Cycle 6");
        
        prepare_test_data(8'h80);
        #(CLK_PERIOD);
        display_outputs("Normal Mode - Cycle 7");
        
        prepare_test_data(8'h90);
        #(CLK_PERIOD);
        display_outputs("Normal Mode - Cycle 8");

        // ===== Test 3: Mode Switching Test =====
        $display("\n>>>>> Test 3: Mode Switching Test <<<<<");
        
        // Switch from normal mode to test mode
        prepare_test_data(8'hF0);
        test_mode = 1;
        #(CLK_PERIOD);
        display_outputs("Mode Switch: Normal->Test");
        verify_test_mode();
        
        // Switch from test mode back to normal mode
        test_mode = 0;
        #(CLK_PERIOD);
        display_outputs("Mode Switch: Test->Normal");

        // ===== Test 4: Reset Test =====
        $display("\n>>>>> Test 4: Reset Function Test <<<<<");
        
        // Reset in normal mode
        test_mode = 0;
        prepare_test_data(8'hCC);
        rst_n = 0;
        #(CLK_PERIOD);
        rst_n = 1;
        #(CLK_PERIOD);
        display_outputs("After Reset - First Cycle");

        // ===== Test 5: Boundary Value Test =====
        $display("\n>>>>> Test 5: Boundary Value Test <<<<<");
        
        test_mode = 1;
        
        // Test all zeros
        prepare_test_data(8'h00);
        #(CLK_PERIOD);
        display_outputs("Boundary Test - All Zeros");
        
        // Test all ones
        prepare_test_data(8'hFF);
        #(CLK_PERIOD);
        display_outputs("Boundary Test - All Ones");

        // ===== Test End =====
        #(CLK_PERIOD * 5);
        $display("\n==========================================");
        $display("Buffer Module Test Complete");
        $display("==========================================");
        
        $finish;
    end

    // Monitor signal changes
    initial begin
        $monitor("Time: %0t | test_mode: %b | rst_n: %b | Input[0]: %02h | Output[0]: %02h", 
                $time, test_mode, rst_n, 
                activation_in_flat[ACTIVATION_WIDTH-1:0], 
                activation_out_flat[ACTIVATION_WIDTH-1:0]);
    end

    // Waveform recording
    initial begin
        $dumpfile("buffer_tb.vcd");
        $dumpvars(0, tb_Buffer);
        
        // Record internal signals for debugging
        $dumpvars(1, dut);
    end

endmodule