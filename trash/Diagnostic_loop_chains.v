//Diagnostic_loop_chains

module Diagnostic_loop_chains (
    input clk,
    input rst_n,
    input col_0 , col_1 , col_2 , col_3 , col_4 , col_5 , col_6 , col_7
);
    wire col0_0 , col1_0 , col2_0 , col3_0 , col4_0 , col5_0 , col6_0 , col7_0;

    reg col0_1 , col0_2 , col0_3 , col0_4 , col0_5 , col0_6 , col0_7 , col0_8;
    reg col1_1 , col1_2 , col1_3 , col1_4 , col1_5 , col1_6 , col1_7 , col1_8;
    reg col2_1 , col2_2 , col2_3 , col2_4 , col2_5 , col2_6 , col2_7 , col2_8;
    reg col3_1 , col3_2 , col3_3 , col3_4 , col3_5 , col3_6 , col3_7 , col3_8;
    reg col4_1 , col4_2 , col4_3 , col4_4 , col4_5 , col4_6 , col4_7 , col4_8;
    reg col5_1 , col5_2 , col5_3 , col5_4 , col5_5 , col5_6 , col5_7 , col5_8;
    reg col6_1 , col6_2 , col6_3 , col6_4 , col6_5 , col6_6 , col6_7 , col6_8;
    reg col7_1 , col7_2 , col7_3 , col7_4 , col7_5 , col7_6 , col7_7 , col7_8;

    assign col0_0 = col_0 || col0_8;
    assign col1_0 = col_1 || col1_8;
    assign col2_0 = col_2 || col2_8;    
    assign col3_0 = col_3 || col3_8;
    assign col4_0 = col_4 || col4_8;
    assign col5_0 = col_5 || col5_8;
    assign col6_0 = col_6 || col6_8;
    assign col7_0 = col_7 || col7_8;


    //col 0
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            col0_1 <= 1'b0;
            col0_2 <= 1'b0;
            col0_3 <= 1'b0;
            col0_4 <= 1'b0;
            col0_5 <= 1'b0;
            col0_6 <= 1'b0;
            col0_7 <= 1'b0;
            col0_8 <= 1'b0;
        end
        else begin
            col0_1 <= col0_0;
            col0_2 <= col0_1;
            col0_3 <= col0_2;
            col0_4 <= col0_3;
            col0_5 <= col0_4;
            col0_6 <= col0_5;
            col0_7 <= col0_6;
            col0_8 <= col0_7;
        end
    end

    //col 1
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            col1_1 <= 1'b0;
            col1_2 <= 1'b0;
            col1_3 <= 1'b0;
            col1_4 <= 1'b0;
            col1_5 <= 1'b0;
            col1_6 <= 1'b0;
            col1_7 <= 1'b0;
            col1_8 <= 1'b0;
        end
        else begin
            col1_1 <= col1_0;
            col1_2 <= col1_1;
            col1_3 <= col1_2;
            col1_4 <= col1_3;
            col1_5 <= col1_4;
            col1_6 <= col1_5;
            col1_7 <= col1_6;
            col1_8 <= col1_7;
        end
    end

    //col 2
    always @(posedge clk or negedge rst_n) begin
        col2_1 <= col2_0;
        col2_2 <= col2_1;
        col2_3 <= col2_2;
        col2_4 <= col2_3;
        col2_5 <= col2_4;
        col2_6 <= col2_5;
        col2_7 <= col2_6;
        col2_8 <= col2_7;
    end

    //col 3
    always @(posedge clk or negedge rst_n) begin
        col3_1 <= col3_0;
        col3_2 <= col3_1;
        col3_3 <= col3_2;
        col3_4 <= col3_3;
        col3_5 <= col3_4;
        col3_6 <= col3_5;
        col3_7 <= col3_6;
        col3_8 <= col3_7;
    end

    //col 4
    always @(posedge clk or negedge rst_n) begin
        col4_1 <= col4_0;
        col4_2 <= col4_1;
        col4_3 <= col4_2;
        col4_4 <= col4_3;
        col4_5 <= col4_4;
        col4_6 <= col4_5;
        col4_7 <= col4_6;
        col4_8 <= col4_7;
    end

    //col 5
    always @(posedge clk or negedge rst_n) begin
        col5_1 <= col5_0;
        col5_2 <= col5_1;
        col5_3 <= col5_2;
        col5_4 <= col5_3;
        col5_5 <= col5_4;
        col5_6 <= col5_5;
        col5_7 <= col5_6;
        col5_8 <= col5_7;
    end

    //col 6
    always @(posedge clk or negedge rst_n) begin
        col6_1 <= col6_0;
        col6_2 <= col6_1;
        col6_3 <= col6_2;
        col6_4 <= col6_3;
        col6_5 <= col6_4;
        col6_6 <= col6_5;
        col6_7 <= col6_6;
        col6_8 <= col6_7;
    end

    //col 7
    always @(posedge clk or negedge rst_n) begin
        col7_1 <= col7_0;
        col7_2 <= col7_1;
        col7_3 <= col7_2;
        col7_4 <= col7_3;
        col7_5 <= col7_4;
        col7_6 <= col7_5;
        col7_7 <= col7_6;
        col7_8 <= col7_7;
    end


// Row_fault detector
wire row_and_result;
wire row_detect_0;

reg row_detect_1 , row_detect_2 , row_detect_3 , row_detect_4 , row_detect_5 , row_detect_6 , row_detect_7 , row_detect_8;

assign row_and_result = col5_0 && col6_0 && col7_0;     //最後3個and
assign row_detect_0 = row_and_result || row_detect_8;

always @(posedge clk or negedge rst_n) begin
    row_detect_1 <= row_detect_0;
    row_detect_2 <= row_detect_1;
    row_detect_3 <= row_detect_2;
    row_detect_4 <= row_detect_3;
    row_detect_5 <= row_detect_4;
    row_detect_6 <= row_detect_5;
    row_detect_7 <= row_detect_6;
    row_detect_8 <= row_detect_7;

end

// Column_fault_detector
wire col_and_result_0 , col_and_result_1 , col_and_result_2 , col_and_result_3 , col_and_result_4 , col_and_result_5 , col_and_result_6 , col_and_result_7;
reg column_detect_0 , column_detect_1 , column_detect_2 , column_detect_3 , column_detect_4 , column_detect_5 , column_detect_6 , column_detect_7;

assign col_and_result_0 = col0_6 && col0_7 && col0_8;
assign col_and_result_1 = col1_6 && col1_7 && col1_8;
assign col_and_result_2 = col2_6 && col2_7 && col2_8;
assign col_and_result_3 = col3_6 && col3_7 && col3_8;
assign col_and_result_4 = col4_6 && col4_7 && col4_8;
assign col_and_result_5 = col5_6 && col5_7 && col5_8;
assign col_and_result_6 = col6_6 && col6_7 && col6_8;
assign col_and_result_7 = col7_6 && col7_7 && col7_8;

always @(posedge clk ) begin
    column_detect_0 <= col_and_result_0;
    column_detect_1 <= col_and_result_1;
    column_detect_2 <= col_and_result_2;
    column_detect_3 <= col_and_result_3;
    column_detect_4 <= col_and_result_4;
    column_detect_5 <= col_and_result_5;
    column_detect_6 <= col_and_result_6;
    column_detect_7 <= col_and_result_7;
end

    
endmodule