# from flask import Flask, render_template, jsonify, request
# import threading
# import time
# import json
# import os
# import serial

# app = Flask(__name__)

# # ---------------------------------------------------------
# # GLOBAL STATE
# # ---------------------------------------------------------
# state = {
#     "timer": "25:00",
#     "phase": "1",
#     "pauses": 0,
#     "display_cycles": 0,      
#     "last_recorded_eff": 100, 
#     "highest_fpga_cycle": 0   
# }

# DATA_FILE = "data.json"

# def load_data():
#     if not os.path.exists(DATA_FILE):
#         return {"history": []}
#     try:
#         with open(DATA_FILE, "r") as f:
#             return json.load(f)
#     except:
#         return {"history": []}

# def save_data(data):
#     with open(DATA_FILE, "w") as f:
#         json.dump(data, f, indent=4)

# user_data = load_data()

# # ---------------------------------------------------------
# # UART PARSER
# # ---------------------------------------------------------
# def parse_uart(line: str):
#     global state, user_data
#     try:
#         # Expected: MM:SS, PHASE, CYCLE, PAUSES
#         parts = line.split(",")
#         if len(parts) < 4: return
        
#         phase_str = parts[1].upper()
#         current_fpga_digit = int(parts[2])
#         pauses_hex = parts[3]

#         state["timer"] = parts[0]
#         state["phase"] = phase_str
#         state["pauses"] = int(pauses_hex, 16)

#         # TRIGGER: Only update when the board moves to a NEW cycle
#         if current_fpga_digit > state["highest_fpga_cycle"]:
#             # 1. Calculate and Save Efficiency for the completed session
#             final_eff = max(0, 100 - (state["pauses"] * 10))
#             state["last_recorded_eff"] = final_eff
            
#             # 2. Update Display Counters
#             state["display_cycles"] = current_fpga_digit
#             state["highest_fpga_cycle"] = current_fpga_digit
            
#             # 3. Log to Data File
#             user_data.setdefault("history", []).append({
#                 "time": time.strftime("%H:%M"),
#                 "efficiency": final_eff
#             })
#             save_data(user_data)
            
#             # 4. Clear temporary pauses for the next loop
#             state["pauses"] = 0

#     except Exception as e:
#         print(f"UART Error: {e}")

# def uart_listener():
#     try:
#         ser = serial.Serial('COM4', 115200, timeout=1) # Verify your COM port
#         while True:
#             raw = ser.readline().decode(errors="ignore").strip()
#             if raw: parse_uart(raw)
#     except Exception as e:
#         print(f"Serial Error: {e}")

# # ---------------------------------------------------------
# # ROUTES
# # ---------------------------------------------------------
# @app.route('/')
# def index():
#     return render_template('index.html')

# @app.route('/update')
# def update():
#     # If studying (Phase 1), show live calculation.
#     # If on break/alarm (Phase 2/A), show the 'locked' result from the session.
#     if state["phase"] == "1":
#         display_eff = max(0, 100 - (state["pauses"] * 10))
#     else:
#         display_eff = state["last_recorded_eff"]
    
#     # SAFETY: Force to 100 if something went wrong to avoid NaN
#     if display_eff is None: display_eff = 100

#     return jsonify({
#         "timer": state["timer"],
#         "phase": state["phase"],
#         "sessions": state["display_cycles"],
#         "efficiency": int(display_eff),
#         "weekData": [d.get("efficiency", 100) for d in user_data.get("history", [])[-7:]]
#     })

# @app.route('/log', methods=['POST'])
# def log_pauses():
#     data = request.get_json()
#     state["pauses"] += int(data.get("pauses", 0))
#     return jsonify({"status": "ok"})

# @app.route('/reset', methods=['POST'])
# def reset():
#     global state, user_data
#     state["display_cycles"] = 0
#     state["highest_fpga_cycle"] = 0
#     state["pauses"] = 0
#     state["last_recorded_eff"] = 100
#     user_data["history"] = []
#     save_data(user_data)
#     return jsonify({"status": "ok"})

# if __name__ == '__main__':
#     threading.Thread(target=uart_listener, daemon=True).start()
#     app.run(debug=True, port=5000, use_reloader=False)
from flask import Flask, render_template, jsonify, request
import threading
import time
import json
import os
import serial

app = Flask(__name__)

# ---------------------------------------------------------
# GLOBAL STATE
# ---------------------------------------------------------
state = {
    "timer": "25:00",
    "phase": "1",                # 1=study, 2=break, A=alarm
    "pauses": 0,
    "display_cycles": 0,         # Cycles shown on UI
    "last_recorded_eff": 100,    # Efficiency of last completed session
    "highest_fpga_cycle": 0      # Track highest FPGA cycle to avoid double counting
}

DATA_FILE = "data.json"

# ---------------------------------------------------------
# LOAD / SAVE DATA
# ---------------------------------------------------------
def load_data():
    if not os.path.exists(DATA_FILE):
        return {"history": []}
    try:
        with open(DATA_FILE, "r") as f:
            return json.load(f)
    except:
        return {"history": []}

def save_data(data):
    with open(DATA_FILE, "w") as f:
        json.dump(data, f, indent=4)

user_data = load_data()

# ---------------------------------------------------------
# UART PARSER
# ---------------------------------------------------------
def parse_uart(line: str):
    global state, user_data
    try:
        # Expected format: MM:SS, PHASE, CYCLE, PAUSES
        parts = line.strip().split(",")
        if len(parts) < 4:
            return
        
        phase_str = parts[1].upper()
        current_fpga_digit = int(parts[2])
        pauses_hex = parts[3]

        # Update global state
        state["timer"] = parts[0]
        state["phase"] = phase_str
        state["pauses"] = int(pauses_hex, 16)  # Hex -> decimal

        # Only update when a NEW cycle completes
        if current_fpga_digit > state["highest_fpga_cycle"]:
            # Calculate efficiency for the completed session
            final_eff = max(0, 100 - (state["pauses"] * 10))
            state["last_recorded_eff"] = final_eff
            state["display_cycles"] = current_fpga_digit
            state["highest_fpga_cycle"] = current_fpga_digit

            # Record history with weekday number (0=Mon, 6=Sun)
            today_wd = time.localtime().tm_wday
            user_data.setdefault("history", []).append({
                "weekday": today_wd,
                "efficiency": final_eff
            })
            save_data(user_data)

            # Reset pauses for next cycle
            state["pauses"] = 0

    except Exception as e:
        print(f"UART Error: {e}")

# ---------------------------------------------------------
# UART LISTENER THREAD
# ---------------------------------------------------------
def uart_listener():
    try:
        ser = serial.Serial('COM4', 115200, timeout=1)  # Change COM port if needed
        print("📡 UART Listener Active on COM4")
        while True:
            raw = ser.readline().decode(errors="ignore").strip()
            if raw:
                parse_uart(raw)
    except Exception as e:
        print(f"Serial Error: {e}")

# ---------------------------------------------------------
# FLASK ROUTES
# ---------------------------------------------------------
@app.route('/')
def index():
    return render_template('index.html')

@app.route('/update')
def update():
    # Efficiency: show last recorded until UI reset
    display_eff = state["last_recorded_eff"]
    if display_eff is None:
        display_eff = 100

    # Weekly chart: default 0 for all days
    week_data = [0, 0, 0, 0, 0, 0, 0]  # Mon=0 ... Sun=6
    for entry in user_data.get("history", []):
        wd = entry.get("weekday")
        if wd is not None and 0 <= wd <= 6:
            week_data[wd] = entry.get("efficiency", 0)

    return jsonify({
        "timer": state["timer"],
        "phase": state["phase"],
        "sessions": state["display_cycles"],
        "efficiency": int(display_eff),
        "weekData": week_data
    })

@app.route('/log', methods=['POST'])
def log_pauses():
    data = request.get_json()
    state["pauses"] += int(data.get("pauses", 0))
    return jsonify({"status": "ok"})

@app.route('/reset', methods=['POST'])
def reset():
    global state, user_data
    # Reset cycles & efficiency only on UI button
    state["display_cycles"] = 0
    state["highest_fpga_cycle"] = 0
    state["pauses"] = 0
    state["last_recorded_eff"] = 100
    user_data["history"] = []
    save_data(user_data)
    return jsonify({"status": "ok"})

# ---------------------------------------------------------
# MAIN
# ---------------------------------------------------------
if __name__ == '__main__':
    threading.Thread(target=uart_listener, daemon=True).start()
    app.run(debug=True, port=5000, use_reloader=False)