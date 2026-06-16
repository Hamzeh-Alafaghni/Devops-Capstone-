# auth-service

Owns user accounts. Issues JWTs (HS256, shared secret, includes `role`) that
other services verify locally without calling back into this service.

## Run standalone

```bash
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
python app.py
```

Listens on `http://localhost:5001`. On first run it seeds an admin account
(`admin` / `admin1234` by default — override with `ADMIN_SEED_USERNAME` /
`ADMIN_SEED_PASSWORD` / `ADMIN_SEED_EMAIL`).

## Endpoints

| Method | Path | Body | Notes |
|---|---|---|---|
| GET | `/health` | - | health check |
| POST | `/api/auth/register` | `{username, password, email?, full_name?}` | username >= 3 chars, password >= 6 chars; returns `{token, user}` |
| POST | `/api/auth/login` | `{username, password}` | returns `{token, user}` |
| GET | `/api/auth/me` | - | requires `Authorization: Bearer <token>`; returns the full profile |
| PUT | `/api/auth/profile` | `{email?, full_name?, address?}` | requires bearer token; updates the caller's own profile |
| POST | `/api/auth/change-password` | `{current_password, new_password}` | requires bearer token |

`user` objects look like:

```json
{"id": 1, "username": "student1", "email": "", "full_name": "", "address": "", "role": "customer", "created_at": "..."}
```

`role` is either `customer` or `admin`. It's embedded in the JWT payload so
catalog-service and orders-service can authorize admin-only actions (product
management, order status updates) without an extra network call.

## Environment variables

- `AUTH_DB_PATH` — path to SQLite file (default: `users.db` next to app.py)
- `SHARED_SECRET` — JWT signing secret. **Must be the same value** on
  catalog-service and orders-service since they verify tokens without
  calling auth-service.
- `ADMIN_SEED_USERNAME` / `ADMIN_SEED_PASSWORD` / `ADMIN_SEED_EMAIL` —
  credentials for the auto-seeded admin account (default `admin` /
  `admin1234` / `admin@example.com`).
