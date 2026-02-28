#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUTPUT_DIR="$ROOT_DIR/.pipeline/output"
RULES_FILE="$ROOT_DIR/.pipeline/rules.yml"
BASELINE_FILE="$ROOT_DIR/.pipeline/baseline.json"

mkdir -p "$OUTPUT_DIR"

python3 - "$ROOT_DIR" "$OUTPUT_DIR" "$RULES_FILE" "$BASELINE_FILE" <<'PY'
import datetime as dt
import json
import os
import re
import subprocess
import sys
from pathlib import Path

root = Path(sys.argv[1])
out_dir = Path(sys.argv[2])
rules_file = Path(sys.argv[3])
baseline_file = Path(sys.argv[4])


def run(cmd):
    p = subprocess.run(cmd, cwd=root, capture_output=True, text=True)
    return p.returncode, p.stdout, p.stderr


def git_sha():
    code, out, _ = run(["git", "rev-parse", "HEAD"])
    return out.strip() if code == 0 else "unknown"


def parse_rules(path: Path):
    # Minimal YAML parser for this repo-local schema.
    rules = {}
    current = None
    if not path.exists():
        return rules

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("- id:"):
            rid = line.split(":", 1)[1].strip()
            current = {"id": rid, "severity": "P3", "enabled": True, "message": rid}
            rules[rid] = current
            continue
        if current is None:
            continue
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key == "severity":
            current["severity"] = value
        elif key == "enabled":
            current["enabled"] = value.lower() == "true"
        elif key == "message":
            current["message"] = value
    return rules


def load_json(path: Path, default):
    if not path.exists():
        return default
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return default


rules = parse_rules(rules_file)
baseline = load_json(
    baseline_file,
    {"approved_exceptions": [], "known_findings": [], "previously_resolved": []},
)

findings = []


def rule_meta(rule_id: str):
    meta = rules.get(rule_id, {})
    return {
        "enabled": meta.get("enabled", True),
        "severity": meta.get("severity", "P3"),
        "message": meta.get("message", rule_id),
    }


def add_finding(rule_id: str, file: str, line: int, evidence: str, recommendation: str):
    meta = rule_meta(rule_id)
    if not meta["enabled"]:
        return
    findings.append(
        {
            "id": rule_id,
            "severity": meta["severity"],
            "file": file,
            "line": int(line),
            "evidence": evidence[:400],
            "recommendation": recommendation,
        }
    )

# 1) print usage detection in Swift files
for sf in root.rglob("*.swift"):
    rel = sf.relative_to(root).as_posix()
    if rel.startswith(".build/"):
        continue
    text = sf.read_text(encoding="utf-8", errors="ignore")
    for idx, l in enumerate(text.splitlines(), start=1):
        if "print(" in l and not l.strip().startswith("//"):
            add_finding(
                "FRAME_LOOP_PRINT",
                rel,
                idx,
                l.strip(),
                "프레임/입력 루프 로그는 #if DEBUG 또는 OSLog로 전환하세요.",
            )

# 2) oversized file (>500 lines)
for sf in root.rglob("*.swift"):
    rel = sf.relative_to(root).as_posix()
    lines = sf.read_text(encoding="utf-8", errors="ignore").splitlines()
    if len(lines) > 500:
        add_finding(
            "OVERSIZED_FILE",
            rel,
            1,
            f"line_count={len(lines)}",
            "파일을 GameState/Game3DView/HUD로 분리해 결합도를 낮추세요.",
        )

# 3) unused declaration candidates (low-confidence heuristic)
ignore_symbols = {
    "body",
    "id",
    "type",
    "position",
    "x",
    "y",
    "z",
    "now",
}
swift_files = [sf for sf in root.rglob("*.swift") if ".build/" not in sf.relative_to(root).as_posix()]
repo_swift_text = "\n".join(
    sf.read_text(encoding="utf-8", errors="ignore") for sf in swift_files
)

unused_cap = 15
unused_count = 0
for sf in swift_files:
    if unused_count >= unused_cap:
        break
    rel = sf.relative_to(root).as_posix()
    text = sf.read_text(encoding="utf-8", errors="ignore")
    lines = text.splitlines()
    for idx, l in enumerate(lines, start=1):
        m = re.match(r"\s*(?:private\s+)?(?:let|var|func)\s+([A-Za-z_][A-Za-z0-9_]*)", l)
        if not m:
            continue
        sym = m.group(1)
        if sym in ignore_symbols:
            continue
        # Skip obvious framework callbacks
        if sym in {"makeUIView", "updateUIView", "makeCoordinator", "testExample", "testLaunch", "setUpWithError", "tearDownWithError", "testLaunchPerformance"}:
            continue
        refs = len(re.findall(rf"\b{re.escape(sym)}\b", repo_swift_text))
        if refs <= 1:
            add_finding(
                "UNUSED_DECLARATION_CANDIDATE",
                rel,
                idx,
                l.strip(),
                "심볼 참조 여부를 확인하고 미사용이면 제거하거나 사용처를 연결하세요.",
            )
            unused_count += 1
            if unused_count >= unused_cap:
                break

# 4) missing tests for core types
core_targets = ["GameState", "Obstacle", "ContentView"]
all_test_text = ""
for tf in list(root.rglob("*Tests*.swift")) + list(root.rglob("*UITests*.swift")):
    all_test_text += tf.read_text(encoding="utf-8", errors="ignore") + "\n"
for core in core_targets:
    if core not in all_test_text:
        add_finding(
            "MISSING_CORE_TESTS",
            "doahGameTests/doahGameTests.swift",
            1,
            f"No direct test reference for core type: {core}",
            f"{core}에 대한 단위 또는 UI 테스트 시나리오를 추가하세요.",
        )

# 5) quality checks in discovery phase
# - CI: strict gate (failures are P1 findings)
# - local: skip xcodebuild gate to avoid host-environment false positives
is_ci = os.environ.get("CI", "").lower() in {"1", "true", "yes"}
if is_ci:
    cmds = [
        ("XCODEBUILD_LIST_FAILED", ["xcodebuild", "-list", "-project", "doahGame.xcodeproj"]),
        (
            "XCODEBUILD_TEST_FAILED",
            [
                "xcodebuild",
                "test",
                "-project",
                "doahGame.xcodeproj",
                "-scheme",
                "doahGame",
                "-destination",
                "platform=iOS Simulator,name=iPhone 16",
            ],
        ),
    ]
    for rid, cmd in cmds:
        code, out, err = run(cmd)
        if code != 0:
            evidence = (err.strip() or out.strip() or "command failed")
            add_finding(
                rid,
                "doahGame.xcodeproj/project.pbxproj",
                1,
                evidence.splitlines()[0][:350],
                f"CI macOS 러너에서 `{ ' '.join(cmd) }`가 통과하도록 환경/스킴을 정비하세요.",
            )

# Deduplicate findings by signature
sig_map = {}
for f in findings:
    sig = f"{f['id']}|{f['file']}|{f['line']}"
    sig_map[sig] = f
findings = list(sig_map.values())

current_signatures = sorted(sig_map.keys())
known_signatures = set(baseline.get("known_findings", []))
previously_resolved = set(baseline.get("previously_resolved", []))
approved_exceptions = set(baseline.get("approved_exceptions", []))

new = [s for s in current_signatures if s not in known_signatures and s not in approved_exceptions]
resolved = [s for s in known_signatures if s not in set(current_signatures)]
regressed = [s for s in current_signatures if s in previously_resolved]

counts = {"total": len(findings), "P1": 0, "P2": 0, "P3": 0}
for f in findings:
    counts[f["severity"]] = counts.get(f["severity"], 0) + 1

output = {
    "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(),
    "commit_sha": git_sha(),
    "findings": sorted(findings, key=lambda x: (x["severity"], x["file"], x["line"])),
    "summary": {
        "new": len(new),
        "resolved": len(resolved),
        "regressed": len(regressed),
        "counts": counts,
    },
}

(out_dir / "findings.json").write_text(
    json.dumps(output, ensure_ascii=False, indent=2), encoding="utf-8"
)

print(f"wrote findings: {out_dir / 'findings.json'}")
print(json.dumps(output["summary"], ensure_ascii=False))
PY
