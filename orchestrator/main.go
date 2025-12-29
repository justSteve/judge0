package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/spf13/cobra"
)

var (
	// Global configuration
	judge0URL  string
	dataDir    string
	httpPort   int
	verbose    bool
)

// Global instances
var (
	sessionManager *SessionManager
	judge0Client   *Judge0Client
)

func main() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

var rootCmd = &cobra.Command{
	Use:   "j0",
	Short: "Judge0 Orchestrator - Interactive execution sessions",
	Long: `Judge0 Orchestrator manages interactive code execution sessions.

It provides:
  - Session management (create, list, execute, close)
  - State persistence between executions
  - Log files for observation
  - HTTP API for programmatic access
  - CLI for human interaction

Examples:
  j0 serve                        # Start HTTP server
  j0 sessions create bash         # Create a bash session
  j0 exec <session-id> "echo hi"  # Execute code in session
  j0 log <session-id> --follow    # Watch session output`,
	PersistentPreRunE: func(cmd *cobra.Command, args []string) error {
		// Skip initialization for help commands
		if cmd.Name() == "help" || cmd.Name() == "version" {
			return nil
		}

		var err error
		sessionManager, err = NewSessionManager(dataDir)
		if err != nil {
			return fmt.Errorf("failed to initialize session manager: %w", err)
		}

		judge0Client = NewJudge0Client(judge0URL)
		return nil
	},
}

func init() {
	rootCmd.PersistentFlags().StringVar(&judge0URL, "judge0-url", "http://localhost:2358", "Judge0 API URL")
	rootCmd.PersistentFlags().StringVar(&dataDir, "data-dir", "./data", "Directory for session data")
	rootCmd.PersistentFlags().IntVar(&httpPort, "port", 8080, "HTTP server port")
	rootCmd.PersistentFlags().BoolVarP(&verbose, "verbose", "v", false, "Verbose output")

	rootCmd.AddCommand(serveCmd)
	rootCmd.AddCommand(sessionsCmd)
	rootCmd.AddCommand(execCmd)
	rootCmd.AddCommand(logCmd)
	rootCmd.AddCommand(aboutCmd)
}

// serveCmd starts the HTTP server
var serveCmd = &cobra.Command{
	Use:   "serve",
	Short: "Start the HTTP API server",
	RunE: func(cmd *cobra.Command, args []string) error {
		mux := http.NewServeMux()

		// Session endpoints
		mux.HandleFunc("POST /sessions", handleCreateSession)
		mux.HandleFunc("GET /sessions", handleListSessions)
		mux.HandleFunc("GET /sessions/{id}", handleGetSession)
		mux.HandleFunc("POST /sessions/{id}/execute", handleExecute)
		mux.HandleFunc("GET /sessions/{id}/log", handleGetLog)
		mux.HandleFunc("DELETE /sessions/{id}", handleCloseSession)

		// Health check
		mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) {
			json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
		})

		// MCP endpoints
		SetupMCPEndpoints(mux)

		addr := fmt.Sprintf(":%d", httpPort)
		log.Printf("Starting server on %s", addr)
		log.Printf("Judge0 URL: %s", judge0URL)
		log.Printf("Data directory: %s", dataDir)

		return http.ListenAndServe(addr, mux)
	},
}

// aboutCmd shows Judge0 instance info
var aboutCmd = &cobra.Command{
	Use:   "about",
	Short: "Show Judge0 instance information",
	RunE: func(cmd *cobra.Command, args []string) error {
		info, err := judge0Client.About()
		if err != nil {
			return fmt.Errorf("failed to get Judge0 info: %w", err)
		}

		enc := json.NewEncoder(os.Stdout)
		enc.SetIndent("", "  ")
		return enc.Encode(info)
	},
}

// HTTP Handlers

func handleCreateSession(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Language string `json:"language"`
		Name     string `json:"name,omitempty"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if req.Language == "" {
		http.Error(w, "language is required", http.StatusBadRequest)
		return
	}

	// Validate language
	if _, err := GetLanguageID(req.Language); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	session, err := sessionManager.CreateSession(req.Language, req.Name)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(session)
}

func handleListSessions(w http.ResponseWriter, r *http.Request) {
	sessions := sessionManager.ListSessions()
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(sessions)
}

func handleGetSession(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	session, err := sessionManager.GetSession(id)
	if err != nil {
		http.Error(w, err.Error(), http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(session)
}

func handleExecute(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	session, err := sessionManager.GetSession(id)
	if err != nil {
		http.Error(w, err.Error(), http.StatusNotFound)
		return
	}

	var req struct {
		Code  string `json:"code"`
		Stdin string `json:"stdin,omitempty"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if req.Code == "" {
		http.Error(w, "code is required", http.StatusBadRequest)
		return
	}

	// Get language ID
	langID, err := GetLanguageID(session.Language)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// Prepare code with environment variables
	fullCode := prepareCodeWithEnv(req.Code, session.State.Env, session.Language)

	// Execute
	startTime := time.Now()
	result, err := judge0Client.Execute(fullCode, langID, req.Stdin)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	duration := time.Since(startTime).Seconds() * 1000

	// Record execution
	exec := Execution{
		Code:     req.Code,
		Output:   result.Stdout,
		Stderr:   result.Stderr,
		ExitCode: result.ExitCode,
		Time:     startTime,
		Duration: duration,
	}

	if err := sessionManager.AddExecution(id, exec); err != nil {
		log.Printf("Warning: failed to record execution: %v", err)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"stdout":    result.Stdout,
		"stderr":    result.Stderr,
		"exit_code": result.ExitCode,
		"time_ms":   duration,
	})
}

func handleGetLog(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	log, err := sessionManager.GetLog(id, 100)
	if err != nil {
		http.Error(w, err.Error(), http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "text/plain")
	w.Write([]byte(log))
}

func handleCloseSession(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	if err := sessionManager.CloseSession(id); err != nil {
		http.Error(w, err.Error(), http.StatusNotFound)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// prepareCodeWithEnv wraps code to inject environment variables
func prepareCodeWithEnv(code string, env map[string]string, language string) string {
	if len(env) == 0 {
		return code
	}

	switch language {
	case "bash", "shell", "sh":
		prefix := ""
		for k, v := range env {
			prefix += fmt.Sprintf("export %s=%q\n", k, v)
		}
		return prefix + code

	case "python", "python3":
		prefix := "import os\n"
		for k, v := range env {
			prefix += fmt.Sprintf("os.environ[%q] = %q\n", k, v)
		}
		return prefix + code

	default:
		// For other languages, just return the code as-is
		return code
	}
}
