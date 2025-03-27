import pytest

import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ['DATABASE_URI'] = 'sqlite:///mini_urls_test.db'

import mini_url.app

@pytest.fixture()
def app():
    app = mini_url.app.app
    yield app

@pytest.fixture()
def client(app):
    return app.test_client()
