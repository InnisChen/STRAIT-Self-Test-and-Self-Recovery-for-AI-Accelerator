`timescale 1ns / 1ps
`define CYCLE      10.0  

module Array_8x8_tb();

    // Parameters
    parameter SYSTOLIC_SIZE = 8;
    parameter WEIGHT_WIDTH = 8;
    parameter ACTIVATION_WIDTH = 8;
    parameter PARTIAL_SUM_WIDTH = WEIGHT_WIDTH + ACTIVATION_WIDTH + $clog2(SYSTOLIC_SIZE);
    

    // signals
    reg clk = 0;
    reg clk_w = 0;
    reg rst_n = 1;  // Changed from rst to rst_n to match module
    wire scan_en = 1'b0;  // Fixed to 0
    reg [SYSTOLIC_SIZE-1:0] PE_disable = 0;
    
    // Flattened input/output signals
    reg [SYSTOLIC_SIZE*WEIGHT_WIDTH-1:0] weight_flat;
    reg [SYSTOLIC_SIZE*ACTIVATION_WIDTH-1:0] activation_flat;
    reg [SYSTOLIC_SIZE*PARTIAL_SUM_WIDTH-1:0] partial_sum_in_flat;
    wire [SYSTOLIC_SIZE*PARTIAL_SUM_WIDTH-1:0] partial_sum_flat;
    
    // Internal arrays for easy manipulation (same as before)
    reg [WEIGHT_WIDTH-1:0] weight_in [SYSTOLIC_SIZE-1:0];
    reg [ACTIVATION_WIDTH-1:0] activation_in [SYSTOLIC_SIZE-1:0];
    reg [PARTIAL_SUM_WIDTH-1:0] partial_sum_in [SYSTOLIC_SIZE-1:0];
    wire [PARTIAL_SUM_WIDTH-1:0] partial_sum_out [SYSTOLIC_SIZE-1:0];

    // Pack/unpack logic for interfacing with flattened module
    genvar pack_i;
    generate
        for (pack_i = 0; pack_i < SYSTOLIC_SIZE; pack_i = pack_i + 1) begin : pack_unpack
            // Pack inputs to flattened signals
            assign weight_flat[pack_i*WEIGHT_WIDTH +: WEIGHT_WIDTH] = weight_in[pack_i];
            assign activation_flat[pack_i*ACTIVATION_WIDTH +: ACTIVATION_WIDTH] = activation_in[pack_i];
            assign partial_sum_in_flat[pack_i*PARTIAL_SUM_WIDTH +: PARTIAL_SUM_WIDTH] = partial_sum_in[pack_i];
            
            // Unpack outputs from flattened signals
            assign partial_sum_out[pack_i] = partial_sum_flat[pack_i*PARTIAL_SUM_WIDTH +: PARTIAL_SUM_WIDTH];
        end
    endgenerate

    Systolic_array #(
        .SYSTOLIC_SIZE(SYSTOLIC_SIZE),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .ACTIVATION_WIDTH(ACTIVATION_WIDTH),
        .PARTIAL_SUM_WIDTH(PARTIAL_SUM_WIDTH)
    ) u1_Systolic_array (
        .clk(clk),
        .rst_n(rst_n),              // Changed from rst to rst_n
        .scan_en(scan_en),
        .clk_w(clk_w),
        .PE_disable(PE_disable),
        .weight_flat(weight_flat),           // Use flattened signals
        .activation_flat(activation_flat),   // Use flattened signals
        .partial_sum_in_flat(partial_sum_in_flat), // Use flattened signals
        .partial_sum_flat(partial_sum_flat)        // Use flattened signals
    );

    // Test variables
    integer i, j, k, m, n;
    integer result_cycle_offset, output_row, output_col, col_idx;
    integer diag_idx, row, col;
    reg [10:0] cycle_count = 0;

    // Data matrices
    reg [WEIGHT_WIDTH-1:0] weight_matrix [0:SYSTOLIC_SIZE-1][0:SYSTOLIC_SIZE-1];
    reg [ACTIVATION_WIDTH-1:0] activation_matrix [0:SYSTOLIC_SIZE-1][0:SYSTOLIC_SIZE-1];
    reg [PARTIAL_SUM_WIDTH-1:0] result_matrix [0:SYSTOLIC_SIZE-1][0:SYSTOLIC_SIZE-1];
    
    // Memory arrays for $readmemh
    reg [WEIGHT_WIDTH-1:0] weight_mem [0:SYSTOLIC_SIZE*SYSTOLIC_SIZE-1];
    reg [ACTIVATION_WIDTH-1:0] activation_mem [0:SYSTOLIC_SIZE*SYSTOLIC_SIZE-1];

    // Initialize all arrays to prevent X states
    initial begin
        for (int row_idx = 0; row_idx < SYSTOLIC_SIZE; row_idx++) begin
            for (int col_idx = 0; col_idx < SYSTOLIC_SIZE; col_idx++) begin
                weight_matrix[row_idx][col_idx] = 0;
                activation_matrix[row_idx][col_idx] = 0;
                result_matrix[row_idx][col_idx] = 0;
            end
        end
        
        for (int mem_idx = 0; mem_idx < SYSTOLIC_SIZE*SYSTOLIC_SIZE; mem_idx++) begin
            weight_mem[mem_idx] = 0;
            activation_mem[mem_idx] = 0;
        end
    end

    // Reset signal - Modified for rst_n (active low)
    initial begin
        $display("----------------------");
        $display("-- Simulation Start --");
        $display("-- Array Size: %0dx%0d --", SYSTOLIC_SIZE, SYSTOLIC_SIZE);
        $display("----------------------");
        rst_n = 1'b0;  // Assert reset (active low)
        #(`CYCLE*2);  
        rst_n = 1'b1;  // Release reset (active low)
        $display("Reset released at time %0t", $time);
        
        // Initialize result matrix and partial_sum_in
        for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin
            for (j = 0; j < SYSTOLIC_SIZE; j = j + 1) begin
                result_matrix[i][j] = 0;
            end
            partial_sum_in[i] = 0;  // Initialize partial sum inputs to 0
        end
        
        // Initialize input arrays properly
        for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin
            weight_in[i] = 0;
            activation_in[i] = 0;
        end
    end

    // Clock generation
    always begin 
        #(`CYCLE/2) clk = ~clk; 
    end

    // Cycle counter - Modified for rst_n
    always @(posedge clk) begin
        if (rst_n) begin
            cycle_count <= cycle_count + 1;
        end else begin
            cycle_count <= 0;
        end
    end

    // clk_w generation based on cycle count - Modified for rst_n
    always @(posedge clk) begin
        if (rst_n) begin
            if (cycle_count >= 0 && cycle_count <= SYSTOLIC_SIZE-1) begin
                // During weight loading phase, clk_w follows clk
                // clk_w will be generated as a clock signal
            end else begin
                clk_w <= 0;
            end
        end else begin
            clk_w <= 0;
        end
    end
    
    // Generate clk_w as a clock signal during weight loading - Modified for rst_n
    always begin 
        if (rst_n && cycle_count >= 0 && cycle_count <= SYSTOLIC_SIZE-1) begin
            #(`CYCLE/2) clk_w = ~clk_w;
        end else begin
            clk_w = 0;
            #(`CYCLE/2);
        end
    end

    // Read input files
    initial begin
        // Wait for reset to complete
        // wait(rst_n);
        // #(`CYCLE);
        
        // Read weight and activation matrices in hexadecimal format
        $display("Reading weight matrix from weight.dat (hexadecimal format)");
        $readmemh("C:/Project/STRAIT/input_data/weight.dat", weight_mem);
        
        $display("Reading activation matrix from activation.dat (hexadecimal format)");
        $readmemh("C:/Project/STRAIT/input_data/activation.dat", activation_mem);
        
        // Convert 1D arrays to 2D matrices
        for (m = 0; m < SYSTOLIC_SIZE; m = m + 1) begin
            for (n = 0; n < SYSTOLIC_SIZE; n = n + 1) begin
                weight_matrix[m][n] = weight_mem[m*SYSTOLIC_SIZE + n];
                activation_matrix[m][n] = activation_mem[m*SYSTOLIC_SIZE + n];
            end
        end
        
        $display("Weight and activation matrices loaded successfully");
        
        // Display loaded matrices
        $display("\nWeight Matrix:");
        for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin
            $write("Row %0d: ", i);
            for (j = 0; j < SYSTOLIC_SIZE; j = j + 1) begin
                $write("%3d ", weight_matrix[i][j]);
            end
            $display("");
        end
        
        $display("\nActivation Matrix:");
        for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin
            $write("Row %0d: ", i);
            for (j = 0; j < SYSTOLIC_SIZE; j = j + 1) begin
                $write("%3d ", activation_matrix[i][j]);
            end
            $display("");
        end
    end

    // Function to display weight array dynamically
    function void display_weight_array();
        $write("  Weights: [");
        for (int idx = 0; idx < SYSTOLIC_SIZE; idx++) begin
            $write("%0d", weight_matrix[idx][col_idx]);
            if (idx < SYSTOLIC_SIZE-1) $write(", ");
        end
        $display("]");
    endfunction

    // Function to display final weight array dynamically
    function void display_final_weight_array();
        $write("  Final Weights: [");
        for (int idx = 0; idx < SYSTOLIC_SIZE; idx++) begin
            $write("%0d", weight_matrix[idx][0]);
            if (idx < SYSTOLIC_SIZE-1) $write(", ");
        end
        $display("]");
    endfunction

    // Function to display partial sum output dynamically
    function void display_partial_sum_output();
        $write("Cycle %0d: partial_sum_out = [", cycle_count+1);
        for (int idx = 0; idx < SYSTOLIC_SIZE; idx++) begin
            $write("%0d", partial_sum_out[idx]);
            if (idx < SYSTOLIC_SIZE-1) $write(", ");
        end
        $display("]");
    endfunction

    // Function to display partial sum output with suffix
    function void display_partial_sum_output_with_suffix(string suffix);
        $write("Cycle %0d: partial_sum_out = [", cycle_count+1);
        for (int idx = 0; idx < SYSTOLIC_SIZE; idx++) begin
            $write("%0d", partial_sum_out[idx]);
            if (idx < SYSTOLIC_SIZE-1) $write(", ");
        end
        $display("] %s", suffix);
    endfunction

    // Data input control - Modified for rst_n
    always @(posedge clk) begin
        if (!rst_n) begin
            // When in reset state (rst_n = 0), keep all inputs at 0
            for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin
                weight_in[i] <= 0;
                activation_in[i] <= 0;
            end
        end else begin
            // When not in reset (rst_n = 1), normal operation
            if (cycle_count >= 0 && cycle_count <= SYSTOLIC_SIZE-2) begin
                // Weight loading phase (Cycle 0 to N-2)
                // Send weights from last column to first column
                col_idx = SYSTOLIC_SIZE - 1 - cycle_count;
                $display("Cycle %0d: Loading weight column %0d", cycle_count+1, col_idx);
                for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin
                    weight_in[i] <= weight_matrix[i][col_idx];
                    activation_in[i] <= 0;
                end
                display_weight_array();
                
            end else if (cycle_count == SYSTOLIC_SIZE-1) begin
                // Mixed phase (Cycle N-1)
                // Send first column weights and first activation
                $display("Cycle %0d: Loading final weight column and first activation", cycle_count+1);
                for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin
                    weight_in[i] <= weight_matrix[i][0];  // Column 0 (first column)
                    activation_in[i] <= (i == 0) ? activation_matrix[0][0] : 0;
                end
                display_final_weight_array();
                $display("  First activation: activation_in[0] = %0d", activation_matrix[0][0]);
                
            end else if (cycle_count >= SYSTOLIC_SIZE && cycle_count <= 3*SYSTOLIC_SIZE-3) begin
                // Activation input phase (Cycle N to 3N-3)
                diag_idx = cycle_count - SYSTOLIC_SIZE + 1;
                
                $display("Cycle %0d: Loading activation diagonal %0d", cycle_count+1, diag_idx);
                // Keep the last weight values (column 0) and calculate diagonal elements
                for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin
                    weight_in[i] <= weight_matrix[i][0];  // Maintain column 0 weights
                    activation_in[i] <= 0;  // Default to 0
                end
                
                // Set diagonal elements
                for (k = 0; k <= diag_idx && k < SYSTOLIC_SIZE; k = k + 1) begin
                    row = diag_idx - k;
                    col = k;
                    if (row < SYSTOLIC_SIZE && col < SYSTOLIC_SIZE) begin
                        activation_in[k] <= activation_matrix[col][row];
                        $display("  activation_in[%0d] <= activation_matrix[%0d][%0d] = %0d", 
                                k, col, row, activation_matrix[col][row]);
                    end
                end
            end else begin
                // For all other cases (computation completion, end, etc.)
                // Keep the last weight values (column 0) and all activations at 0
                for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin
                    weight_in[i] <= weight_matrix[i][0];  // Maintain column 0 weights
                    activation_in[i] <= 0;
                end
                
                if (cycle_count >= 3*SYSTOLIC_SIZE-2 && cycle_count <= 4*SYSTOLIC_SIZE-2) begin
                    $display("Cycle %0d: Waiting for computation completion", cycle_count+1);
                end else if (cycle_count > 4*SYSTOLIC_SIZE-2) begin
                    $display("Cycle %0d: Simulation completed", cycle_count+1);
                    
                    // Display result matrix
                    $display("\nResult Matrix:");
                    for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin
                        $write("Row %0d: ", i);
                        for (j = 0; j < SYSTOLIC_SIZE; j = j + 1) begin
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
    end

    // Capture results as they become available - Modified for rst_n
    // For NxN array, first result appears at cycle 2N+1
    parameter RESULT_START_CYCLE = 2*SYSTOLIC_SIZE+1;
    
    always @(posedge clk) begin
        if (rst_n && cycle_count >= RESULT_START_CYCLE-1) begin
            result_cycle_offset = cycle_count - RESULT_START_CYCLE + 1;
            
            // Print all partial_sum_out values for observation
            display_partial_sum_output();
            
            // Each cycle, multiple PEs output results
            for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin
                // PE i outputs result[i][result_cycle_offset - i] if valid
                output_row = i;
                output_col = result_cycle_offset - i;
                
                if (output_col >= 0 && output_col < SYSTOLIC_SIZE && output_row < SYSTOLIC_SIZE) begin
                    result_matrix[output_row][output_col] = partial_sum_out[i];
                    $display("  -> Captured result[%0d][%0d] = %0d from partial_sum_out[%0d]", 
                            output_row, output_col, partial_sum_out[i], i);
                end
            end
        end
    end

    // Monitor outputs during computation completion phase - Modified for rst_n
    always @(posedge clk) begin
        if (rst_n && cycle_count >= 3*SYSTOLIC_SIZE-2 && cycle_count <= 4*SYSTOLIC_SIZE-2) begin
            if (cycle_count < RESULT_START_CYCLE-1) begin
                display_partial_sum_output_with_suffix("(before results)");
            end
        end
    end

endmodule