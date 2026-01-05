#!/usr/bin/env node
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { CallToolRequestSchema, ListToolsRequestSchema, } from "@modelcontextprotocol/sdk/types.js";
// Configuration
const JUDGE0_URL = process.env.JUDGE0_URL || "http://localhost:2358";
// Language mapping for convenience
const LANGUAGES = {
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
const TOOLS = [
    {
        name: "execute_code",
        description: "Execute code in a sandboxed environment via Judge0. Supports Python, JavaScript, TypeScript, Bash, Go, Ruby, Rust, and SQL. Returns stdout, stderr, and execution metadata.",
        inputSchema: {
            type: "object",
            properties: {
                code: {
                    type: "string",
                    description: "The source code to execute",
                },
                language: {
                    type: "string",
                    description: "Programming language: python, javascript, typescript, bash, go, ruby, rust, sql",
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
            type: "object",
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
            type: "object",
            properties: {},
        },
    },
    {
        name: "judge0_status",
        description: "Check if Judge0 is running and get version info",
        inputSchema: {
            type: "object",
            properties: {},
        },
    },
];
// Helper to make HTTP requests
async function fetchJSON(url, options) {
    const response = await fetch(url, options);
    if (!response.ok) {
        const text = await response.text();
        throw new Error(`HTTP ${response.status}: ${text}`);
    }
    return response.json();
}
// Execute code via Judge0
async function executeCode(code, language, stdin, _description) {
    // Resolve language to ID
    const langLower = language.toLowerCase();
    const languageId = LANGUAGES[langLower];
    if (!languageId) {
        throw new Error(`Unknown language: ${language}. Supported: ${Object.keys(LANGUAGES).join(", ")}`);
    }
    // Submit code (synchronous mode)
    const submission = (await fetchJSON(`${JUDGE0_URL}/submissions?base64_encoded=false&wait=true`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
            source_code: code,
            language_id: languageId,
            stdin: stdin || null,
        }),
    }));
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
async function getSubmission(token) {
    return fetchJSON(`${JUDGE0_URL}/submissions/${token}?base64_encoded=false`);
}
// List available languages
async function listLanguages() {
    return fetchJSON(`${JUDGE0_URL}/languages`);
}
// Get Judge0 status
async function getStatus() {
    return fetchJSON(`${JUDGE0_URL}/about`);
}
// Create and start server
async function main() {
    const server = new Server({
        name: "judge0-mcp-server",
        version: "1.0.0",
    }, {
        capabilities: {
            tools: {},
        },
    });
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
                    const { code, language, stdin, description } = args;
                    const result = await executeCode(code, language, stdin, description);
                    return {
                        content: [
                            {
                                type: "text",
                                text: JSON.stringify(result, null, 2),
                            },
                        ],
                    };
                }
                case "get_submission": {
                    const { token } = args;
                    const result = await getSubmission(token);
                    return {
                        content: [
                            {
                                type: "text",
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
                                type: "text",
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
                                type: "text",
                                text: JSON.stringify(result, null, 2),
                            },
                        ],
                    };
                }
                default:
                    throw new Error(`Unknown tool: ${name}`);
            }
        }
        catch (error) {
            const message = error instanceof Error ? error.message : String(error);
            return {
                content: [
                    {
                        type: "text",
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
