from flask import Flask, jsonify, request
import json
import os
import threading

app = Flask(__name__)
_lock = threading.Lock()
_DATA_FILE = os.path.join(os.path.dirname(__file__), "code_uses.json")

CODE_LIMITS = {
    "friendvoid": 23,
}


def _load_data() -> dict:
    if os.path.exists(_DATA_FILE):
        with open(_DATA_FILE, "r") as f:
            return json.load(f)
    return {}


def _save_data(data: dict) -> None:
    with open(_DATA_FILE, "w") as f:
        json.dump(data, f)


@app.route("/redeem", methods=["POST"])
def redeem():
    body = request.get_json(silent=True) or {}
    code = body.get("code", "").strip().lower()
    if code not in CODE_LIMITS:
        return jsonify({"ok": False, "error": "invalid_code"}), 200

    with _lock:
        data = _load_data()
        uses = data.get(code, 0)
        if uses >= CODE_LIMITS[code]:
            return jsonify({"ok": False, "error": "max_uses", "uses": uses, "limit": CODE_LIMITS[code]}), 200
        data[code] = uses + 1
        _save_data(data)
        return jsonify({"ok": True, "uses": uses + 1, "limit": CODE_LIMITS[code]}), 200


@app.route("/check", methods=["GET"])
def check():
    code = request.args.get("code", "").strip().lower()
    if code not in CODE_LIMITS:
        return jsonify({"ok": False, "error": "invalid_code"}), 200
    data = _load_data()
    uses = data.get(code, 0)
    limit = CODE_LIMITS[code]
    return jsonify({"ok": True, "available": uses < limit, "uses": uses, "limit": limit}), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5050)
