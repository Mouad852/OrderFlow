import os
from collections.abc import Mapping
from functools import lru_cache
from typing import Annotated

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jwt import PyJWKClient

from app.core.config import get_settings

bearer_scheme = HTTPBearer(
    auto_error=False,
    bearerFormat="JWT",
    scheme_name="Microsoft Entra access token",
)


def is_auth_enabled() -> bool:
    return os.getenv("AUTH_ENABLED", "false").lower() in {
        "1",
        "true",
        "yes",
        "on",
    }


@lru_cache
def get_jwks_client(tenant_id: str) -> PyJWKClient:
    return PyJWKClient(f"https://login.microsoftonline.com/{tenant_id}/discovery/v2.0/keys")


def require_orders_access(
    credentials: Annotated[
        HTTPAuthorizationCredentials | None,
        Depends(bearer_scheme),
    ],
) -> Mapping[str, object]:
    # Avoid loading deployment-only settings during local tests and development.
    # Azure environments explicitly set AUTH_ENABLED=true.
    if not is_auth_enabled():
        return {}

    settings = get_settings()

    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="A bearer token is required.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    try:
        signing_key = get_jwks_client(settings.entra_tenant_id).get_signing_key_from_jwt(
            credentials.credentials
        )

        claims = jwt.decode(
            credentials.credentials,
            signing_key.key,
            algorithms=["RS256"],
            audience=settings.entra_api_client_id,
            issuer=(f"https://login.microsoftonline.com/{settings.entra_tenant_id}/v2.0"),
            options={"require": ["aud", "exp", "iat", "iss"]},
        )
    except jwt.PyJWTError as error:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="The bearer token is invalid.",
            headers={"WWW-Authenticate": "Bearer"},
        ) from error

    roles = claims.get("roles", [])

    if settings.entra_required_role not in roles:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="The token does not have the required OrderFlow role.",
        )

    return claims
