#!/usr/bin/env bats

# AI-Oriented Integration Tests: Real-World Scenarios
# Tests realistic AI automation tasks that combine multiple operations

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

    # Create realistic project files
    cat > package.json << 'EOF'
{
  "name": "my-app",
  "version": "1.0.0",
  "description": "A sample application",
  "main": "index.js",
  "dependencies": {
    "express": "^4.18.0"
  },
  "devDependencies": {},
  "scripts": {
    "start": "node index.js"
  }
}
EOF

    cat > index.js << 'EOF'
const express = require('express');
const app = express();

app.get('/', (req, res) => {
  res.send('Hello World');
});

app.listen(3000, () => {
  console.log('Server running on port 3000');
});
EOF

    cat > README.md << 'EOF'
# My App

A simple Express.js application.

## Installation

```bash
npm install
```

## Usage

```bash
npm start
```
EOF

    cat > .env.example << 'EOF'
PORT=3000
NODE_ENV=development
DEBUG=false
EOF
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

@test "code refactoring - add new route with error handling" {
    # AI adds a new API route with proper error handling
    run "$SCRIPT_UNDER_TEST" --force index.js "8a

// New API endpoint added by AI
app.get('/api/health', (req, res) => {
  try {
    res.json({ status: 'healthy', timestamp: new Date().toISOString() });
  } catch (error) {
    res.status(500).json({ error: 'Internal server error' });
  }
});
.
w
q"
    [ "$status" -eq 0 ]
    
    # Verify new route was added
    run grep -q "/api/health" index.js
    [ "$status" -eq 0 ]
    run grep -q "try {" index.js
    [ "$status" -eq 0 ]
    run grep -q "catch (error)" index.js
    [ "$status" -eq 0 ]
    
    # Original functionality preserved
    run grep -q "Hello World" index.js
    [ "$status" -eq 0 ]
    run grep -q "port 3000" index.js
    [ "$status" -eq 0 ]
}

@test "configuration management - add new dependency" {
    # AI correctly adds dependency with proper JSON syntax
    run "$SCRIPT_UNDER_TEST" --force package.json "$(cat <<'EOF'
7s/$/,/
8a
    "cors": "^2.8.5"
.
w
q
EOF
)"
    [ "$status" -eq 0 ]
    
    # Auto-reordering occurred, so changes are in preview file
    [ -f package.json.eed.preview ]
    
    # Verify dependency was added correctly in preview
    run grep -q "cors.*2.8.5" package.json.eed.preview
    [ "$status" -eq 0 ]
    
    # Verify comma was added to express line in preview
    run grep -q "express.*4.18.0\"," package.json.eed.preview
    [ "$status" -eq 0 ]
    
    # Original file should be unchanged (preview mode)
    run grep -q "cors" package.json
    [ "$status" -ne 0 ]
}

@test "configuration management - update version and add script" {
    # AI performs multiple config updates with correct JSON syntax
    run "$SCRIPT_UNDER_TEST" --force package.json "$(cat <<'EOF'
3s/1.0.0/1.1.0/
10s/$/,/
11a
    "dev": "nodemon index.js"
.
w
q
EOF
)"
    [ "$status" -eq 0 ]
    
    # Auto-reordering occurred, so changes are in preview file
    [ -f package.json.eed.preview ]
    
    # Version should be updated in preview
    run grep -q "1.1.0" package.json.eed.preview
    [ "$status" -eq 0 ]
    
    # New script should be added in preview
    run grep -q "nodemon" package.json.eed.preview
    [ "$status" -eq 0 ]
    
    # Original file should be unchanged (preview mode)
    run grep -q "1.1.0" package.json
    [ "$status" -ne 0 ]
    run grep -q "nodemon" package.json
    [ "$status" -ne 0 ]
}

@test "documentation maintenance - update README with new features" {
    # AI enhances README with additional sections
    run "$SCRIPT_UNDER_TEST" --force README.md "\$a

## API Endpoints

- \`GET /\` - Returns welcome message
- \`GET /api/health\` - Health check endpoint

## Environment Variables

Copy \`.env.example\` to \`.env\` and configure:

- \`PORT\` - Server port (default: 3000)
- \`NODE_ENV\` - Environment mode
- \`DEBUG\` - Enable debug logging

## Contributing

1. Fork the repository
2. Create a feature branch
3. Submit a pull request
.
w
q"
    [ "$status" -eq 0 ]
    
    # New sections should be added
    run grep -q "## API Endpoints" README.md
    [ "$status" -eq 0 ]
    run grep -q "## Environment Variables" README.md
    [ "$status" -eq 0 ]
    run grep -q "## Contributing" README.md
    [ "$status" -eq 0 ]
    
    # Original content preserved
    run grep -q "Express.js application" README.md
    [ "$status" -eq 0 ]
    run grep -q "npm install" README.md
    [ "$status" -eq 0 ]
}