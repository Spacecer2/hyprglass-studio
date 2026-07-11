import pytest
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

try:
    from src import server as app_module
    HAS_SERVER = True
except Exception:  # pragma: no cover
    HAS_SERVER = False


@pytest.fixture
def client():
    if not HAS_SERVER:
        pytest.skip("src/server.py is not available")
    app = app_module.create_app(testing=True)
    return app.test_client()


@pytest.mark.skipif(not HAS_SERVER, reason="src/server.py is not available")
def test_root_endpoint(client):
    response = client.get("/")
    assert response.status_code == 200


@pytest.mark.skipif(not HAS_SERVER, reason="src/server.py is not available")
def test_health_endpoint(client):
    response = client.get("/health")
    assert response.status_code == 200
    data = response.get_json()
    assert data is not None
    assert data.get("status") in ("ok", "healthy")


@pytest.mark.skipif(not HAS_SERVER, reason="src/server.py is not available")
def test_profiles_endpoint_returns_list(client):
    response = client.get("/profiles")
    assert response.status_code == 200
    data = response.get_json()
    assert isinstance(data, list)
    assert any(p.get("name") == "default" for p in data)


@pytest.mark.skipif(not HAS_SERVER, reason="src/server.py is not available")
def test_get_profile_by_name(client):
    response = client.get("/profiles/default")
    assert response.status_code == 200
    data = response.get_json()
    assert data.get("name") == "default"


@pytest.mark.skipif(not HAS_SERVER, reason="src/server.py is not available")
def test_get_profile_not_found(client):
    response = client.get("/profiles/nonexistent")
    assert response.status_code == 404
