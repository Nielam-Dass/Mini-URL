from dotenv import load_dotenv
load_dotenv()

from mini_url.app import app
import os

if __name__ == "__main__":
    SERVER_PORT = os.getenv('SERVER_PORT', 5000)
    app.run(debug=True, port=SERVER_PORT)
