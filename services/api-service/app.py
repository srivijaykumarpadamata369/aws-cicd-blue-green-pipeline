"""
api-service
A minimal Flask microservice used to demonstrate the CI/CD pipeline.
Deliberately simple — the pipeline is the project, not the app.
"""
from flask import Flask, jsonify
import os
import socket
import time

app = Flask(__name__)

START_TIME = time.time()
VERSION = os.environ.get("APP_VERSION", "1.0.0")

# Toggle used later to deliberately break a deployment for the
# "watch the rollback happen" demo. Set via env var, NOT hardcoded True.
SIMULATE_FAILURE = os.environ.get("SIMULATE_FAILURE", "false").lower() == "true"


@app.route("/")
def index():
    return jsonify({
        "service": "api-service",
        "version": VERSION,
        "host": socket.gethostname(),
        "uptime_seconds": round(time.time() - START_TIME, 2),
    })


@app.route("/health")
def health():
    """
    Health check endpoint used by the ALB target group and by
    CodeDeploy's post-traffic hook to decide whether the new
    (green) task set is healthy before shifting traffic to it.
    """
    if SIMULATE_FAILURE:
        # Intentionally return 500 so CloudWatch alarm + CodeDeploy
        # rollback can be demonstrated end-to-end.
        return jsonify({"status": "unhealthy", "reason": "simulated failure"}), 500

    return jsonify({"status": "healthy", "version": VERSION}), 200


@app.route("/api/orders")
def orders():
    """Dummy endpoint standing in for real business logic."""
    return jsonify({
        "orders": [
            {"id": 1, "item": "widget", "qty": 3},
            {"id": 2, "item": "gadget", "qty": 1},
        ]
    })


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port)
