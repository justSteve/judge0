# Minimal Language Configuration v2
# ==================================
# Updated for custom minimal Docker image with latest versions.
# Includes Bun as primary JS/TS runtime while keeping Node/TS for compatibility.
#
# To use: rename active.rb to active-full.rb, rename this to active.rb
# To revert: rename active.rb to active-minimal-v2.rb, rename active-full.rb to active.rb
#
# IMPORTANT: Paths must match Dockerfile.minimal ENV versions!
# Update both files together when changing versions.

@languages ||= []
@languages +=
[
  # ============================================================================
  # UTILITY
  # ============================================================================

  {
    id: 43,
    name: "Plain Text",
    is_archived: false,
    source_file: "text.txt",
    run_cmd: "/bin/cat text.txt"
  },

  # ============================================================================
  # SHELL
  # ============================================================================

  {
    id: 46,
    name: "Bash (5.2)",
    is_archived: false,
    source_file: "script.sh",
    run_cmd: "/usr/local/bash-5.2/bin/bash script.sh"
  },

  # ============================================================================
  # PYTHON
  # ============================================================================

  {
    id: 71,
    name: "Python (3.12.8)",
    is_archived: false,
    source_file: "script.py",
    run_cmd: "/usr/local/python-3.12.8/bin/python3 script.py"
  },

  # ============================================================================
  # JAVASCRIPT / TYPESCRIPT
  # ============================================================================

  {
    id: 63,
    name: "JavaScript (Node.js 22.12.0)",
    is_archived: false,
    source_file: "script.js",
    run_cmd: "/usr/local/node-22.12.0/bin/node script.js"
  },
  {
    id: 74,
    name: "TypeScript (5.7.2)",
    is_archived: false,
    source_file: "script.ts",
    compile_cmd: "/usr/bin/tsc %s script.ts",
    run_cmd: "/usr/local/node-22.12.0/bin/node script.js"
  },
  {
    id: 90,
    name: "Bun (1.1.45)",
    is_archived: false,
    source_file: "script.ts",
    run_cmd: "/usr/local/bun-1.1.45/bin/bun script.ts"
  },
  {
    id: 91,
    name: "JavaScript (Bun 1.1.45)",
    is_archived: false,
    source_file: "script.js",
    run_cmd: "/usr/local/bun-1.1.45/bin/bun script.js"
  },

  # ============================================================================
  # SYSTEMS LANGUAGES
  # ============================================================================

  {
    id: 60,
    name: "Go (1.23.4)",
    is_archived: false,
    source_file: "main.go",
    compile_cmd: "GOCACHE=/tmp/.cache/go-build /usr/local/go-1.23.4/bin/go build %s main.go",
    run_cmd: "./main"
  },
  {
    id: 72,
    name: "Ruby (3.3.6)",
    is_archived: false,
    source_file: "script.rb",
    run_cmd: "/usr/local/ruby-3.3.6/bin/ruby script.rb"
  },
  {
    id: 73,
    name: "Rust (1.84.0)",
    is_archived: false,
    source_file: "main.rs",
    compile_cmd: "/usr/local/rust-1.84.0/bin/rustc %s main.rs",
    run_cmd: "./main"
  },

  # ============================================================================
  # DATA
  # ============================================================================

  {
    id: 82,
    name: "SQL (SQLite 3.x)",
    is_archived: false,
    source_file: "script.sql",
    run_cmd: "/bin/cat script.sql | /usr/bin/sqlite3 db.sqlite"
  },

  # ============================================================================
  # MULTI-FILE SUPPORT
  # ============================================================================

  {
    id: 89,
    name: "Multi-file program",
    is_archived: false,
  }
]

# ============================================================================
# LANGUAGE SUMMARY (12 total)
# ============================================================================
# ID  | Language              | Runtime
# ----|----------------------|------------------
# 43  | Plain Text           | cat
# 46  | Bash                 | 5.2
# 71  | Python               | 3.12.8
# 63  | JavaScript (Node)    | 22.12.0
# 74  | TypeScript           | 5.7.2 (via tsc + Node)
# 90  | TypeScript (Bun)     | 1.1.45
# 91  | JavaScript (Bun)     | 1.1.45
# 60  | Go                   | 1.23.4
# 72  | Ruby                 | 3.3.6
# 73  | Rust                 | 1.84.0
# 82  | SQL                  | SQLite 3.x
# 89  | Multi-file           | -
