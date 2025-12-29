package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"time"
)

// MCP Tool Definitions
// These are exposed as MCP tools for Claude to use via the MCP protocol.
// The orchestrator HTTP API already provides the endpoints; this file documents
// the MCP tool schema and provides helper utilities.

// MCPTool represents an MCP tool definition
type MCPTool struct {
	Name        string                 `json:"name"`
	Description string                 `json:"description"`
	InputSchema map[string]interface{} `json:"input_schema"`
}

// MCPTools returns the list of MCP tools provided by this orchestrator
func MCPTools() []MCPTool {
	return []MCPTool{
		{
			Name:        "j0_create_session",
			Description: "Create a new interactive code execution session. Returns session ID for subsequent operations.",
			InputSchema: map[string]interface{}{
				"type": "object",
				"properties": map[string]interface{}{
					"language": map[string]interface{}{
						"type":        "string",
						"description": "Programming language for the session (bash, python, go, javascript, ruby, rust, c, cpp)",
					},
					"name": map[string]interface{}{
						"type":        "string",
						"description": "Optional human-readable name for the session",
					},
				},
				"required": []string{"language"},
			},
		},
		{
			Name:        "j0_execute",
			Description: "Execute code in an existing session. Returns stdout, stderr, and exit code.",
			InputSchema: map[string]interface{}{
				"type": "object",
				"properties": map[string]interface{}{
					"session_id": map[string]interface{}{
						"type":        "string",
						"description": "The session ID to execute code in",
					},
					"code": map[string]interface{}{
						"type":        "string",
						"description": "The code to execute",
					},
					"stdin": map[string]interface{}{
						"type":        "string",
						"description": "Optional standard input for the code",
					},
				},
				"required": []string{"session_id", "code"},
			},
		},
		{
			Name:        "j0_get_session",
			Description: "Get details about a session including its state, environment variables, and execution history.",
			InputSchema: map[string]interface{}{
				"type": "object",
				"properties": map[string]interface{}{
					"session_id": map[string]interface{}{
						"type":        "string",
						"description": "The session ID to retrieve",
					},
				},
				"required": []string{"session_id"},
			},
		},
		{
			Name:        "j0_list_sessions",
			Description: "List all execution sessions with their status and basic info.",
			InputSchema: map[string]interface{}{
				"type":       "object",
				"properties": map[string]interface{}{},
			},
		},
		{
			Name:        "j0_get_log",
			Description: "Get the execution log for a session showing all commands and their output.",
			InputSchema: map[string]interface{}{
				"type": "object",
				"properties": map[string]interface{}{
					"session_id": map[string]interface{}{
						"type":        "string",
						"description": "The session ID to get logs for",
					},
					"lines": map[string]interface{}{
						"type":        "integer",
						"description": "Number of lines to retrieve (default: 100)",
					},
				},
				"required": []string{"session_id"},
			},
		},
		{
			Name:        "j0_close_session",
			Description: "Close a session. The session log is preserved but no more executions can be performed.",
			InputSchema: map[string]interface{}{
				"type": "object",
				"properties": map[string]interface{}{
					"session_id": map[string]interface{}{
						"type":        "string",
						"description": "The session ID to close",
					},
				},
				"required": []string{"session_id"},
			},
		},
		{
			Name:        "j0_set_env",
			Description: "Set an environment variable in a session. The variable will be available in all subsequent executions.",
			InputSchema: map[string]interface{}{
				"type": "object",
				"properties": map[string]interface{}{
					"session_id": map[string]interface{}{
						"type":        "string",
						"description": "The session ID to modify",
					},
					"key": map[string]interface{}{
						"type":        "string",
						"description": "Environment variable name",
					},
					"value": map[string]interface{}{
						"type":        "string",
						"description": "Environment variable value",
					},
				},
				"required": []string{"session_id", "key", "value"},
			},
		},
	}
}

// SetupMCPEndpoints adds MCP-specific endpoints to the HTTP server
func SetupMCPEndpoints(mux *http.ServeMux) {
	// Tool discovery endpoint
	mux.HandleFunc("GET /mcp/tools", handleMCPTools)

	// Tool invocation endpoint
	mux.HandleFunc("POST /mcp/invoke", handleMCPInvoke)

	// Additional API endpoint for setting env vars
	mux.HandleFunc("POST /sessions/{id}/env", handleSetEnv)
}

func handleMCPTools(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(MCPTools())
}

func handleMCPInvoke(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Tool   string                 `json:"tool"`
		Params map[string]interface{} `json:"params"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	var result interface{}
	var err error

	switch req.Tool {
	case "j0_create_session":
		result, err = invokeMCPCreateSession(req.Params)
	case "j0_execute":
		result, err = invokeMCPExecute(req.Params)
	case "j0_get_session":
		result, err = invokeMCPGetSession(req.Params)
	case "j0_list_sessions":
		result, err = invokeMCPListSessions(req.Params)
	case "j0_get_log":
		result, err = invokeMCPGetLog(req.Params)
	case "j0_close_session":
		result, err = invokeMCPCloseSession(req.Params)
	case "j0_set_env":
		result, err = invokeMCPSetEnv(req.Params)
	default:
		http.Error(w, fmt.Sprintf("unknown tool: %s", req.Tool), http.StatusBadRequest)
		return
	}

	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result)
}

func handleSetEnv(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")

	var req struct {
		Key   string `json:"key"`
		Value string `json:"value"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if err := sessionManager.SetEnv(id, req.Key, req.Value); err != nil {
		http.Error(w, err.Error(), http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}

// MCP Tool Invocation Helpers

func invokeMCPCreateSession(params map[string]interface{}) (interface{}, error) {
	language, _ := params["language"].(string)
	name, _ := params["name"].(string)

	if language == "" {
		return nil, fmt.Errorf("language is required")
	}

	if _, err := GetLanguageID(language); err != nil {
		return nil, err
	}

	return sessionManager.CreateSession(language, name)
}

func invokeMCPExecute(params map[string]interface{}) (interface{}, error) {
	sessionID, _ := params["session_id"].(string)
	code, _ := params["code"].(string)
	stdin, _ := params["stdin"].(string)

	if sessionID == "" {
		return nil, fmt.Errorf("session_id is required")
	}
	if code == "" {
		return nil, fmt.Errorf("code is required")
	}

	session, err := sessionManager.GetSession(sessionID)
	if err != nil {
		return nil, err
	}

	langID, err := GetLanguageID(session.Language)
	if err != nil {
		return nil, err
	}

	fullCode := prepareCodeWithEnv(code, session.State.Env, session.Language)

	startTime := time.Now()
	result, err := judge0Client.Execute(fullCode, langID, stdin)
	if err != nil {
		return nil, err
	}
	duration := time.Since(startTime).Seconds() * 1000

	exec := Execution{
		Code:     code,
		Output:   result.Stdout,
		Stderr:   result.Stderr,
		ExitCode: result.ExitCode,
		Time:     startTime,
		Duration: duration,
	}

	sessionManager.AddExecution(sessionID, exec)

	return map[string]interface{}{
		"stdout":    result.Stdout,
		"stderr":    result.Stderr,
		"exit_code": result.ExitCode,
		"time_ms":   duration,
	}, nil
}

func invokeMCPGetSession(params map[string]interface{}) (interface{}, error) {
	sessionID, _ := params["session_id"].(string)
	if sessionID == "" {
		return nil, fmt.Errorf("session_id is required")
	}
	return sessionManager.GetSession(sessionID)
}

func invokeMCPListSessions(params map[string]interface{}) (interface{}, error) {
	return sessionManager.ListSessions(), nil
}

func invokeMCPGetLog(params map[string]interface{}) (interface{}, error) {
	sessionID, _ := params["session_id"].(string)
	if sessionID == "" {
		return nil, fmt.Errorf("session_id is required")
	}

	lines := 100
	if l, ok := params["lines"].(float64); ok {
		lines = int(l)
	}

	content, err := sessionManager.GetLog(sessionID, lines)
	if err != nil {
		return nil, err
	}

	return map[string]string{"log": content}, nil
}

func invokeMCPCloseSession(params map[string]interface{}) (interface{}, error) {
	sessionID, _ := params["session_id"].(string)
	if sessionID == "" {
		return nil, fmt.Errorf("session_id is required")
	}

	if err := sessionManager.CloseSession(sessionID); err != nil {
		return nil, err
	}

	return map[string]string{"status": "closed"}, nil
}

func invokeMCPSetEnv(params map[string]interface{}) (interface{}, error) {
	sessionID, _ := params["session_id"].(string)
	key, _ := params["key"].(string)
	value, _ := params["value"].(string)

	if sessionID == "" {
		return nil, fmt.Errorf("session_id is required")
	}
	if key == "" {
		return nil, fmt.Errorf("key is required")
	}

	if err := sessionManager.SetEnv(sessionID, key, value); err != nil {
		return nil, err
	}

	return map[string]string{"status": "ok"}, nil
}
