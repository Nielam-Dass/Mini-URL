from flask import Flask, render_template, request
from dotenv import load_dotenv
import os

load_dotenv()

app = Flask(__name__)
SERVER_PORT = os.getenv('SERVER_PORT')

@app.route('/')
def hello_world():
    return render_template('index.html')

@app.post('/minify-url')
def minify_url():
    original_url = request.form.get('original-url')
    return f'Received url: {original_url}'

if __name__ == '__main__':
    app.run(debug=True, port=SERVER_PORT)
    