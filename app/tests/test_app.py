def test_index_returns_welcome(client):
    response = client.get("/")
    assert response.status_code == 200
    body = response.get_json()
    assert "Welcome" in body["message"]
    assert "version" in body
    assert "env" in body
