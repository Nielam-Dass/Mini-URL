from flask import Flask, render_template, request
from dotenv import load_dotenv
from extensions import db
from models import MiniURL
import os

load_dotenv()
DATABASE_URI = os.getenv('DATABASE_URI')
SERVER_PORT = os.getenv('SERVER_PORT')

app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = DATABASE_URI
db.init_app(app)

@app.route('/')
def index_page():
    return render_template('index.html')

@app.post('/minify-url')
def minify_url():
    original_url = request.form.get('original-url')
    if original_url and len(original_url)>0:
        # Create mini URL
        new_mini_url = MiniURL(original_url=original_url)
        db.session.add(new_mini_url)
        db.session.commit()
        return f'{str(new_mini_url)}'
    else:
        return 'Bad Request', 400


if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    
    app.run(debug=True, port=SERVER_PORT)
    