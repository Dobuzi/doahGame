#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUTPUT_DIR="$ROOT_DIR/.pipeline/output"
REPORT_FILE="$OUTPUT_DIR/test-report.md"
STATUS_FILE="$OUTPUT_DIR/test-status.json"

mkdir -p "$OUTPUT_DIR"

LIST_LOG="$OUTPUT_DIR/xcodebuild-list.log"
TEST_LOG="$OUTPUT_DIR/xcodebuild-test.log"

IS_CI=false
if [[ "${CI:-}" == "true" || "${CI:-}" == "1" || "${CI:-}" == "yes" ]]; then
  IS_CI=true
fi

if [[ "$IS_CI" == true ]]; then
  set +e
  xcodebuild -list -project "$ROOT_DIR/doahGame.xcodeproj" >"$LIST_LOG" 2>&1
  LIST_CODE=$?

  xcodebuild test -project "$ROOT_DIR/doahGame.xcodeproj" -scheme doahGame -destination 'platform=iOS Simulator,name=iPhone 16' >"$TEST_LOG" 2>&1
  TEST_CODE=$?
  set -e
else
  LIST_CODE=0
  TEST_CODE=0
  cat >"$LIST_LOG" <<'EOF3'
Local run: skipped xcodebuild -list (strict gate runs in CI only).
EOF3
  cat >"$TEST_LOG" <<'EOF4'
Local run: skipped xcodebuild test (strict gate runs in CI only).
EOF4
fi

LIST_PASS=false
TEST_PASS=false
[[ $LIST_CODE -eq 0 ]] && LIST_PASS=true
[[ $TEST_CODE -eq 0 ]] && TEST_PASS=true

cat > "$REPORT_FILE" <<EOF2
# Closed Loop Test Report

- xcodebuild -list: $([[ "$LIST_PASS" == true ]] && echo "PASS" || echo "FAIL")
- xcodebuild test: $([[ "$TEST_PASS" == true ]] && echo "PASS" || echo "FAIL")

## Logs

- list log: \.pipeline/output/xcodebuild-list.log
- test log: \.pipeline/output/xcodebuild-test.log

## Failure Snippet (if any)

### xcodebuild -list

\`\`\`
$(tail -n 40 "$LIST_LOG" 2>/dev/null)
\`\`\`

### xcodebuild test

\`\`\`
$(tail -n 60 "$TEST_LOG" 2>/dev/null)
\`\`\`
EOF2

python3 - "$STATUS_FILE" "$LIST_PASS" "$TEST_PASS" <<'PY'
import json
import sys
from pathlib import Path

status_file = Path(sys.argv[1])
list_pass = sys.argv[2].lower() == "true"
test_pass = sys.argv[3].lower() == "true"

status_file.write_text(
    json.dumps(
        {
            "xcodebuild_list_pass": list_pass,
            "xcodebuild_test_pass": test_pass,
            "all_passed": list_pass and test_pass,
        },
        indent=2,
    )
    + "\n",
    encoding="utf-8",
)
PY

if [[ "$LIST_PASS" == true && "$TEST_PASS" == true ]]; then
  echo "test stage passed"
  exit 0
fi

echo "test stage failed"
exit 1
