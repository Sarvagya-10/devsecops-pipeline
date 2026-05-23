from flask import Blueprint, current_app, jsonify

main_bp = Blueprint("main", __name__)


@main_bp.get("/")
def index():
    return (
        jsonify(
            message=f"Welcome to {current_app.config['APP_NAME']}",
            version=current_app.config["APP_VERSION"],
            env=current_app.config["ENV"],
        ),
        200,
    )
