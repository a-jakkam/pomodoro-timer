from flask import Flask, render_template, jsonify
import threading
import time
import random
import json
import os

app = Flask(__name__)

# Global state to store FPGA data
fpga_status = {
    "timer": "25:00",
    "phase": "1",
    "sessions": 0, # Start at 1 for the first badge
    "pauses": 0,
}
DATA_FILE = "data.json"

def load_data():
    if not os.path.exists(DATA_FILE):
        return {
            "total_sessions": 0,
            "badges": [],
            "history": []
        }
    with open(DATA_FILE, "r") as f:
        return json.load(f)

def save_data(data):
    with open(DATA_FILE, "w") as f:
        json.dump(data, f, indent=4)

user_data = load_data()
def internal_simulator():
    """Simulates the Boolean Board UART signals internally"""
    print("🚀 KINETIC // SIGNAL STATION: Simulation Mode Active")

    while True:
        # Simulate countdown
        for s in range(5, -1, -1):
            fpga_status["timer"] = f"00:{s:02d}"

            # 20% chance of pause
            if random.random() > 0.8:
                fpga_status["pauses"] += 1

            time.sleep(1)

        # ✅ SESSION COMPLETION LOGIC (NOW CORRECTLY INDENTED)
        user_data["total_sessions"] += 1

        efficiency = max(0, 100 - (fpga_status["pauses"] * 10))

        user_data["history"].append({
            "time": time.strftime("%Y-%m-%d"),
            "efficiency": efficiency,
            "pauses": fpga_status["pauses"]
        })

        # Badges
        if user_data["total_sessions"] == 1:
            user_data["badges"].append("First Focus")

        if fpga_status["pauses"] == 0:
            user_data["badges"].append("No Pause Session")

        save_data(user_data)

        print(f"🏆 Session {user_data['total_sessions']} Complete!")

        # Reset pauses AFTER saving
        fpga_status["pauses"] = 0


print(f"🏆 Session {user_data['total_sessions']} Complete!")
# print(f"🏆 SIMULATOR: Session {fpga_status['sessions']} Complete!")

# Fixed the thread start logic
threading.Thread(target=internal_simulator, daemon=True).start()

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/update')
def update():
    efficiency = max(0, 100 - (fpga_status["pauses"] * 10))

    last_7 = user_data["history"][-7:]

    # ✅ INCLUDE CURRENT SESSION (REAL-TIME)
    temp_history = last_7.copy()

    # Only add if timer is running (not 00:00 alarm)
    if fpga_status["timer"] != "00:00":
        temp_history.append({
            "efficiency": efficiency
        })

    avg_eff = 0
    if temp_history:
        avg_eff = sum(d["efficiency"] for d in temp_history) / len(temp_history)

    return jsonify({
        "timer": fpga_status["timer"],
        "phase": fpga_status["phase"],
        "sessions": user_data["total_sessions"],
        "efficiency": efficiency,
        "pauses": fpga_status["pauses"],
        "badges": user_data["badges"],
        "weekly_efficiency": round(avg_eff, 2)
    })

if __name__ == '__main__':
    app.run(debug=True, port=5000, use_reloader=False)