from dotenv import load_dotenv
load_dotenv()

from mini_url.app import app
import os

app.run(debug=True, port=os.getenv('SERVER_PORT', 5000))
