import os


class Config:
    APP_NAME = os.getenv("APP_NAME", "devsecops-demo")
    APP_VERSION = os.getenv("APP_VERSION", "0.1.0")
    ENV = os.getenv("FLASK_ENV", "production")
    DEBUG = ENV == "development"
