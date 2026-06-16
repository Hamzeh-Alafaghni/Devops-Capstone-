"""
auth-service
Owns its own SQLite database (users.db) — no other service may write to it.
Issues JWTs signed with SHARED_SECRET (including the user's role) so other
services can verify tokens and authorize role-gated actions locally, without
calling back into auth-service on every request.

Run standalone:
    python -m venv venv && source venv/bin/activate
    pip install -r requirements.txt
    python app.py
Listens on :5001
"""
import os
import re
import sqlite3
import datetime

import jwt
from flask import Flask, jsonify, request
from werkzeug.security import generate_password_hash, check_password_hash

app = Flask(__name__)

DB_PATH = os.environ.get("AUTH_DB_PATH", os.path.join(os.path.dirname(__file__), "users.db"))
SHARED_SECRET = os.environ.get("SHARED_SECRET", "dev-shared-secret-change-me")
TOKEN_EXP_HOURS = 8

EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")

ADMIN_SEED_USERNAME = os.environ.get("ADMIN_SEED_USERNAME", "admin")
ADMIN_SEED_PASSWORD = os.environ.get("ADMIN_SEED_PASSWORD", "admin1234")
ADMIN_SEED_EMAIL = os.environ.get("ADMIN_SEED_EMAIL", "admin@example.com")


@app.after_request
def add_cors_headers(response):
    # Allows the frontend (a different origin, e.g. http://localhost:5173)
    # to call this API directly from the browser during local development.
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
    response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, PATCH, DELETE, OPTIONS"
    return response


@app.route("/api/auth/<path:_unused>", methods=["OPTIONS"])
def cors_preflight(_unused):
    # Browsers send an OPTIONS preflight before requests with custom headers
    # (like Authorization). Respond 204 so the real request can proceed.
    return "", 204


def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    conn = get_db()
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            email TEXT,
            full_name TEXT,
            address TEXT,
            role TEXT NOT NULL DEFAULT 'customer',
            created_at TEXT NOT NULL
        )
        """
    )
    conn.commit()

    # Seed a default admin account so the admin area is reachable without a
    # separate manual setup step. Change ADMIN_SEED_PASSWORD in real use.
    existing = conn.execute(
        "SELECT id FROM users WHERE username = ?", (ADMIN_SEED_USERNAME,)
    ).fetchone()
    if not existing:
        conn.execute(
            """
            INSERT INTO users (username, password_hash, email, full_name, address, role, created_at)
            VALUES (?, ?, ?, ?, ?, 'admin', ?)
            """,
            (
                ADMIN_SEED_USERNAME,
                generate_password_hash(ADMIN_SEED_PASSWORD),
                ADMIN_SEED_EMAIL,
                "Store Admin",
                "",
                datetime.datetime.utcnow().isoformat(),
            ),
        )
        conn.commit()
    conn.close()


def user_to_dict(row):
    return {
        "id": row["id"],
        "username": row["username"],
        "email": row["email"],
        "full_name": row["full_name"],
        "address": row["address"],
        "role": row["role"],
        "created_at": row["created_at"],
    }


def make_token(user_row):
    payload = {
        "sub": user_row["username"],
        "uid": user_row["id"],
        "role": user_row["role"],
        "exp": datetime.datetime.utcnow() + datetime.timedelta(hours=TOKEN_EXP_HOURS),
        "iat": datetime.datetime.utcnow(),
    }
    return jwt.encode(payload, SHARED_SECRET, algorithm="HS256")


def decode_token():
    """Returns the JWT payload from the Authorization header, or None."""
    auth_header = request.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        return None
    token = auth_header.split(" ", 1)[1]
    try:
        return jwt.decode(token, SHARED_SECRET, algorithms=["HS256"])
    except jwt.PyJWTError:
        return None


@app.route("/health")
def health():
    return jsonify(status="ok", service="auth-service"), 200


@app.route("/api/auth/register", methods=["POST"])
def register():
    data = request.get_json(force=True) or {}
    username = (data.get("username") or "").strip()
    password = data.get("password") or ""
    email = (data.get("email") or "").strip()
    full_name = (data.get("full_name") or "").strip()

    errors = {}
    if not username or len(username) < 3:
        errors["username"] = "username must be at least 3 characters"
    if not password or len(password) < 6:
        errors["password"] = "password must be at least 6 characters"
    if email and not EMAIL_RE.match(email):
        errors["email"] = "email is not a valid address"
    if errors:
        return jsonify(error="validation failed", fields=errors), 400

    conn = get_db()
    existing = conn.execute("SELECT id FROM users WHERE username = ?", (username,)).fetchone()
    if existing:
        conn.close()
        return jsonify(error="username already taken", fields={"username": "already taken"}), 409

    password_hash = generate_password_hash(password)
    conn.execute(
        """
        INSERT INTO users (username, password_hash, email, full_name, address, role, created_at)
        VALUES (?, ?, ?, ?, '', 'customer', ?)
        """,
        (username, password_hash, email, full_name, datetime.datetime.utcnow().isoformat()),
    )
    conn.commit()
    row = conn.execute("SELECT * FROM users WHERE username = ?", (username,)).fetchone()
    conn.close()

    return jsonify(message="registered", token=make_token(row), user=user_to_dict(row)), 201


@app.route("/api/auth/login", methods=["POST"])
def login():
    data = request.get_json(force=True) or {}
    username = (data.get("username") or "").strip()
    password = data.get("password") or ""

    conn = get_db()
    user = conn.execute("SELECT * FROM users WHERE username = ?", (username,)).fetchone()
    conn.close()

    if not user or not check_password_hash(user["password_hash"], password):
        return jsonify(error="invalid username or password"), 401

    return jsonify(token=make_token(user), user=user_to_dict(user)), 200


@app.route("/api/auth/me", methods=["GET"])
def me():
    payload = decode_token()
    if not payload:
        return jsonify(error="missing or invalid bearer token"), 401

    conn = get_db()
    row = conn.execute("SELECT * FROM users WHERE id = ?", (payload["uid"],)).fetchone()
    conn.close()
    if not row:
        return jsonify(error="user not found"), 404
    return jsonify(user_to_dict(row)), 200


@app.route("/api/auth/profile", methods=["PUT"])
def update_profile():
    payload = decode_token()
    if not payload:
        return jsonify(error="missing or invalid bearer token"), 401

    data = request.get_json(force=True) or {}
    email = data.get("email")
    full_name = data.get("full_name")
    address = data.get("address")

    if email is not None and email != "" and not EMAIL_RE.match(email):
        return jsonify(error="validation failed", fields={"email": "email is not a valid address"}), 400

    conn = get_db()
    row = conn.execute("SELECT * FROM users WHERE id = ?", (payload["uid"],)).fetchone()
    if not row:
        conn.close()
        return jsonify(error="user not found"), 404

    conn.execute(
        """
        UPDATE users SET
            email = COALESCE(?, email),
            full_name = COALESCE(?, full_name),
            address = COALESCE(?, address)
        WHERE id = ?
        """,
        (email, full_name, address, payload["uid"]),
    )
    conn.commit()
    row = conn.execute("SELECT * FROM users WHERE id = ?", (payload["uid"],)).fetchone()
    conn.close()
    return jsonify(user_to_dict(row)), 200


@app.route("/api/auth/change-password", methods=["POST"])
def change_password():
    payload = decode_token()
    if not payload:
        return jsonify(error="missing or invalid bearer token"), 401

    data = request.get_json(force=True) or {}
    current_password = data.get("current_password") or ""
    new_password = data.get("new_password") or ""

    if not new_password or len(new_password) < 6:
        return jsonify(error="validation failed", fields={"new_password": "must be at least 6 characters"}), 400

    conn = get_db()
    row = conn.execute("SELECT * FROM users WHERE id = ?", (payload["uid"],)).fetchone()
    if not row or not check_password_hash(row["password_hash"], current_password):
        conn.close()
        return jsonify(error="current password is incorrect"), 401

    conn.execute(
        "UPDATE users SET password_hash = ? WHERE id = ?",
        (generate_password_hash(new_password), payload["uid"]),
    )
    conn.commit()
    conn.close()
    return jsonify(message="password updated"), 200


if __name__ == "__main__":
    init_db()
    app.run(host="0.0.0.0", port=5001)
