"""
DSPy Sandbox Helper Utilities
=============================

Reusable utilities for making DSPy concepts visible and experiments easier.
These helpers emphasize the scripting paradigm and make learning interactive.
"""

import json
import time
from typing import Any, Dict, List, Optional
from datetime import datetime
from collections import namedtuple
import dspy
from dspy import BaseLM

# Simple response objects for mock LM
class MockChoice:
    """Represents a choice in the LM response."""
    def __init__(self, text: str, finish_reason: str = "stop"):
        self.text = text
        self.finish_reason = finish_reason
        # Support numeric index access like a tuple
        self._data = [text, finish_reason]

    def __getitem__(self, key):
        """Support both dict-like and numeric access."""
        if isinstance(key, int):
            return self._data[key]
        return getattr(self, key)

class MockUsage:
    """Represents token usage in the response."""
    def __init__(self, prompt_tokens: int, completion_tokens: int):
        self.prompt_tokens = prompt_tokens
        self.completion_tokens = completion_tokens
        self.total_tokens = prompt_tokens + completion_tokens
        self._data = [prompt_tokens, completion_tokens, prompt_tokens + completion_tokens]

    def __getitem__(self, key):
        """Support both dict-like and numeric access."""
        if isinstance(key, int):
            return self._data[key]
        return getattr(self, key)

class MockResponse:
    """Simple response object mimicking OpenAI response structure."""
    def __init__(self, text: str, prompt_tokens: int, completion_tokens: int):
        self.choices = [MockChoice(text=text, finish_reason="stop")]
        self.usage = MockUsage(prompt_tokens=prompt_tokens, completion_tokens=completion_tokens)
        self._data = [self.choices, self.usage]

    def __getitem__(self, key):
        """Support both dict-like and numeric access."""
        if isinstance(key, int):
            return self._data[key]
        return getattr(self, key)

    def keys(self):
        """Support dict-like keys() method."""
        return ['choices', 'usage']

class ScriptingHelper:
    """Utilities for demonstrating the scripting paradigm."""

    @staticmethod
    def show_signature(sig_class: type) -> None:
        """Display a signature's structure in a clear way."""
        print(f"\n📋 Signature: {sig_class.__name__}")
        print("-" * 40)

        if hasattr(sig_class, '__doc__') and sig_class.__doc__:
            print(f"Description: {sig_class.__doc__.strip()}")
            print()

        print("Input Fields:")
        for name, field in sig_class.model_fields.items():
            if isinstance(field.default, dspy.InputField):
                desc = field.default.desc if hasattr(field.default, 'desc') else "No description"
                print(f"  • {name}: {desc}")

        print("\nOutput Fields:")
        for name, field in sig_class.model_fields.items():
            if isinstance(field.default, dspy.OutputField):
                desc = field.default.desc if hasattr(field.default, 'desc') else "No description"
                print(f"  • {name}: {desc}")
        print("-" * 40)

    @staticmethod
    def trace_execution(func):
        """Decorator to trace script execution with timing."""
        def wrapper(*args, **kwargs):
            print(f"\n⏱️  Starting: {func.__name__}")
            start = time.time()

            result = func(*args, **kwargs)

            elapsed = time.time() - start
            print(f"⏱️  Completed: {func.__name__} ({elapsed:.2f}s)")

            return result
        return wrapper

    @staticmethod
    def compare_outputs(outputs: Dict[str, Any]) -> None:
        """Display multiple outputs side by side for comparison."""
        print("\n📊 Comparison Results")
        print("=" * 60)

        for name, output in outputs.items():
            print(f"\n{name}:")
            print("-" * 30)
            if isinstance(output, dict):
                for key, value in output.items():
                    print(f"  {key}: {value}")
            else:
                print(f"  {output}")

        print("=" * 60)


class MockLM(dspy.BaseLM):
    """A mock language model for demonstration without API keys."""

    def __init__(self, responses: Optional[Dict[str, str]] = None):
        super().__init__(model="mock")
        self.responses = responses or self._default_responses()
        self.call_history = []

    def _default_responses(self) -> Dict[str, str]:
        """Provide default responses for common patterns."""
        return {
            "greet": "Hello! It's wonderful to meet you!",
            "summarize": "This is a concise summary of the provided text.",
            "extract": '{"key": "value", "found": true}',
            "classify": "positive",
            "translate": "Translated text here",
            "explain": "This code does X by using Y approach.",
        }

    def forward(self, prompt=None, messages=None, **kwargs):
        """Mock LM forward call matching DSPy's interface."""
        # Handle both prompt and messages formats
        if prompt is None and messages is not None:
            # For chat-based calls, extract from messages
            full_text = " ".join([msg.get("content", "") for msg in messages])
        else:
            full_text = prompt or ""

        self.call_history.append({
            "timestamp": datetime.now(),
            "prompt": full_text,
            "kwargs": kwargs
        })

        # Try to match patterns
        text_lower = full_text.lower()

        response_text = "This is a mock response for demonstration purposes."
        for key, response in self.responses.items():
            if key in text_lower:
                response_text = response
                break

        # Return in OpenAI response format
        return MockResponse(
            text=response_text,
            prompt_tokens=len(full_text.split()),
            completion_tokens=len(response_text.split())
        )

    def show_history(self) -> None:
        """Display the call history for educational purposes."""
        print("\n📜 LM Call History")
        print("-" * 50)
        for i, call in enumerate(self.call_history, 1):
            print(f"\nCall {i}:")
            print(f"  Time: {call['timestamp'].strftime('%H:%M:%S')}")
            print(f"  Prompt preview: {call['prompt'][:100]}...")
        print("-" * 50)


class ExperimentTracker:
    """Track and compare different experiments."""

    def __init__(self):
        self.experiments = []

    def record(self, name: str, config: Dict, result: Any) -> None:
        """Record an experiment's configuration and results."""
        self.experiments.append({
            "name": name,
            "timestamp": datetime.now(),
            "config": config,
            "result": result
        })

    def compare(self) -> None:
        """Display comparison of all recorded experiments."""
        if not self.experiments:
            print("No experiments recorded yet.")
            return

        print("\n🧪 Experiment Comparison")
        print("=" * 60)

        for exp in self.experiments:
            print(f"\nExperiment: {exp['name']}")
            print(f"Time: {exp['timestamp'].strftime('%H:%M:%S')}")
            print("Config:")
            for key, value in exp['config'].items():
                print(f"  {key}: {value}")
            print(f"Result: {exp['result']}")

        print("=" * 60)


class DSPyExplainer:
    """Explain DSPy concepts as code runs."""

    @staticmethod
    def explain_signature():
        """Explain what a signature is."""
        print("""
        🎓 CONCEPT: DSPy Signature

        A Signature is like a CONTRACT or INTERFACE that defines:
        - What inputs your script expects
        - What outputs it will produce

        Think of it like a function signature in programming:
        Instead of: def process(text: str) -> dict
        You define: class Process(dspy.Signature) with fields

        This contract ensures your LLM interactions are predictable
        and can be optimized automatically by DSPy.
        """)

    @staticmethod
    def explain_predict():
        """Explain what Predict does."""
        print("""
        🎓 CONCEPT: DSPy Predict

        Predict is a MODULE that executes your signature contract.
        It's like converting your signature into an actual function.

        Signature = The specification (what should happen)
        Predict = The implementation (making it happen)

        When you call predictor(input=x), DSPy:
        1. Formats your input according to the signature
        2. Sends it to the LLM with proper instructions
        3. Parses the output into the expected structure
        4. Returns a result object with your fields
        """)

    @staticmethod
    def explain_optimization():
        """Explain the optimization concept."""
        print("""
        🎓 CONCEPT: DSPy Optimization

        Unlike traditional prompting where you manually tweak prompts,
        DSPy can AUTOMATICALLY optimize your scripts.

        It's like having a compiler optimize your code:
        - You write the logic (signatures + modules)
        - DSPy finds the best prompts/examples automatically
        - Your script gets better without manual prompt engineering

        This is the power of PROGRAMMING vs PROMPTING:
        The system can improve itself!
        """)


def setup_mock_environment():
    """Set up a mock environment for learning without API keys."""
    print("🔧 Setting up mock environment for learning...")
    mock_lm = MockLM()
    dspy.configure(lm=mock_lm)
    print("✓ Mock environment ready (no API key needed)\n")
    return mock_lm


def validate_api_setup():
    """Check if real API is configured."""
    try:
        import os
        if os.getenv("OPENAI_API_KEY"):
            print("✓ OpenAI API key found")
            return True
        else:
            print("ℹ️  No API key found - using mock mode for learning")
            print("   To use real LLM: export OPENAI_API_KEY='your-key'")
            return False
    except:
        return False


class ProgressBar:
    """Simple progress indicator for long-running operations."""

    def __init__(self, total: int, prefix: str = "Progress"):
        self.total = total
        self.current = 0
        self.prefix = prefix

    def update(self, increment: int = 1):
        """Update the progress bar."""
        self.current += increment
        percent = (self.current / self.total) * 100
        filled = int(percent // 2)
        bar = "█" * filled + "░" * (50 - filled)
        print(f"\r{self.prefix}: [{bar}] {percent:.1f}%", end="")
        if self.current >= self.total:
            print()  # New line when complete