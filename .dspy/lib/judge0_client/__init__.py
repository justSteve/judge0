"""
Judge0 Python Client Library
=============================

A simple Python client for interacting with Judge0 API.
Designed for use in DSPy workflows and code execution tasks.
"""

from .client import Judge0Client
from .exceptions import Judge0Error, SubmissionError, TimeoutError
from .config import Judge0Config

__version__ = "0.1.0"
__all__ = ["Judge0Client", "Judge0Error", "SubmissionError", "TimeoutError", "Judge0Config"]
