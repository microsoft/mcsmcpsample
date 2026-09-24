import os
import sys
from pathlib import Path

import azure.functions as func

sys.path.insert(0, str(Path(__file__).parent / "src"))

from mcmc_mcp.config import ServerSettings  # noqa: E402
from mcmc_mcp.server import create_application  # noqa: E402

settings = ServerSettings.from_mapping(os.environ)
asgi_app = create_application(settings)

app = func.AsgiFunctionApp(
    app=asgi_app,
    http_auth_level=func.AuthLevel.ANONYMOUS,
    function_name="mcp_http_app",
)
