# Design: Execution Observer - Zero-Friction Agent Execution

**Date:** 2026-01-04
**Status:** Design Complete
**Problem:** Eliminate copy/paste workflow between Claude and human for code execution

---

## The Insight

Judge0 already has API-based code injection:

```
POST /submissions → Code executes → GET /submissions shows results
```

What's missing: an **observer UI** that displays submissions as a feed.

---

## Architecture

```
┌─────────────────┐         ┌─────────────────┐         ┌─────────────────┐
│                 │         │                 │         │                 │
│     Claude      │──POST──▶│     Judge0      │◀──GET───│   Observer UI   │
│   (executor)    │         │      API        │         │    (human)      │
│                 │         │                 │         │                 │
└─────────────────┘         └─────────────────┘         └─────────────────┘
         │                          │                          │
         │                          ▼                          │
         │                   ┌─────────────┐                   │
         │                   │  Database   │                   │
         │                   │(submissions)│                   │
         │                   └─────────────┘                   │
         │                                                     │
         └─────────── "I execute" ──────────────────────────▶ "You observe"
```

### Roles

| Actor | Action | Interface |
|-------|--------|-----------|
| Claude | Submits code | `POST /submissions` |
| Judge0 | Executes code | Worker/Isolate |
| Human | Watches results | Observer UI (new) |

---

## Observer UI Specification

### Core Requirements

1. **No input controls** - Claude owns execution
2. **Auto-refresh** - Poll every 2-3 seconds
3. **Chronological feed** - Newest at top
4. **Code + Output display** - Both visible per submission
5. **Status indicators** - Queue/Processing/Complete

### Page Structure

```html
┌────────────────────────────────────────────────────────────┐
│  Judge0 Execution Observer           [Auto-refresh: ON]    │
├────────────────────────────────────────────────────────────┤
│ ┌────────────────────────────────────────────────────────┐ │
│ │ #abc123 | Python 3 | 2026-01-04 14:32:15 | ● Complete  │ │
│ │ ──────────────────────────────────────────────────────  │ │
│ │ Code:                                                   │ │
│ │ print("Hello from Claude!")                            │ │
│ │                                                        │ │
│ │ Output:                                                │ │
│ │ Hello from Claude!                                     │ │
│ └────────────────────────────────────────────────────────┘ │
│ ┌────────────────────────────────────────────────────────┐ │
│ │ #def456 | Bash | 2026-01-04 14:31:58 | ◐ Processing    │ │
│ │ ...                                                    │ │
│ └────────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────┘
```

### API Usage

```javascript
// Poll for recent submissions
async function fetchSubmissions() {
  const response = await fetch('/submissions?per_page=20&base64_encoded=false');
  const data = await response.json();
  return data.submissions;
}

// Render as feed
setInterval(async () => {
  const submissions = await fetchSubmissions();
  renderFeed(submissions);
}, 3000);
```

---

## Implementation Path

### Phase 1: Static Observer (Minimum Viable)

Create `public/observer.html`:
- Polls `GET /submissions`
- Displays recent submissions
- Shows code and output
- No authentication (local only)

**Time to implement:** ~30 minutes

### Phase 2: Enhanced Observer

- Syntax highlighting (highlight.js)
- Collapsible submissions
- Filter by language
- Search by token

### Phase 3: Real-time (Future)

- WebSocket connection (requires Rails upgrade)
- Or Server-Sent Events
- Push notifications for completion

---

## Workflow Example

**Session: Claude debugging a function**

1. Claude: "Let me test this function"
2. Claude: `POST /submissions` with test code
3. Human: Watches observer UI, sees code appear
4. Human: Sees output (error)
5. Claude: "I see the error, let me fix it"
6. Claude: `POST /submissions` with fixed code
7. Human: Sees new submission appear
8. Human: Sees output (success)

**No copy/paste. No context switching. Shared visibility.**

---

## MCP Integration (Future)

Once observer exists, Claude's MCP tool becomes:

```typescript
interface Judge0ExecuteTool {
  name: "execute_code";
  parameters: {
    code: string;
    language: "python" | "bash" | "javascript" | "typescript";
    description?: string;  // Intent annotation for provenance
  };
  returns: {
    token: string;
    stdout?: string;
    stderr?: string;
    status: "queued" | "processing" | "complete" | "error";
  };
}
```

Human sees every execution in real-time through the observer.

---

## Files to Create

| File | Purpose |
|------|---------|
| `public/observer.html` | Observer UI |
| `public/css/observer.css` | Styling (optional, can be inline) |

---

## Decision Points

1. **Styling**: Minimal inline CSS vs. separate stylesheet?
2. **Base64**: Decode on client or request decoded from API?
3. **History depth**: How many submissions to show? (Default: 20)
4. **Status icons**: Unicode symbols vs. CSS badges?

---

## Security Considerations

- Observer is read-only (GET only)
- No authentication required for local development
- Production: Consider limiting to localhost or adding auth header

---

## Next Step

Implement Phase 1: Create `public/observer.html` with basic polling and feed display.
