#!/bin/bash
# Test script for session layer concept
# Demonstrates code accumulation approach

JUDGE0_URL="http://localhost:2358"

echo "=== Judge0 Session Layer Test ==="
echo ""

# Helper function - uses $'...' for proper newline interpretation
submit() {
    local code="$1"
    local step="$2"
    echo "--- $step ---"
    
    # Build JSON with proper escaping
    local json=$(jq -n --arg code "$code" '{source_code: $code, language_id: 71}')
    
    result=$(curl -s -X POST "$JUDGE0_URL/submissions?wait=true" \
        -H "Content-Type: application/json" \
        -d "$json")
    
    stdout=$(echo "$result" | jq -r '.stdout // "null"')
    status=$(echo "$result" | jq -r '.status.description')
    echo "Output: $stdout"
    echo "Status: $status"
    echo ""
}

echo "Step 1: Agent defines x"
submit $'x = 10\nprint("Agent: x =", x)' "Step 1"

echo "Step 2: User adds y (accumulating x)"
submit $'x = 10\ny = 20\nprint("User: x + y =", x + y)' "Step 2"

echo "Step 3: Agent computes product (accumulating x, y)"
submit $'x = 10\ny = 20\nresult = x * y\nprint("Agent: x * y =", result)' "Step 3"

echo "Step 4: User defines function (accumulating all)"
submit $'x = 10\ny = 20\nresult = x * y\n\ndef describe():\n    return f"x={x}, y={y}, product={result}"\n\nprint("User:", describe())' "Step 4"

echo "=== Session Test Complete ==="
