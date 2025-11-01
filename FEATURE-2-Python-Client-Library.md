# Feature 2: Judge0 Python Client Library

## Overview

A clean, simple Python client library for interacting with Judge0 API, designed for use in DSPy workflows and code execution tasks.

## Status

✅ **COMPLETE** - Ready for use

## Problem Statement

Current challenges with Judge0 integration:
- No standardized Python client
- Repetitive code for API calls
- Configuration management scattered
- No clean error handling
- Difficult to switch between local/Azure/RapidAPI instances

## Solution

A simple, focused Python client library with:
- Clean API for code submission and execution
- Flexible configuration management
- Proper error handling
- Support for local, Azure, and RapidAPI instances
- Type hints and documentation
- DSPy integration ready

## Components

### Core Modules

**Location:** `.dspy/lib/judge0_client/`

1. **client.py** - Main Judge0Client class
   - `submit_code()` - Submit code for execution
   - `get_submission()` - Get results
   - `wait_for_completion()` - Poll until done
   - `execute()` - Submit and wait (convenience)
   - `get_languages()` - List available languages
   - `health_check()` - Validate API availability

2. **config.py** - Configuration management
   - `Judge0Config` - Main config class
   - `.from_env()` - Load from environment
   - `.local()` - Local instance config
   - `.azure()` - Azure VM config
   - `.rapidapi()` - RapidAPI config

3. **exceptions.py** - Custom exceptions
   - `Judge0Error` - Base exception
   - `SubmissionError` - Submission failures
   - `TimeoutError` - Execution timeouts
   - `ConfigurationError` - Config issues

4. **__init__.py** - Package interface

### Documentation

- `.dspy/lib/judge0_client/README.md` - Complete API reference and examples

### Example Integration

- `.dspy/lessons/basics/01_hello_dspy_j0.py` - DSPy lesson using the client

## Features

### ✅ Simple API

```python
from judge0_client import Judge0Client, Judge0Config

# Quick start - local instance
client = Judge0Client()
result = client.execute('print("Hello!")')
print(result['stdout'])  # Hello!
```

### ✅ Flexible Configuration

```python
# Local instance
config = Judge0Config.local()

# Azure VM
config = Judge0Config.azure(host="your-vm.azure.com")

# RapidAPI
config = Judge0Config.rapidapi(api_key="your-key")

# Environment variables
config = Judge0Config.from_env()
```

### ✅ Error Handling

```python
from judge0_client import Judge0Error, SubmissionError, TimeoutError

try:
    result = client.execute(code)
except SubmissionError as e:
    print(f"Submission failed: {e}")
except TimeoutError as e:
    print(f"Timed out: {e}")
```

### ✅ Async Support

```python
# Submit without waiting
result = client.execute(code, wait=False)
token = result['token']

# Do other work...

# Check later
final = client.wait_for_completion(token)
```

### ✅ Multi-Language

```python
# Python
result = client.execute(code, language_id=71)

# JavaScript
result = client.execute(code, language_id=63)

# C++
result = client.execute(code, language_id=54)
```

## API Reference

### Judge0Client

#### Methods

**`__init__(config: Optional[Judge0Config] = None)`**
- Initialize client with optional configuration
- Default: local instance at localhost:2358

**`submit_code(source_code, language_id=71, stdin="", **kwargs) -> str`**
- Submit code for execution
- Returns submission token

**`get_submission(token: str) -> Dict`**
- Get submission results by token

**`wait_for_completion(token: str, max_wait: int = None) -> Dict`**
- Poll until submission completes
- Raises TimeoutError if exceeds max_wait

**`execute(source_code, language_id=71, stdin="", wait=True) -> Dict`**
- Convenience method: submit + wait
- Returns full result dict

**`get_languages() -> list`**
- Get available languages

**`health_check() -> bool`**
- Check if API is accessible

### Judge0Config

#### Class Methods

**`from_env() -> Judge0Config`**
- Load from environment variables
- `JUDGE0_API_URL`, `JUDGE0_API_KEY`, etc.

**`local(port=2358) -> Judge0Config`**
- Local instance configuration

**`azure(host: str, port=2358) -> Judge0Config`**
- Azure VM configuration

**`rapidapi(api_key: str) -> Judge0Config`**
- RapidAPI configuration

## Usage Examples

### Basic Execution

```python
from judge0_client import Judge0Client

client = Judge0Client()

code = """
def greet(name):
    return f"Hello, {name}!"

print(greet("Alice"))
"""

result = client.execute(code)
print(result['stdout'])  # Hello, Alice!
```

### With Input

```python
code = """
name = input()
print(f"Hello, {name}!")
"""

result = client.execute(code, stdin="Bob")
print(result['stdout'])  # Hello, Bob!
```

### Expected Output Validation

```python
result = client.execute(
    source_code='print("test")',
    expected_output="test\n"
)

status = result['status']['id']
# 3 = Accepted
# 4 = Wrong Answer
```

### DSPy Integration

```python
import dspy
from judge0_client import Judge0Client

class CodeExecutor(dspy.Signature):
    """Execute Python code and return output."""
    code = dspy.InputField()
    output = dspy.OutputField()

# Custom module using Judge0
class Judge0Executor(dspy.Module):
    def __init__(self):
        super().__init__()
        self.client = Judge0Client()

    def forward(self, code):
        result = self.client.execute(code)
        return dspy.Prediction(output=result['stdout'])
```

## Installation

### Method 1: Add to Python Path

```python
import sys
sys.path.append('/path/to/judge0/.dspy/lib')

from judge0_client import Judge0Client
```

### Method 2: Install as Package

```bash
cd /path/to/judge0/.dspy/lib
pip install -e ./judge0_client
```

### Method 3: Copy to Project

```bash
cp -r .dspy/lib/judge0_client /your/project/
```

## Configuration

### Environment Variables

```bash
export JUDGE0_API_URL="http://localhost:2358"
export JUDGE0_API_KEY="your-rapidapi-key"  # Optional
export JUDGE0_API_HOST="judge0-ce.p.rapidapi.com"  # Optional
export JUDGE0_TIMEOUT="30"
export JUDGE0_MAX_WAIT="60"
```

### Python Configuration

```python
from judge0_client import Judge0Config

# Manual config
config = Judge0Config(
    api_url="http://your-azure-vm:2358",
    timeout=30,
    max_wait=60
)
```

## Testing

### Unit Tests

```python
# Test basic execution
client = Judge0Client()
result = client.execute('print("test")')
assert result['stdout'].strip() == "test"

# Test error handling
try:
    client.execute('invalid python code')
except SubmissionError:
    pass  # Expected

# Test timeout
try:
    client.execute('import time; time.sleep(100)', max_wait=1)
except TimeoutError:
    pass  # Expected
```

### Integration Test

```python
# Test against actual Judge0 instance
client = Judge0Client()

# Health check
assert client.health_check() == True

# Get languages
languages = client.get_languages()
assert len(languages) > 0

# Execute sample code
result = client.execute('print(2 + 2)')
assert '4' in result['stdout']
```

## Benefits

1. **Simplicity** - Clean, intuitive API
2. **Flexibility** - Supports local, Azure, RapidAPI
3. **Safety** - Proper error handling and timeouts
4. **Integration** - Ready for DSPy workflows
5. **Documentation** - Complete API reference
6. **Testability** - Easy to mock and test

## Use Cases

### 1. Code Testing Platform
Run student code submissions and validate output

### 2. DSPy Code Generation
Execute LLM-generated code to verify correctness

### 3. Multi-Language Support
Execute code in 60+ languages

### 4. Code Tutorials
Interactive coding lessons with real execution

### 5. Competitive Programming
Test solutions against test cases

## Dependencies

```
requests>=2.25.0
```

No other dependencies - intentionally minimal.

## Future Enhancements

### Planned
- Batch submission support
- Webhook callbacks
- Retry logic with exponential backoff
- Result caching
- Streaming output

### Proposed
- Async/await support (async client)
- Context managers for resource cleanup
- Progress callbacks
- File upload support
- Custom compiler options helpers

## Migration Guide

### From Raw API Calls

**Before:**
```python
import requests

response = requests.post(
    "http://localhost:2358/submissions",
    json={"source_code": code, "language_id": 71}
)
token = response.json()['token']

# Poll for result...
while True:
    result = requests.get(f"http://localhost:2358/submissions/{token}")
    # ... complex polling logic
```

**After:**
```python
from judge0_client import Judge0Client

client = Judge0Client()
result = client.execute(code)
```

## Support

**Documentation:**
- [Client README](.dspy/lib/judge0_client/README.md)
- [Example Lesson](.dspy/lessons/basics/01_hello_dspy_j0.py)

**Common Issues:**
- Import errors → Check Python path
- Connection refused → Verify Judge0 is running
- Timeout errors → Increase max_wait parameter
- API key errors → Check RapidAPI configuration

## Metrics

**Code:**
- 4 Python modules (~600 lines)
- 1 README with full API reference
- 1 example integration (DSPy lesson)

**Coverage:**
- All major Judge0 API endpoints
- Error handling for common failures
- Configuration for all deployment types

**Testing:**
- Manual testing completed
- Integration with Judge0 validated
- Error cases verified

## Sign-Off

**Feature:** Judge0 Python Client Library
**Status:** ✅ Complete
**Ready for:** Production use
**Dependencies:** requests>=2.25.0
**Python:** 3.7+
**Documentation:** Complete
**Testing:** Manual validation complete

---

**Submitted by:** Claude Code
**Date:** 2025-11-01
**Version:** 0.1.0
