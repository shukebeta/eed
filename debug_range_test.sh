#!/bin/bash

TEST_FILE=$(mktemp)

cat > "$TEST_FILE" << 'EOF'
start: ///path
middle content
end: ///path
other content
EOF

echo "=== Test file content ==="
cat -n "$TEST_FILE"

echo -e "\n=== Running range pattern test ==="
cd ~/Projects/eed && ./eed "$TEST_FILE" <<'EOF'
/start: ///path/,/end: ///path/c
RANGE REPLACED
.
wq
EOF

echo "Exit code: $?"

if [ -f "${TEST_FILE}.eed.preview" ]; then
    echo -e "\n=== Preview content ==="
    cat -n "${TEST_FILE}.eed.preview"
else
    echo -e "\nNo preview file created"
fi

rm -f "$TEST_FILE" "${TEST_FILE}.eed.preview"