"""
worker-service
A second, minimal service so the pipeline demonstrably handles a
multi-service architecture rather than a single app.
"""
from flask import Flask, jsonify
import os

app = Flask(__name__)
VERSION = os.environ.get("APP_VERSION", "1.0.0")


@app.route("/health")
def health():
    return jsonify({"status": "healthy", "service": "worker-service", "version": VERSION}), 200


@app.route("/process")
def process():
    return jsonify({"status": "processed", "queue_depth": 0})


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port)
