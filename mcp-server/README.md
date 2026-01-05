# Judge0 MCP Server

MCP (Model Context Protocol) server that enables Claude to execute code directly via Judge0.

## Tools

| Tool | Description |
|------|-------------|
| `execute_code` | Execute code in Python, JavaScript, TypeScript, Bash, Go, Ruby, Rust, or SQL |
| `get_submission` | Get results of a previous submission by token |
| `list_languages` | List all available programming languages |
| `judge0_status` | Check if Judge0 is running |

## Setup

### 1. Build the server

```bash
cd mcp-server
npm install
npm run build
```

### 2. Configure Claude Code

Add to your Claude Code MCP settings (`~/.claude/settings.json` or project `.claude/settings.local.json`):

```json
{
  "mcpServers": {
    "judge0": {
      "command": "node",
      "args": ["C:/myStuff/_tooling/Judge0/mcp-server/dist/index.js"],
      "env": {
        "JUDGE0_URL": "http://localhost:2358"
      }
    }
  }
}
```

### 3. Start Judge0

```bash
cd /path/to/judge0
docker-compose up -d
```

### 4. Restart Claude Code

The `judge0` tools will now be available.

## Usage Examples

Once configured, Claude can execute code directly:

```
Claude: Let me test that function...
[Uses execute_code tool with Python code]
Result appears in Observer UI at http://localhost:2358/observer.html
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `JUDGE0_URL` | `http://localhost:2358` | Judge0 API URL |

## Supported Languages

| Alias | Language ID |
|-------|-------------|
| python, python3, py | 71 |
| javascript, js, node | 63 |
| typescript, ts | 74 |
| bash, sh, shell | 46 |
| go, golang | 60 |
| ruby, rb | 72 |
| rust, rs | 73 |
| sql, sqlite | 82 |
