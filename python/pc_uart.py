#!/usr/bin/env python3
import sys
import time
import serial
import serial.tools.list_ports

# Define variables
BAUD_RATE = 115200
N_QUBITS = 3
N = 2**N_QUBITS  # Hilbert space dimension

# Helper functions
def find_port():
    """
    Try to find automatically the serial port of the Arty A7 (FTDI chip).
    If it cannot find it, it lists the available ports.
    """
    ports = list(serial.tools.list_ports.comports())
    for p in ports:
        manufacturer = p.manufacturer if p.manufacturer else ""
        description = p.description if p.description else ""
        descr = (manufacturer + " " + description).upper()
        if "FTDI" in descr or "FT2232" in descr or "USB SERIAL" in descr:
            return p.device

    print("Did not find the Arty A7 serial port automatically.")
    print("Available serial ports:")
    for p in ports:
        print(f"{p.device}  -  {p.description}")
    return None


def grover_hw(port: str,
              marked: int,
              ser: "serial.Serial" = None,
              timeout: float = 2.0) -> tuple:
    """
    Send the marked index to the FPGA and return (result, time_seconds).
    """
    if not (0 <= marked < N):
        raise ValueError(f"Marked index must be between 0 and {N-1}")

    def _trans(conn):
        conn.reset_input_buffer()
        t0 = time.perf_counter()
        conn.write(bytes([marked]))
        response = conn.read(1)
        t1 = time.perf_counter()
        if len(response) == 0:
            raise TimeoutError("ERROR: No response from the FPGA within the timeout.")
        return response[0], (t1 - t0)

    if ser is not None:
        return _trans(ser)

    with serial.Serial(port, BAUD_RATE, timeout=timeout) as conn:
        time.sleep(0.1)  # stabilize the connection
        return _trans(conn)


def main():
    if len(sys.argv) > 1:
        port = sys.argv[1]
    else:
        port = find_port()
        if port is None:
            print("\nSpecify the port manually:")
            return

    print(f"Using port: {port}\n")

    # Marked state to search for
    marked = 3
    result, elapsed_time = grover_hw(port, marked)

    print(f"Searched: |{marked}>   Found: |{result}>")
    print(f"Round-trip time (Python -> UART -> FPGA -> UART -> Python): {elapsed_time*1000:.3f} ms")

    print("\n")
    print("Test on all possible states")
    times = []
    correct_count = 0
    with serial.Serial(port, BAUD_RATE, timeout=2.0) as ser:
        time.sleep(0.1)
        for m in range(N):
            result, elapsed_time = grover_hw(port, m, ser=ser)
            times.append(elapsed_time)
            ok = result == m
            correct_count += int(ok)
            print(f"|{m}> -> |{result}>  {'OK' if ok else 'ERROR'} ({elapsed_time*1000:.3f} ms)")

    print(f"\nAccuracy: {correct_count}/{N}")
    print(f"Average time: {sum(times)/len(times)*1000:.3f} ms")
    print(f"Minimum time: {min(times)*1000:.3f} ms")
    print(f"Maximum time: {max(times)*1000:.3f} ms")

if __name__ == "__main__":
    main()