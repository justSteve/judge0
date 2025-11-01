# Judge0 Python Client Library

A simple, clean Python client for interacting with Judge0 code execution API.

## Installation

```python
# Add to your Python path or install locally
import sys
sys.path.append('/path/to/judge0/.dspy/lib')

from judge0_client import Judge0Client, Judge0Config
```

## Quick Start

### Local Judge0 Instance

```python
from judge0_client import Judge0Client, Judge0Config

# Create client for local instance
config = Judge0Config.local()
client = Judge0Client(config)

# Execute code
result = client.execute(
    source_code='print("Hello, World!")',
    language_id=71  # Python 3
)

print(result['stdout'])  # Hello, World!
```

### Azure VM Instance

```python
from judge0_client import Judge0Client, Judge0Config

# Create client for Azure instance
config = Judge0Config.azure(host="your-vm-ip.azure.com")
client = Judge0Client(config)

# Execute code
result = client.execute('print("Hello from Azure!")')
print(result['stdout'])
```

### RapidAPI Instance

```python
from judge0_client import Judge0Client, Judge0Config

# Create client for RapidAPI
config = Judge0Config.rapidapi(api_key="your-rapidapi-key")
client = Judge0Client(config)

# Execute code
result = client.execute('print("Hello from RapidAPI!")')
print(result['stdout'])
```

## Configuration

### Environment Variables

```bash
# Set environment variables
export JUDGE0_API_URL="http://localhost:2358"
export JUDGE0_API_KEY="your-key"  # Optional, for RapidAPI
export JUDGE0_API_HOST="judge0-ce.p.rapidapi.com"  # Optional, for RapidAPI
export JUDGE0_TIMEOUT="30"
export JUDGE0_MAX_WAIT="60"
```

```python
# Load from environment
from judge0_client import Judge0Client, Judge0Config

config = Judge0Config.from_env()
client = Judge0Client(config)
```

### Manual Configuration

```python
from judge0_client import Judge0Config

config = Judge0Config(
    api_url="http://localhost:2358",
    timeout=30,
    max_wait=60
)
```

## API Reference

### Judge0Client

#### `__init__(config: Optional[Judge0Config] = None)`
Initialize client with optional configuration.

#### `submit_code(source_code, language_id=71, stdin="", **kwargs) -> str`
Submit code for execution. Returns submission token.

**Parameters:**
- `source_code` (str): The source code to execute
- `language_id` (int): Language ID (default: 71 = Python 3)
- `stdin` (str): Input to provide to the program
- `expected_output` (str, optional): Expected output for validation
- `**kwargs`: Additional Judge0 parameters

**Returns:** Submission token (string)

#### `get_submission(token: str, **kwargs) -> Dict`
Get submission results.

**Parameters:**
- `token` (str): Submission token
- `**kwargs`: Additional query parameters

**Returns:** Submission result dictionary

#### `wait_for_completion(token: str, max_wait: int = None, poll_interval: float = 0.5) -> Dict`
Wait for submission to complete.

**Parameters:**
- `token` (str): Submission token
- `max_wait` (int): Maximum seconds to wait
- `poll_interval` (float): Seconds between polls

**Returns:** Final submission result

#### `execute(source_code, language_id=71, stdin="", wait=True, **kwargs) -> Dict`
Submit and optionally wait for results (convenience method).

**Parameters:**
- `source_code` (str): The source code to execute
- `language_id` (int): Language ID
- `stdin` (str): Input to program
- `wait` (bool): Wait for completion
- `**kwargs`: Additional parameters

**Returns:** Submission result or token dict

#### `get_languages() -> list`
Get list of available languages.

#### `health_check() -> bool`
Check if API is accessible.

### Judge0Config

#### Configuration Methods

- `Judge0Config.from_env()` - Load from environment variables
- `Judge0Config.local(port=2358)` - Local instance
- `Judge0Config.azure(host, port=2358)` - Azure VM instance
- `Judge0Config.rapidapi(api_key)` - RapidAPI instance

## Language IDs

Common language IDs:
- **71** - Python 3
- **63** - JavaScript (Node.js)
- **50** - C (GCC)
- **54** - C++ (GCC)
- **62** - Java
- **78** - Kotlin
- **80** - R
- **82** - SQL
- **83** - Swift

Get full list: `client.get_languages()`

## Error Handling

```python
from judge0_client import Judge0Client, Judge0Error, SubmissionError, TimeoutError

client = Judge0Client()

try:
    result = client.execute('print("test")')
except SubmissionError as e:
    print(f"Submission failed: {e}")
except TimeoutError as e:
    print(f"Execution timed out: {e}")
except Judge0Error as e:
    print(f"Judge0 error: {e}")
```

## Advanced Usage

### Async Execution

```python
# Submit without waiting
result = client.execute(source_code, wait=False)
token = result['token']

# Do other work...

# Later, check result
final_result = client.wait_for_completion(token)
```

### With Expected Output

```python
result = client.execute(
    source_code='print("Hello")',
    expected_output="Hello\n"
)

status = result['status']['id']
# 3 = Accepted (output matches expected)
# 4 = Wrong Answer (output doesn't match)
```

### Custom Time Limits

```python
result = client.submit_code(
    source_code='import time; time.sleep(5)',
    cpu_time_limit=2.0,  # 2 seconds max
    wall_time_limit=5.0,  # 5 seconds max
)
```

## Examples

### Running Tests

```python
from judge0_client import Judge0Client

client = Judge0Client()

test_cases = [
    ("print(2 + 2)", "4\n"),
    ("print('hello')", "hello\n"),
]

for code, expected in test_cases:
    result = client.execute(code, expected_output=expected)
    status = result['status']['description']
    print(f"Test: {status}")
```

### Multi-Language Support

```python
codes = {
    71: 'print("Python")',
    63: 'console.log("JavaScript")',
    62: 'public class Main { public static void main(String[] args) { System.out.println("Java"); } }'
}

for lang_id, code in codes.items():
    result = client.execute(code, language_id=lang_id)
    print(f"Language {lang_id}: {result['stdout'].strip()}")
```

## Integration with DSPy

See [lessons/basics/01_hello_dspy_j0.py](../../lessons/basics/01_hello_dspy_j0.py) for example usage in DSPy workflows.

## Contributing

This is a simple client library. To extend:

1. Add new methods to `Judge0Client` class
2. Update exceptions in `exceptions.py`
3. Add configuration options in `config.py`
4. Document in this README

## License

Part of Judge0 project. See main LICENSE file.
