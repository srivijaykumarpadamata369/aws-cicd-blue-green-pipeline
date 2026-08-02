"""
Unit tests for api-service.
Run in CI via: pytest test_app.py
"""
import pytest
from app import app


@pytest.fixture
def client():
    app.config["TESTING"] = True
    with app.test_client() as client:
        yield client


def test_index_returns_200(client):
    resp = client.get("/")
    assert resp.status_code == 200
    body = resp.get_json()
    assert body["service"] == "api-service"


def test_health_returns_200_by_default(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.get_json()["status"] == "healthy"


def test_orders_endpoint_returns_list(client):
    resp = client.get("/api/orders")
    assert resp.status_code == 200
    body = resp.get_json()
    assert isinstance(body["orders"], list)
    assert len(body["orders"]) > 0
