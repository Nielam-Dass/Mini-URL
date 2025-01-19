from flask import Flask, render_template, request, redirect, url_for, flash
from dotenv import load_dotenv
from extensions import db
from models import MiniURL
import os

load_dotenv()
DATABASE_URI = os.getenv('DATABASE_URI')
SERVER_PORT = os.getenv('SERVER_PORT')
SECRET_KEY = os.getenv('APP_SECRET')

app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = DATABASE_URI
app.secret_key = SECRET_KEY
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
        flash(request.host + '/' + new_mini_url.tag)
        return redirect(url_for('index_page'))
    else:
        return 'Bad Request', 400

@app.get('/<string:mini_tag>')
def access_mini_url(mini_tag):
    mini_url = MiniURL.query.filter_by(tag=mini_tag).first_or_404()
    original_url = mini_url.original_url
    return redirect(original_url)


if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    
    app.run(debug=True, port=SERVER_PORT)
    