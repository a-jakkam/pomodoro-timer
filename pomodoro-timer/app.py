import serial
import threading
from flask import Flask, render_template, jsonify

app = Flask(__name__)

# --- CONFIGURATION ---
# Check Device Manager to confirm your COM port
SERIAL_PORT = 'COM5' 
BAUD_RATE = 115200

# Global state to store parsed FPGA data
fpga_status = {
    "timer": "25:00",
    "phase": "0",
    "sessions": 0,
    "pauses": 0,
    "new_data": False
}

def uart_listener():
    """Thread to parse: MM:SS,Phase,Sessions,PauseHex"""
    try:
        ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=1)
        print(f"Connected to FPGA on {SERIAL_PORT}")
        while True:
            line = ser.readline().decode(errors="ignore").strip()
            if line and "," in line:
                parts = line.split(',')
                if len(parts) == 4:
                    fpga_status["timer"] = parts[0]
                    fpga_status["phase"] = parts[1]
                    fpga_status["sessions"] = int(parts[2])
                    # Convert hex pause count (e.g., '0A') to integer
                    fpga_status["pauses"] = int(parts[3], 16)
                    fpga_status["new_data"] = True
    except Exception as e:
        print(f"UART Error: {e}")

# Start the hardware listener in the background
threading.Thread(target=uart_listener, daemon=True).start()

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/update')
def update():
    """Frontend calls this to get the latest hardware state"""
    data = {
        "sessions": fpga_status["sessions"],
        "pauses": fpga_status["pauses"],
        "phase": fpga_status["phase"],
        "timer": fpga_status["timer"] # Optional if you want to show it later
    }
    return jsonify(data)

if __name__ == '__main__':
    app.run(debug=True, port=5000)