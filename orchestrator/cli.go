package main

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/spf13/cobra"
)

// sessionsCmd manages sessions
var sessionsCmd = &cobra.Command{
	Use:   "sessions",
	Short: "Manage execution sessions",
}

func init() {
	sessionsCmd.AddCommand(sessionsCreateCmd)
	sessionsCmd.AddCommand(sessionsListCmd)
	sessionsCmd.AddCommand(sessionsShowCmd)
	sessionsCmd.AddCommand(sessionsCloseCmd)
}

var sessionsCreateCmd = &cobra.Command{
	Use:   "create <language>",
	Short: "Create a new session",
	Long: `Create a new execution session for the specified language.

Supported languages: bash, python, go, javascript, ruby, rust, c, cpp

Examples:
  j0 sessions create bash
  j0 sessions create python --name "data-analysis"`,
	Args: cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		language := args[0]
		name, _ := cmd.Flags().GetString("name")

		// Validate language
		if _, err := GetLanguageID(language); err != nil {
			return err
		}

		session, err := sessionManager.CreateSession(language, name)
		if err != nil {
			return err
		}

		if verbose {
			enc := json.NewEncoder(os.Stdout)
			enc.SetIndent("", "  ")
			return enc.Encode(session)
		}

		fmt.Printf("Created session: %s (%s)\n", session.ID, session.Language)
		fmt.Printf("Log file: %s\n", session.LogFile)
		return nil
	},
}

func init() {
	sessionsCreateCmd.Flags().String("name", "", "Optional session name")
}

var sessionsListCmd = &cobra.Command{
	Use:   "list",
	Short: "List all sessions",
	RunE: func(cmd *cobra.Command, args []string) error {
		sessions := sessionManager.ListSessions()

		if len(sessions) == 0 {
			fmt.Println("No sessions found.")
			return nil
		}

		jsonOut, _ := cmd.Flags().GetBool("json")
		if jsonOut {
			enc := json.NewEncoder(os.Stdout)
			enc.SetIndent("", "  ")
			return enc.Encode(sessions)
		}

		fmt.Printf("%-15s %-10s %-10s %-20s %s\n", "ID", "LANGUAGE", "STATUS", "CREATED", "NAME")
		fmt.Println(strings.Repeat("-", 70))

		for _, s := range sessions {
			name := s.Name
			if name == "" {
				name = "-"
			}
			fmt.Printf("%-15s %-10s %-10s %-20s %s\n",
				s.ID,
				s.Language,
				s.Status,
				s.CreatedAt.Format("2006-01-02 15:04:05"),
				name,
			)
		}

		return nil
	},
}

func init() {
	sessionsListCmd.Flags().Bool("json", false, "Output as JSON")
}

var sessionsShowCmd = &cobra.Command{
	Use:   "show <session-id>",
	Short: "Show session details",
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		session, err := sessionManager.GetSession(args[0])
		if err != nil {
			return err
		}

		enc := json.NewEncoder(os.Stdout)
		enc.SetIndent("", "  ")
		return enc.Encode(session)
	},
}

var sessionsCloseCmd = &cobra.Command{
	Use:   "close <session-id>",
	Short: "Close a session",
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		if err := sessionManager.CloseSession(args[0]); err != nil {
			return err
		}
		fmt.Printf("Session %s closed.\n", args[0])
		return nil
	},
}

// execCmd executes code in a session
var execCmd = &cobra.Command{
	Use:   "exec <session-id> <code>",
	Short: "Execute code in a session",
	Long: `Execute code in an existing session.

The code is executed with the session's environment variables injected.
Output and stderr are returned, and the execution is logged.

Examples:
  j0 exec sess-abc123 "echo hello"
  j0 exec sess-abc123 "ls -la"
  j0 exec sess-abc123 "export FOO=bar && echo \$FOO"`,
	Args: cobra.ExactArgs(2),
	RunE: func(cmd *cobra.Command, args []string) error {
		sessionID := args[0]
		code := args[1]

		session, err := sessionManager.GetSession(sessionID)
		if err != nil {
			return err
		}

		if session.Status != "active" {
			return fmt.Errorf("session is not active: %s", session.Status)
		}

		// Get language ID
		langID, err := GetLanguageID(session.Language)
		if err != nil {
			return err
		}

		// Prepare code with environment
		fullCode := prepareCodeWithEnv(code, session.State.Env, session.Language)

		stdin, _ := cmd.Flags().GetString("stdin")

		// Execute
		startTime := time.Now()
		result, err := judge0Client.Execute(fullCode, langID, stdin)
		if err != nil {
			return fmt.Errorf("execution failed: %w", err)
		}
		duration := time.Since(startTime).Seconds() * 1000

		// Record execution
		exec := Execution{
			Code:     code,
			Output:   result.Stdout,
			Stderr:   result.Stderr,
			ExitCode: result.ExitCode,
			Time:     startTime,
			Duration: duration,
		}

		if err := sessionManager.AddExecution(sessionID, exec); err != nil {
			fmt.Fprintf(os.Stderr, "Warning: failed to record execution: %v\n", err)
		}

		jsonOut, _ := cmd.Flags().GetBool("json")
		if jsonOut {
			enc := json.NewEncoder(os.Stdout)
			enc.SetIndent("", "  ")
			return enc.Encode(map[string]interface{}{
				"stdout":    result.Stdout,
				"stderr":    result.Stderr,
				"exit_code": result.ExitCode,
				"time_ms":   duration,
			})
		}

		// Print output
		if result.Stdout != "" {
			fmt.Print(result.Stdout)
		}
		if result.Stderr != "" {
			fmt.Fprintf(os.Stderr, "%s", result.Stderr)
		}

		if result.ExitCode != 0 {
			return fmt.Errorf("exit code: %d", result.ExitCode)
		}

		return nil
	},
}

func init() {
	execCmd.Flags().String("stdin", "", "Standard input for the code")
	execCmd.Flags().Bool("json", false, "Output as JSON")
}

// logCmd shows session logs
var logCmd = &cobra.Command{
	Use:   "log <session-id>",
	Short: "Show session execution log",
	Long: `Display the execution log for a session.

The log contains all commands executed, their output, and timing information.

Examples:
  j0 log sess-abc123
  j0 log sess-abc123 --follow`,
	Args: cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		sessionID := args[0]

		follow, _ := cmd.Flags().GetBool("follow")
		lines, _ := cmd.Flags().GetInt("lines")

		content, err := sessionManager.GetLog(sessionID, lines)
		if err != nil {
			return err
		}

		fmt.Print(content)

		if follow {
			// TODO: Implement tail -f functionality
			fmt.Println("\n[--follow not yet implemented, showing current log]")
		}

		return nil
	},
}

func init() {
	logCmd.Flags().BoolP("follow", "f", false, "Follow log output (like tail -f)")
	logCmd.Flags().IntP("lines", "n", 100, "Number of lines to show")
}
