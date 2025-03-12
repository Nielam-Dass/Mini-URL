from dotenv import load_dotenv
load_dotenv()

from mini_url.app import app
import os

if __name__ == "__main__":
    app.run(debug=True, port=os.getenv('SERVER_PORT', 5000))
