"""
Judge0 Client Exceptions (Enhanced)
====================================

Enhanced exception classes with detailed context.
"""

from typing import Optional


class Judge0Error(Exception):
    """Base exception for Judge0 client errors."""

    def __init__(self, message: str, **context):
        """
        Initialize exception with message and optional context.

        Args:
            message: Error message
            **context: Additional context information
        """
        super().__init__(message)
        self.message = message
        self.context = context

    def __str__(self):
        """String representation with context."""
        parts = [self.message]

        if self.context:
            context_str = ", ".join(f"{k}={v}" for k, v in self.context.items())
            parts.append(f"[{context_str}]")

        return " ".join(parts)

    def to_dict(self):
        """Convert to dictionary for logging."""
        return {
            "error_type": self.__class__.__name__,
            "message": self.message,
            **self.context
        }


class SubmissionError(Judge0Error):
    """Raised when code submission fails."""

    def __init__(
        self,
        message: str,
        status_code: Optional[int] = None,
        response_text: Optional[str] = None,
        token: Optional[str] = None,
        **context
    ):
        """
        Initialize submission error.

        Args:
            message: Error message
            status_code: HTTP status code if available
            response_text: Response body if available
            token: Submission token if available
            **context: Additional context
        """
        context_dict = context.copy()

        if status_code is not None:
            context_dict["status_code"] = status_code

        if response_text:
            # Truncate long responses
            context_dict["response"] = response_text[:200] + (
                "..." if len(response_text) > 200 else ""
            )

        if token:
            context_dict["token"] = token

        super().__init__(message, **context_dict)

        # Store as attributes for easy access
        self.status_code = status_code
        self.response_text = response_text
        self.token = token


class TimeoutError(Judge0Error):
    """Raised when submission doesn't complete in time."""

    def __init__(
        self,
        message: str,
        token: Optional[str] = None,
        max_wait: Optional[int] = None,
        polls: Optional[int] = None,
        last_status: Optional[str] = None,
        last_status_id: Optional[int] = None,
        **context
    ):
        """
        Initialize timeout error.

        Args:
            message: Error message
            token: Submission token
            max_wait: Maximum wait time that was exceeded
            polls: Number of polling attempts made
            last_status: Last known status description
            last_status_id: Last known status ID
            **context: Additional context
        """
        context_dict = context.copy()

        if token:
            context_dict["token"] = token
        if max_wait is not None:
            context_dict["max_wait_sec"] = max_wait
        if polls is not None:
            context_dict["polls"] = polls
        if last_status:
            context_dict["last_status"] = last_status
        if last_status_id is not None:
            context_dict["last_status_id"] = last_status_id

        super().__init__(message, **context_dict)

        self.token = token
        self.max_wait = max_wait
        self.polls = polls
        self.last_status = last_status
        self.last_status_id = last_status_id


class ConfigurationError(Judge0Error):
    """Raised when configuration is invalid."""

    def __init__(self, message: str, config_key: Optional[str] = None, **context):
        """
        Initialize configuration error.

        Args:
            message: Error message
            config_key: The configuration key that is invalid
            **context: Additional context
        """
        if config_key:
            context["config_key"] = config_key

        super().__init__(message, **context)
        self.config_key = config_key


class NetworkError(Judge0Error):
    """Raised when network communication fails."""

    def __init__(
        self,
        message: str,
        url: Optional[str] = None,
        attempts: Optional[int] = None,
        **context
    ):
        """
        Initialize network error.

        Args:
            message: Error message
            url: The URL that failed
            attempts: Number of retry attempts made
            **context: Additional context
        """
        if url:
            context["url"] = url
        if attempts is not None:
            context["attempts"] = attempts

        super().__init__(message, **context)
        self.url = url
        self.attempts = attempts


class ValidationError(Judge0Error):
    """Raised when response validation fails."""

    def __init__(self, message: str, field: Optional[str] = None, **context):
        """
        Initialize validation error.

        Args:
            message: Error message
            field: The field that failed validation
            **context: Additional context
        """
        if field:
            context["field"] = field

        super().__init__(message, **context)
        self.field = field
