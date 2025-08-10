# outside
input clk,
input rst_n,
input test_mode,
input BIST_mode,
input activation_valid // 送給bist開始計數地址，再送給activation_mem當寫入地址
output MBIST_test_result,
output LBIST_test_result,

# envm
output test_type, // 0: MBIST, 1: LBIST
output test_counter_bist_envm
output detection_en_bist_envm
output detection_addr_bist_envm
input Scan_data_weight_envm_bist
input Scan_data_activation_envm_bist
input Scan_data_answer_envm_bist


# bisr
envm_wr_en_bist_bisr
allocation_start_bist_bisr
read_addr_bist_bisr


# weight_partialsum_buffer
weight_in_test_flat_bist_buffer
partial_sum_test_flat_bist_buffer


# systolic
scan_en_bist_array


# accumulator
wr_en_bist_accumulator
wr_addr_bist_accumulator
rd_addr_bist_accumulator


# activation_mem
wr_en_bist_activationmem
wr_addr_bist_activationmem

# activation_buffer
activation_in_test_flat_bist_buffer


# DLCs
start_en_bist_dlc
col_inputs_bist_dlc
