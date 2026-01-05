#!/usr/bin/env bun

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  Tool,
} from "@modelcontextprotocol/sdk/types.js";

// Configuration
const JUDGE0_URL = process.env.JUDGE0_URL || "http://localhost:2358";

// Language mapping for convenience
const LANGUAGES: Record<string, number> = {
  python: 71,
  python3: 71,
  py: 71,
  javascript: 63,
  js: 63,
  node: 63,
  typescript: 74,
  ts: 74,
  bash: 46,
  sh: 46,
  shell: 46,
  go: 60,
  golang: 60,
  ruby: 72,
  rb: 72,
  rust: 73,
  rs: 73,
  sql: 82,
  sqlite: 82,
};

// Tool definitions
const TOOLS: Tool[] = [
  {
    name: "execute_code",
    description:
      "Execute code in a sandboxed environment via Judge0. Supports Python, JavaScript, TypeScript, Bash, Go, Ruby, Rust, and SQL. Returns stdout, stderr, and execution metadata.",
    inputSchema: {
      type: "object" as const,
      properties: {
        code: {
          type: "string",
          description: "The source code to execute",
        },
        language: {
          type: "string",
          description:
            "Programming language: python, javascript, typescript, bash, go, ruby, rust, sql",
        },
        stdin: {
          type: "string",
          description: "Optional input to provide via stdin",
        },
        description: {
          type: "string",
          description: "Optional description of what this code does (for logging)",
        },
      },
      required: ["code", "language"],
    },
  },
  {
    name: "get_submission",
    description: "Get the result of a previous code submission by its token",
    inputSchema: {
      type: "object" as const,
      properties: {
        token: {
          type: "string",
          description: "The submission token returned from execute_code",
        },
      },
      required: ["token"],
    },
  },
  {
    name: "list_languages",
    description: "List all available programming languages and their IDs",
    inputSchema: {
      type: "object" as const,
      properties: {},
    },
  },
  {
    name: "judge0_status",
    description: "Check if Judge0 is running and get version info",
    inputSchema: {
      type: "object" as const,
      properties: {},
    },
  },
];

// Helper to make HTTP requests
async function fetchJSON(url: string, options?: RequestInit): Promise<unknown> {
  const response = await fetch(url, options);
  if (!response.ok) {
    const text = await response.text();
    throw new Error(`HTTP ${response.status}: ${text}`);
  }
  return response.json();
}

// Execute code via Judge0
async function executeCode(
  code: string,
  language: string,
  stdin?: string,
  _description?: string
): Promise<{
  token: string;
  status: string;
  stdout: string | null;
  stderr: string | null;
  compile_output: string | null;
  time: string | null;
  memory: number | null;
  exit_code: number | null;
}> {
  // Resolve language to ID
  const langLower = language.toLowerCase();
  const languageId = LANGUAGES[langLower];
  if (!languageId) {
    throw new Error(
      `Unknown language: ${language}. Supported: ${Object.keys(LANGUAGES).join(", ")}`
    );
  }

  // Submit code (synchronous mode)
  const submission = (await fetchJSON(
    `${JUDGE0_URL}/submissions?base64_encoded=false&wait=true`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        source_code: code,
        language_id: languageId,
        stdin: stdin || null,
      }),
    }
  )) as {
    token: string;
    status?: { id: number; description: string };
    stdout?: string;
    stderr?: string;
    compile_output?: string;
    time?: string;
    memory?: number;
    exit_code?: number;
  };

  return {
    token: submission.token,
    status: submission.status?.description || "Unknown",
    stdout: submission.stdout || null,
    stderr: submission.stderr || null,
    compile_output: submission.compile_output || null,
    time: submission.time || null,
    memory: submission.memory || null,
    exit_code: submission.exit_code ?? null,
  };
}

// Get submission by token
async function getSubmission(token: string): Promise<unknown> {
  return fetchJSON(`${JUDGE0_URL}/submissions/${token}?base64_encoded=false`);
}

// List available languages
async function listLanguages(): Promise<unknown> {
  return fetchJSON(`${JUDGE0_URL}/languages`);
}

// Get Judge0 status
async function getStatus(): Promise<unknown> {
  return fetchJSON(`${JUDGE0_URL}/about`);
}

// Create and start server
async function main() {
  const server = new Server(
    {
      name: "judge0-mcp-server",
      version: "1.0.0",
    },
    {
      capabilities: {
        tools: {},
      },
    }
  );

  // Handle list tools
  server.setRequestHandler(ListToolsRequestSchema, async () => ({
    tools: TOOLS,
  }));

  // Handle tool calls
  server.setRequestHandler(CallToolRequestSchema, async (request) => {
    const { name, arguments: args } = request.params;

    try {
      switch (name) {
        case "execute_code": {
          const { code, language, stdin, description } = args as {
            code: string;
            language: string;
            stdin?: string;
            description?: string;
          };
          const result = await executeCode(code, language, stdin, description);
          return {
            content: [
              {
                type: "text" as const,
                text: JSON.stringify(result, null, 2),
              },
            ],
          };
        }

        case "get_submission": {
          const { token } = args as { token: string };
          const result = await getSubmission(token);
          return {
            content: [
              {
                type: "text" as const,
                text: JSON.stringify(result, null, 2),
              },
            ],
          };
        }

        case "list_languages": {
          const result = await listLanguages();
          return {
            content: [
              {
                type: "text" as const,
                text: JSON.stringify(result, null, 2),
              },
            ],
          };
        }

        case "judge0_status": {
          const result = await getStatus();
          return {
            content: [
              {
                type: "text" as const,
                text: JSON.stringify(result, null, 2),
              },
            ],
          };
        }

        default:
          throw new Error(`Unknown tool: ${name}`);
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      return {
        content: [
          {
            type: "text" as const,
            text: `Error: ${message}`,
          },
        ],
        isError: true,
      };
    }
  });

  // Connect via stdio
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("Judge0 MCP server running on stdio");
}

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
