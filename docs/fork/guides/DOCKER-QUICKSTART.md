# Docker Quick Start Guide

Get Judge0 running locally in minutes.

## Prerequisites

- Docker Desktop (Windows/Mac) or Docker Engine (Linux)
- Docker Compose v2+
- 4GB RAM minimum (8GB recommended)

## Quick Start

### 1. Clone and Configure

```bash
# Clone the repository
git clone https://github.com/justSteve/judge0.git
cd judge0

# Verify judge0.conf has passwords set
grep -E "(REDIS_PASSWORD|POSTGRES_PASSWORD)" judge0.conf
```

**Note**: `judge0.conf` should already have secure passwords configured. If not, generate them:

```bash
# Generate secure passwords (PowerShell)
[System.Web.Security.Membership]::GeneratePassword(32,8)

# Or use openssl (Linux/Mac)
openssl rand -base64 32
```

### 2. Start Services

```bash
# Start database and Redis first
docker-compose up -d db redis

# Wait 10 seconds for initialization
sleep 10

# Start all services
docker-compose up -d

# Verify all 4 services are running
docker-compose ps
```

Expected output:
```
NAME                COMMAND                  STATUS          PORTS
judge0-db-1         "docker-entrypoint.s…"   running         5432/tcp
judge0-redis-1      "docker-entrypoint.s…"   running         6379/tcp
judge0-server-1     "/api/docker-entrypo…"   running         0.0.0.0:2358->2358/tcp
judge0-worker-1     "/api/docker-entrypo…"   running
```

### 3. Test the API

```bash
# Check API is responding
curl http://localhost:2358/about

# Execute Python code
curl -X POST "http://localhost:2358/submissions?wait=true" \
  -H "Content-Type: application/json" \
  -d '{"source_code": "print(\"Hello, Judge0!\")", "language_id": 71}'
```

### 4. Access Documentation

Open http://localhost:2358/docs in your browser.

---

## Common Operations

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f server
docker-compose logs -f worker
```

### Restart Services

```bash
# Restart all
docker-compose restart

# Restart specific service
docker-compose restart server
```

### Stop Services

```bash
# Stop but keep data
docker-compose stop

# Stop and remove containers (keeps data volumes)
docker-compose down

# Stop and remove everything including data
docker-compose down -v
```

### Update to Latest

```bash
docker-compose pull
docker-compose up -d
```

---

## Language Reference

### Core Languages (Primary Use)

| ID | Language | Command |
|----|----------|---------|
| 46 | Bash 5.0.0 | `bash script.sh` |
| 62 | Java OpenJDK 13.0.1 | Compile + run |
| 63 | JavaScript Node.js 12.14.0 | `node script.js` |
| 71 | Python 3.8.1 | `python3 script.py` |
| 74 | TypeScript 3.7.4 | Compile to JS + run |

### Additional Languages

| ID | Language |
|----|----------|
| 70 | Python 2.7.17 |
| 72 | Ruby 2.7.0 |
| 60 | Go 1.13.5 |
| 73 | Rust 1.40.0 |
| 82 | SQL (SQLite) |

Full list: `GET /languages/all`

---

## Execution Examples

### Python

```bash
curl -X POST "http://localhost:2358/submissions?wait=true" \
  -H "Content-Type: application/json" \
  -d '{
    "source_code": "print(sum(range(10)))",
    "language_id": 71
  }'
```

### JavaScript

```bash
curl -X POST "http://localhost:2358/submissions?wait=true" \
  -H "Content-Type: application/json" \
  -d '{
    "source_code": "console.log(Array.from({length: 5}, (_, i) => i*2))",
    "language_id": 63
  }'
```

### Bash

```bash
curl -X POST "http://localhost:2358/submissions?wait=true" \
  -H "Content-Type: application/json" \
  -d '{
    "source_code": "echo \"Hello from Bash\" && date",
    "language_id": 46
  }'
```

### Java

```bash
curl -X POST "http://localhost:2358/submissions?wait=true" \
  -H "Content-Type: application/json" \
  -d '{
    "source_code": "public class Main { public static void main(String[] args) { System.out.println(\"Hello from Java\"); } }",
    "language_id": 62
  }'
```

### TypeScript

```bash
curl -X POST "http://localhost:2358/submissions?wait=true" \
  -H "Content-Type: application/json" \
  -d '{
    "source_code": "const greet = (name: string): string => `Hello, ${name}!`; console.log(greet(\"TypeScript\"));",
    "language_id": 74
  }'
```

### With stdin Input

```bash
curl -X POST "http://localhost:2358/submissions?wait=true" \
  -H "Content-Type: application/json" \
  -d '{
    "source_code": "name = input()\nprint(f\"Hello, {name}!\")",
    "language_id": 71,
    "stdin": "World"
  }'
```

---

## Python Client Usage

```python
import sys
sys.path.append('/path/to/judge0/.dspy/lib')

from judge0_client import Judge0Client

# Local instance (default)
client = Judge0Client()

# Execute code
result = client.execute('print("Hello from Python client!")')
print(result['stdout'])

# Check health
if client.is_healthy():
    print("Judge0 is running")
```

---

## Configuration

### Key Settings in judge0.conf

```bash
# Required - must be set
REDIS_PASSWORD=<secure-password>
POSTGRES_PASSWORD=<secure-password>

# WSL2/Docker Desktop requirement
ENABLE_PER_PROCESS_AND_THREAD_TIME_LIMIT=true
ENABLE_PER_PROCESS_AND_THREAD_MEMORY_LIMIT=true

# Resource limits (defaults shown)
CPU_TIME_LIMIT=5          # seconds
WALL_TIME_LIMIT=10        # seconds
MEMORY_LIMIT=128000       # KB (128MB)
```

### Workers

```bash
# In judge0.conf
COUNT=2                   # Number of workers (default: 2*nproc)
MAX_QUEUE_SIZE=100        # Max pending submissions
```

---

## Troubleshooting

### Services Won't Start

```bash
# Check logs
docker-compose logs server

# Common issue: passwords not set
grep -E "^(REDIS_PASSWORD|POSTGRES_PASSWORD)=" judge0.conf
```

### Port Already in Use

```bash
# Check what's using port 2358
lsof -i :2358              # Linux/Mac
netstat -ano | findstr 2358  # Windows

# Use different port
# Edit docker-compose.yml: ports: "3000:2358"
```

### Out of Memory

Increase Docker memory allocation:
- Docker Desktop: Settings → Resources → Memory
- Minimum: 4GB, Recommended: 8GB

### WSL2 Specific

```bash
# Verify cgroup settings
grep -E "ENABLE_PER_PROCESS" judge0.conf
# Both should be =true
```

### Connection Refused

```bash
# Check services are running
docker-compose ps

# Check network
curl -v http://localhost:2358/about

# Restart if needed
docker-compose restart
```

---

## Development Mode

For development with live code reloading:

```bash
docker-compose -f docker-compose.dev.yml up -d
```

This mounts the local codebase into the container.

---

## Status Codes Reference

| ID | Status | Meaning |
|----|--------|---------|
| 1 | In Queue | Waiting to be processed |
| 2 | Processing | Currently executing |
| 3 | Accepted | Execution completed successfully |
| 4 | Wrong Answer | Output didn't match expected |
| 5 | Time Limit Exceeded | Took too long |
| 6+ | Runtime Error | Various signals (SIGSEGV, etc.) |
| 11 | Runtime Error (NZEC) | Non-zero exit code |
| 12 | Compilation Error | Code failed to compile |
| 13 | Internal Error | Judge0 system error |

---

## Next Steps

1. **Run test executions** to verify all languages work
2. **Set up Python client** for programmatic access
3. **Configure monitoring** for production use
4. **Review [Session Layer Design](../architecture/SESSION-LAYER-DESIGN.md)** for persistent sessions

---

## Related Documentation

- [Azure Deployment](../../.steve/AZURE_DEPLOYMENT.md) - Cloud deployment
- [Python Client](../../.dspy/lib/judge0_client/README.md) - Client library
- [PowerShell Scripts](../../scripts/README-PowerShell.md) - Automation
