`timescale 1ns / 1ps
`define CYCLE      10.0  

module Array_8x8_tb();

    // Parameters
    parameter ARRAY_SIZE = 8;
    parameter DATA_WIDTH = 8;
    parameter PARTIAL_SUM_WIDTH = 24;
    
    // File format parameter - change this to switch between number formats
    // 0: decimal ($readmem), 1: hexadecimal ($readmemh), 2: binary ($readmemb)
    parameter FILE_FORMAT = 0;

    // signals
    reg clk = 0;
    reg clk_w = 0;
    reg rst = 1;
    wire scan_en = 1'b0;  // Fixed to 0
    reg PE_disable = 1'b0;
    reg [DATA_WIDTH-1:0] weight_in [0:ARRAY_SIZE-1];
    reg [DATA_WIDTH-1:0] activation_in [0:ARRAY_SIZE-1];
    wire [PARTIAL_SUM_WIDTH-1:0] partial_sum_out [0:ARRAY_SIZE-1];    

    PE_Array_8x8 u1_PE_Array_8x8(
        .clk(clk),
        .rst(rst),
        .scan_en(scan_en),
        .clk_w(clk_w),
        .PE_disable_0(PE_disable),
        .PE_disable_1(PE_disable),
        .PE_disable_2(PE_disable),
        .PE_disable_3(PE_disable),
        .PE_disable_4(PE_disable),
        .PE_disable_5(PE_disable),
        .PE_disable_6(PE_disable),
        .PE_disable_7(PE_disable),
        .weight_0(weight_in[0]),
        .weight_1(weight_in[1]),
        .weight_2(weight_in[2]),
        .weight_3(weight_in[3]),
        .weight_4(weight_in[4]),
        .weight_5(weight_in[5]),
        .weight_6(weight_in[6]),
        .weight_7(weight_in[7]),
        .activation_0(activation_in[0]),
        .activation_1(activation_in[1]),
        .activation_2(activation_in[2]),
        .activation_3(activation_in[3]),
        .activation_4(activation_in[4]),
        .activation_5(activation_in[5]),
        .activation_6(activation_in[6]),
        .activation_7(activation_in[7]),
        .partial_sum_in_0(24'b0),
        .partial_sum_in_1(24'b0),
        .partial_sum_in_2(24'b0),
        .partial_sum_in_3(24'b0),
        .partial_sum_in_4(24'b0),
        .partial_sum_in_5(24'b0),
        .partial_sum_in_6(24'b0),
        .partial_sum_in_7(24'b0),
        .partial_sum_0(partial_sum_out[0]),
        .partial_sum_1(partial_sum_out[1]),
        .partial_sum_2(partial_sum_out[2]),
        .partial_sum_3(partial_sum_out[3]),
        .partial_sum_4(partial_sum_out[4]),
        .partial_sum_5(partial_sum_out[5]),
        .partial_sum_6(partial_sum_out[6]),
        .partial_sum_7(partial_sum_out[7])
    );

    // Test variables
    integer i, j, k, m, n;
    integer result_start_cycle, result_cycle_offset, output_row, output_col, col_idx;
    integer diag_idx, row, col;
    reg [10:0] cycle_count = 0;

    // Data matrices
    reg [DATA_WIDTH-1:0] weight_matrix [0:ARRAY_SIZE-1][0:ARRAY_SIZE-1];
    reg [DATA_WIDTH-1:0] activation_matrix [0:ARRAY_SIZE-1][0:ARRAY_SIZE-1];
    reg [PARTIAL_SUM_WIDTH-1:0] result_matrix [0:ARRAY_SIZE-1][0:ARRAY_SIZE-1];
    
    // Memory arrays for $readmemh
    reg [DATA_WIDTH-1:0] weight_mem [0:ARRAY_SIZE*ARRAY_SIZE-1];
    reg [DATA_WIDTH-1:0] activation_mem [0:ARRAY_SIZE*ARRAY_SIZE-1];

    // Reset signal
    initial begin
        $display("----------------------");
        $display("-- Simulation Start --");
        $display("----------------------");
        rst = 1'b1;
        #(`CYCLE*1);  
        rst = 1'b0;
        #(`CYCLE*1);  
        rst = 1'b1;
        #(`CYCLE);
        $display("Reset completed at time %0t", $time);
        
        // Initialize result matrix
        for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
            for (j = 0; j < ARRAY_SIZE; j = j + 1) begin
                result_matrix[i][j] = 0;
            end
        end
    end

    // Clock generation
    always begin 
        #(`CYCLE/2) clk = ~clk; 
    end

    // Cycle counter
    always @(posedge clk) begin
        if (rst) begin
            cycle_count <= cycle_count + 1;
        end else begin
            cycle_count <= 0;
        end
    end

    // clk_w generation based on cycle count
    always @(posedge clk) begin
        if (rst) begin
            if (cycle_count >= 0 && cycle_count <= ARRAY_SIZE-1) begin
                // During weight loading phase, clk_w follows clk
                // clk_w will be generated as a clock signal
            end else begin
                clk_w <= 0;
            end
        end else begin
            clk_w <= 0;
        end
    end
    
    // Generate clk_w as a clock signal during weight loading
    always begin 
        if (rst && cycle_count >= 0 && cycle_count <= ARRAY_SIZE-1) begin
            #(`CYCLE/2) clk_w = ~clk_w;
        end else begin
            clk_w = 0;
            #(`CYCLE/2);
        end
    end

    // Read input files
    initial begin
        // Wait for reset to complete
        wait(rst);
        #(`CYCLE);
        
        // Read weight matrix using different formats based on FILE_FORMAT parameter
        if (FILE_FORMAT == 0) begin
            $display("Reading weight matrix from weight.dat (decimal format)");
            $readmemh("C:/Project/STRAIT/weight.dat", weight_mem);  // Use readmemh for decimal too
        end else if (FILE_FORMAT == 1) begin
            $display("Reading weight matrix from weight.dat (hexadecimal format)");
            $readmemh("C:/Project/STRAIT/weight.dat", weight_mem);
        end else if (FILE_FORMAT == 2) begin
            $display("Reading weight matrix from weight.dat (binary format)");
            $readmemb("C:/Project/STRAIT/weight.dat", weight_mem);
        end else begin
            $display("ERROR: Invalid FILE_FORMAT parameter. Use 0(decimal), 1(hex), or 2(binary)");
            $finish;
        end
        
        // Read activation matrix using the same format
        if (FILE_FORMAT == 0) begin
            $display("Reading activation matrix from activation.dat (decimal format)");
            $readmemh("C:/Project/STRAIT/activation.dat", activation_mem);  // Use readmemh for decimal too
        end else if (FILE_FORMAT == 1) begin
            $display("Reading activation matrix from activation.dat (hexadecimal format)");
            $readmemh("C:/Project/STRAIT/activation.dat", activation_mem);
        end else if (FILE_FORMAT == 2) begin
            $display("Reading activation matrix from activation.dat (binary format)");
            $readmemb("C:/Project/STRAIT/activation.dat", activation_mem);
        end else begin
            $display("ERROR: Invalid FILE_FORMAT parameter for activation file");
            $finish;
        end
        
        // Convert 1D arrays to 2D matrices
        for (m = 0; m < ARRAY_SIZE; m = m + 1) begin
            for (n = 0; n < ARRAY_SIZE; n = n + 1) begin
                weight_matrix[m][n] = weight_mem[m*ARRAY_SIZE + n];
                activation_matrix[m][n] = activation_mem[m*ARRAY_SIZE + n];
            end
        end
        
        $display("Weight and activation matrices loaded successfully");
        
        // Display loaded matrices
        $display("\nWeight Matrix:");
        for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
            $write("Row %0d: ", i);
            for (j = 0; j < ARRAY_SIZE; j = j + 1) begin
                $write("%3d ", weight_matrix[i][j]);
            end
            $display("");
        end
        
        $display("\nActivation Matrix:");
        for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
            $write("Row %0d: ", i);
            for (j = 0; j < ARRAY_SIZE; j = j + 1) begin
                $write("%3d ", activation_matrix[i][j]);
            end
            $display("");
        end
    end

    // Data input control
    always @(posedge clk) begin
        if (rst) begin
            // Initialize all inputs to 0
            for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                weight_in[i] <= 0;
                activation_in[i] <= 0;
            end
            
            if (cycle_count >= 0 && cycle_count <= ARRAY_SIZE-2) begin
                // Weight loading phase (Cycle 0 to N-2)
                // Send weights from last column to first column
                col_idx = ARRAY_SIZE - 1 - cycle_count;
                $display("Cycle %0d: Loading weight column %0d", cycle_count+1, col_idx);
                for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                    weight_in[i] <= weight_matrix[i][col_idx];
                    activation_in[i] <= 0;
                end
                $display("  Weights: [%0d, %0d, %0d, %0d, %0d, %0d, %0d, %0d]", 
                        weight_matrix[0][col_idx], weight_matrix[1][col_idx], weight_matrix[2][col_idx], weight_matrix[3][col_idx],
                        weight_matrix[4][col_idx], weight_matrix[5][col_idx], weight_matrix[6][col_idx], weight_matrix[7][col_idx]);
                
            end else if (cycle_count == ARRAY_SIZE-1) begin
                // Mixed phase (Cycle N-1)
                // Send first column weights and first activation
                $display("Cycle %0d: Loading final weight column and first activation", cycle_count+1);
                for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                    weight_in[i] <= weight_matrix[i][0];  // Column 0 (first column)
                end
                $display("  Final Weights: [%0d, %0d, %0d, %0d, %0d, %0d, %0d, %0d]", 
                        weight_matrix[0][0], weight_matrix[1][0], weight_matrix[2][0], weight_matrix[3][0],
                        weight_matrix[4][0], weight_matrix[5][0], weight_matrix[6][0], weight_matrix[7][0]);
                // First activation: only [0][0]
                activation_in[0] <= activation_matrix[0][0];
                for (i = 1; i < ARRAY_SIZE; i = i + 1) begin
                    activation_in[i] <= 0;
                end
                $display("  First activation: activation_in[0] = %0d", activation_matrix[0][0]);
                
            end else if (cycle_count >= ARRAY_SIZE && cycle_count <= 3*ARRAY_SIZE-3) begin
                // Activation input phase (Cycle N to 3N-3)
                diag_idx = cycle_count - ARRAY_SIZE + 1;
                
                $display("Cycle %0d: Loading activation diagonal %0d", cycle_count+1, diag_idx);
                // Keep the last weight values (column 0)
                for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                    weight_in[i] <= weight_matrix[i][0];  // Maintain column 0 weights
                    activation_in[i] <= 0;
                end
                
                // Calculate diagonal elements
                for (k = 0; k <= diag_idx && k < ARRAY_SIZE; k = k + 1) begin
                    row = diag_idx - k;
                    col = k;
                    if (row < ARRAY_SIZE && col < ARRAY_SIZE) begin
                        activation_in[k] <= activation_matrix[col][row];
                        $display("  activation_in[%0d] <= activation_matrix[%0d][%0d] = %0d", 
                                k, col, row, activation_matrix[col][row]);
                    end
                end
                
            end else if (cycle_count >= 3*ARRAY_SIZE-2 && cycle_count <= 4*ARRAY_SIZE-2) begin
                // Computation completion phase (extended to capture all results)
                $display("Cycle %0d: Waiting for computation completion", cycle_count+1);
                // Keep the last weight values (column 0)
                for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                    weight_in[i] <= weight_matrix[i][0];  // Maintain column 0 weights
                    activation_in[i] <= 0;
                end
                
            end else if (cycle_count > 4*ARRAY_SIZE-2) begin
                // End simulation (extended to capture all results)
                $display("Cycle %0d: Simulation completed", cycle_count+1);
                
                // Display result matrix
                $display("\nResult Matrix:");
                for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                    $write("Row %0d: ", i);
                    for (j = 0; j < ARRAY_SIZE; j = j + 1) begin
                        $write("%8d ", result_matrix[i][j]);
                    end
                    $display("");
                end
                
                $display("----------------------");
                $display("-- Simulation End --");
                $display("----------------------");
                $finish;
            end
        end
    end

    // Capture results as they become available
    // For 8x8 array, first result appears at cycle 2N = 16
    parameter RESULT_START_CYCLE = 2*ARRAY_SIZE+1; // Cycle 16 for 8x8
    
    always @(posedge clk) begin
        if (rst && cycle_count >= RESULT_START_CYCLE-1) begin
            result_cycle_offset = cycle_count - RESULT_START_CYCLE + 1;
            
            // Print all partial_sum_out values for observation
            $display("Cycle %0d: partial_sum_out = [%0d, %0d, %0d, %0d, %0d, %0d, %0d, %0d]", 
                    cycle_count+1, 
                    partial_sum_out[0], partial_sum_out[1], partial_sum_out[2], partial_sum_out[3],
                    partial_sum_out[4], partial_sum_out[5], partial_sum_out[6], partial_sum_out[7]);
            
            // Each cycle, multiple PEs output results
            for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                // PE i outputs result[i][result_cycle_offset - i] if valid
                output_row = i;
                output_col = result_cycle_offset - i;
                
                if (output_col >= 0 && output_col < ARRAY_SIZE && output_row < ARRAY_SIZE) begin
                    result_matrix[output_row][output_col] = partial_sum_out[i];
                    $display("  -> Captured result[%0d][%0d] = %0d from partial_sum_out[%0d]", 
                            output_row, output_col, partial_sum_out[i], i);
                end
            end
        end
    end

    // Monitor outputs during computation completion phase
    always @(posedge clk) begin
        if (rst && cycle_count >= 3*ARRAY_SIZE-2 && cycle_count <= 4*ARRAY_SIZE-2) begin
            if (cycle_count < RESULT_START_CYCLE-1) begin
                $display("Cycle %0d: partial_sum_out = [%0d, %0d, %0d, %0d, %0d, %0d, %0d, %0d] (before results)", 
                        cycle_count+1, 
                        partial_sum_out[0], partial_sum_out[1], partial_sum_out[2], partial_sum_out[3],
                        partial_sum_out[4], partial_sum_out[5], partial_sum_out[6], partial_sum_out[7]);
            end
        end
    end

endmodule