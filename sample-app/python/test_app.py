from app import app


def test_index():
    assert app.test_client().get("/").get_json() == {"greeting": "hello sbom"}
