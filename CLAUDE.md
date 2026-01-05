# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Vision: Agent Execution Infrastructure

This fork of Judge0 is evolving from a conventional code execution engine into **agent execution infrastructure** — a shared executable workspace where code runs become persistent, queryable artifacts in a collaborative environment.

### The Problem We're Solving

The traditional workflow creates friction:
1. Human describes intent
2. Agent suggests code
3. Human copies code, runs locally, copies results back
4. Agent parses text, suggests fixes
5. Repeat

This copy/paste loop loses context, history, and causality. Each execution is ephemeral — there's no shared ground.

### The Paradigm Shift

Judge0 becomes shared infrastructure where:
- **Executions are tracked artifacts** — not ephemeral runs, but persistent records with code, output, timing, and dependencies
- **Sessions are epochs** — organizational containers that group related executions with full history
- **Intent precedes execution** — what we're trying to do is captured before code runs
- **Provenance chains show causality** — "this fix was discovered from that failed execution"
- **Agents have queryable memory** — past executions are searchable, not just text in logs

### Roles in This Architecture

**The Human (Steve)** is not the primary hands-on executor. The role is:
- **Architect**: defining workspace structure, conventions, and workflows
- **Supervisor**: observing agent work, intervening on priorities and blockers
- **Operator**: initializing sessions, triggering syncs, resolving conflicts
- **Director**: pointing agents at intents, reviewing execution chains

**Agents** are the primary consumers of the shared workspace:
- Execute code through Judge0
- Query execution history
- Track dependencies between runs
- Bootstrap context from prior sessions
- Coordinate with other agents through shared state

### Future: Beads Integration

The next phase integrates with [beads](https://github.com/justSteve/beads) — a git-backed, dependency-aware tracking system designed for agents. When complete:
- Every execution becomes a bead (tracked artifact)
- Sessions become epochs (bead hierarchies)
- Dependencies are explicit (discovered-from, blocks relationships)
- Git provides synchronization between human and agent views
- MCP provides agent query interface

**Note**: Beads integration is a separate deep-dive. This CLAUDE.md establishes the conceptual framework; implementation details follow.

---

## Technical Reference

The sections below document Judge0's current technical state. This infrastructure will be wrapped by the integration layer described above.

### Core Technology

Ruby on Rails 6.1 API using PostgreSQL, Redis/Resque for job queuing, and [Isolate](https://github.com/ioi/isolate) for sandboxed execution.

### Development Commands

**Docker (primary)**:
```bash
docker-compose up -d              # Start services
docker-compose logs -f            # View logs
docker-compose restart            # Restart services
docker-compose exec server bundle exec rspec  # Run tests
docker-compose exec server bundle exec rails console  # Rails console
```

**WSL2 Local Development**:
```bash
./scripts/wsl/setup-wsl.sh                    # Bash setup
.\scripts\wsl\Bootstrap-Judge0-WSL.ps1        # PowerShell setup
```

**Azure VM Management**:
```powershell
.\scripts\Get-Judge0Status.ps1        # Check status
.\scripts\Check-And-Update.ps1        # Check for updates
.\scripts\Restart-Judge0.ps1          # Restart services
```

### Python Client

Current client in `.dspy/lib/judge0_client/`:

```python
from judge0_client import Judge0Client, Judge0Config

client = Judge0Client()                           # Local instance
result = client.execute('print("Hello")')

config = Judge0Config.azure(host="your-vm-ip")    # Azure VM
client = Judge0Client(config)
```

**Note**: This client will be extended to integrate with the tracking layer.

### API Endpoints

| Endpoint | Description |
|----------|-------------|
| `POST /submissions` | Create submission (`?wait=true` for sync) |
| `GET /submissions/:token` | Get submission result |
| `POST /submissions/batch` | Batch create |
| `GET /languages` | List supported languages |
| `GET /about` | API version info |
| `GET /workers` | Worker health check |

### Execution Flow

1. **API Layer** (`app/controllers/submissions_controller.rb`) — receives submission
2. **Model** (`app/models/submission.rb`) — validates/stores with Base64 encoding
3. **Queue** (Redis/Resque) — async processing
4. **Worker** (`app/jobs/isolate_job.rb`) — sandboxed execution with resource limits
5. **Response** — stdout, stderr, exit code, timing metadata

### Status Codes

| ID | Description |
|----|-------------|
| 1 | In Queue |
| 2 | Processing |
| 3 | Accepted |
| 4 | Wrong Answer |
| 5 | Time Limit Exceeded |
| 6+ | Runtime errors (signals) |
| 11 | Runtime Error (NZEC) |
| 12 | Compilation Error |
| 13 | Internal Error |

### Language IDs (Core Set)

| ID | Language |
|----|----------|
| 46 | Bash |
| 63 | JavaScript (Node.js) |
| 71 | Python 3 |
| 74 | TypeScript |
| 60 | Go |
| 72 | Ruby |
| 73 | Rust |
| 82 | SQL (SQLite) |

Full list: `GET /languages/all`

### Configuration

Key settings in `judge0.conf`:
- `ENABLE_PER_PROCESS_AND_THREAD_*_LIMIT=true` — required for WSL2/Docker Desktop
- `REDIS_PASSWORD` / `POSTGRES_PASSWORD` — required, no defaults
- `CPU_TIME_LIMIT`, `MEMORY_LIMIT`, `WALL_TIME_LIMIT` — execution constraints

---

## Repository Structure

**This fork adds**:

- `docs/fork/` — Fork-specific documentation ([INDEX](docs/fork/INDEX.md))
  - `guides/` — Docker, language configuration, deployment guides
  - `architecture/` — Session layer design, future plans
- `scripts/` — Infrastructure management (PowerShell, Bash)
- `.dspy/lib/judge0_client/` — Python client library
- `.dspy/` — DSPy learning sandbox (see `.dspy/CLAUDE.md`)
- `.steve/` — Azure deployment guides
- `db/languages/active-minimal.rb` — Minimal language config (10 languages)

**Upstream Judge0**:

- `app/` — Rails application
- `docs/api/` — API reference documentation
- `docker-compose.yml` — Service orchestration
- `judge0.conf` — Configuration

---

## Quick Start

See [Docker Quick Start](docs/fork/guides/DOCKER-QUICKSTART.md) for local setup.

```bash
# Start services
docker-compose up -d

# Test execution
curl -X POST "http://localhost:2358/submissions?wait=true" \
  -H "Content-Type: application/json" \
  -d '{"source_code": "print(1+1)", "language_id": 71}'
```
