# Fork Documentation Index

This index organizes documentation specific to this Judge0 fork — the agent execution infrastructure being built on top of upstream Judge0.

## Vision & Architecture

| Document | Purpose | Location |
|----------|---------|----------|
| [CLAUDE.md](../../CLAUDE.md) | Vision statement + technical reference | Root |
| [AGENTS.md](../../AGENTS.md) | Agent workflow instructions | Root |
| [Session Layer Design](./architecture/SESSION-LAYER-DESIGN.md) | Persistent execution sessions | Architecture |

## Guides

| Document | Purpose | Location |
|----------|---------|----------|
| [Docker Quick Start](./guides/DOCKER-QUICKSTART.md) | Local Docker setup | Guides |
| [Language Configuration](./guides/LANGUAGE-CONFIGURATION.md) | Customize available languages | Guides |
| [Known Issues](./guides/KNOWN-ISSUES.md) | WSL2/Docker Desktop limitations | Guides |
| [Azure Deployment](../../.steve/AZURE_DEPLOYMENT.md) | Deploy to Azure VM | .steve/ |
| [Azure CLI Guide](../../.steve/AZURE_CLI_GUIDE.md) | Azure CLI commands | .steve/ |
| [PowerShell Scripts](../../scripts/README-PowerShell.md) | Windows/Azure automation | scripts/ |
| [Bash Scripts](../../scripts/README.md) | Linux automation | scripts/ |
| [WSL Setup](../../scripts/wsl/README-WSL.md) | WSL2 development | scripts/wsl/ |

## Features

| Document | Purpose | Location |
|----------|---------|----------|
| [Features Overview](../../FEATURES.md) | High-level feature list | Root |
| [Infrastructure Scripts](../../FEATURE-1-Infrastructure-Management.md) | Feature 1 spec | Root |
| [Python Client Library](../../FEATURE-2-Python-Client-Library.md) | Feature 2 spec | Root |
| [Logging Guide](../../LOGGING-GUIDE.md) | Logging configuration | Root |

## Client Library

| Document | Purpose | Location |
|----------|---------|----------|
| [Client README](../../.dspy/lib/judge0_client/README.md) | Python client API | .dspy/lib/ |
| [DSPy Sandbox](../../.dspy/README.md) | DSPy integration workspace | .dspy/ |

## Project Management

| Document | Purpose | Location |
|----------|---------|----------|
| [Next Agent Handoff](../../4THENEXTAGENT.README.md) | Session handoff context | Root |
| [Project Summary](../../PROJECT-SUMMARY.md) | Executive summary | Root |
| [Next Steps](../../NEXT-STEPS.md) | Roadmap & ideas | Root |

## Code Reviews

| Document | Purpose | Location |
|----------|---------|----------|
| [Review Summary](../../REVIEW-SUMMARY.md) | Executive review | Root |
| [Logging Review](../../REVIEW-Logging-And-Error-Handling.md) | Detailed code review | Root |

---

## Upstream Judge0 Documentation

The following are original Judge0 documents:

| Document | Purpose |
|----------|---------|
| [docs/api/](../api/) | API reference documentation |
| [docs/maintainers/](../maintainers/) | Maintainer guides |
| [CHANGELOG.md](../../CHANGELOG.md) | Version history |
| [SECURITY.md](../../SECURITY.md) | Security policy |
| [CODE_OF_CONDUCT.md](../../CODE_OF_CONDUCT.md) | Community guidelines |

---

## Quick Reference

### Language IDs (Core Set)

| ID | Language |
|----|----------|
| 46 | Bash (5.0.0) |
| 63 | JavaScript (Node.js 12.14.0) |
| 71 | Python (3.8.1) |
| 74 | TypeScript (3.7.4) |

### API Endpoints

| Endpoint | Description |
|----------|-------------|
| `POST /submissions?wait=true` | Execute code (synchronous) |
| `GET /submissions/:token` | Get submission result |
| `GET /languages` | List languages |
| `GET /about` | API version |

### Common Commands

```bash
# Docker
docker-compose up -d              # Start services
docker-compose logs -f            # View logs
docker-compose restart            # Restart

# Test execution
curl -X POST "http://localhost:2358/submissions?wait=true" \
  -H "Content-Type: application/json" \
  -d '{"source_code": "print(\"Hello\")", "language_id": 71}'
```
