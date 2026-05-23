import logging
import os
import sys

from flask import Flask

from src.config import Config
from src.routes.health import health_bp
from src.routes.main import main_bp


def _configure_logging() -> None:
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(
        logging.Formatter(
            '{"time":"%(asctime)s","level":"%(levelname)s",'
            '"logger":"%(name)s","message":"%(message)s"}'
        )
    )
    root = logging.getLogger()
    root.handlers.clear()
    root.addHandler(handler)
    root.setLevel(os.getenv("LOG_LEVEL", "INFO"))


def create_app(config_object: type = Config) -> Flask:
    _configure_logging()
    app = Flask(__name__)
    app.config.from_object(config_object)
    app.register_blueprint(health_bp)
    app.register_blueprint(main_bp)
    return app
