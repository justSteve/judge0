"""
Lesson 02: Chat vs Script - Understanding the Paradigm Shift
============================================================

This lesson shows the fundamental difference between "chatting" with
an LLM and "scripting" with DSPy. We'll solve the same problem both
ways to see why scripting is more powerful for building systems.

Key Concepts:
- Chat paradigm: Unstructured, conversational, unpredictable
- Script paradigm: Structured, functional, predictable
- Why scripting enables building reliable AI systems
"""

import dspy
import json

def main(mode="demo"):
    print("🎯 Lesson 02: Chat vs Script Paradigm\n")

    # The task we'll solve both ways
    task_description = """
    TASK: Extract key information from a product review:
    - Overall sentiment (positive/negative/neutral)
    - Main pros mentioned
    - Main cons mentioned
    - Would they recommend it? (yes/no/unclear)
    """

    sample_review = """
    I bought this coffee maker last month and I have mixed feelings.
    On the positive side, it makes great coffee and heats up quickly.
    The design is sleek and doesn't take much counter space.
    However, it's quite expensive and the water reservoir is small,
    so I have to refill it often. The controls are a bit confusing at first.
    Overall, I'd probably recommend it to coffee enthusiasts who don't mind
    the price, but casual coffee drinkers might want something simpler.
    """

    print("📝 Sample Review:")
    print("-" * 40)
    print(sample_review.strip())
    print("-" * 40)
    print()

    # ============================================================
    # APPROACH 1: The Chat Way (What Most People Do)
    # ============================================================

    if mode == "compare" or mode == "demo":
        print("=" * 50)
        print("APPROACH 1: Chat Paradigm 💬")
        print("=" * 50)
        print()

        print("In the CHAT paradigm, you write prompts like:")
        print()
        print('prompt = f"""')
        print('Please analyze this review and tell me:')
        print('- The sentiment')
        print('- The pros')
        print('- The cons')
        print('- If they would recommend it')
        print()
        print('Review: {review}')
        print('"""')
        print()

        print("Problems with this approach:")
        print("❌ Output format varies each time")
        print("❌ Need to parse natural language response")
        print("❌ Hard to integrate into larger systems")
        print("❌ No guarantees about what fields you'll get")
        print("❌ Prompt engineering becomes a dark art")
        print()

        # Simulate what you might get back
        print("Example unstructured response:")
        print("-" * 40)
        print("""Based on the review, the sentiment appears to be mixed or neutral.
The reviewer mentions several pros including great coffee quality,
quick heating, and sleek design. As for cons, they note the high price
and small water reservoir. They would conditionally recommend it...""")
        print("-" * 40)
        print()
        print("Now you have to PARSE this text to extract the data! 😰")
        print()

    # ============================================================
    # APPROACH 2: The DSPy Script Way (The Better Way)
    # ============================================================

    print("=" * 50)
    print("APPROACH 2: Script Paradigm 🔧")
    print("=" * 50)
    print()

    print("In the SCRIPT paradigm, you define a contract:")
    print()

    # Step 1: Define the exact structure you want
    print("Step 1: Define the Contract (Signature)")
    print("```python")
    print("class ReviewAnalysis(dspy.Signature):")
    print('    """Extract structured information from a product review."""')
    print("    review_text = dspy.InputField()")
    print("    sentiment = dspy.OutputField(desc='positive, negative, or neutral')")
    print("    pros = dspy.OutputField(desc='List of positive points, comma-separated')")
    print("    cons = dspy.OutputField(desc='List of negative points, comma-separated')")
    print("    recommendation = dspy.OutputField(desc='yes, no, or unclear')")
    print("```")
    print()

    class ReviewAnalysis(dspy.Signature):
        """Extract structured information from a product review."""
        review_text = dspy.InputField()
        sentiment = dspy.OutputField(desc="positive, negative, or neutral")
        pros = dspy.OutputField(desc="List of positive points, comma-separated")
        cons = dspy.OutputField(desc="List of negative points, comma-separated")
        recommendation = dspy.OutputField(desc="yes, no, or unclear")

    # Step 2: Create the analyzer module
    print("Step 2: Create the Analyzer")
    print("```python")
    print("analyzer = dspy.Predict(ReviewAnalysis)")
    print("```")
    print()

    # Configure DSPy (with mock for demo)
    try:
        lm = dspy.LM('openai/gpt-4o-mini')
        dspy.configure(lm=lm)
        print("✓ Using OpenAI GPT-4o-mini\n")
    except:
        print("ℹ️  Using mock LM for demonstration\n")
        class MockLM:
            def __call__(self, prompt, **kwargs):
                # Return structured mock data
                return [{
                    "sentiment": "neutral",
                    "pros": "great coffee, heats quickly, sleek design, compact",
                    "cons": "expensive, small reservoir, confusing controls",
                    "recommendation": "yes"
                }]
        dspy.configure(lm=MockLM())

    analyzer = dspy.Predict(ReviewAnalysis)

    # Step 3: Run the script
    print("Step 3: Execute the Script")
    print("```python")
    print("result = analyzer(review_text=review)")
    print("```")
    print()

    print("🚀 Running analysis...\n")
    result = analyzer(review_text=sample_review)

    print("📊 Structured Output:")
    print("-" * 40)
    print(f"Sentiment:       {result.sentiment}")
    print(f"Pros:           {result.pros}")
    print(f"Cons:           {result.cons}")
    print(f"Recommendation:  {result.recommendation}")
    print("-" * 40)
    print()

    print("Benefits of the SCRIPT approach:")
    print("✅ Guaranteed structure every time")
    print("✅ Direct access to fields: result.sentiment")
    print("✅ Easy to integrate into larger systems")
    print("✅ Type hints and IDE support")
    print("✅ Can be optimized automatically by DSPy")
    print()

    # ============================================================
    # PART 3: The Power of Composition
    # ============================================================

    print("=" * 50)
    print("BONUS: Scripting Enables Composition")
    print("=" * 50)
    print()

    print("With scripting, you can chain operations:")
    print()
    print("```python")
    print("# This is hard with chat, trivial with scripts!")
    print("review_result = analyzer(review_text=review)")
    print("summary_result = summarizer(sentiment=review_result.sentiment,")
    print("                           pros=review_result.pros)")
    print("email_result = email_writer(summary=summary_result.text)")
    print("```")
    print()

    print("Try doing THAT with a chat interface! 🚀")
    print()

    # ============================================================
    # Summary
    # ============================================================

    print("=" * 50)
    print("KEY TAKEAWAY")
    print("=" * 50)
    print("""
CHAT PARADIGM:
- You're having a conversation
- Outputs are unpredictable text
- Integration is difficult
- Each prompt is standalone

SCRIPT PARADIGM:
- You're writing a program
- Outputs are structured data
- Integration is natural
- Operations compose together

This shift from CHATTING to SCRIPTING is what makes DSPy powerful
for building real AI systems, not just demos.
    """)

    return {
        "lesson": "02_chat_vs_script",
        "concepts": ["Paradigm shift", "Structured outputs", "Composition"],
        "success": True
    }

if __name__ == "__main__":
    main()