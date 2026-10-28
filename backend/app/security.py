from datetime import datetime, timedelta, timezone
from functools import wraps
import jwt
from flask import current_app, request, g, jsonify
from werkzeug.security import generate_password_hash, check_password_hash

def hash_password(password): return generate_password_hash(password, method="scrypt")
def verify_password(password, encoded): return check_password_hash(encoded, password)
def issue_token(user_id):
    now = datetime.now(timezone.utc)
    return jwt.encode({"sub": str(user_id), "iat": now, "exp": now + timedelta(hours=current_app.config["TOKEN_HOURS"])}, current_app.config["JWT_SECRET"], algorithm="HS256")

def authenticated(fn):
    @wraps(fn)
    def wrapped(*args, **kwargs):
        header = request.headers.get("Authorization", "")
        if not header.startswith("Bearer "):
            return jsonify(error={"code": "unauthorized", "message": "Bearer token required"}), 401
        try:
            payload = jwt.decode(header[7:], current_app.config["JWT_SECRET"], algorithms=["HS256"])
            g.user_id = payload["sub"]
        except jwt.PyJWTError:
            return jsonify(error={"code": "unauthorized", "message": "Token is invalid or expired"}), 401
        return fn(*args, **kwargs)
    return wrapped
