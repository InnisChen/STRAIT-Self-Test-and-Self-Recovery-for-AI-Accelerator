module comparator_8 #(
    parameter SYSTOLIC_SIZE = 8
)(
    input rst_n, clk,
    input [23:0] correct_answer,

    //input [23:0] com_ps [SYSTOLIC_SIZE-1:0],
    input [23:0] com_ps_0, com_ps_1, com_ps_2, com_ps_3, com_ps_4, com_ps_5, com_ps_6, com_ps_7,

    //output comparaed_ps [SYSTOLIC_SIZE-1:0]
    output comparaed_ps_0, comparaed_ps_1, comparaed_ps_2, comparaed_ps_3, comparaed_ps_4, comparaed_ps_5, comparaed_ps_6, comparaed_ps_7
);

    //reg [23:0] com_cps2ps [SYSTOLIC_SIZE-1:0];
    reg [23:0] com_cps2ps_0, com_cps2ps_1, com_cps2ps_2, com_cps2ps_3, com_cps2ps_4, com_cps2ps_5, com_cps2ps_6, com_cps2ps_7;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            com_cps2ps_0 <= 0;
            com_cps2ps_1 <= 0;
            com_cps2ps_2 <= 0;
            com_cps2ps_3 <= 0;
            com_cps2ps_4 <= 0;
            com_cps2ps_5 <= 0;
            com_cps2ps_6 <= 0;
            com_cps2ps_7 <= 0;
        end else begin
            //compare input sum whit corrent sum
            com_cps2ps_0 <= correct_answer ^ com_ps_0;
            com_cps2ps_1 <= correct_answer ^ com_ps_1;
            com_cps2ps_2 <= correct_answer ^ com_ps_2;
            com_cps2ps_3 <= correct_answer ^ com_ps_3;
            com_cps2ps_4 <= correct_answer ^ com_ps_4;
            com_cps2ps_5 <= correct_answer ^ com_ps_5;
            com_cps2ps_6 <= correct_answer ^ com_ps_6;
            com_cps2ps_7 <= correct_answer ^ com_ps_7;
        end
    end

    //or each bit
    assign comparaed_ps_0 = |com_cps2ps_0;
    assign comparaed_ps_1 = |com_cps2ps_1;
    assign comparaed_ps_2 = |com_cps2ps_2;
    assign comparaed_ps_3 = |com_cps2ps_3;
    assign comparaed_ps_4 = |com_cps2ps_4;
    assign comparaed_ps_5 = |com_cps2ps_5;
    assign comparaed_ps_6 = |com_cps2ps_6;
    assign comparaed_ps_7 = |com_cps2ps_7;
endmodule