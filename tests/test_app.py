def test_index(client):
    response = client.get("/")
    assert response.status_code == 200
    assert b"<h1>MiniURL</h1>" in response.data
    assert b"<h2>Minify big URLs quickly...</h2>" in response.data
    assert b"<input type=\"text\" name=\"original-url\" id=\"original-url\">" in response.data
    assert b"<input type=\"submit\" value=\"Submit\">" in response.data
    assert b"<p>Your MiniURL:</p>" not in response.data
    