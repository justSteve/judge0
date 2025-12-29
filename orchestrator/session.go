package main

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"
)

// Session represents an interactive execution session
type Session struct {
	ID        string       `json:"id"`
	Name      string       `json:"name,omitempty"`
	Language  string       `json:"language"`
	CreatedAt time.Time    `json:"created_at"`
	UpdatedAt time.Time    `json:"updated_at"`
	State     SessionState `json:"state"`
	LogFile   string       `json:"log_file"`
	Status    string       `json:"status"` // "active", "paused", "closed"
}

// SessionState holds persistent state between executions
type SessionState struct {
	Env     map[string]string `json:"env"`
	History []Execution       `json:"history"`
}

// Execution represents a single code execution within a session
type Execution struct {
	ID       string    `json:"id"`
	Code     string    `json:"code"`
	Output   string    `json:"output"`
	Stderr   string    `json:"stderr,omitempty"`
	ExitCode int       `json:"exit_code"`
	Time     time.Time `json:"time"`
	Duration float64   `json:"duration_ms"`
}

// SessionManager handles session CRUD operations
type SessionManager struct {
	sessions map[string]*Session
	dataDir  string
	mu       sync.RWMutex
}

// NewSessionManager creates a new session manager
func NewSessionManager(dataDir string) (*SessionManager, error) {
	if err := os.MkdirAll(dataDir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create data directory: %w", err)
	}

	logsDir := filepath.Join(dataDir, "logs")
	if err := os.MkdirAll(logsDir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create logs directory: %w", err)
	}

	sm := &SessionManager{
		sessions: make(map[string]*Session),
		dataDir:  dataDir,
	}

	// Load existing sessions
	if err := sm.loadSessions(); err != nil {
		return nil, fmt.Errorf("failed to load sessions: %w", err)
	}

	return sm, nil
}

// generateID creates a random session ID
func generateID(prefix string) string {
	bytes := make([]byte, 4)
	rand.Read(bytes)
	return prefix + "-" + hex.EncodeToString(bytes)
}

// CreateSession creates a new session
func (sm *SessionManager) CreateSession(language, name string) (*Session, error) {
	sm.mu.Lock()
	defer sm.mu.Unlock()

	id := generateID("sess")
	now := time.Now()

	session := &Session{
		ID:        id,
		Name:      name,
		Language:  language,
		CreatedAt: now,
		UpdatedAt: now,
		State: SessionState{
			Env:     make(map[string]string),
			History: []Execution{},
		},
		LogFile: filepath.Join(sm.dataDir, "logs", id+".log"),
		Status:  "active",
	}

	// Create log file
	if err := os.WriteFile(session.LogFile, []byte{}, 0644); err != nil {
		return nil, fmt.Errorf("failed to create log file: %w", err)
	}

	sm.sessions[id] = session

	// Persist session
	if err := sm.saveSession(session); err != nil {
		return nil, fmt.Errorf("failed to save session: %w", err)
	}

	return session, nil
}

// GetSession retrieves a session by ID
func (sm *SessionManager) GetSession(id string) (*Session, error) {
	sm.mu.RLock()
	defer sm.mu.RUnlock()

	session, ok := sm.sessions[id]
	if !ok {
		return nil, fmt.Errorf("session not found: %s", id)
	}
	return session, nil
}

// ListSessions returns all sessions
func (sm *SessionManager) ListSessions() []*Session {
	sm.mu.RLock()
	defer sm.mu.RUnlock()

	sessions := make([]*Session, 0, len(sm.sessions))
	for _, s := range sm.sessions {
		sessions = append(sessions, s)
	}
	return sessions
}

// AddExecution records an execution in the session
func (sm *SessionManager) AddExecution(sessionID string, exec Execution) error {
	sm.mu.Lock()
	defer sm.mu.Unlock()

	session, ok := sm.sessions[sessionID]
	if !ok {
		return fmt.Errorf("session not found: %s", sessionID)
	}

	exec.ID = generateID("exec")
	session.State.History = append(session.State.History, exec)
	session.UpdatedAt = time.Now()

	// Append to log file
	logEntry := fmt.Sprintf("[%s] $ %s\n%s\n", exec.Time.Format(time.RFC3339), exec.Code, exec.Output)
	if exec.Stderr != "" {
		logEntry += fmt.Sprintf("[stderr] %s\n", exec.Stderr)
	}
	logEntry += fmt.Sprintf("[exit: %d, duration: %.2fms]\n\n", exec.ExitCode, exec.Duration)

	f, err := os.OpenFile(session.LogFile, os.O_APPEND|os.O_WRONLY, 0644)
	if err != nil {
		return fmt.Errorf("failed to open log file: %w", err)
	}
	defer f.Close()
	f.WriteString(logEntry)

	return sm.saveSession(session)
}

// SetEnv sets an environment variable in the session
func (sm *SessionManager) SetEnv(sessionID, key, value string) error {
	sm.mu.Lock()
	defer sm.mu.Unlock()

	session, ok := sm.sessions[sessionID]
	if !ok {
		return fmt.Errorf("session not found: %s", sessionID)
	}

	session.State.Env[key] = value
	session.UpdatedAt = time.Now()

	return sm.saveSession(session)
}

// CloseSession marks a session as closed
func (sm *SessionManager) CloseSession(id string) error {
	sm.mu.Lock()
	defer sm.mu.Unlock()

	session, ok := sm.sessions[id]
	if !ok {
		return fmt.Errorf("session not found: %s", id)
	}

	session.Status = "closed"
	session.UpdatedAt = time.Now()

	return sm.saveSession(session)
}

// GetLog returns the last N lines of a session's log
func (sm *SessionManager) GetLog(sessionID string, lines int) (string, error) {
	sm.mu.RLock()
	session, ok := sm.sessions[sessionID]
	sm.mu.RUnlock()

	if !ok {
		return "", fmt.Errorf("session not found: %s", sessionID)
	}

	content, err := os.ReadFile(session.LogFile)
	if err != nil {
		return "", fmt.Errorf("failed to read log file: %w", err)
	}

	// TODO: Implement tail functionality for large logs
	return string(content), nil
}

// saveSession persists a session to disk
func (sm *SessionManager) saveSession(session *Session) error {
	data, err := json.MarshalIndent(session, "", "  ")
	if err != nil {
		return err
	}

	path := filepath.Join(sm.dataDir, session.ID+".json")
	return os.WriteFile(path, data, 0644)
}

// loadSessions loads all sessions from disk
func (sm *SessionManager) loadSessions() error {
	entries, err := os.ReadDir(sm.dataDir)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}

	for _, entry := range entries {
		if entry.IsDir() || filepath.Ext(entry.Name()) != ".json" {
			continue
		}

		path := filepath.Join(sm.dataDir, entry.Name())
		data, err := os.ReadFile(path)
		if err != nil {
			continue
		}

		var session Session
		if err := json.Unmarshal(data, &session); err != nil {
			continue
		}

		sm.sessions[session.ID] = &session
	}

	return nil
}
