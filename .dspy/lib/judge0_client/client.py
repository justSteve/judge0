"""
Judge0 API Client
=================

Main client for interacting with Judge0 code execution API.
"""

import requests
import time
from typing import Optional, Dict, Any
from .exceptions import Judge0Error, SubmissionError, TimeoutError
from .config import Judge0Config


class Judge0Client:
    """Client for Judge0 code execution API."""

    def __init__(self, config: Optional[Judge0Config] = None):
        """
        Initialize Judge0 client.

        Args:
            config: Judge0Config instance. If None, uses default config.
        """
        self.config = config or Judge0Config.from_env()

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

        Args:
            source_code: The source code to execute
            language_id: Language ID (default: 71 = Python 3)
            stdin: Input to provide to the program
            expected_output: Expected output for validation
            **kwargs: Additional Judge0 submission parameters

        Returns:
            Submission token (string)

        Raises:
            SubmissionError: If submission fails
        """
        url = f"{self.config.api_url}/submissions"

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
            response = requests.post(
                url,
                json=payload,
                headers=headers,
                timeout=self.config.timeout
            )

            if response.status_code == 201:
                token = response.json().get("token")
                if not token:
                    raise SubmissionError("No token in response")
                return token
            else:
                raise SubmissionError(
                    f"Submission failed with status {response.status_code}: {response.text}"
                )
        except requests.RequestException as e:
            raise SubmissionError(f"Network error: {str(e)}")

    def get_submission(self, token: str, **kwargs) -> Dict[str, Any]:
        """
        Get submission results from Judge0.

        Args:
            token: Submission token
            **kwargs: Additional query parameters (e.g., fields, base64_encoded)

        Returns:
            Submission result dictionary

        Raises:
            Judge0Error: If request fails
        """
        url = f"{self.config.api_url}/submissions/{token}"
        headers = self.config.get_headers()

        # Build query parameters
        params = kwargs if kwargs else None

        try:
            response = requests.get(
                url,
                headers=headers,
                params=params,
                timeout=self.config.timeout
            )

            if response.status_code == 200:
                return response.json()
            else:
                raise Judge0Error(
                    f"Failed to get submission: {response.status_code} - {response.text}"
                )
        except requests.RequestException as e:
            raise Judge0Error(f"Network error: {str(e)}")

    def wait_for_completion(
        self,
        token: str,
        max_wait: Optional[int] = None,
        poll_interval: float = 0.5
    ) -> Dict[str, Any]:
        """
        Wait for submission to complete.

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

        while waited < max_wait:
            result = self.get_submission(token)
            status_id = result.get("status", {}).get("id")

            # Status 1 = In Queue, 2 = Processing
            if status_id not in [1, 2]:
                return result

            time.sleep(poll_interval)
            waited += poll_interval

        raise TimeoutError(f"Submission did not complete within {max_wait} seconds")

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
        token = self.submit_code(source_code, language_id, stdin, **kwargs)

        if wait:
            return self.wait_for_completion(token, max_wait)
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

        try:
            response = requests.get(url, headers=headers, timeout=self.config.timeout)

            if response.status_code == 200:
                return response.json()
            else:
                raise Judge0Error(f"Failed to get languages: {response.text}")
        except requests.RequestException as e:
            raise Judge0Error(f"Network error: {str(e)}")

    def health_check(self) -> bool:
        """
        Check if Judge0 API is accessible.

        Returns:
            True if API is responding, False otherwise
        """
        try:
            url = f"{self.config.api_url}/about"
            headers = self.config.get_headers()
            response = requests.get(url, headers=headers, timeout=5)
            return response.status_code == 200
        except:
            return False
