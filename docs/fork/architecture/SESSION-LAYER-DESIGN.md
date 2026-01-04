# Judge0 Session Layer Design

## Overview

Judge0 provides stateless code execution - each submission is isolated with no memory of previous runs. For agent + user collaborative scenarios, we need a **session layer** that maintains execution context across multiple submissions.

## Goals

| Goal | Description |
|------|-------------|
| **Persistent State** | Variables, imports, and definitions persist across executions |
| **Shared Visibility** | Both agent and user see the same session state |
| **Multi-language** | Support Python, JavaScript, and other interpreted languages |
| **Lightweight** | Minimal overhead on top of Judge0 |

## Architecture Options

### Option A: Code Accumulation (Simplest)

Accumulate all executed code and re-run the full history on each submission.

```
Session Storage
┌─────────────────────────────────┐
│ execution_history: [            │
│   "x = 10",                     │
│   "y = 20",                     │
│   "print(x + y)"                │
│ ]                               │
└─────────────────────────────────┘

On new submission "z = x * y":
  → Concatenate: "x = 10\ny = 20\nprint(x + y)\nz = x * y"
  → Send to Judge0
  → Return only NEW output
```

**Pros**: Simple, works with any language, no external dependencies  
**Cons**: Execution time grows with history, side effects re-execute

### Option B: Pickle/Serialize State (Python-specific)

Serialize Python state after each execution, restore before next.

```python
# After each execution, append:
import pickle, base64
print("__STATE__:" + base64.b64encode(pickle.dumps(dir())).decode())

# Before next execution, prepend:
import pickle, base64
globals().update(pickle.loads(base64.b64decode("...")))
```

**Pros**: Fast execution, only runs new code  
**Cons**: Python-only, can't serialize all objects (lambdas, connections)

### Option C: Persistent Container (Most Robust)

Run a long-lived container with a REPL, send code via stdin/stdout.

```
┌──────────────────────────────────────────────────────┐
│  Session Container (Python REPL)                     │
│  ┌────────────────────────────────────────────────┐  │
│  │ >>> x = 10        # Agent                      │  │
│  │ >>> y = 20        # User                       │  │
│  │ >>> print(x + y)  # Agent                      │  │
│  │ 30                                             │  │
│  └────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────┘
```

**Pros**: True persistent state, real REPL experience  
**Cons**: Requires container orchestration outside Judge0, security considerations

---

## Recommended Approach: Hybrid (Option A + Smart Diffing)

For MVP, use **Code Accumulation** with optimizations:

1. **Track defined symbols** - Only re-run definitions, not print statements
2. **Separate setup from execution** - Imports/defs run once, expressions run fresh
3. **Output diffing** - Return only output from the latest execution

### Session Data Model

```typescript
interface Session {
  id: string;
  language_id: number;
  created_at: Date;
  last_activity: Date;
  
  // Code segments
  imports: string[];        // import statements (run once)
  definitions: string[];    // function/class defs (run once)  
  executions: Execution[];  // execution history
  
  // State tracking
  defined_symbols: string[];
}

interface Execution {
  id: string;
  timestamp: Date;
  actor: 'agent' | 'user';
  code: string;
  stdout: string;
  stderr: string;
  status: 'success' | 'error';
}
```

### API Design

```
POST /sessions
  → { session_id, language_id }

POST /sessions/{id}/execute
  Body: { code: string, actor: 'agent' | 'user' }
  → { stdout, stderr, status, execution_id }

GET /sessions/{id}
  → { session, executions[] }

GET /sessions/{id}/context
  → { combined_code, defined_symbols }

DELETE /sessions/{id}
```

### Implementation Components

```
┌─────────────────────────────────────────────────────────────┐
│                    Session Layer Service                     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────┐ │
│  │   Session   │    │    Code     │    │     Judge0      │ │
│  │   Manager   │───▶│  Assembler  │───▶│     Client      │ │
│  └─────────────┘    └─────────────┘    └─────────────────┘ │
│         │                                      │            │
│         ▼                                      ▼            │
│  ┌─────────────┐                      ┌─────────────────┐  │
│  │   Storage   │                      │   Judge0 API    │  │
│  │  (Redis/DB) │                      │  localhost:2358 │  │
│  └─────────────┘                      └─────────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Implementation Plan

### Phase 1: MVP (Code Accumulation)

1. **Session Storage** - In-memory or Redis
2. **Code Assembler** - Concatenate history + new code
3. **Output Parser** - Extract only new output
4. **REST API** - Simple Express/FastAPI wrapper

### Phase 2: Optimization

1. **Smart diffing** - Track symbols, skip redundant re-runs
2. **Import caching** - Pre-warm common imports
3. **Timeout handling** - Kill long-running accumulated code

### Phase 3: Multi-language

1. **Language adapters** - Python, JavaScript, Ruby
2. **State serialization** - Per-language pickle/JSON strategies

---

## Quick Start: Manual Session Test

Before building the session layer, validate the approach manually:

```bash
# Execution 1: Define variable
curl -X POST "http://localhost:2358/submissions?wait=true" \
  -H "Content-Type: application/json" \
  -d '{"source_code": "x = 10\nprint(\"x defined\")", "language_id": 71}'

# Execution 2: Accumulate and use variable
curl -X POST "http://localhost:2358/submissions?wait=true" \
  -H "Content-Type: application/json" \
  -d '{"source_code": "x = 10\ny = 20\nprint(x + y)", "language_id": 71}'

# Execution 3: Full history + new code
curl -X POST "http://localhost:2358/submissions?wait=true" \
  -H "Content-Type: application/json" \
  -d '{"source_code": "x = 10\ny = 20\nz = x * y\nprint(f\"Result: {z}\")", "language_id": 71}'
```

---

## Security Considerations

| Risk | Mitigation |
|------|------------|
| Code injection across sessions | Sessions are isolated, IDs are UUIDs |
| Resource exhaustion | Limit history size, execution time |
| Sensitive data in history | Session expiry, explicit cleanup |
| Malicious accumulated code | Same sandboxing as Judge0 (isolate) |

---

## Next Steps

1. **Test manual accumulation** - Validate approach works
2. **Build minimal session service** - Python/Node wrapper
3. **Integrate with agent framework** - MCP tool or direct API
4. **Add persistence** - Redis for session storage
