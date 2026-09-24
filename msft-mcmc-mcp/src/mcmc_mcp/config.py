from collections.abc import Mapping
from dataclasses import dataclass
from enum import StrEnum


class ConfigurationError(ValueError):
    pass


class AuthMode(StrEnum):
    ENTRA = "entra"
    TRUSTED = "trusted"


@dataclass(frozen=True, slots=True)
class ServerSettings:
    auth_mode: AuthMode
    allowed_hosts: tuple[str, ...]

    @classmethod
    def from_mapping(cls, values: Mapping[str, str]) -> "ServerSettings":
        raw_mode = values.get("AUTH_MODE", "").strip()
        if not raw_mode:
            raise ConfigurationError("AUTH_MODE is required")

        try:
            auth_mode = AuthMode(raw_mode)
        except ValueError as error:
            supported = ", ".join(mode.value for mode in AuthMode)
            raise ConfigurationError(f"AUTH_MODE must be one of: {supported}") from error

        raw_hosts = values.get("MCP_ALLOWED_HOSTS", "127.0.0.1:*,localhost:*")
        allowed_hosts = tuple(host.strip() for host in raw_hosts.split(",") if host.strip())
        if not allowed_hosts:
            raise ConfigurationError("MCP_ALLOWED_HOSTS must contain at least one host")

        return cls(auth_mode=auth_mode, allowed_hosts=allowed_hosts)
