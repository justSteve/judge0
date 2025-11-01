"""
Judge0 Client Exceptions
========================

Custom exception classes for Judge0 client.
"""


class Judge0Error(Exception):
    """Base exception for Judge0 client errors."""
    pass


class SubmissionError(Judge0Error):
    """Raised when code submission fails."""
    pass


class TimeoutError(Judge0Error):
    """Raised when submission doesn't complete in time."""
    pass


class ConfigurationError(Judge0Error):
    """Raised when configuration is invalid."""
    pass
