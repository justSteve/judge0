"""
Lesson 01: Hello DSPy - Running Through Judge0
===============================================

This is a simplified version of the DSPy "Hello World" lesson that runs
through Judge0 for code execution.

Key Concepts:
- Submit Python code to Judge0 API
- Wait for execution results
- Display structured output

Judge0 API Basics:
- POST /submissions - Submit code with language_id and source_code
- GET /submissions/{token} - Get execution results
- Language ID 71 = Python 3
"""

import requests
import time
import json

# Judge0 API endpoint (using the free public instance)
# Note: For production, you should use your own instance or a paid plan
JUDGE0_API = "https://judge0-ce.p.rapidapi.com"

def submit_code(source_code, language_id=71, stdin=""):
    """
    Submit code to Judge0 for execution.

    Args:
        source_code: The Python code to execute
        language_id: Language ID (71 = Python 3)
        stdin: Input to provide to the program

    Returns:
        Submission token
    """
    url = f"{JUDGE0_API}/submissions"

    payload = {
        "source_code": source_code,
        "language_id": language_id,
        "stdin": stdin
    }

    headers = {
        "content-type": "application/json",
        "X-RapidAPI-Key": "YOUR_RAPIDAPI_KEY_HERE",  # Replace with your key
        "X-RapidAPI-Host": "judge0-ce.p.rapidapi.com"
    }

    # For local Judge0 instance (if running your own):
    # url = "http://localhost:2358/submissions?wait=true"
    # headers = {"content-type": "application/json"}

    response = requests.post(url, json=payload, headers=headers)

    if response.status_code == 201:
        return response.json().get("token")
    else:
        raise Exception(f"Submission failed: {response.text}")


def get_submission(token):
    """
    Get submission results from Judge0.

    Args:
        token: Submission token

    Returns:
        Submission result dictionary
    """
    url = f"{JUDGE0_API}/submissions/{token}"

    headers = {
        "X-RapidAPI-Key": "YOUR_RAPIDAPI_KEY_HERE",  # Replace with your key
        "X-RapidAPI-Host": "judge0-ce.p.rapidapi.com"
    }

    # For local Judge0 instance:
    # url = f"http://localhost:2358/submissions/{token}"
    # headers = {}

    response = requests.get(url, headers=headers)

    if response.status_code == 200:
        return response.json()
    else:
        raise Exception(f"Failed to get submission: {response.text}")


def wait_for_completion(token, max_wait=10):
    """
    Wait for submission to complete.

    Args:
        token: Submission token
        max_wait: Maximum seconds to wait

    Returns:
        Final submission result
    """
    waited = 0
    while waited < max_wait:
        result = get_submission(token)
        status_id = result.get("status", {}).get("id")

        # Status 1 = In Queue, 2 = Processing
        if status_id not in [1, 2]:
            return result

        time.sleep(0.5)
        waited += 0.5

    raise Exception("Timeout waiting for submission")


def main():
    print("Lesson 01: Hello DSPy (via Judge0)\n")
    print("=" * 50)

    # The DSPy-inspired code we want to run
    # This is a simplified version that doesn't require DSPy installation
    dspy_code = '''
# Simulated DSPy greeting (without actual DSPy dependency)

class GreetUser:
    """Simulates a DSPy signature for greeting users."""

    def __init__(self, name):
        self.name = name

    def generate_greeting(self):
        # In real DSPy, this would use an LLM
        # For this demo, we'll use a simple template
        return f"Hello, {self.name}! It's wonderful to meet you!"

# Create and execute
greeter = GreetUser("Alice")
result = greeter.generate_greeting()

print(f"Input: name = 'Alice'")
print(f"Output: {result}")
'''

    print("Step 1: Submitting code to Judge0...")
    print(f"Code length: {len(dspy_code)} characters")
    print()

    try:
        # Submit code to Judge0
        token = submit_code(dspy_code)
        print(f"Submission created with token: {token}")
        print()

        # Wait for execution
        print("Step 2: Waiting for execution...")
        result = wait_for_completion(token)
        print()

        # Display results
        print("Step 3: Results")
        print("=" * 50)

        status = result.get("status", {})
        print(f"Status: {status.get('description')}")
        print(f"Execution Time: {result.get('time')} seconds")
        print(f"Memory Used: {result.get('memory')} KB")
        print()

        if result.get("stdout"):
            print("Output:")
            print(result["stdout"])

        if result.get("stderr"):
            print("Errors:")
            print(result["stderr"])

        if result.get("compile_output"):
            print("Compilation:")
            print(result["compile_output"])

        print()
        print("=" * 50)
        print("Lesson Complete!")
        print()
        print("What you learned:")
        print("- How to submit code to Judge0 API")
        print("- How to poll for execution results")
        print("- How to handle execution status and output")

        return {
            "lesson": "01_hello_dspy_j0",
            "token": token,
            "status": status.get("description"),
            "success": True
        }

    except Exception as e:
        print(f"Error: {e}")
        print()
        print("Note: This example requires either:")
        print("1. A RapidAPI key (set YOUR_RAPIDAPI_KEY_HERE)")
        print("2. A local Judge0 instance running (uncomment local URLs)")
        print()
        print("For testing without API access, see the mock version below:")
        print()

        # Mock execution result for demonstration
        print("=" * 50)
        print("MOCK EXECUTION RESULT")
        print("=" * 50)
        print("Status: Accepted")
        print("Execution Time: 0.023 seconds")
        print("Memory Used: 3840 KB")
        print()
        print("Output:")
        print("Input: name = 'Alice'")
        print("Output: Hello, Alice! It's wonderful to meet you!")
        print()

        return {
            "lesson": "01_hello_dspy_j0",
            "status": "mock",
            "success": False,
            "error": str(e)
        }


if __name__ == "__main__":
    result = main()
    print()
    print(f"Result: {json.dumps(result, indent=2)}")
