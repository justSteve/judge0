# Minimal Language Configuration
# ================================
# This configuration includes only the core languages needed for agent workflows:
# - Python (primary scripting)
# - JavaScript/TypeScript (web/node workflows)
# - Java (enterprise/DSPy)
# - Bash (system scripting)
# - Plus a few utility languages for agent flexibility
#
# To use: rename active.rb to active-full.rb, rename this to active.rb
# To revert: rename active.rb to active-minimal.rb, rename active-full.rb to active.rb

@languages ||= []
@languages +=
[
  # ============================================================================
  # CORE LANGUAGES (Human + Agent Primary Use)
  # ============================================================================

  {
    id: 43,
    name: "Plain Text",
    is_archived: false,
    source_file: "text.txt",
    run_cmd: "/bin/cat text.txt"
  },
  {
    id: 46,
    name: "Bash (5.0.0)",
    is_archived: false,
    source_file: "script.sh",
    run_cmd: "/usr/local/bash-5.0/bin/bash script.sh"
  },
  {
    id: 62,
    name: "Java (OpenJDK 13.0.1)",
    is_archived: false,
    source_file: "Main.java",
    compile_cmd: "/usr/local/openjdk13/bin/javac %s Main.java",
    run_cmd: "/usr/local/openjdk13/bin/java Main"
  },
  {
    id: 63,
    name: "JavaScript (Node.js 12.14.0)",
    is_archived: false,
    source_file: "script.js",
    run_cmd: "/usr/local/node-12.14.0/bin/node script.js"
  },
  {
    id: 71,
    name: "Python (3.8.1)",
    is_archived: false,
    source_file: "script.py",
    run_cmd: "/usr/local/python-3.8.1/bin/python3 script.py"
  },
  {
    id: 74,
    name: "TypeScript (3.7.4)",
    is_archived: false,
    source_file: "script.ts",
    compile_cmd: "/usr/bin/tsc %s script.ts",
    run_cmd: "/usr/local/node-12.14.0/bin/node script.js"
  },

  # ============================================================================
  # AGENT UTILITY LANGUAGES (Useful for agent flexibility)
  # ============================================================================

  {
    id: 60,
    name: "Go (1.13.5)",
    is_archived: false,
    source_file: "main.go",
    compile_cmd: "GOCACHE=/tmp/.cache/go-build /usr/local/go-1.13.5/bin/go build %s main.go",
    run_cmd: "./main"
  },
  {
    id: 72,
    name: "Ruby (2.7.0)",
    is_archived: false,
    source_file: "script.rb",
    run_cmd: "/usr/local/ruby-2.7.0/bin/ruby script.rb"
  },
  {
    id: 73,
    name: "Rust (1.40.0)",
    is_archived: false,
    source_file: "main.rs",
    compile_cmd: "/usr/local/rust-1.40.0/bin/rustc %s main.rs",
    run_cmd: "./main"
  },
  {
    id: 82,
    name: "SQL (SQLite 3.27.2)",
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
# EXCLUDED LANGUAGES (Available in active-full.rb)
# ============================================================================
# The following languages are excluded from this minimal config:
# - C, C++ (IDs: 48-54, 75-76) - Low-level, rarely needed for agent work
# - C#, Visual Basic .NET (IDs: 51, 84, 87) - .NET ecosystem
# - Assembly (ID: 45) - Very specialized
# - COBOL, Fortran, Pascal (IDs: 59, 67, 77) - Legacy languages
# - Haskell, OCaml, Prolog (IDs: 61, 65, 69) - Academic/functional
# - D, Elixir, Erlang (IDs: 56-58) - Specialized
# - Common Lisp, Clojure (IDs: 55, 86) - Lisp dialects
# - Objective-C, Swift (IDs: 79, 83) - Apple ecosystem
# - Kotlin, Scala, Groovy (IDs: 78, 81, 88) - JVM alternatives
# - Lua, Perl, PHP, R (IDs: 64, 68, 80, 85) - Scripting alternatives
# - Basic, Octave (IDs: 47, 66) - Specialized
# - Python 2.7 (ID: 70) - Legacy Python
