# STRAIT

## eNVM

## bisr_weight_allocation

### faulty_pe_storage
### mapping_table
### row_weight_storage


## Systolic_array
### STRAIT_PE

## hybrid_bist
### Comparator
### Memory_data_generator

### MBIST
MBIST 測試的部分完全錯誤  

Cycle 1:  MBIST_WRITE  → Write(addr0, pattern0)  
Cycle 2:  MBIST_CHECK  → Write(addr1, pattern0) + Read(addr0) & Compare(pattern0)  
Cycle 3:  MBIST_CHECK  → Write(addr2, pattern0) + Read(addr1) & Compare(pattern0)  
...  
Cycle 8:  MBIST_CHECK  → Write(addr7, pattern0) + Read(addr6) & Compare(pattern0)  
Cycle 9:  MBIST_CHECK  → Write(addr0, pattern1) + Read(addr7) & Compare(pattern0)  
...  
  
以此類推直到全部的pattern 都結束，中途比較結果如果有發生錯誤，就會直接停止測試，到FAIL 狀態  

### LBIST

#### SA Test

<!-- | 測試類型 | Weight | Activation | Partial_Sum_In | Answer |
|----------|--------|------------|----------------|--------|
| SA (test_type=0) | Weight | Activation | Partial_Sum_In | Expected_Answer | -->

#### TD Test

<!-- | 階段 | Weight | Activation | Partial_Sum_In | Answer |
|------|--------|------------|----------------|--------|
| Launch (TD_answer_choose=0) | W2 | A2 | P1 | Launch_Answer |
| Capture (TD_answer_choose=1) | W2 | A1 | P2 | Capture_Answer | -->

## Diagnostic_loop_chains

## Accumulator

## Activation_mem

## Buffer
