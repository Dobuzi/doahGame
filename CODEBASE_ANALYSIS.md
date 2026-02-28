# doahGame 코드베이스 점검/분석 보고서

작성일: 2026-02-28 (업데이트)

## 1) 점검 범위
- 프로젝트 구조/소스 코드 정적 분석
- 테스트 코드 및 파이프라인 스크립트 점검
- Closed Loop 산출물(`discover/plan`) 결과 확인
- 로컬/CI 환경 차이 확인

## 2) 현재 상태 요약
- 앱 구조가 분리됨:
  - `doahGame/ContentView.swift` (121 lines)
  - `doahGame/GameState.swift` (165 lines)
  - `doahGame/Game3DView.swift` (387 lines)
- 이전 핵심 이슈(프레임 경로 `print`, `dt` 상한 부재, 스폰 누적 리셋)는 해소됨
- 단위 테스트가 추가되어 `GameState` 핵심 동작 검증이 가능해짐
- Closed Loop 파이프라인이 저장소에 도입되어 리포트/게이트 흐름이 동작함

## 3) 완료된 개선 항목

### [완료] 프레임 루프 로그 제거
- 반영 파일: `doahGame/ContentView.swift`
- 결과: 프레임 경로 `print` 제거

### [완료] 큰 `dt` 완화
- 반영 파일: `doahGame/ContentView.swift`
- 결과: `dt = min(now.timeIntervalSince(lastUpdate), 1.0 / 15.0)` 적용

### [완료] 스폰 누적 시간 보정
- 반영 파일: `doahGame/GameState.swift`
- 결과: `spawnAccumulator -= spawnInterval`로 잔여 시간 보존

### [완료] 핵심 코드 분리
- 반영 파일:
  - `doahGame/ContentView.swift`
  - `doahGame/GameState.swift`
  - `doahGame/Game3DView.swift`
- 결과: 단일 673라인 파일 결합도 완화

### [완료] 기본 단위 테스트 보강
- 반영 파일: `doahGameTests/doahGameTests.swift`
- 결과: 점프/낙하/충돌/스폰 누적 시나리오 테스트 추가

## 4) 현재 개선 포인트 (우선순위)

### [높음] UI 테스트가 여전히 템플릿 수준
- 위치:
  - `doahGameUITests/doahGameUITests.swift`
  - `doahGameUITests/doahGameUITestsLaunchTests.swift`
- 내용: 앱 실행/성능 측정 템플릿만 존재, 실제 게임 루프 시나리오 검증 없음
- 영향: 화면 상호작용/상태 전이 회귀 탐지 한계
- 권장:
  - 최소 1개 E2E 시나리오 추가(시작→점프 입력→충돌 유도→게임오버 UI 검증)
  - 접근성 식별자 부여 후 안정적 셀렉터 사용

### [중간] `Game3DView.swift`의 책임 과다
- 위치: `doahGame/Game3DView.swift` (387 lines)
- 내용: 씬 생성, 모델 조립, 애니메이션 업데이트, 장애물 생성 로직이 한 타입에 집중
- 영향: 수정 범위 확대, 시각 요소 변경 시 회귀 위험 증가
- 권장:
  - `RabbitFactory`, `ObstacleFactory`, `SceneLightingBuilder` 같은 빌더/팩토리로 분리
  - `Coordinator` 갱신 루틴을 소규모 함수로 분할

### [중간] 로컬/CI 품질 게이트 편차 관리 필요
- 위치:
  - `scripts/pipeline/discover.sh`
  - `scripts/pipeline/test.sh`
- 내용: 로컬에서는 `xcodebuild` 게이트를 스킵하고 CI에서만 엄격 적용
- 영향: 로컬에서는 잠재적 빌드 이슈 조기 탐지가 어려움
- 권장:
  - README에 로컬 엄격 모드 실행 방법 명시 (`CI=true make loop-all`)
  - 필요 시 `STRICT_LOCAL_GATE` 옵션 도입

### [중간] 배포 타깃이 매우 높음(26.0)
- 위치: `doahGame.xcodeproj/project.pbxproj` (앱/테스트 타깃 전반)
- 내용: `IPHONEOS_DEPLOYMENT_TARGET = 26.0`
- 영향: 지원 기기/OS 범위 축소 가능성
- 권장: 제품 요구사항에 맞는 최소 지원 버전 재설정

### [낮음] 물리/난이도 로직의 테스트 가능성 확장 여지
- 위치: `doahGame/GameState.swift`
- 내용: 난수 기반 스폰/난이도 증가 로직이 직접 포함되어 장기적으로 결정적 테스트 작성이 어려움
- 영향: 밸런스 조정 시 정밀 회귀 테스트 작성 부담
- 권장: 랜덤 생성기/난이도 정책 추상화(주입 가능 구조) 고려

## 5) Closed Loop 관점 점검 결과

### 로컬 실행
- `./scripts/pipeline/discover.sh` 결과: `total=0` (로컬 환경 스킵 정책 반영)
- `make loop-all` 결과: `COMPLETED`

### CI 모드 시뮬레이션
- `CI=true ./scripts/pipeline/discover.sh` 결과: `P1 2건`
  - `XCODEBUILD_LIST_FAILED`
  - `XCODEBUILD_TEST_FAILED`
- 로컬 환경에서는 Xcode developer directory 제약으로 재현됨

## 6) 다음 실행 우선순위 (제안)
1. UI 테스트 1개 이상 실제 시나리오 추가
2. `Game3DView` 내부 책임 분리(팩토리/빌더)
3. 배포 타깃 정책 확정 및 pbxproj 반영
4. 파이프라인 로컬 엄격 모드 옵션 추가

## 7) 참고 파일
- 앱 코드:
  - `doahGame/ContentView.swift`
  - `doahGame/GameState.swift`
  - `doahGame/Game3DView.swift`
- 테스트:
  - `doahGameTests/doahGameTests.swift`
  - `doahGameUITests/doahGameUITests.swift`
- 파이프라인:
  - `scripts/pipeline/discover.sh`
  - `scripts/pipeline/test.sh`
  - `.github/workflows/closed-loop.yml`
