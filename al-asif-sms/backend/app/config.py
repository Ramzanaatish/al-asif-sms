from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = "postgresql+psycopg2://alasif:alasif@localhost:5432/alasif_sms"
    secret_key: str = "change-me-in-production"
    access_token_expire_minutes: int = 60 * 12
    app_name: str = "Al-Asif School Management System"

    class Config:
        env_file = ".env"


settings = Settings()
