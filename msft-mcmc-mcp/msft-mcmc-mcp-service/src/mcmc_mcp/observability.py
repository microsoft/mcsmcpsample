import json
import logging
import re
import time
from collections.abc import Awaitable, Callable
from typing import Any, cast
from uuid import uuid4

from starlette.types import Message, Receive, Scope, Send

_CORRELATION_HEADER = b"x-correlation-id"
_SAFE_CORRELATION_ID = re.compile(r"^[A-Za-z0-9._-]{1,128}$")


class CorrelationLoggingMiddleware:
    def __init__(self, app: Callable[..., Awaitable[None]]) -> None:
        self._app = app
        self._logger = logging.getLogger("mcmc_mcp.requests")

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self._app(scope, receive, send)
            return

        correlation_id = self._correlation_id(scope)
        status_code = 500
        started = time.perf_counter()

        async def send_with_correlation(message: Message) -> None:
            nonlocal status_code
            if message["type"] == "http.response.start":
                status_code = message["status"]
                headers = list(message.get("headers", []))
                headers.append((_CORRELATION_HEADER, correlation_id.encode("ascii")))
                message["headers"] = headers
            await send(message)

        try:
            await self._app(scope, receive, send_with_correlation)
        finally:
            event: dict[str, Any] = {
                "event": "http_request_completed",
                "correlation_id": correlation_id,
                "method": scope["method"],
                "path": scope["path"],
                "status_code": status_code,
                "duration_ms": round((time.perf_counter() - started) * 1000, 2),
            }
            self._logger.info(json.dumps(event, separators=(",", ":"), sort_keys=True))

    @staticmethod
    def _correlation_id(scope: Scope) -> str:
        for name, value in scope.get("headers", []):
            if name.lower() != _CORRELATION_HEADER:
                continue
            candidate = cast(bytes, value).decode("ascii", errors="ignore")
            if _SAFE_CORRELATION_ID.fullmatch(candidate):
                return candidate
        return str(uuid4())
