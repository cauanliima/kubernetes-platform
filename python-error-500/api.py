from flask import Flask, jsonify
import random
import time

app = Flask(__name__)

@app.route("/")
def index():
    # Define probabilidades:
    # 70% erro 500
    # 10% demora 1s
    # 20% demora 15s
    r = random.random()

    if r < 0.7:
        return jsonify({"error": "Simulated 500"}), 500

    elif r < 0.8:
        time.sleep(1)
        return jsonify({"message": "Delayed 1s"}), 200

    else:
        time.sleep(15)
        return jsonify({"message": "Delayed 15s"}), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)

