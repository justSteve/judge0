# DSPy Courseware Repository

This folder contains the centralized courseware content for the DSPy learning agent.

## Structure

```
.dspy/
├── lessons/          # Lesson files organized by topic
│   └── basics/       # Basic DSPy concepts
├── data/             # Sample data for exercises
├── lab/              # Experimental/practice workspace
├── lib/              # Shared utilities and helpers
└── outputs/          # Generated outputs and history
```

## Usage

The DSPy agent (located at `myClaude/dspy/`) references this courseware content.

## Content Organization

- **lessons/basics/** - Core DSPy lessons (01_hello_dspy.py, etc.)
- **data/** - Sample datasets for exercises
- **lib/** - Helper functions (providers.py, helpers.py)
- **outputs/** - Execution history and results

## Adding New Content

1. Create lesson files in appropriate `lessons/` subdirectory
2. Add any required data files to `data/`
3. Update this README with new content descriptions
4. Ensure the DSPy agent can reference the new content

## Integration with judge0

This courseware is designed to be executed through the judge0 code execution platform.
Each agent can consume this content through their own implementation patterns.
