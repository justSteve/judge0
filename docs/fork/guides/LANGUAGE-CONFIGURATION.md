# Language Configuration Guide

Control which programming languages are available through the Judge0 API.

## Overview

Judge0 uses database seeds to define available languages. The actual compilers exist in the Docker image (`judge0/compilers:1.4.0`), but you control which ones are exposed through the API.

## Configuration Files

```
db/languages/
├── active.rb          # Currently active languages (loaded by seeds.rb)
├── active-minimal.rb  # Minimal set (10 languages) - for focused workflows
├── archived.rb        # Archived/legacy language versions
```

## Quick Switch

### Use Minimal Configuration (Recommended)

```bash
cd db/languages

# Backup current config
mv active.rb active-full.rb

# Use minimal config
cp active-minimal.rb active.rb

# Rebuild database
docker-compose exec server bundle exec rails db:seed
docker-compose restart
```

### Restore Full Configuration

```bash
cd db/languages
mv active.rb active-minimal.rb
mv active-full.rb active.rb

docker-compose exec server bundle exec rails db:seed
docker-compose restart
```

## Language Sets

### Minimal Configuration (10 Languages)

Optimized for agent workflows:

| ID | Language | Purpose |
|----|----------|---------|
| 43 | Plain Text | Output/debugging |
| 46 | Bash 5.0.0 | System scripting |
| 60 | Go 1.13.5 | Systems programming |
| 63 | JavaScript Node.js 12 | Web/scripting |
| 71 | Python 3.8.1 | Primary scripting |
| 72 | Ruby 2.7.0 | Scripting |
| 73 | Rust 1.40.0 | Systems programming |
| 74 | TypeScript 3.7.4 | Typed JavaScript |
| 82 | SQL SQLite 3.27 | Data queries |
| 89 | Multi-file | Complex projects |

### Full Configuration (47 Languages)

Includes everything from the base Judge0 image.

## Custom Configuration

Create your own `active.rb` by copying and modifying:

```ruby
@languages ||= []
@languages +=
[
  {
    id: 71,                              # Must be unique
    name: "Python (3.8.1)",              # Display name
    is_archived: false,                  # true = hidden from GET /languages
    source_file: "script.py",            # Default filename
    compile_cmd: nil,                    # Optional: compilation command
    run_cmd: "/usr/local/python-3.8.1/bin/python3 script.py"
  },
  # Add more languages...
]
```

### Required Fields

| Field | Description |
|-------|-------------|
| `id` | Unique numeric ID (used in API calls) |
| `name` | Display name |
| `is_archived` | `false` = active, `true` = hidden |
| `source_file` | Default source filename |
| `run_cmd` | Execution command |

### Optional Fields

| Field | Description |
|-------|-------------|
| `compile_cmd` | Compilation command (for compiled languages) |

## API Impact

### GET /languages

Returns only languages where `is_archived: false`.

### GET /languages/all

Returns all languages regardless of archived status.

### POST /submissions

Any language ID works as long as it exists in the database, even if archived.

## Best Practices

1. **Keep IDs stable** - Client code may depend on specific IDs
2. **Use minimal for production** - Faster API responses, less noise
3. **Test after changes** - Verify languages work before deploying
4. **Backup before modifying** - Keep original configs

## Verification

After switching configurations:

```bash
# List active languages
curl http://localhost:2358/languages | jq '.[] | {id, name}'

# Test Python
curl -X POST "http://localhost:2358/submissions?wait=true" \
  -H "Content-Type: application/json" \
  -d '{"source_code": "print(1+1)", "language_id": 71}'

# Test TypeScript
curl -X POST "http://localhost:2358/submissions?wait=true" \
  -H "Content-Type: application/json" \
  -d '{"source_code": "console.log(1+1)", "language_id": 74}'
```

## Reducing Docker Image Size

The language configuration only controls API exposure. The compilers remain in the Docker image.

To actually reduce image size, you'd need to build a custom compilers image:

```dockerfile
FROM judge0/compilers:1.4.0

# Remove unwanted compilers (example)
RUN rm -rf /usr/local/gcc-* /usr/local/mono-* /usr/local/fpc-*
```

This is more complex and may break dependencies. The API-level filtering is usually sufficient.

## Related

- [Docker Quick Start](./DOCKER-QUICKSTART.md)
- [Judge0 Language IDs](https://ce.judge0.com/languages)
