# API quick reference

Base URL: `http://127.0.0.1:5000`. The backend uses Flask; endpoint documentation is maintained here. JSON errors use `{ "error": { "code": "...", "message": "..." } }`.

Browser pages: `/` home, `/intake` nutrition analysis, `/register`, and `/login`. Each page includes a feedback/contact form. Public API: `GET /health`, `GET /api/foods?q=rice&limit=50`, `GET /api/foods/{food_id}`, `POST /api/auth/register`, `POST /api/auth/login`, `POST /api/feedback`, and `POST /api/meals/calculate` with `{ "items": [{"food_id":"1","portion_grams":150}] }`.

Registration requires `{ "name":"...", "email":"...", "contact":"...", "password":"at least 10 characters" }`. Login accepts contact and password without requiring a prior browser registration flag. An unregistered contact returns `404` with error code `account_not_registered`; a registered contact with an incorrect password returns `401` with `invalid_credentials`. The intake analyzer requires a bearer token and accepts `{ "intake_name":"Poha", "portion_grams":150, "intake_time":"14:30" }`. It returns each nutrient estimate scaled from the CSV reference values per 100 g and saves the analysis. Enter time in 24-hour `HH:MM` format. `GET /api/intake/analyses` returns the authenticated user's saved analyses.

## MongoDB database

The configured database is `AI_Hypoglycemia`. MongoDB uses collections (rather than SQL tables); the Flask startup initializer creates these collections and indexes:

| Collection | Stored fields |
| --- | --- |
| `users` | `_id`, `display_name`, `email`, `contact`, `password_hash`, `created_at`, optional `last_login_at`, `preferences` |
| `login_events` | `_id`, `user_id`, `created_at`, `event` (successful sign-ins only; passwords are never stored) |
| `intake_analyses` | `_id`, `user_id`, `timestamp`, `intake_name`, `intake_time`, `portion_grams`, `nutrition`, `source`, `is_estimate` |
| `feedback` | `_id`, `name`, `contact`, `message`, `created_at` |

The database also initializes `food_database`, `glucose_readings`, `meal_records`, `activity_records`, `predictions`, and `user_preferences` for the rest of the app. User email and contact have unique indexes; health/intake history and login events have user/time indexes.

Authenticated requests send `Authorization: Bearer <token>`. Routes: `GET /api/auth/me`, `DELETE /api/auth/account`; `POST/GET /api/glucose`, `GET/PATCH/DELETE /api/glucose/{id}`; `POST/GET /api/meals`, `DELETE /api/meals/{id}`; `POST/GET /api/activity`; `POST/GET /api/predictions/hypoglycemia` and `/api/predictions`; `GET /api/dashboard/summary`.

Glucose body: `{ "value": 105, "unit":"mg/dL", "timestamp":"2026-03-01T09:30:00Z", "context":"fasting" }`. Prediction returns 503 until an appropriate internally trained artifact is available.
