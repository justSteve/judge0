# Judge0 Minimal Image Build

Custom Docker image with only the languages needed for agent workflows.

## Quick Start

```bash
# Build the minimal image (from Judge0 root)
cd C:\myStuff\_tooling\Judge0
docker build -f build/Dockerfile.minimal -t judge0/compilers:minimal .

# Update docker-compose.yml to use it
# Change: image: judge0/judge0:latest
# To:     image: judge0/compilers:minimal

# Restart services
docker-compose down && docker-compose up -d
```

## Files

| File | Purpose |
|------|---------|
| `Dockerfile.minimal` | Build recipe for minimal image |
| `versions.json` | Declarative version manifest |
| `../db/languages/active-minimal-v2.rb` | Language configuration for Judge0 |

## Included Languages

| Language | Version | Notes |
|----------|---------|-------|
| Python | 3.12.8 | Primary scripting |
| Node.js | 22.12.0 | Kept for compatibility |
| Bun | 1.1.45 | Primary JS/TS runtime |
| TypeScript | 5.7.2 | Via tsc (npm) |
| Bash | 5.2 | Shell scripting |
| Go | 1.23.4 | Systems programming |
| Ruby | 3.3.6 | Scripting |
| Rust | 1.84.0 | Systems programming |
| SQLite | 3.x | SQL queries |

## Version Update Workflow

### 1. Check for Updates

```bash
# Python
curl -s https://www.python.org/downloads/ | grep -o 'Python [0-9.]*' | head -1

# Node.js
curl -s https://nodejs.org/en/ | grep -o 'LTS[^<]*' | head -1

# Bun
curl -s https://api.github.com/repos/oven-sh/bun/releases/latest | jq -r .tag_name

# Go
curl -s https://go.dev/VERSION?m=text

# Ruby
curl -s https://www.ruby-lang.org/en/downloads/ | grep -o 'ruby-[0-9.]*' | head -1

# Rust
curl -s https://www.rust-lang.org/ | grep -o 'Version [0-9.]*' | head -1
```

### 2. Update Version Manifest

Edit `versions.json` with new versions.

### 3. Update Dockerfile

Edit `Dockerfile.minimal` ENV variables:
```dockerfile
ENV PYTHON_VERSION=3.12.8
ENV NODE_VERSION=22.12.0
# etc.
```

### 4. Update Language Config

Edit `../db/languages/active-minimal-v2.rb` paths to match.

### 5. Rebuild Image

```bash
docker build -f Dockerfile.minimal -t judge0/compilers:minimal .
```

### 6. Deploy

```bash
docker-compose down
docker-compose up -d
```

## Cross-Project Synchronization

This image serves as the execution engine for all projects under `c:\myStuff\`. 
See bead `Judge0-rbp` for the version synchronization strategy.

**Key principle**: All projects should target the versions in this image.

## Size Comparison

| Image | Size |
|-------|------|
| `judge0/judge0:latest` | ~14 GB |
| `judge0/compilers:minimal` | ~2-3 GB (estimated) |

## Troubleshooting

### Build fails on Python

Python 3.12+ requires OpenSSL 1.1.1+. The base image may need updating.

```dockerfile
# Add before Python build if needed
RUN apt-get update && apt-get install -y libssl-dev
```

### tsc not found

TypeScript is installed globally via npm. Ensure Node.js is built first:
```dockerfile
RUN /usr/local/node-$NODE_VERSION/bin/npm install -g typescript@$TYPESCRIPT_VERSION
```

### Bun fails to run

Bun is a single binary. Check unzip worked:
```bash
docker run --rm judge0/compilers:minimal ls -la /usr/local/bun-*/bin/
```
