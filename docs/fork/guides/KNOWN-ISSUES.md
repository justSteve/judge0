# Known Issues

## WSL2/Docker Desktop Language Limitations

### Affected Languages
- **Java**: JVM fails to allocate heap memory
- **JavaScript/TypeScript**: May timeout during initialization

### Root Cause

When running on WSL2 or Docker Desktop, the following settings are required for cgroups v2 compatibility:

```bash
ENABLE_PER_PROCESS_AND_THREAD_TIME_LIMIT=true
ENABLE_PER_PROCESS_AND_THREAD_MEMORY_LIMIT=true
```

These per-process limits restrict memory allocation for each subprocess, which conflicts with:
- Java's JVM heap reservation
- Node.js V8 engine initialization

### Working Languages

The following languages work correctly:

| ID | Language | Status |
|----|----------|--------|
| 46 | Bash | Working |
| 60 | Go | Working |
| 70-71 | Python | Working |
| 72 | Ruby | Working |
| 73 | Rust | Working |
| 82 | SQL | Working |

### Workarounds

#### Option 1: Use Native Docker (Linux)

On a native Linux host (not WSL2), you can disable per-process limits:

```bash
ENABLE_PER_PROCESS_AND_THREAD_TIME_LIMIT=false
ENABLE_PER_PROCESS_AND_THREAD_MEMORY_LIMIT=false
```

This enables Java and JavaScript but requires cgroups v1.

#### Option 2: Azure VM Deployment

Deploy Judge0 on an Azure Linux VM where cgroups v1 is available:

```bash
# On Azure VM
ENABLE_PER_PROCESS_AND_THREAD_TIME_LIMIT=false
ENABLE_PER_PROCESS_AND_THREAD_MEMORY_LIMIT=false
```

See [Azure Deployment Guide](../../.steve/AZURE_DEPLOYMENT.md).

#### Option 3: Use Alternative Languages

For agent workflows, Python and Bash cover most use cases. TypeScript can be transpiled externally before execution as JavaScript.

### Status

This is a known limitation of running Judge0 on WSL2/Docker Desktop. The upstream Judge0 project documents this in their configuration file.

For production use with Java/JavaScript support, deploy on a native Linux host or Azure VM.
