#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUTPUT_DIR="$ROOT_DIR/.pipeline/output"
FINDINGS_FILE="$OUTPUT_DIR/findings.json"
PLAN_FILE="$OUTPUT_DIR/improvement-plan.md"

if [[ ! -f "$FINDINGS_FILE" ]]; then
  echo "missing findings file: $FINDINGS_FILE" >&2
  exit 1
fi

python3 - "$FINDINGS_FILE" "$PLAN_FILE" <<'PY'
import json
import sys
from pathlib import Path

findings_file = Path(sys.argv[1])
plan_file = Path(sys.argv[2])

payload = json.loads(findings_file.read_text(encoding="utf-8"))
findings = payload.get("findings", [])
summary = payload.get("summary", {})

sev_rank = {"P1": 0, "P2": 1, "P3": 2}
findings = sorted(findings, key=lambda f: (sev_rank.get(f.get("severity", "P3"), 9), f.get("file", ""), f.get("line", 0)))

actions = {
    "FRAME_LOOP_PRINT": ("로그 경량화", "프레임 경로 print 제거 또는 #if DEBUG 보호", "로그 가시성 감소 가능", "빌드 후 게임 플레이 시 성능/로그량 확인"),
    "OVERSIZED_FILE": ("파일 분리", "ContentView/GameState/Game3DView 분리", "파일 이동 중 참조 깨짐", "빌드 통과 + 미리보기 동작 확인"),
    "UNUSED_DECLARATION_CANDIDATE": ("불필요 선언 정리", "미사용 심볼 제거 또는 사용처 연결", "오탐으로 인한 기능 손실", "검색 기반 참조 재검증"),
    "MISSING_CORE_TESTS": ("테스트 보강", "핵심 도메인 타입 테스트 추가", "테스트 유지비 증가", "test 타깃 실행 통과"),
    "XCODEBUILD_LIST_FAILED": ("CI 환경 정비", "xcodebuild list 통과 조건 복구", "러너 설정 의존", "CI job green"),
    "XCODEBUILD_TEST_FAILED": ("회귀 테스트 복구", "xcodebuild test 실패 원인 해결", "시뮬레이터/스킴 의존", "CI test green"),
}

lines = []
lines.append("# Closed Loop Improvement Plan")
lines.append("")
lines.append("## Summary")
lines.append("")
counts = summary.get("counts", {})
lines.append(f"- Total findings: {counts.get('total', 0)}")
lines.append(f"- P1: {counts.get('P1', 0)} | P2: {counts.get('P2', 0)} | P3: {counts.get('P3', 0)}")
lines.append(f"- Baseline diff: new={summary.get('new', 0)}, resolved={summary.get('resolved', 0)}, regressed={summary.get('regressed', 0)}")
lines.append("")
lines.append("## Top 5 Priority Items")
lines.append("")
lines.append("| Priority | ID | File | Line | Action |")
lines.append("|---|---|---|---:|---|")
for f in findings[:5]:
    action = actions.get(f["id"], ("분석", "", "", ""))[0]
    lines.append(f"| {f['severity']} | {f['id']} | {f['file']} | {f['line']} | {action} |")

lines.append("")
lines.append("## Execution Units")
lines.append("")
for idx, f in enumerate(findings, start=1):
    intent, change, risk, verify = actions.get(
        f["id"],
        ("개선 항목 처리", "대상 코드 개선", "사양 미정", "기본 빌드/테스트 확인"),
    )
    lines.append(f"### {idx}. [{f['severity']}] {f['id']}")
    lines.append(f"- Target: `{f['file']}:{f['line']}`")
    lines.append(f"- Intent: {intent}")
    lines.append(f"- Change: {change}")
    lines.append(f"- Risk: {risk}")
    lines.append(f"- Verification: {verify}")
    lines.append(f"- Evidence: `{f['evidence']}`")
    lines.append(f"- Recommendation: {f['recommendation']}")
    lines.append("")

plan_file.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")
print(f"wrote plan: {plan_file}")
PY
