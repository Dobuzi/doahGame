#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUTPUT_DIR="$ROOT_DIR/.pipeline/output"
PATCH_FILE="$OUTPUT_DIR/execution-proposal.patch"
FINDINGS_FILE="$OUTPUT_DIR/findings.json"
TARGET_FILE="$ROOT_DIR/doahGame/ContentView.swift"

mkdir -p "$OUTPUT_DIR"

python3 - "$FINDINGS_FILE" "$TARGET_FILE" "$PATCH_FILE" <<'PY'
import difflib
import json
import re
import sys
from pathlib import Path

findings_file = Path(sys.argv[1])
target_file = Path(sys.argv[2])
patch_file = Path(sys.argv[3])

if not findings_file.exists():
    raise SystemExit(f"missing findings file: {findings_file}")

_ = json.loads(findings_file.read_text(encoding="utf-8"))

patch_sections = []

if target_file.exists():
    original = target_file.read_text(encoding="utf-8")
    proposed = original

    # 1) Guard/remove noisy print logs
    proposed = re.sub(
        r"^(\s*)print\((.+)\)\s*$",
        r"\1// debug log removed: print(\2)",
        proposed,
        flags=re.M,
    )

    # 2) Clamp dt in timer update
    proposed = proposed.replace(
        "let dt = now.timeIntervalSince(lastUpdate)",
        "let dt = min(now.timeIntervalSince(lastUpdate), 1.0 / 15.0)",
    )

    # 3) Preserve spawn accumulator remainder
    proposed = proposed.replace(
        "spawnAccumulator = 0\n            spawnObstacle()",
        "spawnAccumulator -= spawnInterval\n            if spawnAccumulator < 0 { spawnAccumulator = 0 }\n            spawnObstacle()",
    )

    if proposed != original:
        diff = difflib.unified_diff(
            original.splitlines(),
            proposed.splitlines(),
            fromfile="a/doahGame/ContentView.swift",
            tofile="b/doahGame/ContentView.swift",
            lineterm="",
        )
        patch_sections.append("\n".join(diff))

# 4) File split skeleton proposal (not applied)
patch_sections.append(
    "\n".join(
        [
            "diff --git a/doahGame/GameState.swift b/doahGame/GameState.swift",
            "new file mode 100644",
            "index 0000000..1111111",
            "--- /dev/null",
            "+++ b/doahGame/GameState.swift",
            "@@ -0,0 +1,8 @@",
            "+import Foundation",
            "+",
            "+// Proposal only: move GameState and Obstacle out of ContentView.swift.",
            "+// This patch is generated for manual review and should not be auto-applied.",
            "+// struct Obstacle { ... }",
            "+// @Observable class GameState { ... }",
            "+",
            "+",
        ]
    )
)

patch_file.write_text("\n\n".join([s for s in patch_sections if s.strip()]) + "\n", encoding="utf-8")
print(f"wrote proposal patch: {patch_file}")
PY
