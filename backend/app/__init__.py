import os
import secrets
from datetime import datetime, timezone
from flask import Flask, jsonify
from flask_cors import CORS
from dotenv import load_dotenv
from .database import Database
from .routes import api
from .web import web

def create_app(test_config=None):
    load_dotenv()
    app = Flask(__name__)
    jwt_secret = os.getenv("JWT_SECRET") or secrets.token_urlsafe(48)
    app.config.update(
        JWT_SECRET=jwt_secret,
        DEBUG=os.getenv("FLASK_ENV") == "development",
        TOKEN_HOURS=12,
    )
    if test_config:
        app.config.update(test_config)
    if not os.getenv("JWT_SECRET"):
        app.logger.warning("JWT_SECRET is unset; using a temporary key. Configure a persistent secret in .env.")
    origins = [x.strip() for x in os.getenv("CORS_ORIGINS", "").split(",") if x.strip()]
    CORS(app, resources={r"/api/*": {"origins": origins}})
    app.extensions["database"] = app.config.get("DATABASE_ADAPTER") or Database.from_env()
    app.register_blueprint(api, url_prefix="/api")
    app.register_blueprint(web)

    @app.get("/health")
    def health():
        db = app.extensions["database"]
        try:
            db.ping()
            db.initialize()
            return jsonify(status="ok", database="connected", time=datetime.now(timezone.utc).isoformat())
        except Exception:
            return jsonify(status="degraded", database="unavailable"), 503

    @app.errorhandler(404)
    def not_found(_):
        return jsonify(error={"code": "not_found", "message": "Resource not found"}), 404

    @app.errorhandler(500)
    def server_error(_):
        app.logger.exception("Unhandled server error")
        return jsonify(error={"code": "server_error", "message": "Request could not be completed"}), 500
    return app
