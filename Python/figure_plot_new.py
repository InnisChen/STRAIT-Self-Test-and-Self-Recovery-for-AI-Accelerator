#!/usr/bin/env python3
"""
STRAIT Enhanced Algorithm Implementation - Complete Figure Generation
Enhanced Algorithm with Multiple Rescue Rows for AI Accelerator Fault Recovery
"""

import numpy as np
import matplotlib.pyplot as plt
import random
from typing import List, Tuple, Dict

# ==================== CONFIGURATION ====================
# Algorithm Configuration
RECOVERY_MODE = "original"  # Options: "original", "enhanced"
NUM_RESCUE_ROWS = 3        # Number of rescue rows to add (1, 2, 3, etc.)
ITERATIONS = 1000           # Number of iterations per experiment

# Figure Generation Selection
GENERATE_FIG13 = 0      # Recovery rate vs Sparsity
GENERATE_FIG14 = 0      # Recovery rate vs Fault rate  
GENERATE_FIG15 = True      # Recovery rate vs Array size

# ==================== CORE IMPLEMENTATION ====================

class StraitEnhancedRecovery:
    def __init__(self, array_size: int = 256, enable_rescue_row: bool = True):
        self.array_size = array_size
        self.enable_rescue_row = enable_rescue_row
        
    def generate_weight_matrix(self, sparsity: float) -> np.ndarray:
        """Generate weight matrix with given sparsity"""
        weights = np.random.randn(self.array_size, self.array_size)
        zero_mask = np.random.random((self.array_size, self.array_size)) < sparsity
        weights[zero_mask] = 0
        return weights
    
    def inject_faults(self, fault_rate: float) -> Tuple[List[int], List[List[int]], List[int]]:
        """Inject faults with given fault rate"""
        total_pes = self.array_size * self.array_size
        total_faults = int(total_pes * fault_rate / 100)
        
        if total_faults == 0:
            return [], [], []
        
        # Generate unique fault positions
        faulty_positions = set()
        attempts = 0
        while len(faulty_positions) < total_faults and attempts < total_faults * 100:
            row = random.randint(0, self.array_size - 1)
            col = random.randint(0, self.array_size - 1)
            faulty_positions.add((row, col))
            attempts += 1
        
        # Group faults by row
        faulty_rows = {}
        for row, col in faulty_positions:
            if row not in faulty_rows:
                faulty_rows[row] = []
            faulty_rows[row].append(col)
        
        f_row_add = sorted(list(faulty_rows.keys()))
        faulty_position = [faulty_rows[row] for row in f_row_add]
        f_count = [len(positions) for positions in faulty_position]
        
        return f_row_add, faulty_position, f_count
    
    def get_zero_weight_positions(self, weights: np.ndarray) -> List[List[int]]:
        """Get zero weight positions for each row"""
        return [np.where(weights[row] == 0)[0].tolist() for row in range(self.array_size)]
    
    def positions_match(self, faulty_pos: List[int], zero_weight_pos: List[int]) -> bool:
        """Check if all faulty positions can be covered by zero weight positions"""
        return all(pos in zero_weight_pos for pos in faulty_pos)
    
    def original_algorithm_2(self, faulty_position: List[List[int]], 
                           f_count: List[int], 
                           z_weight_position: List[List[int]]) -> Tuple[bool, List[int]]:
        """Original Algorithm 2 with unrecovered rows tracking"""
        num_f_row = len(faulty_position)
        if num_f_row == 0:
            return True, []
        
        allo_flag = [0] * self.array_size
        recov_flag = [0] * num_f_row
        
        for m in range(self.array_size):
            num_cov_PE = 0
            recov_target = -1
            
            for n in range(num_f_row):
                if recov_flag[n] == 0:
                    if self.positions_match(faulty_position[n], z_weight_position[m]):
                        if f_count[n] > num_cov_PE:
                            recov_target = n
                            num_cov_PE = f_count[n]
            
            if num_cov_PE != 0:
                recov_target_add = recov_target % self.array_size
                allo_flag[recov_target_add] = 1
                recov_flag[recov_target] = 1
            else:
                for k in range(self.array_size):
                    if allo_flag[k] == 0:
                        allo_flag[k] = 1
                        break
        
        unrecovered_rows = [i for i, flag in enumerate(recov_flag) if flag == 0]
        return len(unrecovered_rows) == 0, unrecovered_rows
    
    def rescue_with_multiple_rows(self, unrecovered_rows: List[int], 
                                faulty_position: List[List[int]], 
                                f_count: List[int],
                                z_weight_position: List[List[int]],
                                fault_rate: float) -> bool:
        """Multiple rescue rows mechanism"""
        if not unrecovered_rows:
            return True
        
        rescued_rows = set()
        
        for _ in range(NUM_RESCUE_ROWS):
            # Generate fault pattern for this rescue row
            total_faults_in_row = int(self.array_size * fault_rate / 100)
            if total_faults_in_row > 0:
                rescue_row_faults = random.sample(range(self.array_size), 
                                                min(total_faults_in_row, self.array_size))
            else:
                rescue_row_faults = []
            
            working_pes = [i for i in range(self.array_size) if i not in rescue_row_faults]
            
            # Find best match among remaining unrecovered rows
            best_match_idx = -1
            max_fault_count = 0
            
            for row_idx in unrecovered_rows:
                if row_idx in rescued_rows:
                    continue
                    
                faulty_pos = faulty_position[row_idx]
                
                for weight_row_idx in range(self.array_size):
                    zero_positions = z_weight_position[weight_row_idx]
                    
                    if self.positions_match(faulty_pos, zero_positions):
                        non_zero_positions = [i for i in range(self.array_size) if i not in zero_positions]
                        
                        if self.positions_match(non_zero_positions, working_pes):
                            if f_count[row_idx] > max_fault_count:
                                best_match_idx = row_idx
                                max_fault_count = f_count[row_idx]
                            break
            
            if best_match_idx != -1:
                rescued_rows.add(best_match_idx)
        
        # SUCCESS only if ALL unrecovered rows are rescued
        return len(rescued_rows) == len(unrecovered_rows)
    
    def enhanced_weight_allocation_algorithm(self, faulty_position: List[List[int]], 
                                           f_count: List[int], 
                                           z_weight_position: List[List[int]],
                                           fault_rate: float) -> bool:
        """Enhanced algorithm with rescue mechanism"""
        # Try original Algorithm 2
        original_success, unrecovered_rows = self.original_algorithm_2(
            faulty_position, f_count, z_weight_position)
        
        if original_success:
            return True
        
        # Try rescue mechanism if enabled
        if self.enable_rescue_row and RECOVERY_MODE == "enhanced":
            return self.rescue_with_multiple_rows(
                unrecovered_rows, faulty_position, f_count, z_weight_position, fault_rate)
        
        return False
    
    def run_single_experiment(self, sparsity: float, fault_rate: float) -> bool:
        """Run a single recovery experiment"""
        weights = self.generate_weight_matrix(sparsity)
        z_weight_position = self.get_zero_weight_positions(weights)
        f_row_add, faulty_position, f_count = self.inject_faults(fault_rate)
        
        if len(faulty_position) > 0:
            if RECOVERY_MODE == "original":
                success, _ = self.original_algorithm_2(faulty_position, f_count, z_weight_position)
                return success
            else:
                return self.enhanced_weight_allocation_algorithm(
                    faulty_position, f_count, z_weight_position, fault_rate)
        return True
    
    def run_experiments(self, sparsity_range: List[float], 
                       fault_rates: List[float]) -> Dict[float, List[float]]:
        """Run experiments for given sparsity and fault rate ranges"""
        results = {}
        
        for sparsity in sparsity_range:
            recovery_rates = []
            for fault_rate in fault_rates:
                successful_recoveries = 0
                for _ in range(ITERATIONS):
                    if self.run_single_experiment(sparsity, fault_rate):
                        successful_recoveries += 1
                recovery_rate = (successful_recoveries / ITERATIONS) * 100
                recovery_rates.append(recovery_rate)
            results[sparsity] = recovery_rates
            
            # Display progress for each sparsity level
            rate_strs = [f"{r:5.1f}%" for r in recovery_rates]
            print(f"Sparsity {sparsity*100:2.0f}%: {rate_strs}")
            
        return results

# ==================== FIGURE GENERATION ====================

def create_plot_style():
    """Common plot styling"""
    plt.grid(True, alpha=0.5, linestyle='-', linewidth=0.5, color='gray')
    plt.legend(fontsize=11, loc='lower right', frameon=True, fancybox=False, 
              edgecolor='black', facecolor='white')
    
    ax = plt.gca()
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.spines['left'].set_linewidth(1)
    ax.spines['bottom'].set_linewidth(1)

def generate_figure_13():
    """Figure 13: Recovery Rate vs Sparsity"""
    strait = StraitEnhancedRecovery(array_size=256, enable_rescue_row=True)
    
    sparsity_range = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9]
    fault_rates = [0.03, 0.05, 0.07, 0.1]
    
    print("Generating Figure 13: Recovery Rate vs Sparsity")
    results = strait.run_experiments(sparsity_range, fault_rates)
    
    plt.figure(figsize=(10, 6))
    colors = ['black', 'darkgray', 'gray', 'lightgray']
    markers = ['s', '^', 'd', 'o']
    fault_numbers = [20, 33, 46, 66]
    
    for i, fault_rate in enumerate(fault_rates):
        recovery_rates = [results[sparsity][i] for sparsity in sparsity_range]
        plt.plot([s*100 for s in sparsity_range], recovery_rates, 
                color=colors[i], marker=markers[i], linestyle='-',
                label=f'Faulty_PE_rate {fault_rate:.2f} ({fault_numbers[i]})', 
                markersize=8, linewidth=2, 
                markerfacecolor='white', markeredgewidth=1.5, markeredgecolor=colors[i])
    
    plt.axvline(x=30, color='black', linestyle='--', linewidth=1.5, alpha=0.8)
    plt.xlabel('Sparsity', fontsize=14)
    plt.ylabel('Recovery rate', fontsize=14)
    
    title = "Figure 13: Recovery Rate vs Sparsity"
    if RECOVERY_MODE == "enhanced":
        title += f" (Enhanced with {NUM_RESCUE_ROWS} Rescue Row{'s' if NUM_RESCUE_ROWS > 1 else ''})"
    plt.title(title, fontsize=16, fontweight='bold', pad=15)
    
    plt.xlim(10, 90)
    plt.ylim(40, 110)
    plt.xticks([10, 20, 30, 40, 50, 60, 70, 80, 90], 
              ['10%', '20%', '30%', '40%', '50%', '60%', '70%', '80%', '90%'])
    plt.yticks([40, 50, 60, 70, 80, 90, 100, 110], 
              ['40%', '50%', '60%', '70%', '80%', '90%', '100%', '110%'])
    
    create_plot_style()
    plt.tight_layout()
    plt.show(block=False)
    plt.pause(0.1)

def generate_figure_14():
    """Figure 14: Recovery Rate vs Fault Rate"""
    strait = StraitEnhancedRecovery(array_size=256, enable_rescue_row=True)
    
    sparsity_levels = [0.3, 0.4, 0.5]
    fault_rates = [0.1, 0.2, 0.3, 0.4, 0.5]
    
    print("Generating Figure 14: Recovery Rate vs Fault Rate")
    results = {}
    for sparsity in sparsity_levels:
        recovery_rates = []
        for fault_rate in fault_rates:
            successful_recoveries = 0
            for _ in range(ITERATIONS):
                if strait.run_single_experiment(sparsity, fault_rate):
                    successful_recoveries += 1
            recovery_rate = (successful_recoveries / ITERATIONS) * 100
            recovery_rates.append(recovery_rate)
        results[sparsity] = recovery_rates
        
        # Display progress
        rate_strs = [f"{r:5.1f}%" for r in recovery_rates]
        print(f"Sparsity {sparsity*100:2.0f}%: {rate_strs}")
    
    # Create figure name based on mode and rescue rows
    if RECOVERY_MODE == "enhanced":
        figure_name = f"Figure 14 - Enhanced {NUM_RESCUE_ROWS}row{'s' if NUM_RESCUE_ROWS > 1 else ''}"
        save_name = f"figure14_enhanced_{NUM_RESCUE_ROWS}row"
    else:
        figure_name = "Figure 14 - Original"
        save_name = "figure14_original"
    
    plt.figure(figsize=(10, 6))
    colors = ['lightgray', 'gray', 'black']
    markers = ['s', 'o', '^']
    
    for i, sparsity in enumerate(sparsity_levels):
        recovery_rates = results[sparsity]
        plt.plot(fault_rates, recovery_rates, 
                color=colors[i], marker=markers[i], linestyle='-',
                label=f'Sparsity {int(sparsity*100)}', 
                markersize=10, linewidth=2.5, 
                markerfacecolor='white', markeredgewidth=2, markeredgecolor=colors[i])
    
    plt.xlabel('Faulty PE rate', fontsize=14)
    plt.ylabel('Recovery rate', fontsize=14)
    
    # Use the new naming scheme
    plt.title(figure_name, fontsize=16, fontweight='bold', pad=15)
    
    plt.xlim(0.1, 0.5)
    plt.ylim(40, 110)
    plt.xticks([0.1, 0.2, 0.3, 0.4, 0.5],
              ['0.1%', '0.2%', '0.3%', '0.4%', '0.5%'])
    plt.yticks([40, 50, 60, 70, 80, 90, 100, 110], 
              ['40%', '50%', '60%', '70%', '80%', '90%', '100%', '110%'])
    
    create_plot_style()
    plt.tight_layout()
    
    # Set window title - fix for Figure 13
    fig = plt.gcf()
    fig.canvas.manager.set_window_title(save_name)
    
    plt.show(block=False)
    plt.pause(0.1)

def generate_figure_15():
    """Figure 15: Recovery Rate vs Array Size"""
    array_sizes = [16, 32, 64, 128, 256]
    fault_rates = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]
    sparsity = 0.5
    
    print("Generating Figure 15: Recovery Rate vs Array Size")
    results = {}
    for array_size in array_sizes:
        strait = StraitEnhancedRecovery(array_size=array_size, enable_rescue_row=True)
        recovery_rates = []
        for fault_rate in fault_rates:
            successful_recoveries = 0
            for _ in range(ITERATIONS):
                if strait.run_single_experiment(sparsity, fault_rate):
                    successful_recoveries += 1
            recovery_rate = (successful_recoveries / ITERATIONS) * 100
            recovery_rates.append(recovery_rate)
        results[array_size] = recovery_rates
        
        # Display progress
        rate_strs = [f"{r:5.1f}%" for r in recovery_rates]
        print(f"Array {array_size:3d}x{array_size:3d}: {rate_strs}")
    
    # Create figure name based on mode and rescue rows
    if RECOVERY_MODE == "enhanced":
        figure_name = f"Figure 15 - Enhanced {NUM_RESCUE_ROWS}row{'s' if NUM_RESCUE_ROWS > 1 else ''}"
        save_name = f"figure15_enhanced_{NUM_RESCUE_ROWS}row"
    else:
        figure_name = "Figure 15 - Original"
        save_name = "figure15_original"
    
    plt.figure(figsize=(12, 8))
    colors = ['black', 'darkgray', 'gray', 'lightgray', 'silver']
    markers = ['o', 'd', '^', 's', 'o']
    
    for i, array_size in enumerate(array_sizes):
        recovery_rates = results[array_size]
        plt.plot(fault_rates, recovery_rates, 
                color=colors[i], marker=markers[i], linestyle='-',
                label=f'{array_size}x{array_size}', 
                markersize=8, linewidth=2.5, 
                markerfacecolor='white', markeredgewidth=2, markeredgecolor=colors[i])
    
    plt.xlabel('Faulty PE rate', fontsize=14)
    plt.ylabel('Recovery rate', fontsize=14)
    
    # Use the new naming scheme
    plt.title(figure_name, fontsize=16, fontweight='bold', pad=15)
    
    # Dynamic x-axis configuration
    plt.xlim(fault_rates[0] - 0.05, fault_rates[-1] + 0.05)
    plt.ylim(0, 120)
    
    x_ticks = fault_rates
    x_labels = [f'{rate:.1f}%' for rate in fault_rates]
    plt.xticks(x_ticks, x_labels, fontsize=12)
    plt.yticks([0, 20, 40, 60, 80, 100, 120], 
              ['0%', '20%', '40%', '60%', '80%', '100%', '120%'])
    
    create_plot_style()
    plt.tight_layout()
    
    # Set window title
    fig = plt.gcf()
    fig.canvas.manager.set_window_title(save_name)
    
    plt.show(block=False)
    plt.pause(0.1)

# ==================== MAIN EXECUTION ====================

if __name__ == "__main__":
    print("STRAIT Enhanced Algorithm - Complete Figure Generation")
    print("=" * 60)
    print(f"Configuration:")
    print(f"  • Algorithm mode: {RECOVERY_MODE}")
    print(f"  • Rescue rows: {NUM_RESCUE_ROWS}")
    print(f"  • Iterations: {ITERATIONS}")
    print("=" * 60)
    
    # Set random seed for reproducibility
    np.random.seed(42)
    random.seed(42)
    
    # Generate selected figures
    figures_generated = 0
    
    if GENERATE_FIG13:
        generate_figure_13()
        figures_generated += 1
    
    if GENERATE_FIG14:
        generate_figure_14()
        figures_generated += 1
    
    if GENERATE_FIG15:
        generate_figure_15()
        figures_generated += 1
    
    print(f"\nCompleted! Generated {figures_generated} figure{'s' if figures_generated != 1 else ''}.")
    print(f"Current mode: {RECOVERY_MODE} with {NUM_RESCUE_ROWS} rescue row{'s' if NUM_RESCUE_ROWS > 1 else ''}")
    
    # Keep plots open
    input("Press Enter to close all plots and exit...")