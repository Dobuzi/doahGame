# doahGame

SwiftUI + RealityKit 기반 3D 러닝 게임 프로젝트입니다.  
현재 저장소에는 게임 코드와 함께, 코드 품질을 지속적으로 점검하는 Closed Loop 파이프라인이 포함되어 있습니다.

## 프로젝트 개요

- 앱 진입점: `doahGame/doahGameApp.swift`
- 메인 화면/UI: `doahGame/ContentView.swift`
- 게임 상태/물리/충돌: `doahGame/GameState.swift`
- 3D 렌더링(RealityKit): `doahGame/Game3DView.swift`
- 단위 테스트: `doahGameTests/doahGameTests.swift`
- UI 테스트: `doahGameUITests/*`

## 요구 사항

- Xcode 26 이상 권장
- iOS Simulator 실행 가능 환경

로컬에서 `xcodebuild`가 동작하지 않으면 다음과 같은 오류가 발생할 수 있습니다.
- `xcode-select: ... active developer directory '/Library/Developer/CommandLineTools' ...`

이 경우 Xcode 개발자 디렉터리 설정이 필요합니다.

## 실행 방법

1. Xcode에서 `doahGame.xcodeproj` 열기
2. Scheme `doahGame` 선택
3. iOS Simulator에서 Run

## 테스트

Xcode에서:
- Product > Test

CLI에서 (Xcode 환경 필요):

```bash
xcodebuild test -project doahGame.xcodeproj -scheme doahGame -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Closed Loop 파이프라인

이 저장소는 아래 순환 루프를 자동화합니다.

1. 개선점 발굴 (`discover`)
2. 개선 계획 생성 (`plan`)
3. 개선 제안 패치 생성 (`execute`, 자동 커밋 없음)
4. 테스트 (`test`)
5. 완료 판정 (`finalize`)

### 로컬 실행

```bash
make loop-discover
make loop-plan
make loop-execute
make loop-test
make loop-finalize
make loop-all
```

### 출력 산출물

- `.pipeline/output/findings.json`
- `.pipeline/output/improvement-plan.md`
- `.pipeline/output/execution-proposal.patch`
- `.pipeline/output/test-report.md`
- `.pipeline/output/final-report.md`

참고:
- `.pipeline/output/*`는 `.gitignore`로 제외되며, `.gitkeep`만 추적됩니다.
- 로컬에서는 환경 차이로 인한 오탐을 줄이기 위해 일부 게이트를 완화하고, CI에서는 엄격 게이트를 적용합니다.

## GitHub Actions 워크플로

- PR 루프: `.github/workflows/closed-loop.yml`
  - 트리거: `pull_request` (`opened`, `synchronize`, `reopened`)
- 주간 루프: `.github/workflows/closed-loop-weekly.yml`
  - 트리거: 매주 월요일 09:00 KST (`0 0 * * 1` UTC)
  - `BLOCKED` 시 이슈 생성 (`tech-debt`, `closed-loop`)

## 관련 문서

- 코드베이스 점검 보고서: `CODEBASE_ANALYSIS.md`
