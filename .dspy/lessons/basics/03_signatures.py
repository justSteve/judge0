"""
Lesson 03: Signatures - Defining Your Script's Contract
========================================================

Signatures are the foundation of DSPy scripting. They define exactly
what your script expects as input and what it will produce as output.
Think of them as strongly-typed function signatures for LLM operations.

Key Concepts:
- Signatures are contracts between your code and the LLM
- Input fields define what data you provide
- Output fields define what structure you get back
- Descriptions guide the LLM's behavior
"""

import sys
from pathlib import Path
sys.path.append(str(Path(__file__).parent.parent.parent))

import dspy
from lib.helpers import ScriptingHelper, DSPyExplainer, setup_mock_environment

def main():
    print("🎯 Lesson 03: Signatures as Contracts\n")

    # Setup environment
    setup_mock_environment()

    # ============================================================
    # PART 1: Understanding Signatures
    # ============================================================

    print("=" * 50)
    print("PART 1: What is a Signature?")
    print("=" * 50)

    DSPyExplainer.explain_signature()

    # ============================================================
    # PART 2: Building Different Types of Signatures
    # ============================================================

    print("=" * 50)
    print("PART 2: Signature Examples")
    print("=" * 50)
    print()

    # Example 1: Simple transformation
    print("Example 1: Simple Transformation")
    print("-" * 30)
    print("```python")
    print("class Translate(dspy.Signature):")
    print('    """Translate text to another language."""')
    print("    text = dspy.InputField(desc='Text to translate')")
    print("    target_language = dspy.InputField(desc='Target language')")
    print("    translation = dspy.OutputField(desc='Translated text')")
    print("```")

    class Translate(dspy.Signature):
        """Translate text to another language."""
        text = dspy.InputField(desc="Text to translate")
        target_language = dspy.InputField(desc="Target language")
        translation = dspy.OutputField(desc="Translated text")

    ScriptingHelper.show_signature(Translate)

    # Example 2: Analysis with multiple outputs
    print("\nExample 2: Multiple Outputs")
    print("-" * 30)
    print("```python")
    print("class SentimentAnalysis(dspy.Signature):")
    print('    """Analyze sentiment and extract key phrases."""')
    print("    text = dspy.InputField()")
    print("    sentiment = dspy.OutputField(desc='positive, negative, or neutral')")
    print("    confidence = dspy.OutputField(desc='confidence score 0-100')")
    print("    key_phrases = dspy.OutputField(desc='comma-separated phrases')")
    print("```")

    class SentimentAnalysis(dspy.Signature):
        """Analyze sentiment and extract key phrases."""
        text = dspy.InputField()
        sentiment = dspy.OutputField(desc="positive, negative, or neutral")
        confidence = dspy.OutputField(desc="confidence score 0-100")
        key_phrases = dspy.OutputField(desc="comma-separated phrases")

    ScriptingHelper.show_signature(SentimentAnalysis)

    # Example 3: Complex data extraction
    print("\nExample 3: Structured Data Extraction")
    print("-" * 30)
    print("```python")
    print("class ExtractEvent(dspy.Signature):")
    print('    """Extract event information from text."""')
    print("    text = dspy.InputField(desc='Text containing event info')")
    print("    event_name = dspy.OutputField(desc='Name of the event')")
    print("    date = dspy.OutputField(desc='Date in YYYY-MM-DD format')")
    print("    location = dspy.OutputField(desc='Event location')")
    print("    attendees = dspy.OutputField(desc='Expected number or list')")
    print("```")

    class ExtractEvent(dspy.Signature):
        """Extract event information from text."""
        text = dspy.InputField(desc="Text containing event info")
        event_name = dspy.OutputField(desc="Name of the event")
        date = dspy.OutputField(desc="Date in YYYY-MM-DD format")
        location = dspy.OutputField(desc="Event location")
        attendees = dspy.OutputField(desc="Expected number or list")

    ScriptingHelper.show_signature(ExtractEvent)

    # ============================================================
    # PART 3: Using Signatures in Practice
    # ============================================================

    print("\n" + "=" * 50)
    print("PART 3: Putting Signatures to Work")
    print("=" * 50)
    print()

    print("Let's use the SentimentAnalysis signature:")
    print()

    # Create the module
    analyzer = dspy.Predict(SentimentAnalysis)

    # Test text
    test_text = "This workshop was absolutely fantastic! I learned so much."

    print(f"Input text: '{test_text}'")
    print("\nRunning analysis...")

    # Execute
    result = analyzer(text=test_text)

    print("\n📊 Results (Structured Output):")
    print("-" * 30)
    print(f"Sentiment:    {result.sentiment}")
    print(f"Confidence:   {result.confidence}")
    print(f"Key Phrases:  {result.key_phrases}")
    print("-" * 30)

    print("\nNotice how we get EXACTLY the fields we defined!")
    print("No parsing, no guessing - just structured data.\n")

    # ============================================================
    # PART 4: Signature Design Principles
    # ============================================================

    print("=" * 50)
    print("PART 4: Design Principles")
    print("=" * 50)
    print("""
    GOOD SIGNATURE DESIGN:

    1. BE SPECIFIC: Use descriptions to guide behavior
       ✅ desc="Date in YYYY-MM-DD format"
       ❌ desc="date"

    2. SINGLE RESPONSIBILITY: Each signature does one thing
       ✅ class ExtractDates(dspy.Signature)
       ❌ class DoEverything(dspy.Signature)

    3. PREDICTABLE OUTPUTS: Define clear output types
       ✅ score = OutputField(desc="integer 0-100")
       ❌ result = OutputField(desc="some analysis")

    4. COMPOSABLE: Design signatures that chain well
       ✅ Extract -> Analyze -> Summarize
       ❌ One giant signature with 20 fields

    5. TESTABLE: You should be able to validate outputs
       ✅ category = OutputField(desc="one of: tech, finance, health")
       ❌ thoughts = OutputField(desc="any thoughts")
    """)

    # ============================================================
    # PART 5: Exercise
    # ============================================================

    print("=" * 50)
    print("PART 5: Your Turn!")
    print("=" * 50)
    print("""
    EXERCISE: Create signatures for these tasks:

    1. CodeReview signature:
       - Input: code (the code to review)
       - Output: issues, suggestions, quality_score

    2. RecipeParser signature:
       - Input: recipe_text
       - Output: ingredients, steps, cooking_time, difficulty

    3. EmailClassifier signature:
       - Input: email_content
       - Output: category, priority, requires_response

    Add these to this file and run again to see them in action!
    """)

    return {
        "lesson": "03_signatures",
        "concepts": ["Signatures", "Contracts", "Field descriptions", "Design principles"],
        "success": True
    }

if __name__ == "__main__":
    main()