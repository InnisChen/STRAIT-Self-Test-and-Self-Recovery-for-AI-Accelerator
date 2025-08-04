
module PE_Array_8x8 (
    input clk, rst, scan_en,
    input clk_w,
    input PE_disable_0, PE_disable_1, PE_disable_2, PE_disable_3, PE_disable_4, PE_disable_5, PE_disable_6, PE_disable_7,
    input [7:0] weight_0, weight_1, weight_2, weight_3, weight_4, weight_5, weight_6, weight_7,
    input [7:0] activation_0, activation_1, activation_2, activation_3, activation_4, activation_5, activation_6, activation_7,
    input [23:0] partial_sum_in_0, partial_sum_in_1, partial_sum_in_2, partial_sum_in_3, partial_sum_in_4, partial_sum_in_5, partial_sum_in_6, partial_sum_in_7,
    output [23:0] partial_sum_0, partial_sum_1, partial_sum_2, partial_sum_3, partial_sum_4, partial_sum_5, partial_sum_6, partial_sum_7
);
    wire PE_disable1_0, PE_disable1_1, PE_disable1_2, PE_disable1_3, PE_disable1_4, PE_disable1_5, PE_disable1_6, PE_disable1_7,
         PE_disable2_0, PE_disable2_1, PE_disable2_2, PE_disable2_3, PE_disable2_4, PE_disable2_5, PE_disable2_6, PE_disable2_7,
         PE_disable3_0, PE_disable3_1, PE_disable3_2, PE_disable3_3, PE_disable3_4, PE_disable3_5, PE_disable3_6, PE_disable3_7,
         PE_disable4_0, PE_disable4_1, PE_disable4_2, PE_disable4_3, PE_disable4_4, PE_disable4_5, PE_disable4_6, PE_disable4_7,
         PE_disable5_0, PE_disable5_1, PE_disable5_2, PE_disable5_3, PE_disable5_4, PE_disable5_5, PE_disable5_6, PE_disable5_7,
         PE_disable6_0, PE_disable6_1, PE_disable6_2, PE_disable6_3, PE_disable6_4, PE_disable6_5, PE_disable6_6, PE_disable6_7,
         PE_disable7_0, PE_disable7_1, PE_disable7_2, PE_disable7_3, PE_disable7_4, PE_disable7_5, PE_disable7_6, PE_disable7_7;


    wire [7:0] weight1_0, weight1_1, weight1_2, weight1_3, weight1_4, weight1_5, weight1_6, weight1_7, 
               weight2_0, weight2_1, weight2_2, weight2_3, weight2_4, weight2_5, weight2_6, weight2_7, 
               weight3_0, weight3_1, weight3_2, weight3_3, weight3_4, weight3_5, weight3_6, weight3_7, 
               weight4_0, weight4_1, weight4_2, weight4_3, weight4_4, weight4_5, weight4_6, weight4_7, 
               weight5_0, weight5_1, weight5_2, weight5_3, weight5_4, weight5_5, weight5_6, weight5_7, 
               weight6_0, weight6_1, weight6_2, weight6_3, weight6_4, weight6_5, weight6_6, weight6_7, 
               weight7_0, weight7_1, weight7_2, weight7_3, weight7_4, weight7_5, weight7_6, weight7_7;

    wire [7:0] activation0_1, activation0_2, activation0_3, activation0_4, activation0_5, activation0_6, activation0_7,
               activation1_1, activation1_2, activation1_3, activation1_4, activation1_5, activation1_6, activation1_7,
               activation2_1, activation2_2, activation2_3, activation2_4, activation2_5, activation2_6, activation2_7,
               activation3_1, activation3_2, activation3_3, activation3_4, activation3_5, activation3_6, activation3_7,
               activation4_1, activation4_2, activation4_3, activation4_4, activation4_5, activation4_6, activation4_7,
               activation5_1, activation5_2, activation5_3, activation5_4, activation5_5, activation5_6, activation5_7,
               activation6_1, activation6_2, activation6_3, activation6_4, activation6_5, activation6_6, activation6_7,
               activation7_1, activation7_2, activation7_3, activation7_4, activation7_5, activation7_6, activation7_7;

    wire [23:0] partial_sum1_0, partial_sum1_1, partial_sum1_2, partial_sum1_3, partial_sum1_4, partial_sum1_5, partial_sum1_6, partial_sum1_7, 
                partial_sum2_0, partial_sum2_1, partial_sum2_2, partial_sum2_3, partial_sum2_4, partial_sum2_5, partial_sum2_6, partial_sum2_7,
                partial_sum3_0, partial_sum3_1, partial_sum3_2, partial_sum3_3, partial_sum3_4, partial_sum3_5, partial_sum3_6, partial_sum3_7,
                partial_sum4_0, partial_sum4_1, partial_sum4_2, partial_sum4_3, partial_sum4_4, partial_sum4_5, partial_sum4_6, partial_sum4_7,
                partial_sum5_0, partial_sum5_1, partial_sum5_2, partial_sum5_3, partial_sum5_4, partial_sum5_5, partial_sum5_6, partial_sum5_7,
                partial_sum6_0, partial_sum6_1, partial_sum6_2, partial_sum6_3, partial_sum6_4, partial_sum6_5, partial_sum6_6, partial_sum6_7,
                partial_sum7_0, partial_sum7_1, partial_sum7_2, partial_sum7_3, partial_sum7_4, partial_sum7_5, partial_sum7_6, partial_sum7_7;

//row:0

    STRAIT_PE PE_0_0( //row:0, column:0
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight_0),
        .activation(activation_0),
        .partial_sum_in(partial_sum_in_0),
        .PE_disable(PE_disable_0), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight1_0), 
        .activation_out(activation0_1),
        .partial_sum_out(partial_sum1_0),
        .PE_disable_out(PE_disable1_0)
    );

    STRAIT_PE PE_0_1( //row:0, column:1
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight_1),
        .activation(activation0_1),
        .partial_sum_in(partial_sum_in_1),
        .PE_disable(PE_disable_1), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight1_1), 
        .activation_out(activation0_2),
        .partial_sum_out(partial_sum1_1),
        .PE_disable_out(PE_disable1_1)
    );

    STRAIT_PE PE_0_2( //row:0, column:2
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight_2),
        .activation(activation0_2),
        .partial_sum_in(partial_sum_in_2),
        .PE_disable(PE_disable_2), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight1_2), 
        .activation_out(activation0_3),
        .partial_sum_out(partial_sum1_2),
        .PE_disable_out(PE_disable1_2)
    );

    STRAIT_PE PE_0_3( //row:0, column:3
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight_3),
        .activation(activation0_3),
        .partial_sum_in(partial_sum_in_3),
        .PE_disable(PE_disable_3), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight1_3), 
        .activation_out(activation0_4),
        .partial_sum_out(partial_sum1_3),
        .PE_disable_out(PE_disable1_3)
    );

    STRAIT_PE PE_0_4( //row:0, column:4
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight_4),
        .activation(activation0_4),
        .partial_sum_in(partial_sum_in_4),
        .PE_disable(PE_disable_4), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight1_4), 
        .activation_out(activation0_5),
        .partial_sum_out(partial_sum1_4),
        .PE_disable_out(PE_disable1_4)
    );

    STRAIT_PE PE_0_5( //row:0, column:5
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight_5),
        .activation(activation0_5),
        .partial_sum_in(partial_sum_in_5),
        .PE_disable(PE_disable_5), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight1_5), 
        .activation_out(activation0_6),
        .partial_sum_out(partial_sum1_5),
        .PE_disable_out(PE_disable1_5)
    );

    STRAIT_PE PE_0_6( //row:0, column:6
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight_6),
        .activation(activation0_6),
        .partial_sum_in(partial_sum_in_6),
        .PE_disable(PE_disable_6), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight1_6), 
        .activation_out(activation0_7),
        .partial_sum_out(partial_sum1_6),
        .PE_disable_out(PE_disable1_6)
    );

    STRAIT_PE PE_0_7( //row:0, column:7
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight_7),
        .activation(activation0_7),
        .partial_sum_in(partial_sum_in_7),
        .PE_disable(PE_disable_7), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight1_7), 
        .activation_out(),
        .partial_sum_out(partial_sum1_7),
        .PE_disable_out(PE_disable1_7)
    );

//row:1

    STRAIT_PE PE_1_0( //row:1, column:0
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight1_0),
        .activation(activation_1),
        .partial_sum_in(partial_sum1_0),
        .PE_disable(PE_disable1_0), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight2_0), 
        .activation_out(activation1_1),
        .partial_sum_out(partial_sum2_0),
        .PE_disable_out(PE_disable2_0)
    );

    STRAIT_PE PE_1_1( //row:1, column:1
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight1_1),
        .activation(activation1_1),
        .partial_sum_in(partial_sum1_1),
        .PE_disable(PE_disable1_1), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight2_1), 
        .activation_out(activation1_2),
        .partial_sum_out(partial_sum2_1),
        .PE_disable_out(PE_disable2_1)
    );

    STRAIT_PE PE_1_2( //row:1, column:2
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight1_2),
        .activation(activation1_2),
        .partial_sum_in(partial_sum1_2),
        .PE_disable(PE_disable1_2), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight2_2), 
        .activation_out(activation1_3),
        .partial_sum_out(partial_sum2_2),
        .PE_disable_out(PE_disable2_2)
    );

    STRAIT_PE PE_1_3( //row:1, column:3
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight1_3),
        .activation(activation1_3),
        .partial_sum_in(partial_sum1_3),
        .PE_disable(PE_disable1_3), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight2_3), 
        .activation_out(activation1_4),
        .partial_sum_out(partial_sum2_3),
        .PE_disable_out(PE_disable2_3)
    );

    STRAIT_PE PE_1_4( //row:1, column:4
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight1_4),
        .activation(activation1_4),
        .partial_sum_in(partial_sum1_4),
        .PE_disable(PE_disable1_4), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight2_4), 
        .activation_out(activation1_5),
        .partial_sum_out(partial_sum2_4),
        .PE_disable_out(PE_disable2_4)
    );

    STRAIT_PE PE_1_5( //row:1, column:5
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight1_5),
        .activation(activation1_5),
        .partial_sum_in(partial_sum1_5),
        .PE_disable(PE_disable1_5), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight2_5), 
        .activation_out(activation1_6),
        .partial_sum_out(partial_sum2_5),
        .PE_disable_out(PE_disable2_5)
    );

    STRAIT_PE PE_1_6( //row:1, column:6
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight1_6),
        .activation(activation1_6),
        .partial_sum_in(partial_sum1_6),
        .PE_disable(PE_disable1_6), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight2_6), 
        .activation_out(activation1_7),
        .partial_sum_out(partial_sum2_6),
        .PE_disable_out(PE_disable2_6)
    );

    STRAIT_PE PE_1_7( //row:1, column:7
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight1_7),
        .activation(activation1_7),
        .partial_sum_in(partial_sum1_7),
        .PE_disable(PE_disable1_7), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight2_7), 
        .activation_out(),
        .partial_sum_out(partial_sum2_7),
        .PE_disable_out(PE_disable2_7)
    );

//row:2

    STRAIT_PE PE_2_0( //row:2, column:0
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight2_0),
        .activation(activation_2),
        .partial_sum_in(partial_sum2_0),
        .PE_disable(PE_disable2_0), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight3_0), 
        .activation_out(activation2_1),
        .partial_sum_out(partial_sum3_0),
        .PE_disable_out(PE_disable3_0)
    );

    STRAIT_PE PE_2_1( //row:2, column:1
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight2_1),
        .activation(activation2_1),
        .partial_sum_in(partial_sum2_1),
        .PE_disable(PE_disable2_1), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight3_1), 
        .activation_out(activation2_2),
        .partial_sum_out(partial_sum3_1),
        .PE_disable_out(PE_disable3_1)
    );

    STRAIT_PE PE_2_2( //row:2, column:2
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight2_2),
        .activation(activation2_2),
        .partial_sum_in(partial_sum2_2),
        .PE_disable(PE_disable2_2), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight3_2), 
        .activation_out(activation2_3),
        .partial_sum_out(partial_sum3_2),
        .PE_disable_out(PE_disable3_2)
    );

    STRAIT_PE PE_2_3( //row:2, column:3
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight2_3),
        .activation(activation2_3),
        .partial_sum_in(partial_sum2_3),
        .PE_disable(PE_disable2_3), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight3_3), 
        .activation_out(activation2_4),
        .partial_sum_out(partial_sum3_3),
        .PE_disable_out(PE_disable3_3)
    );

    STRAIT_PE PE_2_4( //row:2, column:4
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight2_4),
        .activation(activation2_4),
        .partial_sum_in(partial_sum2_4),
        .PE_disable(PE_disable2_4), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight3_4), 
        .activation_out(activation2_5),
        .partial_sum_out(partial_sum3_4),
        .PE_disable_out(PE_disable3_4)
    );

    STRAIT_PE PE_2_5( //row:2, column:5
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight2_5),
        .activation(activation2_5),
        .partial_sum_in(partial_sum2_5),
        .PE_disable(PE_disable2_5), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight3_5), 
        .activation_out(activation2_6),
        .partial_sum_out(partial_sum3_5),
        .PE_disable_out(PE_disable3_5)
    );

    STRAIT_PE PE_2_6( //row:2, column:6
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight2_6),
        .activation(activation2_6),
        .partial_sum_in(partial_sum2_6),
        .PE_disable(PE_disable2_6), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight3_6), 
        .activation_out(activation2_7),
        .partial_sum_out(partial_sum3_6),
        .PE_disable_out(PE_disable3_6)
    );

    STRAIT_PE PE_2_7( //row:2, column:7
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight2_7),
        .activation(activation2_7),
        .partial_sum_in(partial_sum2_7),
        .PE_disable(PE_disable2_7), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight3_7), 
        .activation_out(),
        .partial_sum_out(partial_sum3_7),
        .PE_disable_out(PE_disable3_7)
    );

//row:3

    STRAIT_PE PE_3_0( //row:3, column:0
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight3_0),
        .activation(activation_3),
        .partial_sum_in(partial_sum3_0),
        .PE_disable(PE_disable3_0), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight4_0), 
        .activation_out(activation3_1),
        .partial_sum_out(partial_sum4_0),
        .PE_disable_out(PE_disable4_0)
    );

    STRAIT_PE PE_3_1( //row:3, column:1
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight3_1),
        .activation(activation3_1),
        .partial_sum_in(partial_sum3_1),
        .PE_disable(PE_disable3_1), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight4_1), 
        .activation_out(activation3_2),
        .partial_sum_out(partial_sum4_1),
        .PE_disable_out(PE_disable4_1)
    );

    STRAIT_PE PE_3_2( //row:3, column:2
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight3_2),
        .activation(activation3_2),
        .partial_sum_in(partial_sum3_2),
        .PE_disable(PE_disable3_2), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight4_2), 
        .activation_out(activation3_3),
        .partial_sum_out(partial_sum4_2),
        .PE_disable_out(PE_disable4_2)
    );

    STRAIT_PE PE_3_3( //row:3, column:3
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight3_3),
        .activation(activation3_3),
        .partial_sum_in(partial_sum3_3),
        .PE_disable(PE_disable3_3), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight4_3), 
        .activation_out(activation3_4),
        .partial_sum_out(partial_sum4_3),
        .PE_disable_out(PE_disable4_3)
    );

    STRAIT_PE PE_3_4( //row:3, column:4
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight3_4),
        .activation(activation3_4),
        .partial_sum_in(partial_sum3_4),
        .PE_disable(PE_disable3_4), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight4_4), 
        .activation_out(activation3_5),
        .partial_sum_out(partial_sum4_4),
        .PE_disable_out(PE_disable4_4)
    );

    STRAIT_PE PE_3_5( //row:3, column:5
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight3_5),
        .activation(activation3_5),
        .partial_sum_in(partial_sum3_5),
        .PE_disable(PE_disable3_5), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight4_5), 
        .activation_out(activation3_6),
        .partial_sum_out(partial_sum4_5),
        .PE_disable_out(PE_disable4_5)
    );

    STRAIT_PE PE_3_6( //row:3, column:6
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight3_6),
        .activation(activation3_6),
        .partial_sum_in(partial_sum3_6),
        .PE_disable(PE_disable3_6), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight4_6), 
        .activation_out(activation3_7),
        .partial_sum_out(partial_sum4_6),
        .PE_disable_out(PE_disable4_6)
    );

    STRAIT_PE PE_3_7( //row:3, column:7
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight3_7),
        .activation(activation3_7),
        .partial_sum_in(partial_sum3_7),
        .PE_disable(PE_disable3_7), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight4_7), 
        .activation_out(),
        .partial_sum_out(partial_sum4_7),
        .PE_disable_out(PE_disable4_7)
    );

//row:4

    STRAIT_PE PE_4_0( //row:4, column:0
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight4_0),
        .activation(activation_4),
        .partial_sum_in(partial_sum4_0),
        .PE_disable(PE_disable4_0), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight5_0), 
        .activation_out(activation4_1),
        .partial_sum_out(partial_sum5_0),
        .PE_disable_out(PE_disable5_0)
    );

    STRAIT_PE PE_4_1( //row:4, column:1
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight4_1),
        .activation(activation4_1),
        .partial_sum_in(partial_sum4_1),
        .PE_disable(PE_disable4_1), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight5_1), 
        .activation_out(activation4_2),
        .partial_sum_out(partial_sum5_1),
        .PE_disable_out(PE_disable5_1)
    );

    STRAIT_PE PE_4_2( //row:4, column:2
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight4_2),
        .activation(activation4_2),
        .partial_sum_in(partial_sum4_2),
        .PE_disable(PE_disable4_2), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight5_2), 
        .activation_out(activation4_3),
        .partial_sum_out(partial_sum5_2),
        .PE_disable_out(PE_disable5_2)
    );

    STRAIT_PE PE_4_3( //row:4, column:3
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight4_3),
        .activation(activation4_3),
        .partial_sum_in(partial_sum4_3),
        .PE_disable(PE_disable4_3), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight5_3), 
        .activation_out(activation4_4),
        .partial_sum_out(partial_sum5_3),
        .PE_disable_out(PE_disable5_3)
    );

    STRAIT_PE PE_4_4( //row:4, column:4
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight4_4),
        .activation(activation4_4),
        .partial_sum_in(partial_sum4_4),
        .PE_disable(PE_disable4_4), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight5_4), 
        .activation_out(activation4_5),
        .partial_sum_out(partial_sum5_4),
        .PE_disable_out(PE_disable5_4)
    );

    STRAIT_PE PE_4_5( //row:4, column:5
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight4_5),
        .activation(activation4_5),
        .partial_sum_in(partial_sum4_5),
        .PE_disable(PE_disable4_5), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight5_5), 
        .activation_out(activation4_6),
        .partial_sum_out(partial_sum5_5),
        .PE_disable_out(PE_disable5_5)
    );

    STRAIT_PE PE_4_6( //row:4, column:6
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight4_6),
        .activation(activation4_6),
        .partial_sum_in(partial_sum4_6),
        .PE_disable(PE_disable4_6), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight5_6), 
        .activation_out(activation4_7),
        .partial_sum_out(partial_sum5_6),
        .PE_disable_out(PE_disable5_6)
    );

    STRAIT_PE PE_4_7( //row:4, column:7
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight4_7),
        .activation(activation4_7),
        .partial_sum_in(partial_sum4_7),
        .PE_disable(PE_disable4_7), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight5_7), 
        .activation_out(),
        .partial_sum_out(partial_sum5_7),
        .PE_disable_out(PE_disable5_7)
    );

//row:5

    STRAIT_PE PE_5_0( //row:5, column:0
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight5_0),
        .activation(activation_5),
        .partial_sum_in(partial_sum5_0),
        .PE_disable(PE_disable5_0), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight6_0), 
        .activation_out(activation5_1),
        .partial_sum_out(partial_sum6_0),
        .PE_disable_out(PE_disable6_0)
    );

    STRAIT_PE PE_5_1( //row:5, column:1
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight5_1),
        .activation(activation5_1),
        .partial_sum_in(partial_sum5_1),
        .PE_disable(PE_disable5_1), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight6_1), 
        .activation_out(activation5_2),
        .partial_sum_out(partial_sum6_1),
        .PE_disable_out(PE_disable6_1)
    );

    STRAIT_PE PE_5_2( //row:5, column:2
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight5_2),
        .activation(activation5_2),
        .partial_sum_in(partial_sum5_2),
        .PE_disable(PE_disable5_2), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight6_2), 
        .activation_out(activation5_3),
        .partial_sum_out(partial_sum6_2),
        .PE_disable_out(PE_disable6_2)
    );

    STRAIT_PE PE_5_3( //row:5, column:3
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight5_3),
        .activation(activation5_3),
        .partial_sum_in(partial_sum5_3),
        .PE_disable(PE_disable5_3), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight6_3), 
        .activation_out(activation5_4),
        .partial_sum_out(partial_sum6_3),
        .PE_disable_out(PE_disable6_3)
    );

    STRAIT_PE PE_5_4( //row:5, column:4
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight5_4),
        .activation(activation5_4),
        .partial_sum_in(partial_sum5_4),
        .PE_disable(PE_disable5_4), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight6_4), 
        .activation_out(activation5_5),
        .partial_sum_out(partial_sum6_4),
        .PE_disable_out(PE_disable6_4)
    );

    STRAIT_PE PE_5_5( //row:5, column:5
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight5_5),
        .activation(activation5_5),
        .partial_sum_in(partial_sum5_5),
        .PE_disable(PE_disable5_5), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight6_5), 
        .activation_out(activation5_6),
        .partial_sum_out(partial_sum6_5),
        .PE_disable_out(PE_disable6_5)
    );

    STRAIT_PE PE_5_6( //row:5, column:6
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight5_6),
        .activation(activation5_6),
        .partial_sum_in(partial_sum5_6),
        .PE_disable(PE_disable5_6), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight6_6), 
        .activation_out(activation5_7),
        .partial_sum_out(partial_sum6_6),
        .PE_disable_out(PE_disable6_6)
    );

    STRAIT_PE PE_5_7( //row:5, column:7
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight5_7),
        .activation(activation5_7),
        .partial_sum_in(partial_sum5_7),
        .PE_disable(PE_disable5_7), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight6_7), 
        .activation_out(),
        .partial_sum_out(partial_sum6_7),
        .PE_disable_out(PE_disable6_7)
    );


//row:6

    STRAIT_PE PE_6_0( //row:6, column:0
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight6_0),
        .activation(activation_6),
        .partial_sum_in(partial_sum6_0),
        .PE_disable(PE_disable6_0), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight7_0), 
        .activation_out(activation6_1),
        .partial_sum_out(partial_sum7_0),
        .PE_disable_out(PE_disable7_0)
    );

    STRAIT_PE PE_6_1( //row:6, column:1
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight6_1),
        .activation(activation6_1),
        .partial_sum_in(partial_sum6_1),
        .PE_disable(PE_disable6_1), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight7_1), 
        .activation_out(activation6_2),
        .partial_sum_out(partial_sum7_1),
        .PE_disable_out(PE_disable7_1)
    );

    STRAIT_PE PE_6_2( //row:6, column:2
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight6_2),
        .activation(activation6_2),
        .partial_sum_in(partial_sum6_2),
        .PE_disable(PE_disable6_2), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight7_2), 
        .activation_out(activation6_3),
        .partial_sum_out(partial_sum7_2),
        .PE_disable_out(PE_disable7_2)
    );

    STRAIT_PE PE_6_3( //row:6, column:3
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight6_3),
        .activation(activation6_3),
        .partial_sum_in(partial_sum6_3),
        .PE_disable(PE_disable6_3), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight7_3), 
        .activation_out(activation6_4),
        .partial_sum_out(partial_sum7_3),
        .PE_disable_out(PE_disable7_3)
    );

    STRAIT_PE PE_6_4( //row:6, column:4
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight6_4),
        .activation(activation6_4),
        .partial_sum_in(partial_sum6_4),
        .PE_disable(PE_disable6_4), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight7_4), 
        .activation_out(activation6_5),
        .partial_sum_out(partial_sum7_4),
        .PE_disable_out(PE_disable7_4)
    );

    STRAIT_PE PE_6_5( //row:6, column:5
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight6_5),
        .activation(activation6_5),
        .partial_sum_in(partial_sum6_5),
        .PE_disable(PE_disable6_5), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight7_5), 
        .activation_out(activation6_6),
        .partial_sum_out(partial_sum7_5),
        .PE_disable_out(PE_disable7_5)
    );

    STRAIT_PE PE_6_6( //row:6, column:6
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight6_6),
        .activation(activation6_6),
        .partial_sum_in(partial_sum6_6),
        .PE_disable(PE_disable6_6), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight7_6), 
        .activation_out(activation6_7),
        .partial_sum_out(partial_sum7_6),
        .PE_disable_out(PE_disable7_6)
    );

    STRAIT_PE PE_6_7( //row:6, column:7
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight6_7),
        .activation(activation6_7),
        .partial_sum_in(partial_sum6_7),
        .PE_disable(PE_disable6_7), 
        .scan_en(scan_en), //same
        //output
        .weight_out(weight7_7), 
        .activation_out(),
        .partial_sum_out(partial_sum7_7),
        .PE_disable_out(PE_disable7_7)
    );

//row:7

    STRAIT_PE PE_7_0( //row:7, column:0
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight7_0),
        .activation(activation_7),
        .partial_sum_in(partial_sum7_0),
        .PE_disable(PE_disable7_0), 
        .scan_en(scan_en), //same
        //output
        .weight_out(), 
        .activation_out(activation7_1),
        .partial_sum_out(partial_sum_0),
        .PE_disable_out()
    );

    STRAIT_PE PE_7_1( //row:7, column:1
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight7_1),
        .activation(activation7_1),
        .partial_sum_in(partial_sum7_1),
        .PE_disable(PE_disable7_1), 
        .scan_en(scan_en), //same
        //output
        .weight_out(), 
        .activation_out(activation7_2),
        .partial_sum_out(partial_sum_1),
        .PE_disable_out()
    );

    STRAIT_PE PE_7_2( //row:7, column:2
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight7_2),
        .activation(activation7_2),
        .partial_sum_in(partial_sum7_2),
        .PE_disable(PE_disable7_2), 
        .scan_en(scan_en), //same
        //output
        .weight_out(), 
        .activation_out(activation7_3),
        .partial_sum_out(partial_sum_2),
        .PE_disable_out()
    );

    STRAIT_PE PE_7_3( //row:7, column:3
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight7_3),
        .activation(activation7_3),
        .partial_sum_in(partial_sum7_3),
        .PE_disable(PE_disable7_3), 
        .scan_en(scan_en), //same
        //output
        .weight_out(), 
        .activation_out(activation7_4),
        .partial_sum_out(partial_sum_3),
        .PE_disable_out()
    );

    STRAIT_PE PE_7_4( //row:7, column:4
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight7_4),
        .activation(activation7_4),
        .partial_sum_in(partial_sum7_4),
        .PE_disable(PE_disable7_4), 
        .scan_en(scan_en), //same
        //output
        .weight_out(), 
        .activation_out(activation7_5),
        .partial_sum_out(partial_sum_4),
        .PE_disable_out()
    );

    STRAIT_PE PE_7_5( //row:7, column:5
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight7_5),
        .activation(activation7_5),
        .partial_sum_in(partial_sum7_5),
        .PE_disable(PE_disable7_5), 
        .scan_en(scan_en), //same
        //output
        .weight_out(), 
        .activation_out(activation7_6),
        .partial_sum_out(partial_sum_5),
        .PE_disable_out()
    );

    STRAIT_PE PE_7_6( //row:7, column:6
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight7_6),
        .activation(activation7_6),
        .partial_sum_in(partial_sum7_6),
        .PE_disable(PE_disable7_6), 
        .scan_en(scan_en), //same
        //output
        .weight_out(), 
        .activation_out(activation7_7),
        .partial_sum_out(partial_sum_6),
        .PE_disable_out()
    );

    STRAIT_PE PE_7_7( //row:7, column:7
        //input
        .clk(clk), //same
        .clk_w(clk_w),
        .rst(rst), //same
        .weight(weight7_7),
        .activation(activation7_7),
        .partial_sum_in(partial_sum7_7),
        .PE_disable(PE_disable7_7), 
        .scan_en(scan_en), //same
        //output
        .weight_out(), 
        .activation_out(),
        .partial_sum_out(partial_sum_7),
        .PE_disable_out()
    );

endmodule
