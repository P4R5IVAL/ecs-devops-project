from flask import Flask

app = Flask(__name__)

@app.route("/")
def home():
    return "My DevOps Project"

@app.route("/health")
def health():
    return {"status": "ok"}