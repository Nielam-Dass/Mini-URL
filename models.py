from sqlalchemy.sql import func
from extensions import db
import string
import random

tag_chars = string.ascii_uppercase + string.digits

class MiniURL(db.Model):
    id = db.Column(db.Integer, primary_key=True)

    original_url = db.Column(db.String(2048), nullable=False)
    
    tag = db.Column(db.String(8), unique=True, default=lambda: ''.join(random.choices(tag_chars, k=8)))
    
    timestamp = db.Column(db.DateTime(timezone=True), server_default=func.now())

    def __str__(self):
        return f'id={self.id}; original_url={self.original_url}; tag={self.tag}; timestamp={self.timestamp}'
