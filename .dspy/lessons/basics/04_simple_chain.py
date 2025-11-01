"""
Lesson 04: Chaining Scripts - Building Pipelines
================================================

The true power of DSPy's scripting paradigm shows when you chain
operations together. Each step's output becomes the next step's input,
creating reliable, complex AI pipelines from simple components.

Key Concepts:
- Sequential composition of DSPy modules
- Data flow between operations
- Building complex behavior from simple parts
- Why this is impossible with chat paradigms
"""

import sys
from pathlib import Path
sys.path.append(str(Path(__file__).parent.parent.parent))

import dspy
from lib.helpers import ScriptingHelper, ExperimentTracker, setup_mock_environment

def main():
    print("🎯 Lesson 04: Building Script Chains\n")

    # Setup
    setup_mock_environment()
    tracker = ExperimentTracker()

    # ============================================================
    # PART 1: The Power of Composition
    # ============================================================

    print("=" * 50)
    print("PART 1: Why Chaining Matters")
    print("=" * 50)
    print("""
    In traditional chatting with LLMs:
    - Each interaction is isolated
    - You manually copy/paste between prompts
    - No guarantee of compatible formats
    - Error-prone and not scalable

    With DSPy scripting:
    - Operations connect like LEGO blocks
    - Output of one feeds directly to the next
    - Type safety and structure preserved
    - Build complex systems from simple parts
    """)

    # ============================================================
    # PART 2: A Simple Chain Example
    # ============================================================

    print("=" * 50)
    print("PART 2: Article Processing Pipeline")
    print("=" * 50)
    print()

    print("We'll build a 3-step article processing pipeline:")
    print("1. Extract key points from article")
    print("2. Generate a summary from key points")
    print("3. Create a tweet from the summary")
    print()

    # Step 1: Define the signatures for each step
    print("Defining our pipeline components:")
    print("-" * 40)

    class ExtractKeyPoints(dspy.Signature):
        """Extract main points from an article."""
        article = dspy.InputField(desc="Full article text")
        key_points = dspy.OutputField(desc="Bullet points of main ideas")
        topic = dspy.OutputField(desc="Main topic of the article")

    class GenerateSummary(dspy.Signature):
        """Create a summary from key points."""
        key_points = dspy.InputField(desc="Bullet points to summarize")
        topic = dspy.InputField(desc="Main topic for context")
        summary = dspy.OutputField(desc="2-3 sentence summary")

    class CreateTweet(dspy.Signature):
        """Create a tweet from a summary."""
        summary = dspy.InputField(desc="Summary to convert to tweet")
        topic = dspy.InputField(desc="Topic for hashtag generation")
        tweet = dspy.OutputField(desc="Tweet text under 280 chars with hashtags")

    print("✓ ExtractKeyPoints: article -> key_points, topic")
    print("✓ GenerateSummary: key_points, topic -> summary")
    print("✓ CreateTweet: summary, topic -> tweet")
    print()

    # Step 2: Create the modules
    extractor = dspy.Predict(ExtractKeyPoints)
    summarizer = dspy.Predict(GenerateSummary)
    tweeter = dspy.Predict(CreateTweet)

    # Step 3: Create sample input
    sample_article = """
    Researchers at MIT have developed a new type of battery that could
    revolutionize energy storage. The battery uses abundant materials
    and can charge in under a minute while lasting for thousands of cycles.
    Initial tests show 90% capacity retention after 10,000 charge cycles.
    The technology could make electric vehicles more practical and enable
    better grid-scale energy storage for renewable sources.
    """

    print("📄 Input Article:")
    print("-" * 40)
    print(sample_article.strip())
    print("-" * 40)
    print()

    # ============================================================
    # PART 3: Execute the Chain
    # ============================================================

    print("=" * 50)
    print("PART 3: Running the Pipeline")
    print("=" * 50)
    print()

    print("🔄 Step 1: Extract Key Points")
    print("-" * 30)
    step1_result = extractor(article=sample_article)
    print(f"Topic: {step1_result.topic}")
    print(f"Key Points: {step1_result.key_points}")
    tracker.record("Step 1", {"module": "ExtractKeyPoints"}, step1_result.key_points)
    print()

    print("🔄 Step 2: Generate Summary")
    print("-" * 30)
    step2_result = summarizer(
        key_points=step1_result.key_points,
        topic=step1_result.topic
    )
    print(f"Summary: {step2_result.summary}")
    tracker.record("Step 2", {"module": "GenerateSummary"}, step2_result.summary)
    print()

    print("🔄 Step 3: Create Tweet")
    print("-" * 30)
    step3_result = tweeter(
        summary=step2_result.summary,
        topic=step1_result.topic
    )
    print(f"Tweet: {step3_result.tweet}")
    tracker.record("Step 3", {"module": "CreateTweet"}, step3_result.tweet)
    print()

    # ============================================================
    # PART 4: Building a Reusable Pipeline Class
    # ============================================================

    print("=" * 50)
    print("PART 4: Making it Reusable")
    print("=" * 50)
    print()

    print("We can wrap our chain in a class for reuse:")
    print()

    class ArticlePipeline(dspy.Module):
        """A reusable article processing pipeline."""

        def __init__(self):
            super().__init__()
            self.extractor = dspy.Predict(ExtractKeyPoints)
            self.summarizer = dspy.Predict(GenerateSummary)
            self.tweeter = dspy.Predict(CreateTweet)

        def forward(self, article):
            # Step 1: Extract
            extraction = self.extractor(article=article)

            # Step 2: Summarize
            summary = self.summarizer(
                key_points=extraction.key_points,
                topic=extraction.topic
            )

            # Step 3: Tweet
            tweet = self.tweeter(
                summary=summary.summary,
                topic=extraction.topic
            )

            return {
                'topic': extraction.topic,
                'key_points': extraction.key_points,
                'summary': summary.summary,
                'tweet': tweet.tweet
            }

    print("```python")
    print("class ArticlePipeline(dspy.Module):")
    print("    def __init__(self):")
    print("        self.extractor = dspy.Predict(ExtractKeyPoints)")
    print("        self.summarizer = dspy.Predict(GenerateSummary)")
    print("        self.tweeter = dspy.Predict(CreateTweet)")
    print()
    print("    def forward(self, article):")
    print("        # Chain the operations")
    print("        extraction = self.extractor(article=article)")
    print("        summary = self.summarizer(...)")
    print("        tweet = self.tweeter(...)")
    print("        return {'topic': ..., 'summary': ..., 'tweet': ...}")
    print("```")
    print()

    print("Now we can use it like a function:")
    print()

    pipeline = ArticlePipeline()
    result = pipeline(article=sample_article)

    print("📦 Pipeline Output:")
    print("-" * 40)
    for key, value in result.items():
        print(f"{key}: {value}")
        print()
    print("-" * 40)

    # ============================================================
    # PART 5: The Scripting Advantage
    # ============================================================

    print("\n" + "=" * 50)
    print("PART 5: Why This Matters")
    print("=" * 50)
    print("""
    WHAT WE JUST DID:
    1. Built a multi-step AI pipeline
    2. Each step has guaranteed input/output structure
    3. Steps automatically chain together
    4. The whole pipeline is reusable and testable

    TRY DOING THIS WITH CHAT:
    - You'd need to manually prompt 3 times
    - Copy/paste between each step
    - Parse unstructured text each time
    - No reusability or automation

    THIS IS THE POWER OF SCRIPTING:
    - Build once, run many times
    - Compose complex behavior from simple parts
    - Predictable, testable, optimizable
    - This is how you build AI SYSTEMS, not demos
    """)

    # ============================================================
    # PART 6: Experiment Ideas
    # ============================================================

    print("=" * 50)
    print("PART 6: Your Turn - Experiments")
    print("=" * 50)
    print("""
    EXPERIMENT IDEAS:

    1. Add a 4th step that translates the tweet to another language
    2. Create a branch that generates both a tweet AND an email
    3. Add error handling - what if extraction fails?
    4. Build a different pipeline:
       - Code -> Explanation -> Tutorial -> Quiz
       - Recipe -> Shopping List -> Meal Plan -> Calories
       - Bug Report -> Analysis -> Fix Suggestion -> PR Description

    The key insight: Once you think in SCRIPTS instead of CHATS,
    you can build sophisticated AI workflows with simple Python!
    """)

    return {
        "lesson": "04_simple_chain",
        "concepts": ["Chaining", "Pipelines", "Composition", "Reusability"],
        "pipeline_steps": 3,
        "success": True
    }

if __name__ == "__main__":
    main()