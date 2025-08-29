#\!/usr/bin/env bats

# Test: existing test  
function existing_test() {
  run echo "hello"
  [ "$status" -eq 0 ]
}
