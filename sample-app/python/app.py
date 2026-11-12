import requests
import yaml
from flask import Flask, jsonify

app = Flask(__name__)


@app.get("/")
def index():
    return jsonify(yaml.safe_load("greeting: hello sbom"))


if __name__ == "__main__":
    app.run()
