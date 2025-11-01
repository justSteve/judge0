"""
Provider Abstraction Layer
==========================

Flexible LM provider management supporting:
- OpenAI (GPT-4o-mini)
- Anthropic (Claude 3.5 Sonnet)
- Mock LM (offline learning)

Automatically detects available API keys and switches providers intelligently.
"""

import os
from typing import Optional, Union
import dspy
from .helpers import MockLM

# Provider models (can be overridden via environment variables)
PROVIDER_MODELS = {
    "openai": "openai/gpt-4o-mini",
    "anthropic": "anthropic/claude-3-5-sonnet-20241022",
    "mock": None,  # Uses MockLM class
}

# API key environment variable names
API_KEY_ENV_VARS = {
    "openai": "OPENAI_API_KEY",
    "anthropic": "ANTHROPIC_API_KEY",
}


def get_available_providers() -> dict:
    """
    Check which providers have API keys available.

    Returns:
        dict: {'provider_name': True/False, ...}
    """
    available = {
        "openai": bool(os.getenv("OPENAI_API_KEY")),
        "anthropic": bool(os.getenv("ANTHROPIC_API_KEY")),
        "mock": True,  # Always available
    }
    return available


def get_preferred_provider() -> str:
    """
    Determine which provider to use based on:
    1. LM_PROVIDER environment variable (explicit choice)
    2. Available API keys (prefer Anthropic if both present)
    3. Mock as fallback

    Returns:
        str: Provider name ('openai', 'anthropic', or 'mock')
    """
    # Explicit environment variable takes precedence
    if explicit := os.getenv("LM_PROVIDER"):
        return explicit.lower()

    # Check what's available
    available = get_available_providers()

    # Prefer Anthropic if both are available
    if available["anthropic"]:
        return "anthropic"
    elif available["openai"]:
        return "openai"
    else:
        return "mock"


def get_lm(
    provider: Optional[str] = None,
    model: Optional[str] = None,
    verbose: bool = False
) -> Union[dspy.BaseLM, MockLM]:
    """
    Get configured language model for any provider.

    Args:
        provider: Provider name ('openai', 'anthropic', 'mock').
                 If None, auto-detects available provider.
        model: Specific model to use. If None, uses default for provider.
        verbose: Print provider information

    Returns:
        dspy.BaseLM: Configured language model instance

    Examples:
        # Auto-detect (uses Anthropic if key exists, else OpenAI, else mock)
        lm = get_lm()

        # Explicit provider
        lm = get_lm(provider='openai')

        # Explicit model
        lm = get_lm(provider='anthropic', model='anthropic/claude-3-opus-20250219')

        # With debug info
        lm = get_lm(verbose=True)
    """
    # Auto-detect provider if not specified
    if provider is None:
        provider = get_preferred_provider()

    provider = provider.lower()

    # Validate provider
    if provider not in PROVIDER_MODELS:
        raise ValueError(
            f"Unknown provider: {provider}. "
            f"Choose from: {list(PROVIDER_MODELS.keys())}"
        )

    # Handle mock provider
    if provider == "mock":
        if verbose:
            print("🔧 Using Mock LM (offline learning mode)")
        return MockLM()

    # Handle real providers (OpenAI, Anthropic)
    model = model or PROVIDER_MODELS[provider]

    # Check for API key
    api_key_env = API_KEY_ENV_VARS[provider]
    if not os.getenv(api_key_env):
        raise EnvironmentError(
            f"Missing API key for {provider}. "
            f"Set {api_key_env} environment variable or use mock provider."
        )

    # Create LM instance
    lm = dspy.LM(model)

    if verbose:
        print(f"✓ Configured {provider.upper()}: {model}")

    return lm


def configure_dspy(
    provider: Optional[str] = None,
    model: Optional[str] = None,
    verbose: bool = False
) -> Union[dspy.BaseLM, MockLM]:
    """
    Configure DSPy with the specified (or auto-detected) provider.

    Args:
        provider: Provider name (auto-detected if None)
        model: Specific model (uses default if None)
        verbose: Print configuration info

    Returns:
        dspy.BaseLM: The configured LM instance

    Example:
        lm = configure_dspy(verbose=True)
        # Now dspy.settings.lm is configured
    """
    lm = get_lm(provider=provider, model=model, verbose=verbose)
    dspy.configure(lm=lm)
    return lm


def show_provider_info():
    """Display available providers and their status."""
    available = get_available_providers()
    preferred = get_preferred_provider()

    print("\n" + "=" * 50)
    print("📊 Provider Status")
    print("=" * 50)

    print("\nAvailable Providers:")
    for provider, is_available in available.items():
        status = "✓ Available" if is_available else "✗ Not Available"
        star = " (PREFERRED)" if provider == preferred else ""
        print(f"  {provider:12} {status}{star}")

    print(f"\n🎯 Default Provider: {preferred.upper()}")
    print("=" * 50 + "\n")


# Convenience function for setup in lessons
def setup_sandbox_lm(verbose: bool = True) -> Union[dspy.BaseLM, MockLM]:
    """
    One-line setup for DSPy in sandbox lessons.

    Args:
        verbose: Print setup information

    Returns:
        dspy.BaseLM: Configured LM instance
    """
    try:
        return configure_dspy(verbose=verbose)
    except EnvironmentError as e:
        if verbose:
            print(f"⚠️  Warning: {e}")
            print("Falling back to Mock LM")
        return configure_dspy(provider="mock", verbose=verbose)