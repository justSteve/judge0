"""
Judge0 Configuration
====================

Configuration management for Judge0 client.
"""

import os
from typing import Optional, Dict
from .exceptions import ConfigurationError


class Judge0Config:
    """Configuration for Judge0 client."""

    def __init__(
        self,
        api_url: Optional[str] = None,
        api_key: Optional[str] = None,
        api_host: Optional[str] = None,
        timeout: int = 30,
        max_wait: int = 60,
        use_rapidapi: bool = False
    ):
        """
        Initialize Judge0 configuration.

        Args:
            api_url: Judge0 API base URL
            api_key: API key (for RapidAPI)
            api_host: API host (for RapidAPI)
            timeout: Request timeout in seconds
            max_wait: Maximum wait time for submissions in seconds
            use_rapidapi: Whether to use RapidAPI headers
        """
        self.api_url = api_url or "http://localhost:2358"
        self.api_key = api_key
        self.api_host = api_host
        self.timeout = timeout
        self.max_wait = max_wait
        self.use_rapidapi = use_rapidapi

    @classmethod
    def from_env(cls) -> "Judge0Config":
        """
        Create configuration from environment variables.

        Environment variables:
            JUDGE0_API_URL: API base URL (default: http://localhost:2358)
            JUDGE0_API_KEY: API key for RapidAPI
            JUDGE0_API_HOST: API host for RapidAPI
            JUDGE0_TIMEOUT: Request timeout (default: 30)
            JUDGE0_MAX_WAIT: Max wait time (default: 60)

        Returns:
            Judge0Config instance
        """
        api_url = os.getenv("JUDGE0_API_URL", "http://localhost:2358")
        api_key = os.getenv("JUDGE0_API_KEY")
        api_host = os.getenv("JUDGE0_API_HOST")
        timeout = int(os.getenv("JUDGE0_TIMEOUT", "30"))
        max_wait = int(os.getenv("JUDGE0_MAX_WAIT", "60"))

        # Detect if using RapidAPI
        use_rapidapi = bool(api_key and api_host)

        return cls(
            api_url=api_url,
            api_key=api_key,
            api_host=api_host,
            timeout=timeout,
            max_wait=max_wait,
            use_rapidapi=use_rapidapi
        )

    @classmethod
    def local(cls, port: int = 2358, **kwargs) -> "Judge0Config":
        """
        Create configuration for local Judge0 instance.

        Args:
            port: Port number (default: 2358)
            **kwargs: Additional config parameters

        Returns:
            Judge0Config instance
        """
        return cls(api_url=f"http://localhost:{port}", **kwargs)

    @classmethod
    def azure(cls, host: str, port: int = 2358, **kwargs) -> "Judge0Config":
        """
        Create configuration for Azure VM Judge0 instance.

        Args:
            host: Azure VM hostname or IP
            port: Port number (default: 2358)
            **kwargs: Additional config parameters

        Returns:
            Judge0Config instance
        """
        return cls(api_url=f"http://{host}:{port}", **kwargs)

    @classmethod
    def rapidapi(cls, api_key: str, **kwargs) -> "Judge0Config":
        """
        Create configuration for RapidAPI Judge0.

        Args:
            api_key: RapidAPI key
            **kwargs: Additional config parameters

        Returns:
            Judge0Config instance
        """
        return cls(
            api_url="https://judge0-ce.p.rapidapi.com",
            api_key=api_key,
            api_host="judge0-ce.p.rapidapi.com",
            use_rapidapi=True,
            **kwargs
        )

    def get_headers(self) -> Dict[str, str]:
        """
        Get HTTP headers for requests.

        Returns:
            Dictionary of headers
        """
        headers = {"content-type": "application/json"}

        if self.use_rapidapi:
            if not self.api_key:
                raise ConfigurationError("API key required for RapidAPI")
            if not self.api_host:
                raise ConfigurationError("API host required for RapidAPI")

            headers["X-RapidAPI-Key"] = self.api_key
            headers["X-RapidAPI-Host"] = self.api_host

        return headers

    def __repr__(self) -> str:
        """String representation of config."""
        masked_key = f"{self.api_key[:8]}..." if self.api_key else None
        return (
            f"Judge0Config(api_url='{self.api_url}', "
            f"api_key='{masked_key}', "
            f"use_rapidapi={self.use_rapidapi})"
        )
