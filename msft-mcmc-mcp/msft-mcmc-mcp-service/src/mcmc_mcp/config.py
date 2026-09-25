import json
from collections.abc import Mapping
from dataclasses import dataclass
from enum import StrEnum


class ConfigurationError(ValueError):
    pass


class AuthMode(StrEnum):
    ENTRA = "entra"
    TRUSTED = "trusted"


@dataclass(frozen=True, slots=True)
class EntraSettings:
    tenant_id: str
    audience: str
    required_scope: str
    resource_server_url: str
    oid_access: Mapping[str, frozenset[str]]

    @classmethod
    def from_mapping(cls, values: Mapping[str, str]) -> "EntraSettings":
        required = {
            "ENTRA_TENANT_ID": "tenant_id",
            "ENTRA_AUDIENCE": "audience",
            "ENTRA_REQUIRED_SCOPE": "required_scope",
            "MCP_RESOURCE_SERVER_URL": "resource_server_url",
            "ENTRA_OID_ACCESS_JSON": "oid_access",
        }
        missing = [name for name in required if not values.get(name, "").strip()]
        if missing:
            raise ConfigurationError(f"entra mode requires: {', '.join(sorted(missing))}")

        try:
            raw_oid_access = json.loads(values["ENTRA_OID_ACCESS_JSON"])
        except json.JSONDecodeError as error:
            raise ConfigurationError("ENTRA_OID_ACCESS_JSON must be valid JSON") from error
        if not isinstance(raw_oid_access, dict):
            raise ConfigurationError("ENTRA_OID_ACCESS_JSON must be a JSON object")

        oid_access: dict[str, frozenset[str]] = {}
        for oid, customer_numbers in raw_oid_access.items():
            if not isinstance(oid, str) or not oid:
                raise ConfigurationError("ENTRA_OID_ACCESS_JSON keys must be nonempty strings")
            if not isinstance(customer_numbers, list) or not all(
                isinstance(number, str) for number in customer_numbers
            ):
                raise ConfigurationError(
                    "ENTRA_OID_ACCESS_JSON values must be arrays of customer numbers"
                )
            oid_access[oid] = frozenset(customer_numbers)

        return cls(
            tenant_id=values["ENTRA_TENANT_ID"].strip(),
            audience=values["ENTRA_AUDIENCE"].strip(),
            required_scope=values["ENTRA_REQUIRED_SCOPE"].strip(),
            resource_server_url=values["MCP_RESOURCE_SERVER_URL"].strip(),
            oid_access=oid_access,
        )


@dataclass(frozen=True, slots=True)
class ServerSettings:
    auth_mode: AuthMode
    allowed_hosts: tuple[str, ...]
    entra: EntraSettings | None = None

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

        entra = EntraSettings.from_mapping(values) if auth_mode is AuthMode.ENTRA else None
        return cls(auth_mode=auth_mode, allowed_hosts=allowed_hosts, entra=entra)
