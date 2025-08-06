module bisr_weight_allocation #(
    parameter SYSTOLIC_SIZE = 8,
    parameter WEIGHT_WIDTH = 8,
    parameter ACTIVATION_WIDTH = 8,
    parameter ADDR_WIDTH = $clog2(SYSTOLIC_SIZE)
)(
    input wire clk,
    input wire rst_n,
    
    // eNVM 介面 - 簡化的輸入
    input wire envm_wr_en,
    input wire [SYSTOLIC_SIZE*SYSTOLIC_SIZE-1:0] envm_faulty_patterns_flat,
    
    // 權重輸入和配置介面
    input wire weight_start,                                    // 開始權重配置的信號
    input wire [SYSTOLIC_SIZE*WEIGHT_WIDTH-1:0] input_weights,
    input wire weight_valid,
    
    // Address Counter 介面 (正常運作時的讀取)
    input wire [ADDR_WIDTH-1:0] read_addr,
    
    // 輸出給 Systolic Array
    output wire [SYSTOLIC_SIZE*WEIGHT_WIDTH-1:0] output_weights,
    
    // 輸出給 Activation Buffer
    output wire [ADDR_WIDTH-1:0] output_mapped_addr,
    
    // Recovery result (輸出給軟體)
    output wire recovery_success,
    output wire recovery_done
);

    // Internal signals
    wire [SYSTOLIC_SIZE-1:0] zero_weight_flags;
    wire [SYSTOLIC_SIZE-1:0] faulty_rows_mask;
    wire [SYSTOLIC_SIZE-1:0] valid_bits_out;
    wire all_faulty_matched;
    wire allocation_failed;
    
    // Faulty PE Storage signals
    wire match_success;
    wire match_failed;
    wire [ADDR_WIDTH-1:0] faulty_row_addr;
    
    // Mapping Table signals
    wire [ADDR_WIDTH-1:0] mapped_read_addr;
    
    // Internal address counters
    reg [ADDR_WIDTH-1:0] faulty_pe_addr;     // faulty PE storage 使用
    reg [ADDR_WIDTH-1:0] mapping_addr;       // mapping table 使用
    reg mapping_addr_valid;                  // mapping 地址是否有效
    
    genvar i;
    
    // Step 1: Zero weight detection (組合邏輯)
    generate
        for (i = 0; i < SYSTOLIC_SIZE; i=i+1) begin : zero_detection
            assign zero_weight_flags[i] = ~(|input_weights[i*WEIGHT_WIDTH +: WEIGHT_WIDTH]);
        end
    endgenerate
    
    // Internal address counter logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            faulty_pe_addr <= {ADDR_WIDTH{1'b0}};
            mapping_addr <= {ADDR_WIDTH{1'b0}};
            mapping_addr_valid <= 1'b0;
        end
        else if (weight_start) begin
            faulty_pe_addr <= {ADDR_WIDTH{1'b0}};
            mapping_addr <= {ADDR_WIDTH{1'b0}};
            mapping_addr_valid <= 1'b0;
        end
        else if (weight_valid) begin
            if(faulty_pe_addr == SYSTOLIC_SIZE - 1) begin
                faulty_pe_addr <= faulty_pe_addr;
            end
            else faulty_pe_addr <= faulty_pe_addr + 1;
            
            // mapping table 處理前一個結果
            mapping_addr <= faulty_pe_addr;
            mapping_addr_valid <= 1'b1;  // 從第二個 cycle 開始有效
        end
    end
    
    // Recovery result check
    assign recovery_done = (faulty_pe_addr == SYSTOLIC_SIZE-1) && !weight_valid;
    assign recovery_success = recovery_done && ~(|valid_bits_out);
    
    // Instantiate Faulty PE Storage
    faulty_pe_storage #(
        .SYSTOLIC_SIZE(SYSTOLIC_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) faulty_pe_inst (
        .clk(clk),
        .rst_n(rst_n),
        
        // eNVM interface - 簡化的輸入
        .wr_en(envm_wr_en),
        .faulty_patterns_flat(envm_faulty_patterns_flat),
        
        // Weight allocation interface
        .zero_weight_flags(zero_weight_flags),
        .weight_valid(weight_valid),
        .current_row_addr(faulty_pe_addr),
        
        // Output to Mapping Table
        .match_success(match_success),
        .match_failed(match_failed),
        .faulty_row_addr(faulty_row_addr),
        
        // Initialization info to Mapping Table
        .faulty_rows_mask(faulty_rows_mask),
        
        // Output to Recovery result check and Mapping Table
        .valid_bits_out(valid_bits_out),
        .all_faulty_matched(all_faulty_matched)
    );
    
    // Instantiate Mapping Table
    mapping_table #(
        .SYSTOLIC_SIZE(SYSTOLIC_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) mapping_inst (
        .clk(clk),
        .rst_n(rst_n),
        
        // Initialization from Faulty PE Storage
        .faulty_rows_mask(faulty_rows_mask),
        
        // Update interface from Faulty PE Storage
        .match_success(match_success),
        .match_failed(match_failed),
        .faulty_addr(faulty_row_addr),
        .current_row_addr(mapping_addr),
        .all_faulty_matched(all_faulty_matched),
        .envm_wr_en(envm_wr_en),
        
        // Query interface
        .input_addr(read_addr),
        .mapped_addr(mapped_read_addr),
        
        // Allocation status output
        .allocation_failed(allocation_failed)
    );
    
    // Instantiate Row Weight Storage
    row_weight_storage #(
        .SYSTOLIC_SIZE(SYSTOLIC_SIZE),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) weight_storage_inst (
        .clk(clk),
        .rst_n(rst_n),
        
        // Write interface (權重配置時寫入)
        .wr_en(weight_valid),
        .wr_addr(faulty_pe_addr),
        .wr_data(input_weights),
        
        // Read interface (to Systolic Array)
        .rd_addr(mapped_read_addr),  // 使用映射後的地址
        .rd_data(output_weights)
    );
    
    // Output mapped address to Activation Buffer
    assign output_mapped_addr = mapped_read_addr;

endmodule