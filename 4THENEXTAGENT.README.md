# Handoff: Judge0 Project State

**Date:** 2026-01-04
**Status:** Observer UI created - ready for zero-friction workflow testing

---

## Current State

### What's Ready

- **Execution Observer UI** (`public/observer.html`) - Watch Claude's submissions in real-time
- **Documentation consolidated** into `docs/fork/` with clear separation from upstream
- **Docker guides** created for local setup and language configuration
- **Minimal language config** (`db/languages/active-minimal.rb`) with 10 core languages
- **Python client library** at `.dspy/lib/judge0_client/`
- **Infrastructure scripts** for Azure VM management

### Documentation Structure

```
docs/fork/
├── INDEX.md                           # Master index of all fork docs
├── guides/
│   ├── DOCKER-QUICKSTART.md          # Local setup guide
│   ├── LANGUAGE-CONFIGURATION.md     # Customize languages
│   └── KNOWN-ISSUES.md               # WSL2/Docker Desktop limitations
├── architecture/
│   └── SESSION-LAYER-DESIGN.md       # Persistent session design
└── plans/
    └── 2026-01-04-execution-observer-design.md  # Observer architecture

public/
├── observer.html                      # NEW: Zero-friction observation UI
└── dummy-client.html                  # Original test client
```

### Key Files

| File | Purpose |
|------|---------|
| `public/observer.html` | Watch Claude's executions (no input) |
| `CLAUDE.md` | Vision + technical reference |
| `docs/fork/INDEX.md` | Documentation index |
| `docs/fork/guides/DOCKER-QUICKSTART.md` | Get running locally |
| `db/languages/active-minimal.rb` | Minimal language set |
| `.dspy/lib/judge0_client/` | Python client |

---

## Zero-Friction Workflow

The new workflow eliminates copy/paste:

```
┌─────────────────┐         ┌─────────────────┐         ┌─────────────────┐
│     Claude      │──POST──▶│     Judge0      │◀──GET───│   Observer UI   │
│   (executor)    │         │      API        │         │    (human)      │
└─────────────────┘         └─────────────────┘         └─────────────────┘
     "I execute"                                            "You observe"
```

### Test the Workflow

1. **Start Judge0:**
   ```bash
   docker-compose up -d
   sleep 15
   ```

2. **Open Observer:**
   Open `http://localhost:2358/observer.html` in browser

3. **Claude submits code:**
   ```bash
   curl -X POST "http://localhost:2358/submissions?wait=true" \
     -H "Content-Type: application/json" \
     -d '{"source_code": "print(\"Hello from Claude!\")", "language_id": 71}'
   ```

4. **Watch Observer:**
   Submission appears with code and output - no copy/paste needed

---

## Language IDs (Core Set)

| ID | Language |
|----|----------|
| 46 | Bash 5.0.0 |
| 63 | JavaScript Node.js 12 |
| 71 | Python 3.8.1 |
| 74 | TypeScript 3.7.4 |

---

## What's NOT Ready Yet

- **MCP Tool Integration** - Claude can't directly POST yet (needs MCP tool)
- **Session layer** - Design exists but not implemented
- **Beads integration** - Future phase
- **Production logging** - Enhanced v2 clients exist but not integrated

---

## Quick Reference

### Docker Commands

```bash
docker-compose up -d          # Start
docker-compose logs -f        # Logs
docker-compose restart        # Restart
docker-compose down           # Stop
```

### URLs

| URL | Purpose |
|-----|---------|
| `http://localhost:2358/observer.html` | Watch executions |
| `http://localhost:2358/dummy-client.html` | Manual test input |
| `http://localhost:2358/about` | API version |
| `http://localhost:2358/languages` | Available languages |

### API Endpoints

```bash
GET  /about                   # Version info
GET  /languages               # Available languages
GET  /submissions             # List all submissions (Observer uses this)
POST /submissions?wait=true   # Execute code (sync)
GET  /submissions/:token      # Get result by token
```

---

## Session End Protocol

Before ending session:

```bash
git status
git add -A
git commit -m "feat: add execution observer UI for zero-friction workflow"
bd sync
git push
```
