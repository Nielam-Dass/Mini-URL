def test_index(client):
    response = client.get('/')
    assert b'<h1>MiniURL</h1>' in response.data
    