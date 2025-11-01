"""
Judge0 API Client (Enhanced with Logging and Retry Logic)
==========================================================

Production-ready client with comprehensive logging and error handling.
"""

import requests
import time
import logging
from functools import wraps
from typing import Optional, Dict, Any, Callable
from .exceptions import Judge0Error, SubmissionError, TimeoutError
from .config import Judge0Config


# Configure module logger
logger = logging.getLogger(__name__)


def retry_on_failure(
    max_attempts: int = 3,
    delay: float = 1.0,
    backoff: float = 2.0,
    exceptions: tuple = (requests.RequestException,)
):
    """
    Decorator for retrying failed operations with exponential backoff.

    Args:
        max_attempts: Maximum number of retry attempts
        delay: Initial delay between retries in seconds
        backoff: Multiplier for delay after each retry
        exceptions: Tuple of exceptions to catch and retry

    Example:
        @retry_on_failure(max_attempts=3, delay=1.0)
        def my_function():
            # ... code that might fail
    """
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        def wrapper(*args, **kwargs):
            attempt = 1
            current_delay = delay

            while attempt <= max_attempts:
                try:
                    logger.debug(f"{func.__name__}: Attempt {attempt}/{max_attempts}")
                    result = func(*args, **kwargs)
                    if attempt > 1:
                        logger.info(f"{func.__name__}: Succeeded on attempt {attempt}")
                    return result

                except exceptions as e:
                    if attempt == max_attempts:
                        logger.error(
                            f"{func.__name__}: Failed after {max_attempts} attempts: {e}"
                        )
                        raise

                    logger.warning(
                        f"{func.__name__}: Failed (attempt {attempt}/{max_attempts}): {e}. "
                        f"Retrying in {current_delay:.1f}s..."
                    )

                    time.sleep(current_delay)
                    current_delay *= backoff
                    attempt += 1

        return wrapper
    return decorator


class Judge0Client:
    """
    Enhanced Judge0 API client with logging and retry logic.

    This version includes:
    - Comprehensive logging at all levels
    - Automatic retry with exponential backoff
    - Detailed error context
    - Performance metrics
    - Better validation
    """

    def __init__(self, config: Optional[Judge0Config] = None, logger_instance: Optional[logging.Logger] = None):
        """
        Initialize Judge0 client.

        Args:
            config: Judge0Config instance. If None, uses default config.
            logger_instance: Optional custom logger. If None, uses module logger.
        """
        self.config = config or Judge0Config.from_env()
        self.logger = logger_instance or logger

        self.logger.info(
            "Initialized Judge0Client",
            extra={
                "api_url": self.config.api_url,
                "timeout": self.config.timeout,
                "max_wait": self.config.max_wait,
            }
        )

    @retry_on_failure(max_attempts=3, delay=1.0, backoff=2.0)
    def submit_code(
        self,
        source_code: str,
        language_id: int = 71,  # Python 3
        stdin: str = "",
        expected_output: Optional[str] = None,
        **kwargs
    ) -> str:
        """
        Submit code to Judge0 for execution.

        This method includes automatic retry on network errors.

        Args:
            source_code: The source code to execute
            language_id: Language ID (default: 71 = Python 3)
            stdin: Input to provide to the program
            expected_output: Expected output for validation
            **kwargs: Additional Judge0 submission parameters

        Returns:
            Submission token (string)

        Raises:
            SubmissionError: If submission fails after retries
        """
        url = f"{self.config.api_url}/submissions"

        # Log submission details
        self.logger.info(
            "Submitting code",
            extra={
                "language_id": language_id,
                "code_length": len(source_code),
                "has_stdin": bool(stdin),
                "has_expected_output": bool(expected_output),
            }
        )

        self.logger.debug(f"Code snippet: {source_code[:100]}...")

        payload = {
            "source_code": source_code,
            "language_id": language_id,
            "stdin": stdin,
        }

        if expected_output:
            payload["expected_output"] = expected_output

        # Add any additional parameters
        payload.update(kwargs)

        headers = self.config.get_headers()

        try:
            start_time = time.time()
            response = requests.post(
                url,
                json=payload,
                headers=headers,
                timeout=self.config.timeout
            )
            response_time = (time.time() - start_time) * 1000

            self.logger.debug(
                "Submission response received",
                extra={
                    "status_code": response.status_code,
                    "response_time_ms": round(response_time, 2),
                }
            )

            if response.status_code == 201:
                token = response.json().get("token")

                # Validate token
                if not token:
                    self.logger.error("No token in response", extra={"response": response.text[:500]})
                    raise SubmissionError(
                        "No token in response",
                        status_code=response.status_code,
                        response_text=response.text
                    )

                if not isinstance(token, str) or len(token) == 0:
                    self.logger.error(f"Invalid token format: {token}")
                    raise SubmissionError(f"Invalid token: {token}")

                self.logger.info(
                    "Submission successful",
                    extra={
                        "token": token,
                        "response_time_ms": round(response_time, 2),
                    }
                )

                return token

            else:
                self.logger.error(
                    "Submission failed",
                    extra={
                        "status_code": response.status_code,
                        "response": response.text[:500],
                    }
                )

                raise SubmissionError(
                    f"Submission failed with status {response.status_code}",
                    status_code=response.status_code,
                    response_text=response.text
                )

        except requests.Timeout as e:
            self.logger.error(f"Submission timed out after {self.config.timeout}s: {e}")
            raise SubmissionError(f"Request timed out: {e}") from e

        except requests.ConnectionError as e:
            self.logger.error(f"Connection error during submission: {e}")
            raise SubmissionError(f"Connection error: {e}") from e

        except requests.RequestException as e:
            self.logger.exception("Network error during submission")
            raise SubmissionError(f"Network error: {e}") from e

    @retry_on_failure(max_attempts=3, delay=0.5, backoff=1.5)
    def get_submission(self, token: str, **kwargs) -> Dict[str, Any]:
        """
        Get submission results from Judge0.

        This method includes automatic retry on network errors.

        Args:
            token: Submission token
            **kwargs: Additional query parameters (e.g., fields, base64_encoded)

        Returns:
            Submission result dictionary

        Raises:
            Judge0Error: If request fails after retries
        """
        url = f"{self.config.api_url}/submissions/{token}"
        headers = self.config.get_headers()

        # Build query parameters
        params = kwargs if kwargs else None

        self.logger.debug(f"Fetching submission: {token}")

        try:
            start_time = time.time()
            response = requests.get(
                url,
                headers=headers,
                params=params,
                timeout=self.config.timeout
            )
            response_time = (time.time() - start_time) * 1000

            if response.status_code == 200:
                result = response.json()

                self.logger.debug(
                    "Submission fetched",
                    extra={
                        "token": token,
                        "status_id": result.get("status", {}).get("id"),
                        "status": result.get("status", {}).get("description"),
                        "response_time_ms": round(response_time, 2),
                    }
                )

                return result

            else:
                self.logger.error(
                    "Failed to get submission",
                    extra={
                        "token": token,
                        "status_code": response.status_code,
                        "response": response.text[:500],
                    }
                )

                raise Judge0Error(
                    f"Failed to get submission: {response.status_code} - {response.text[:200]}"
                )

        except requests.RequestException as e:
            self.logger.exception(f"Network error fetching submission {token}")
            raise Judge0Error(f"Network error: {e}") from e

    def wait_for_completion(
        self,
        token: str,
        max_wait: Optional[int] = None,
        poll_interval: float = 0.5
    ) -> Dict[str, Any]:
        """
        Wait for submission to complete with detailed logging.

        Args:
            token: Submission token
            max_wait: Maximum seconds to wait (default: from config)
            poll_interval: Seconds between polling attempts

        Returns:
            Final submission result dictionary

        Raises:
            TimeoutError: If submission doesn't complete in time
        """
        max_wait = max_wait or self.config.max_wait
        waited = 0.0
        polls = 0
        last_status = None
        last_status_id = None

        self.logger.info(
            "Waiting for submission completion",
            extra={
                "token": token,
                "max_wait": max_wait,
                "poll_interval": poll_interval,
            }
        )

        start_time = time.time()

        while waited < max_wait:
            polls += 1

            try:
                result = self.get_submission(token)
                status_id = result.get("status", {}).get("id")
                status_desc = result.get("status", {}).get("description", "Unknown")

                last_status = status_desc
                last_status_id = status_id

                # Log status changes
                if status_desc != last_status or polls == 1:
                    self.logger.debug(
                        f"Poll {polls}: status={status_desc} (id={status_id}), waited={waited:.1f}s"
                    )

                # Status 1 = In Queue, 2 = Processing
                if status_id not in [1, 2]:
                    total_time = time.time() - start_time

                    self.logger.info(
                        "Submission completed",
                        extra={
                            "token": token,
                            "final_status": status_desc,
                            "polls": polls,
                            "total_time_sec": round(total_time, 2),
                        }
                    )

                    return result

                time.sleep(poll_interval)
                waited += poll_interval

            except Judge0Error as e:
                self.logger.warning(
                    f"Error during poll {polls}: {e}. Continuing..."
                )
                # Continue polling unless we've exceeded max_wait

        # Timeout reached
        self.logger.error(
            "Submission timeout",
            extra={
                "token": token,
                "max_wait": max_wait,
                "polls": polls,
                "last_status": last_status,
                "last_status_id": last_status_id,
            }
        )

        raise TimeoutError(
            f"Submission {token} did not complete within {max_wait}s. "
            f"Last status: {last_status} (id={last_status_id}). "
            f"Total polls: {polls}"
        )

    def execute(
        self,
        source_code: str,
        language_id: int = 71,
        stdin: str = "",
        wait: bool = True,
        max_wait: Optional[int] = None,
        **kwargs
    ) -> Dict[str, Any]:
        """
        Submit code and optionally wait for results (convenience method).

        Args:
            source_code: The source code to execute
            language_id: Language ID (default: 71 = Python 3)
            stdin: Input to provide to the program
            wait: If True, wait for completion and return results
            max_wait: Maximum seconds to wait if wait=True
            **kwargs: Additional Judge0 submission parameters

        Returns:
            If wait=True: Full submission result
            If wait=False: Dict with just the token

        Raises:
            SubmissionError: If submission fails
            TimeoutError: If wait=True and submission doesn't complete
        """
        operation_start = time.time()

        token = self.submit_code(source_code, language_id, stdin, **kwargs)

        if wait:
            result = self.wait_for_completion(token, max_wait)

            total_time = time.time() - operation_start
            self.logger.info(
                "Execute operation completed",
                extra={
                    "total_time_sec": round(total_time, 2),
                    "token": token,
                }
            )

            return result
        else:
            return {"token": token}

    def get_languages(self) -> list:
        """
        Get list of available languages.

        Returns:
            List of language dictionaries

        Raises:
            Judge0Error: If request fails
        """
        url = f"{self.config.api_url}/languages"
        headers = self.config.get_headers()

        self.logger.debug("Fetching available languages")

        try:
            response = requests.get(url, headers=headers, timeout=self.config.timeout)

            if response.status_code == 200:
                languages = response.json()
                self.logger.info(f"Fetched {len(languages)} languages")
                return languages
            else:
                self.logger.error(
                    f"Failed to get languages: {response.status_code} - {response.text[:200]}"
                )
                raise Judge0Error(
                    f"Failed to get languages: {response.status_code}"
                )

        except requests.RequestException as e:
            self.logger.exception("Network error fetching languages")
            raise Judge0Error(f"Network error: {e}") from e

    def health_check(self, include_details: bool = False) -> Any:
        """
        Check if Judge0 API is accessible with proper logging.

        Args:
            include_details: If True, return detailed health info dict

        Returns:
            If include_details=False: True/False
            If include_details=True: Dict with health details
        """
        details = {
            "healthy": False,
            "api_url": self.config.api_url,
            "error": None,
            "version": None,
            "response_time_ms": None,
        }

        try:
            url = f"{self.config.api_url}/about"
            headers = self.config.get_headers()

            start_time = time.time()
            response = requests.get(url, headers=headers, timeout=5)
            response_time = (time.time() - start_time) * 1000

            details["response_time_ms"] = round(response_time, 2)

            if response.status_code == 200:
                data = response.json()
                details["healthy"] = True
                details["version"] = data.get("version")

                self.logger.info(
                    "Health check passed",
                    extra={
                        "response_time_ms": round(response_time, 2),
                        "version": data.get("version"),
                    }
                )
            else:
                details["error"] = f"Status {response.status_code}"
                self.logger.warning(
                    f"Health check failed: status {response.status_code}"
                )

        except Exception as e:
            details["error"] = str(e)
            self.logger.warning(f"Health check failed: {e}")

        return details if include_details else details["healthy"]
