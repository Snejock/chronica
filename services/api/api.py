import logging
import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from packages.logger.logger_setup import logger_setup
from packages.routers import health

logger = logging.getLogger(__name__)


if __name__ == "__main__":
    logger_setup(log_file_path="log/api.log", level=logging.INFO)
    logger.info("Initializing application...")
    app = FastAPI(title="Chronica API")

    # TODO: сузить allow_origins до адреса Signalfire-фронтенда, когда он будет развёрнут
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.include_router(health.router)

    uvicorn.run(app, host="0.0.0.0", port=8000)
