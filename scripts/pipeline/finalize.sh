#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUTPUT_DIR="$ROOT_DIR/.pipeline/output"
FINDINGS_FILE="$OUTPUT_DIR/findings.json"
STATUS_FILE="$OUTPUT_DIR/test-status.json"
REPORT_FILE="$OUTPUT_DIR/final-report.md"
FLAG_FILE="$OUTPUT_DIR/final-status.txt"

python3 - "$FINDINGS_FILE" "$STATUS_FILE" "$REPORT_FILE" "$FLAG_FILE" <<'PY'
import json
import sys
from pathlib import Path

findings_file = Path(sys.argv[1])
status_file = Path(sys.argv[2])
report_file = Path(sys.argv[3])
flag_file = Path(sys.argv[4])

if not findings_file.exists():
    raise SystemExit(f"missing findings file: {findings_file}")

findings_payload = json.loads(findings_file.read_text(encoding="utf-8"))
summary = findings_payload.get("summary", {})
findings = findings_payload.get("findings", [])

if status_file.exists():
    test_status = json.loads(status_file.read_text(encoding="utf-8"))
else:
    test_status = {
        "xcodebuild_list_pass": False,
        "xcodebuild_test_pass": False,
        "all_passed": False,
    }

new_count = int(summary.get("new", 0))
regressed_count = int(summary.get("regressed", 0))
new_p1 = 0
for f in findings:
    if f.get("severity") == "P1":
        new_p1 += 1

reasons = []
if new_p1 > 0:
    reasons.append(f"new_or_active_p1={new_p1}")
if not test_status.get("all_passed", False):
    reasons.append("test_stage_failed")
if regressed_count > 0:
    reasons.append(f"regressed={regressed_count}")
if new_count > 0:
    reasons.append(f"baseline_worsened_new={new_count}")

status = "COMPLETED" if not reasons else "BLOCKED"

lines = []
lines.append("# Closed Loop Final Report")
lines.append("")
lines.append(f"- Status: **{status}**")
lines.append(f"- New findings: {new_count}")
lines.append(f"- Regressed findings: {regressed_count}")
lines.append(f"- Test passed: {test_status.get('all_passed', False)}")
lines.append("")
lines.append("## Gate Evaluation")
lines.append("")
if reasons:
    for r in reasons:
        lines.append(f"- BLOCKED: {r}")
else:
    lines.append("- All gates passed")

report_file.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")
flag_file.write_text(status + "\n", encoding="utf-8")
print(status)
PY

# finalize stage should always produce a report; do not hard-fail workflow here
exit 0
