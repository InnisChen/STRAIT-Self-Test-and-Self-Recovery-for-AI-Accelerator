# 模擬 TCAM 在 STRAIT Weight Allocation 中的運作，包含行地址
# 假設 5x5 脈動陣列，2 個故障行，3 個權重行

def convert_weight_to_binary(weight_row):
    """將權重行轉換為二進位向量：零權重 -> 1，非零權重 -> 0"""
    return [1 if w == 0 else 0 for w in weight_row]

def tcam_match(faulty_pe_vector, weight_binary):
    """模擬 TCAM 比較：檢查權重行的零權重位置是否覆蓋故障 PE 位置"""
    for i in range(len(faulty_pe_vector)):
        # TCAM 匹配邏輯：故障位置 (1) 必須對應零權重 (1)，非故障位置 (X) 不檢查
        if faulty_pe_vector[i] == 1 and weight_binary[i] != 1:
            return False
    return True

def count_faulty_pes(faulty_pe_vector):
    """計算故障 PE 的數量"""
    return sum(1 for bit in faulty_pe_vector if bit == 1)

# 模擬輸入數據
# Faulty PE Storage 包含行地址和故障 PE 向量
faulty_pe_storage = [
    {"row_address": 5, "vector": [1, 0, 1, 1, 0]},  # 脈動陣列第 5 行：3 個故障 PE (位置 0, 2, 3)
    {"row_address": 10, "vector": [0, 0, 0, 1, 0]}, # 脈動陣列第 10 行：1 個故障 PE (位置 3)
]

# 假設 3 個權重行
weight_rows = [
    [0, 5, 0, 0, 2],   # 權重行 0：零權重在位置 0, 2, 3
    [1, 0, 0, 0, 0],   # 權重行 1：零權重在位置 1, 2, 3, 4
    [3, 2, 1, 0, 4],   # 權重行 2：零權重在位置 3
]

# 模擬 TCAM Weight Allocation 過程
print("模擬 TCAM 在 Weight Allocation 中的運作（包含行地址）")
print("==============================================")
print("故障 PE 儲存 (TCAM):")
for entry in faulty_pe_storage:
    print(f"脈動陣列行 {entry['row_address']}: {entry['vector']} (故障 PE 數: {count_faulty_pes(entry['vector'])})")

print("\n權重行處理與 TCAM 比較:")
mapping_result = []  # 儲存映射結果 (權重行 -> 脈動陣列行)
recov_flag = {entry["row_address"]: 0 for entry in faulty_pe_storage}  # 記錄每個故障行是否已恢復

for weight_idx, weight_row in enumerate(weight_rows):
    # 將權重行轉換為二進位向量
    weight_binary = convert_weight_to_binary(weight_row)
    print(f"\n處理權重行 {weight_idx}: {weight_row}")
    print(f"轉換為二進位向量: {weight_binary}")

    # TCAM 並行比較
    best_match_row_address = -1
    max_faulty_pes = -1
    for entry in faulty_pe_storage:
        row_address = entry["row_address"]
        if recov_flag[row_address] == 0:  # 只檢查未恢復的故障行
            if tcam_match(entry["vector"], weight_binary):
                faulty_pe_count = count_faulty_pes(entry["vector"])
                print(f"  匹配脈動陣列行 {row_address} (故障 PE 數: {faulty_pe_count})")
                # 選擇匹配最多故障 PE 的行
                if faulty_pe_count > max_faulty_pes:
                    max_faulty_pes = faulty_pe_count
                    best_match_row_address = row_address

    # 分配權重行
    if best_match_row_address != -1:
        print(f"選擇分配: 權重行 {weight_idx} -> 脈動陣列行 {best_match_row_address}")
        mapping_result.append((weight_idx, best_match_row_address))
        recov_flag[best_match_row_address] = 1
    else:
        print(f"無匹配故障行，權重行 {weight_idx} 分配到非故障行 {weight_idx}")
        mapping_result.append((weight_idx, weight_idx))  # 分配到原始行或非故障行

# 檢查恢復結果
print("\n最終映射結果:")
for weight_idx, row_address in mapping_result:
    print(f"權重行 {weight_idx} -> 脈動陣列行 {row_address}")

if all(recov_flag[addr] == 1 for addr in recov_flag):
    print("\nWeight Allocation 成功：所有故障行已恢復！")
else:
    print("\nWeight Allocation 失敗：部分故障行未恢復！")