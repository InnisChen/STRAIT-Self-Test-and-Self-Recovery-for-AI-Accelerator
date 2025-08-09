import os
import re

# 修改路徑成主資料夾
base_path = r"./DC"

# 初始化結果儲存
cell_area_result = {}
total_area_result = {}

# 正規表示式
cell_area_pattern = re.compile(r"Total cell area\s*:\s*([0-9.]+)")
total_area_pattern = re.compile(r"Total area\s*:\s*([0-9.]+)")

# 逐一檢查子資料夾
for folder in os.listdir(base_path):
    folder_path = os.path.join(base_path, folder)
    if os.path.isdir(folder_path):
        log_path = os.path.join(folder_path, "area.log")
        cell_area = "none"
        total_area = "none"
        
        if os.path.exists(log_path):
            with open(log_path, "r", encoding="utf-8") as f:
                content = f.read()
                cell_match = cell_area_pattern.search(content)
                total_match = total_area_pattern.search(content)

                if cell_match:
                    cell_area = cell_match.group(1)
                if total_match:
                    total_area = total_match.group(1)

        cell_area_result[folder] = cell_area
        total_area_result[folder] = total_area

# 輸出結果
print("\nTotal cell area:")
for folder in sorted(cell_area_result.keys()):
    print(f"{folder:<15}: {cell_area_result[folder]}")

print("\nTotal area:")
for folder in sorted(total_area_result.keys()):
    print(f"{folder:<15}: {total_area_result[folder]}")
# import os
# import re
# from tabulate import tabulate

# # ✅ 設定資料夾路徑
# base_path = r"C:/Project/STRAIT/DC"

# # 表格資料：[folder_name, total_cell_area, total_area]
# rows = []

# # 正規表示式
# cell_area_pattern = re.compile(r"Total cell area\s*:\s*([0-9.]+)")
# total_area_pattern = re.compile(r"Total area\s*:\s*([0-9.]+)")

# # 掃描所有子資料夾
# for folder in sorted(os.listdir(base_path)):
#     folder_path = os.path.join(base_path, folder)
#     if os.path.isdir(folder_path):
#         log_path = os.path.join(folder_path, "area.log")
#         cell_area = "none"
#         total_area = "none"
        
#         if os.path.exists(log_path):
#             with open(log_path, "r", encoding="utf-8") as f:
#                 content = f.read()
#                 cell_match = cell_area_pattern.search(content)
#                 total_match = total_area_pattern.search(content)
#                 if cell_match:
#                     cell_area = cell_match.group(1)  # 不進行格式化
#                 if total_match:
#                     total_area = total_match.group(1)  # 不進行格式化
        
#         rows.append([folder, cell_area, total_area])

# # 顯示成表格，讓數字欄右對齊，文字欄靠左
# headers = ["Folder", "Total cell area", "Total area"]
# align = ("left", "right", "right")

# print(tabulate(rows, headers=headers, tablefmt="github", colalign=align))
