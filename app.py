from flask import Flask

app = Flask(__name__)

@app.route("/")
def home():
    return "Hello CI"

@app.route("/add/<int:a>/<int:b>")
def add(a, b):
    return {"result": a + b}
import os
