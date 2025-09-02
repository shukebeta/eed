#!/usr/bin/env bats

# AI-Oriented Integration Tests: File Lifecycle Management
# Tests file creation, modification, and handling of different file types

setup() {
    # Determine repository root using BATS_TEST_DIRNAME
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

    # Create unique test directory and switch into it
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"

    # Use the repository eed executable directly
    SCRIPT_UNDER_TEST="$REPO_ROOT/eed"

    # Prevent logging during tests
    export EED_TESTING=true
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

@test "file creation - new JavaScript file" {
    # AI often creates new files from scratch
    run "$SCRIPT_UNDER_TEST" --force new_script.js "1i
// AI-generated JavaScript file
function greet(name) {
    return \`Hello, \${name}!\`;
}

module.exports = { greet };
.
w
q"
    [ "$status" -eq 0 ]
    
    # File should be created with correct content
    [ -f new_script.js ]
    run grep -q "AI-generated JavaScript file" new_script.js
    [ "$status" -eq 0 ]
    run grep -q "module.exports" new_script.js
    [ "$status" -eq 0 ]
}

@test "file creation - new Python file" {
    # AI creates various file types
    run "$SCRIPT_UNDER_TEST" --force new_module.py "1i
#!/usr/bin/env python3
# AI-generated Python module

def process_data(data):
    \"\"\"Process input data and return result.\"\"\"
    return [x.strip() for x in data if x.strip()]

if __name__ == '__main__':
    print('Module loaded successfully')
.
w
q"
    [ "$status" -eq 0 ]
    
    # Verify Python file creation
    [ -f new_module.py ]
    run grep -q "#!/usr/bin/env python3" new_module.py
    [ "$status" -eq 0 ]
    run grep -q "def process_data" new_module.py
    [ "$status" -eq 0 ]
    run grep -q "__main__" new_module.py
    [ "$status" -eq 0 ]
}

@test "file creation - JSON configuration file" {
    # AI frequently creates config files
    run "$SCRIPT_UNDER_TEST" --force config.json "1i
{
  \"app_name\": \"ai-assistant\",
  \"version\": \"2.1.0\",
  \"features\": {
    \"auto_save\": true,
    \"debug_mode\": false,
    \"max_retries\": 3
  },
  \"dependencies\": []
}
.
w
q"
    [ "$status" -eq 0 ]
    
    # Verify JSON structure
    [ -f config.json ]
    run grep -q "ai-assistant" config.json
    [ "$status" -eq 0 ]
    run grep -q "auto_save" config.json
    [ "$status" -eq 0 ]
    # Basic JSON structure validation (without external dependencies)
    run grep -q "{" config.json
    [ "$status" -eq 0 ]
    run grep -q "}" config.json
    [ "$status" -eq 0 ]
}

@test "file creation - YAML configuration file" {
    # AI also works with YAML files
    run "$SCRIPT_UNDER_TEST" --force docker-compose.yml "1i
version: '3.8'
services:
  app:
    build: .
    ports:
      - \"3000:3000\"
    environment:
      - NODE_ENV=production
      - DEBUG=false
    volumes:
      - ./data:/app/data
.
w
q"
    [ "$status" -eq 0 ]
    
    # Verify YAML structure
    [ -f docker-compose.yml ]
    run grep -q "version: '3.8'" docker-compose.yml
    [ "$status" -eq 0 ]
    run grep -q "services:" docker-compose.yml
    [ "$status" -eq 0 ]
    run grep -q "NODE_ENV=production" docker-compose.yml
    [ "$status" -eq 0 ]
}

@test "existing file modification - update package.json" {
    # Start with existing package.json
    cat > package.json << 'EOF'
{
  "name": "test-project",
  "version": "1.0.0",
  "dependencies": {
    "express": "^4.18.0"
  }
}
EOF

    # AI updates dependencies
    run "$SCRIPT_UNDER_TEST" --force package.json "4a
    \"lodash\": \"^4.17.21\",
.
w
q"
    [ "$status" -eq 0 ]
    
    # Verify dependency was added
    run grep -q "lodash" package.json
    [ "$status" -eq 0 ]
    run grep -q "express" package.json
    [ "$status" -eq 0 ]
}

@test "existing file modification - update README.md" {
    # Create existing README
    cat > README.md << 'EOF'
# Test Project

A simple test project.

## Installation

Run `npm install`.
EOF

    # AI adds new section
    run "$SCRIPT_UNDER_TEST" --force README.md "\$a

## Usage

To use this project:

1. Start the server: \`npm start\`
2. Open browser to http://localhost:3000
3. Enjoy!
.
w
q"
    [ "$status" -eq 0 ]
    
    # Verify new section was added
    run grep -q "## Usage" README.md
    [ "$status" -eq 0 ]
    run grep -q "npm start" README.md
    [ "$status" -eq 0 ]
    run grep -q "localhost:3000" README.md
    [ "$status" -eq 0 ]
}

@test "empty file handling - initialize from scratch" {
    # Let eed create the file (no touch - eed's happy path)
    run "$SCRIPT_UNDER_TEST" --force empty.txt "1i
This file was empty.
Now it has content added by AI.

Line 3 of new content.
.
w
q"
    [ "$status" -eq 0 ]
    
    # Verify file was created with content
    [ -f empty.txt ]
    run grep -q "This file was empty" empty.txt
    [ "$status" -eq 0 ]
    run grep -q "added by AI" empty.txt
    [ "$status" -eq 0 ]
    # Verify exact line count (eed creates new file with our 4 lines + 1 initial empty line)
    run wc -l empty.txt
    lines=$(echo "$output" | grep -o '[0-9]\+')
    [ "$lines" -eq 5 ]  # Should have exactly 5 lines
}