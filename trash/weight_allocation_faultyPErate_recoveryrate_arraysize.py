import numpy as np
import matplotlib.pyplot as plt
import random
from collections import defaultdict

def strict_algorithm2_repair(array_size, sparsity, faulty_ratio, num_trials):
    results = []
    for _ in range(num_trials):
        density = 1 - sparsity / 100
        weight_matrix = np.random.choice([0, 1], size=(array_size, array_size), p=[1-density, density])
        total_pe = array_size * array_size
        num_faulty = int(total_pe * faulty_ratio)
        faulty_indices = random.sample(range(total_pe), num_faulty)
        faulty_pe = [(idx // array_size, idx % array_size) for idx in faulty_indices]
        faulty_rows = defaultdict(set)
        for r, c in faulty_pe:
            faulty_rows[r].add(c)
        num_rows = array_size
        recov_flag = [0] * num_rows
        allo_flag = [0] * num_rows
        mapping_result = {}
        for m in range(num_rows):
            num_cov_PE = 0
            recov_target = -1
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
# Fig. 15 實驗：固定 sparsity，分析不同 array size 對 recovery rate 影響
# ---------------------
def run_fig15_array_size_experiment():
    array_sizes = [16, 32, 64, 128, 256]
    sparsity = 30
    faulty_pe_rates = [round(x, 3) for x in np.arange(0.001, 0.051, 0.001)]  # 0.1% ~ 1.0%
    # faulty_pe_rates = [round(x, 3) for x in np.arange(0.001, 0.011, 0.001)]  # 0.1% ~ 1.0%
    num_trials = 100  # 建議正式圖用 1000
    results = {}
    for size in array_sizes:
        recovery = []
        for rate in faulty_pe_rates:
            r = strict_algorithm2_repair(size, sparsity, rate, num_trials)
            recovery.append(r)
        results[size] = recovery
    return faulty_pe_rates, results

# 執行實驗並畫圖
x_vals, recovery_by_size = run_fig15_array_size_experiment()

plt.figure(figsize=(10, 6))
markers = {16: 'o', 32: 'D', 64: '^', 128: 's', 256: 'o'}
colors = {16: 'black', 32: 'dimgray', 64: 'gray', 128: 'darkgray', 256: 'lightgray'}
fillstyles = {16: 'full', 32: 'full', 64: 'none', 128: 'none', 256: 'none'}

for size in [16, 32, 64, 128, 256]:
    plt.plot(
        [f'{int(x*1000)/10}%' for x in x_vals],
        recovery_by_size[size],
        marker=markers[size],
        color=colors[size],
        label=f'{size}x{size}',
        markerfacecolor=colors[size] if fillstyles[size] == 'full' else 'white',
        markeredgecolor=colors[size],
        linewidth=2
    )

plt.xlabel('Faulty PE rate', fontsize=14)
plt.ylabel('Recovery rate', fontsize=14)
plt.title('Recovery Rate vs. Faulty PE Rate (Varying Array Size)', fontsize=16)
plt.ylim(0.0, 1.2)
plt.grid(True)
plt.legend(fontsize=12)
plt.tight_layout()
plt.show()
