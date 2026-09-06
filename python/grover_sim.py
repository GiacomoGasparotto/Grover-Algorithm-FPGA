#!/usr/bin/env python3
import numpy as np
import time as time_module

# Define parameters for fixed-point representation
FP_WIDTH = 18           # fixed-point width in bits
FP_FRAC  = 15           # fractional bits
FP_SCALE = 2**FP_FRAC   # = 32768 -> 1.0 is represented as 32768

# Helpers
def to_fp(x: float) -> int:
    """Converts a float to a fixed-point integer (Q3.15, 18-bit signed)."""
    v = int(round(x * FP_SCALE))
    # Clamping to the 18-bit signed range: [-131072, 131071]
    v = max(-(2**(FP_WIDTH-1)), min(2**(FP_WIDTH-1)-1, v))
    return v

def from_fp(v: int) -> float:
    """Converts a fixed-point integer back to a float."""
    return v / FP_SCALE


# Matrix helpers
def hadamard(n: int) -> list:
    """
    Hadamard matrix
    """
    N = 2**n
    return [[to_fp((-1)**bin(i & j).count('1') / np.sqrt(N)) for j in range(N)] for i in range(N)]

def diffusion(n: int) -> list:
    """
    Grover diffusion operator   
    """
    N = 2**n
    return [[to_fp(2/N - (1 if i == j else 0)) for j in range(N)] for i in range(N)]

def matvec(M: list, v: list) -> list:
    """
    Matrix-vector product
    """
    N = len(v)
    out = []
    for i in range(N):
        acc = 0  # 48-bit accumulator 
        for j in range(N):
            prod = M[i][j] * v[j]  
            acc += prod         
        
        result = acc >> FP_FRAC
        
        result = max(-(2**(FP_WIDTH-1)), min(2**(FP_WIDTH-1)-1, result))
        out.append(result)
    return out


# Algorithm simulation
def grover_simulation(n_qubits: int, marked: int, k: int = None):
    """
    Fixed-point simulation of Grover's algorithm.
    Exactly replicates the logic of grover_top.vhd.
    """
    N = 2**n_qubits
    if k is None:
        k = int(np.floor(np.pi / 4 * np.sqrt(N)))

    H = hadamard(n_qubits)
    D = diffusion(n_qubits)

    # psi_0 = |00...0>
    psi = [0] * N
    psi[0] = to_fp(1.0)   # = 32768

    # APPLY_H / WAIT_H
    psi = matvec(H, psi)

    # Grover iterations: Oracle + Diffusion k times
    for _ in range(k):
        psi[marked] = -psi[marked]  # Oracle
        psi = matvec(D, psi)        # Diffusion

    # (Classical) measure: argmax |psi[i]|
    result = max(range(N), key=lambda i: abs(psi[i]))
    return result, psi


def time_sweep(n_min: int = 2, 
               n_max: int = 10, 
               reps: int = 3) -> list:
    """
    Measures Python execution time as n grows
    """
    rows = []
    for n in range(n_min, n_max + 1):
        N = 2**n
        k = int(np.floor(np.pi / 4 * np.sqrt(N)))
        marked = N // 2

        t0 = time_module.perf_counter()
        for _ in range(reps):
            grover_simulation(n, marked, k)
        t1 = time_module.perf_counter()

        elapsed_ms = (t1 - t0) / reps * 1000
        rows.append({'n': n, 'N': N, 'k': k, 'time_ms': elapsed_ms})
        print(f"n={n:>2}, N={N:>7}, k={k:>4}, time={elapsed_ms:>10.3f} ms")
    return rows


if __name__ == "__main__":

    n = 3 # Number of qubits
    marked = 3 # Marked state to search for
    N = 2**n # Hilbert space dimension
    k = int(np.floor(np.pi / 4 * np.sqrt(N))) # Optimal number of iterations

    print("Grover's algorithm simulation:")
    print(f"n={n} qubits,  N={N} states,  MARKED=|{marked}>,  k={k} iterations")
    print()

    result, psi = grover_simulation(n, marked, k)
    prob = [(x / FP_SCALE) ** 2 for x in psi]

    print(f"State found: |{result}>  {'OK' if result == marked else 'ERROR'}")
    print(f"P(|{marked}>) = {prob[marked]:.4f} = {prob[marked]*100:.2f}%")

    print(f"\nFinal state vector:")
    print(f"{'State':>7} {'Amp (int)':>12} {'P':>10}")
    
    for i in range(N):
        flag = " <- MARKED" if i == marked else ""
        print(f"|{i}> {psi[i]:>12d} {prob[i]:>10.4f}{flag}")

    print("\nTime sweep:")
    time_sweep(n_min=2, n_max=10, reps=3)