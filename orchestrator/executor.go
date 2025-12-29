package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

// Judge0Client handles communication with Judge0 API
type Judge0Client struct {
	baseURL    string
	httpClient *http.Client
}

// Judge0Submission represents a code submission request
type Judge0Submission struct {
	SourceCode       string `json:"source_code"`
	LanguageID       int    `json:"language_id"`
	Stdin            string `json:"stdin,omitempty"`
	ExpectedOutput   string `json:"expected_output,omitempty"`
	CPUTimeLimit     int    `json:"cpu_time_limit,omitempty"`
	MemoryLimit      int    `json:"memory_limit,omitempty"`
	AdditionalFiles  string `json:"additional_files,omitempty"`
	CompilerOptions  string `json:"compiler_options,omitempty"`
	CommandLineArgs  string `json:"command_line_arguments,omitempty"`
}

// Judge0Result represents execution result
type Judge0Result struct {
	Token         string  `json:"token"`
	Stdout        string  `json:"stdout"`
	Stderr        string  `json:"stderr"`
	CompileOutput string  `json:"compile_output"`
	Message       string  `json:"message"`
	ExitCode      int     `json:"exit_code"`
	Time          string  `json:"time"`
	Memory        int     `json:"memory"`
	Status        Status  `json:"status"`
}

// Status represents Judge0 execution status
type Status struct {
	ID          int    `json:"id"`
	Description string `json:"description"`
}

// Language IDs for common languages
const (
	LanguageBash       = 46
	LanguagePython3    = 71
	LanguageGo         = 60
	LanguageJavaScript = 63
	LanguageRuby       = 72
	LanguageRust       = 73
	LanguageC          = 50
	LanguageCPP        = 54
)

// LanguageMap maps language names to Judge0 IDs
var LanguageMap = map[string]int{
	"bash":       LanguageBash,
	"shell":      LanguageBash,
	"sh":         LanguageBash,
	"python":     LanguagePython3,
	"python3":    LanguagePython3,
	"go":         LanguageGo,
	"golang":     LanguageGo,
	"javascript": LanguageJavaScript,
	"js":         LanguageJavaScript,
	"node":       LanguageJavaScript,
	"ruby":       LanguageRuby,
	"rust":       LanguageRust,
	"c":          LanguageC,
	"cpp":        LanguageCPP,
	"c++":        LanguageCPP,
}

// NewJudge0Client creates a new Judge0 API client
func NewJudge0Client(baseURL string) *Judge0Client {
	return &Judge0Client{
		baseURL: baseURL,
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
	}
}

// GetLanguageID returns the Judge0 language ID for a language name
func GetLanguageID(language string) (int, error) {
	id, ok := LanguageMap[language]
	if !ok {
		return 0, fmt.Errorf("unsupported language: %s", language)
	}
	return id, nil
}

// Execute submits code for execution and waits for result
func (c *Judge0Client) Execute(code string, languageID int, stdin string) (*Judge0Result, error) {
	// Create submission
	submission := Judge0Submission{
		SourceCode:   code,
		LanguageID:   languageID,
		Stdin:        stdin,
		CPUTimeLimit: 5,     // 5 seconds
		MemoryLimit:  128000, // 128MB
	}

	// Submit
	token, err := c.createSubmission(submission)
	if err != nil {
		return nil, fmt.Errorf("failed to create submission: %w", err)
	}

	// Poll for result
	return c.waitForResult(token)
}

// createSubmission sends code to Judge0 and returns submission token
func (c *Judge0Client) createSubmission(sub Judge0Submission) (string, error) {
	data, err := json.Marshal(sub)
	if err != nil {
		return "", err
	}

	url := c.baseURL + "/submissions?base64_encoded=false&wait=false"
	req, err := http.NewRequest("POST", url, bytes.NewReader(data))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusCreated {
		body, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("submission failed: %s - %s", resp.Status, string(body))
	}

	var result struct {
		Token string `json:"token"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return "", err
	}

	return result.Token, nil
}

// waitForResult polls Judge0 until execution completes
func (c *Judge0Client) waitForResult(token string) (*Judge0Result, error) {
	url := c.baseURL + "/submissions/" + token + "?base64_encoded=false"

	maxAttempts := 30
	for i := 0; i < maxAttempts; i++ {
		req, err := http.NewRequest("GET", url, nil)
		if err != nil {
			return nil, err
		}

		resp, err := c.httpClient.Do(req)
		if err != nil {
			return nil, err
		}

		var result Judge0Result
		if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
			resp.Body.Close()
			return nil, err
		}
		resp.Body.Close()

		// Status ID 1-2 = In Queue/Processing
		// Status ID 3+ = Finished (with various outcomes)
		if result.Status.ID >= 3 {
			return &result, nil
		}

		time.Sleep(500 * time.Millisecond)
	}

	return nil, fmt.Errorf("execution timed out waiting for result")
}

// About returns Judge0 instance information
func (c *Judge0Client) About() (map[string]interface{}, error) {
	url := c.baseURL + "/about"
	resp, err := c.httpClient.Get(url)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var result map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, err
	}

	return result, nil
}

// Languages returns supported languages
func (c *Judge0Client) Languages() ([]map[string]interface{}, error) {
	url := c.baseURL + "/languages"
	resp, err := c.httpClient.Get(url)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var result []map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, err
	}

	return result, nil
}
