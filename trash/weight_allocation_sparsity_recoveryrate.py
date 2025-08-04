import numpy as np
import matplotlib.pyplot as plt
import random
from collections import defaultdict

def strict_algorithm2_repair(array_size, sparsity, faulty_ratio, num_trials):
    results = []

    for _ in range(num_trials):
        # 建立稀疏權重矩陣
        density = 1 - sparsity / 100
        weight_matrix = np.random.choice([0, 1], size=(array_size, array_size), p=[1-density, density])

        # 產生隨機故障 PE
        total_pe = array_size * array_size
        num_faulty = int(total_pe * faulty_ratio)
        faulty_indices = random.sample(range(total_pe), num_faulty)
        faulty_pe = [(idx // array_size, idx % array_size) for idx in faulty_indices]

        # 將錯誤依照 row 群組
        faulty_rows = defaultdict(set)
        for r, c in faulty_pe:
            faulty_rows[r].add(c)

        num_rows = array_size
        recov_flag = [0] * num_rows      # 每個 faulty row 是否已修復
        allo_flag = [0] * num_rows       # 每個 weight row 是否已使用
        mapping_result = {}             # weight_row m -> faulty_row n

        for m in range(num_rows):  # 嘗試分配每個 weight_row m
            num_cov_PE = 0
            recov_target = -1

            # 找可對應最多錯誤 PE 的 faulty row
            for n, fault_cols in faulty_rows.items():
                if recov_flag[n] == 1:
                    continue
                if all(weight_matrix[m][c] == 0 for c in fault_cols):
                    if len(fault_cols) > num_cov_PE:
                        num_cov_PE = len(fault_cols)
                        recov_target = n

            if num_cov_PE != 0:
                mapping_result[recov_target] = m
                recov_flag[recov_target] = 1
                allo_flag[m] = 1
            else:
                # 無法修復時：分配給非錯誤行
                for k in range(num_rows):
                    if allo_flag[k] == 0 and k not in faulty_rows:
                        mapping_result[k] = m
                        allo_flag[m] = 1
                        break

        total_faulty_rows = len(faulty_rows)
        recovered_rows = sum(recov_flag)
        repair_rate = recovered_rows / total_faulty_rows if total_faulty_rows > 0 else 1.0
        results.append(repair_rate)

    return np.mean(results)


# ---------------------
# 主參數設定與實驗繪圖
# ---------------------
array_size = 256
sparsity_levels = list(range(10, 100, 10))
faulty_pe_rates = [0.03, 0.05, 0.07, 0.10]
num_trials = 2  # 論文使用 1000 次實驗平均
28
# 繪圖設定
styles = {
    0.03: {'label': 'Faulty_PE_rate 0.03 (20)', 'marker': 's', 'color': 'black'},
    0.05: {'label': 'Faulty_PE_rate 0.05 (33)', 'marker': '^', 'color': 'dimgray'},
    0.07: {'label': 'Faulty_PE_rate 0.07 (46)', 'marker': 'D', 'color': 'gray'},
    0.10: {'label': 'Faulty_PE_rate 0.10 (66)', 'marker': 'o', 'color': 'lightgray'},
}

plt.figure(figsize=(10, 6))

for rate in faulty_pe_rates:
    results = [strict_algorithm2_repair(array_size, sp, rate, num_trials) for sp in sparsity_levels]
    plt.plot(
        sparsity_levels,
        results,
        marker=styles[rate]['marker'],
        label=styles[rate]['label'],
        color=styles[rate]['color'],
        linewidth=2
    )

# ---------------------
# 美化圖表
# ---------------------
plt.xticks(sparsity_levels, [f'{s}%' for s in sparsity_levels], fontsize=12)
plt.yticks(
    np.arange(0.4, 1.1 + 0.01, 0.1),
    [f'{round(y * 100):.0f}%' for y in np.arange(0.4, 1.1 + 0.01, 0.1)],
    fontsize=12
)
plt.axvline(x=30, linestyle='--', color='black')  # 論文中的 sparsity=30% 虛線
plt.xlabel('Sparsity', fontsize=14)
plt.ylabel('Recovery rate', fontsize=14)
plt.title('Recovery Rate vs. Sparsity (STRAIT Algorithm 2)', fontsize=16)
plt.grid(True)
plt.legend(fontsize=12)
plt.ylim(0.4, 1.1)
plt.tight_layout()
plt.show()
