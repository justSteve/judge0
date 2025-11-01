# Dual-Use Sandbox Workspace Implementation Plan

## Executive Summary

This document outlines the design and implementation strategy for a **Dual-Use Sandbox Workspace**—a unified code execution environment serving two complementary purposes:

1. **Exploratory Courseware**: Interactive learning environment for DSPy framework tutorials, theory validation, and hands-on experimentation
2. **LLM Agent Launcher**: Runtime execution platform for AI-driven code generation and execution in support of options trading analysis

The workspace will be built on **Judge0** (self-hosted), providing robust, sandboxed code execution with a minimal, purpose-built frontend. This design maintains clean separation of concerns while replicating easily across related projects.

---

## Motivation & Design Philosophy

### Why This Approach?

**Single Infrastructure, Dual Purpose**

Historically, exploratory learning environments and production AI agent launchers remain separate concerns. This design intentionally unifies them:

- **Learning + Execution**: DSPy students can experiment interactively, then transition experiments into agent workflows without reimplementation
- **Rapid Prototyping**: Agents can suggest code, execute it in sandbox, and iterate—all within the same runtime
- **Infrastructure Efficiency**: One self-hosted Judge0 instance handles both courseware and agent workloads
- **Consistency**: Both paths use identical execution guarantees, language support, and error handling

### Architectural Constraints

- **Language Support**: Python 3.x + Node.js/TypeScript only (no bloat)
- **UI Sparsity**: Minimal interface—code editor, language selector, execute button, output panes
- **Self-Hosted**: Runs in personal infrastructure (WSL2 Docker on Windows)
- **Stateless Execution**: No session management or code persistence (courseware and agents manage their own state)
- **LLM Integration Ready**: API design accommodates programmatic agent-driven submissions

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                   DUAL-USE WORKSPACE                        │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  FRONTEND LAYER (React/TypeScript)                          │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ Sparse UI: Code Editor | Language Selector | Exec   │   │
│  │ Mode Toggle: Courseware ↔ LLM Agent                 │   │
│  │ Output Panes: stdout | stderr | console messages    │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                          ↕ REST API
┌─────────────────────────────────────────────────────────────┐
│  API LAYER (Node.js Express)                                │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ /api/execute      - Execute code submission          │   │
│  │ /api/languages    - List supported runtimes          │   │
│  │ /api/status       - Judge0 health check              │   │
│  │ Context injection: mode, metadata, execution hints   │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                          ↕ HTTP
┌─────────────────────────────────────────────────────────────┐
│  JUDGE0 EXECUTION ENGINE (Docker)                           │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ Sandboxed Runtime: Python 3.x + Node.js/TypeScript   │   │
│  │ Compiler/Interpreter Instances                       │   │
│  │ Resource Isolation: Memory, CPU, execution time      │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Layer Responsibilities

**Frontend (React/TypeScript)**
- Code editor with Python/TS syntax highlighting (Monaco or CodeMirror)
- Language selector (dropdown: Python | Node.js)
- Execute button with loading state
- Split-pane output: stdout/stderr/console
- Optional: Mode indicator (Courseware vs. Agent)
- Optional: Execution metadata (runtime, timestamp, result code)

**API Layer (Node.js Express)**
- Thin wrapper around Judge0 REST API
- Handles execution submissions and result polling
- Injects execution context (mode, session metadata)
- Rate limiting and basic auth for agent submissions
- Error normalization and response formatting

**Judge0 Backend**
- Manages sandbox lifecycle
- Executes Python and Node code in isolated containers
- Returns stdout, stderr, exit codes, execution time
- No modifications needed—use official Docker Compose deployment

---

## Use Case Flows

### Flow 1: Courseware Exploration

```
1. Student opens workspace in browser
2. Selects language (Python) and loads a DSPy tutorial
3. Edits example code or writes own implementation
4. Clicks "Execute" → API submits to Judge0
5. Judge0 runs in sandbox (3s timeout)
6. Results display: output, errors, execution time
7. Student iterates: modify → execute → learn
```

**UI State**: Courseware mode, manual code entry, human-friendly output formatting

### Flow 2: LLM Agent Execution

```
1. Agent framework (e.g., Claude + tools) generates code
2. Programmatic submission: POST /api/execute
   {
     "code": "import dspy\n...",
     "language": "python",
     "mode": "agent",
     "session_id": "agent-trade-analysis-001"
   }
3. API injects execution context
4. Judge0 executes in sandbox
5. API returns structured result to agent
6. Agent parses output and decides next action
7. Agent may submit follow-up code or execute trades
```

**API Response**:
```json
{
  "success": true,
  "stdout": "...",
  "stderr": "",
  "exit_code": 0,
  "execution_time_ms": 245,
  "language": "python",
  "session_id": "agent-trade-analysis-001"
}
```

**UI State**: Transparent—API-driven, no user interaction

### Hybrid Flow: Courseware → Agent

Student develops a DSPy pattern interactively, then wraps it in agent submission:

```
1. Experiment in courseware: validate DSPy pipeline logic
2. Copy finalized code → agent template
3. Agent orchestrates submissions via API
4. Results feed back into trading decision logic
```

---

## Getting Started: Implementation Phases

### Phase 1: Foundation (Judge0 Self-Hosting)

**Objective**: Get Judge0 running locally in Docker with Python + Node.js support

**Duration**: 2-4 hours

**Steps**:

1. **Prerequisites**
   - WSL2 with Docker Desktop installed
   - Git clone the Judge0 repository: `git clone https://github.com/judge0/judge0.git`
   - Navigate to repo root

2. **Download and Extract Release**
   ```bash
   cd judge0
   wget https://github.com/judge0/judge0/releases/download/v1.13.0/judge0-v1.13.0.zip
   unzip judge0-v1.13.0.zip
   cd judge0-v1.13.0
   ```

3. **Configure Environment**
   - Copy `.env.example` to `.env`
   - Edit `.env`:
     ```
     ENABLE_PYTHON=true
     ENABLE_NODEJS=true
     # Disable all other languages
     DISABLE_OTHER_LANGUAGES=true
     
     # API configuration
     API_HOST=0.0.0.0
     API_PORT=8080
     
     # Resource limits (optional, for stability)
     MAX_EXECUTION_TIME=10
     ```

4. **Start Judge0**
   ```bash
   docker-compose up -d
   ```

5. **Verify Installation**
   ```bash
   curl http://localhost:8080/api/config/languages
   # Should return: [{"id":71,"name":"Python (3.8.1)",...},{"id":63,"name":"Node.js (12.14.0)",...}]
   ```

**Deliverable**: Judge0 API running on `http://localhost:8080`

---

### Phase 2: API Layer (Express Wrapper)

**Objective**: Build thin Node.js wrapper with execution endpoint

**Duration**: 4-6 hours

**Structure**:
```
sandbox-api/
├── src/
│   ├── server.ts
│   ├── controllers/
│   │   └── executionController.ts
│   ├── services/
│   │   └── judge0Client.ts
│   └── middleware/
│       └── errorHandler.ts
├── docker-compose.yml
├── Dockerfile
├── package.json
└── .env.example
```

**Key Endpoints**:

```typescript
// POST /api/execute
{
  code: string;           // source code
  language: 'python' | 'javascript' | 'typescript';
  mode: 'courseware' | 'agent';
  session_id?: string;    // agent session tracking
  timeout?: number;       // execution timeout (default 5s)
}

// GET /api/languages
// Returns available runtimes

// GET /api/status
// Judge0 health check
```

**Implementation Checklist**:
- [ ] Express server with TypeScript
- [ ] Judge0 client (wraps REST calls with polling)
- [ ] Execution endpoint with validation
- [ ] Error handling and normalization
- [ ] Docker containerization
- [ ] Local deployment verification

**Deliverable**: API running on `http://localhost:3000/api`

---

### Phase 3: Frontend (React UI)

**Objective**: Build sparse, focused code execution interface

**Duration**: 6-8 hours

**Stack**:
- React 18+ with TypeScript
- Monaco Editor (or CodeMirror) for syntax highlighting
- Tailwind CSS for minimal styling
- Vite for build tooling

**Structure**:
```
sandbox-ui/
├── src/
│   ├── components/
│   │   ├── CodeEditor.tsx
│   │   ├── LanguageSelector.tsx
│   │   ├── ExecuteButton.tsx
│   │   └── OutputPane.tsx
│   ├── hooks/
│   │   └── useExecution.ts
│   ├── api/
│   │   └── client.ts
│   ├── App.tsx
│   └── main.tsx
├── vite.config.ts
└── package.json
```

**UI Layout** (minimal, desktop-focused):
```
┌─────────────────────────────────────────────┐
│ Language [Python ▼]        [Execute] 🔄     │
├─────────────────────────────────────────────┤
│                                             │
│  CODE EDITOR (Left 60%)   │  OUTPUT (40%)   │
│                           │                 │
│  import dspy              │ STDOUT          │
│  ...                      │ ─────────────   │
│                           │                 │
│                           │ STDERR          │
│                           │ ─────────────   │
│                           │ (red text)      │
└─────────────────────────────────────────────┘
```

**Component Checklist**:
- [ ] Monaco/CodeMirror integration with language detection
- [ ] Language dropdown affecting editor syntax highlighting
- [ ] Execute button with loading state
- [ ] Split pane output rendering (stdout/stderr separated)
- [ ] Copy-to-clipboard for output
- [ ] Execution metadata (time, exit code)
- [ ] Error boundary for robustness

**Deliverable**: Standalone React app running on `http://localhost:5173`

---

### Phase 4: Integration & Testing

**Objective**: Wire frontend → API → Judge0; test both use cases

**Duration**: 4-6 hours

**Steps**:

1. **Environment Configuration**
   - Frontend `.env`: API base URL
   - API `.env`: Judge0 endpoint, rate limits
   - Docker Compose orchestrates all three services

2. **Integration Testing**
   ```bash
   # Test courseware flow: manual code submission
   curl -X POST http://localhost:3000/api/execute \
     -H "Content-Type: application/json" \
     -d '{
       "code": "print(\"Hello from DSPy\")",
       "language": "python",
       "mode": "courseware"
     }'
   
   # Test agent flow: programmatic submission
   curl -X POST http://localhost:3000/api/execute \
     -H "Content-Type: application/json" \
     -d '{
       "code": "import json; print(json.dumps({\"trade\": \"SPX 2DTE butterfly\"}))",
       "language": "python",
       "mode": "agent",
       "session_id": "agent-001"
     }'
   ```

3. **UI Testing**
   - [ ] Type Python code → execute → see output
   - [ ] Switch to Node.js → see syntax highlighting change
   - [ ] Error handling: submit invalid code → see stderr
   - [ ] Timeout behavior: submit infinite loop → see timeout error

4. **Load Testing** (optional)
   - Verify Judge0 handles concurrent submissions
   - Monitor Docker resource usage

**Deliverable**: End-to-end functional workspace

---

### Phase 5: Polish & Deployment

**Objective**: Production-ready setup for personal use

**Duration**: 2-4 hours

**Tasks**:

1. **Docker Compose Orchestration**
   ```yaml
   version: '3.8'
   services:
     judge0:
       # Judge0 with Python + Node.js
     api:
       # Sandbox API wrapper
       depends_on:
         - judge0
     ui:
       # React frontend
       depends_on:
         - api
   
   # Single command: docker-compose up -d
   ```

2. **Security Hardening** (for agent access)
   - Optional API key/token auth for `/api/execute` in agent mode
   - Rate limiting per session_id
   - Execution timeout enforcement
   - Log agent submissions for audit trail

3. **Documentation**
   - README with setup instructions
   - API documentation (OpenAPI/Swagger optional)
   - Example courseware notebooks
   - Example agent submission patterns

4. **Monitoring** (optional)
   - Judge0 health endpoint polling
   - Error logging to file/service
   - Execution time metrics

**Deliverable**: Production-ready workspace with documentation

---

## Project Structure (Recommended)

Place all three components in a single monorepo for easy coordination:

```
sandbox-workspace/
├── README.md
├── IMPLEMENTATION_PLAN.md (this file)
├── docker-compose.yml          # Orchestrates all services
├── .env.example
│
├── judge0/                      # Judge0 deployment
│   ├── docker-compose.yml
│   ├── .env
│   └── ...
│
├── sandbox-api/                 # Express wrapper
│   ├── src/
│   ├── Dockerfile
│   ├── package.json
│   └── ...
│
├── sandbox-ui/                  # React frontend
│   ├── src/
│   ├── vite.config.ts
│   ├── package.json
│   └── ...
│
└── docs/
    ├── SETUP.md
    ├── API_REFERENCE.md
    └── USAGE_EXAMPLES.md
```

---

## Replication Pattern

Once the workspace is complete, replicate to other projects:

1. **Extract common API layer** into shared package
2. **Create project-specific frontends** (minimal changes per project)
3. **Document project-specific DSPy patterns** in courseware

Example: `options-trading-courseware/` would reuse sandbox API + create its own UI/courseware content.

---

## Estimated Timeline

| Phase | Duration | Cumulative |
|-------|----------|-----------|
| Judge0 Self-Hosting | 2–4h | 2–4h |
| API Layer | 4–6h | 6–10h |
| Frontend UI | 6–8h | 12–18h |
| Integration & Testing | 4–6h | 16–24h |
| Polish & Deployment | 2–4h | 18–28h |

**Total: 18–28 hours** (roughly 2.5–3.5 working days)

---

## Dependencies & Prerequisites

- **System**: WSL2 with Docker Desktop installed
- **Languages**: Node.js 16+, npm or yarn
- **Tools**: Git, curl (for testing)
- **Knowledge**: Basic Docker, React, TypeScript, REST APIs

---

## Success Criteria

✅ Judge0 running locally, executing Python + Node.js code  
✅ API wrapper responding to execution requests  
✅ React frontend rendering code editor and output  
✅ Courseware flow: manual submission → output display  
✅ Agent flow: programmatic submission → structured JSON response  
✅ Execution timeout + error handling working reliably  
✅ Docker Compose orchestrates all services in single command  
✅ Documentation complete and usable  

---

## Future Enhancements (Out of Scope)

- Session persistence (courseware history, saved snippets)
- Advanced agent orchestration (multi-step workflows)
- Real-time collaboration features
- Performance analytics and benchmarking
- Extended language support (R, Scala, etc.)
- Web deployment (currently local-only)

---

## References & Resources

- **Judge0 GitHub**: https://github.com/judge0/judge0
- **Judge0 Docs**: https://api.judge0.com/
- **Judge0 Self-Hosting Guide**: https://denishoti.medium.com/how-to-self-host-judge0-api-on-your-pc-locally-all-you-need-to-know-ad8a2b64fd1
- **Monaco Editor**: https://microsoft.github.io/monaco-editor/
- **Express + TypeScript**: https://expressjs.com/
- **React + Vite**: https://vitejs.dev/

---

## Document History

| Version | Date | Author | Notes |
|---------|------|--------|-------|
| 1.0 | 2025-10-30 | Planning | Initial implementation plan |

