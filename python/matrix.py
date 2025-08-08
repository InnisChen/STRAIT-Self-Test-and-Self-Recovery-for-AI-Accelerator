import numpy as np

def read_hex_file(filename):
    """讀取十六進制檔案並轉換為矩陣"""
    matrix = []
    current_row = []
    
    with open(filename, 'r') as file:
        for line in file:
            line = line.strip()
            
            # 跳過註解行和空行
            if line.startswith('//') or not line:
                # 如果遇到新的行註解且當前行有數據，則保存當前行
                if current_row and line.startswith('//'):
                    matrix.append(current_row)
                    current_row = []
                continue
            
            # 將十六進制轉換為十進制
            if line.startswith('0x'):
                hex_value = int(line, 16)
                current_row.append(hex_value)
    
    # 添加最後一行
    if current_row:
        matrix.append(current_row)
    
    return np.array(matrix)

def main():
    try:
        # 讀取兩個檔案
        print("讀取 weight.dat...")
        weight_matrix = read_hex_file('./input_data/weight.dat')
        
        print("讀取 activation.dat...")
        activation_matrix = read_hex_file('./input_data/activation.dat')
        
        print(f"Weight 矩陣形狀: {weight_matrix.shape}")
        print(f"Activation 矩陣形狀: {activation_matrix.shape}")
        
        print("\nWeight 矩陣:")
        print(weight_matrix)
        
        print("\nActivation 矩陣:")
        print(activation_matrix)
        
        # 計算矩陣乘法: weight * activation
        result = np.dot(weight_matrix, activation_matrix)
        
        print(f"\n結果矩陣形狀: {result.shape}")
        print("\n計算結果 (weight * activation):")
        print(result)
        
        # 將結果保存到檔案
        np.savetxt('result.txt', result, fmt='%d')
        print("\n結果已保存到 result.txt")
        
    except FileNotFoundError as e:
        print(f"檔案未找到: {e}")
    except Exception as e:
        print(f"發生錯誤: {e}")

if __name__ == "__main__":
    main()