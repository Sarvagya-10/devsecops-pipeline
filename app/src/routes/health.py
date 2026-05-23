from flask import Blueprint, current_app, jsonify

health_bp = Blueprint("health", __name__)


@health_bp.get("/health")
def health():
    return jsonify(status="ok"), 200


@health_bp.get("/ready")
def ready():
    return (
        jsonify(
            status="ready",
            app=current_app.config["APP_NAME"],
            version=current_app.config["APP_VERSION"],
        ),
        200,
    )
