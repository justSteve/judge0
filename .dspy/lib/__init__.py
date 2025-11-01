"""
DSPy Sandbox Library
====================

Utilities and helpers for learning DSPy through scripting.
"""

from .helpers import (
    ScriptingHelper,
    MockLM,
    ExperimentTracker,
    DSPyExplainer,
    setup_mock_environment,
    validate_api_setup,
    ProgressBar,
)

from .providers import (
    get_lm,
    configure_dspy,
    get_available_providers,
    get_preferred_provider,
    setup_sandbox_lm,
    show_provider_info,
)

__all__ = [
    # Helpers
    'ScriptingHelper',
    'MockLM',
    'ExperimentTracker',
    'DSPyExplainer',
    'setup_mock_environment',
    'validate_api_setup',
    'ProgressBar',
    # Providers
    'get_lm',
    'configure_dspy',
    'get_available_providers',
    'get_preferred_provider',
    'setup_sandbox_lm',
    'show_provider_info',
]