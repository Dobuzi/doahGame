# doahGame 코드베이스 점검/분석 보고서

작성일: 2026-02-28

## 1) 범위
- 프로젝트 전체 파일 구조 확인
- 핵심 앱 로직(`ContentView.swift`) 정적 점검
- 테스트 코드/프로젝트 빌드 설정 점검
- 런타임 실행 기반 검증은 환경 제약으로 미수행

## 2) 프로젝트 개요
- 플랫폼/스택: SwiftUI + RealityKit 기반 iOS 게임 앱
- 엔트리 포인트: `doahGame/doahGameApp.swift`
- 핵심 구현: `doahGame/ContentView.swift` 단일 파일에 UI, 게임 상태, 물리, 렌더링 코디네이터가 집중
- 테스트: 기본 템플릿 상태(실질 검증 로직 없음)

## 3) 파일 구조 요약
- `doahGame/doahGameApp.swift`: 앱 시작점, `ContentView` 주입
- `doahGame/ContentView.swift`: 게임 전체 로직(약 673라인)
  - `ContentView`: HUD/입력/게임 루프 타이머
  - `GameState`: 점프 물리, 장애물 스폰/이동, 충돌/점수
  - `Game3DView`: RealityKit 씬 생성
  - `Game3DView.Coordinator`: 프레임 단위 엔티티 동기화
- `doahGameTests/doahGameTests.swift`: 템플릿 테스트
- `doahGameUITests/*.swift`: 앱 실행/런치 성능 템플릿 테스트

## 4) 핵심 점검 결과 (우선순위)

### [높음] 프레임 루프 내 과도한 로그 출력
- 위치: `doahGame/ContentView.swift:25`, `doahGame/ContentView.swift:175`, `doahGame/ContentView.swift:198`
- 내용: 60fps 루프 경로에서 `print`가 반복 실행되어 디버그/릴리즈 모두에서 성능 저하, 로그 오염, 프레임 드랍 유발 가능
- 영향: 실제 기기에서 입력/렌더링 체감 지연 가능성 큼
- 권장: `#if DEBUG` + 샘플링 로깅 또는 `OSLog`로 전환

### [높음] 게임 로직/렌더링/뷰가 단일 파일에 강결합
- 위치: `doahGame/ContentView.swift` 전반 (`1~673`)
- 내용: UI, 도메인 로직, 3D 씬 구성, 코디네이터 상태가 한 파일에 결합
- 영향: 기능 추가 시 회귀 위험 증가, 테스트 작성 난이도 상승, 코드 리뷰/온보딩 비용 증가
- 권장: `GameState`, `GameRenderer(RealityKit)`, `HUDView`로 분리

### [중간] 프레임 시간(`dt`) 상한 없음
- 위치: `doahGame/ContentView.swift:96`, `doahGame/ContentView.swift:179`
- 내용: 앱 일시정지/포그라운드 복귀 시 큰 `dt`가 그대로 물리 계산에 반영될 수 있음
- 영향: 점프/충돌/장애물 위치가 비정상적으로 튀는 현상 가능
- 권장: `dt = min(dt, 1.0/15.0)` 같은 상한 적용

### [중간] 장애물 스폰 누적 시간 처리 정밀도 부족
- 위치: `doahGame/ContentView.swift:220-223`
- 내용: `spawnAccumulator >= spawnInterval` 시 누적치를 0으로 리셋해 잔여 시간을 버림
- 영향: 프레임 지연 시 스폰 간격이 의도보다 들쭉날쭉해질 수 있음
- 권장: `spawnAccumulator -= spawnInterval` 방식으로 잔여시간 보존

### [중간] 테스트 커버리지 사실상 0%
- 위치: `doahGameTests/doahGameTests.swift:12-14`, `doahGameUITests/doahGameUITests.swift:26-32`
- 내용: 템플릿 코드만 존재, 게임 핵심 로직에 대한 단위/UI 테스트 부재
- 영향: 난이도/물리/충돌 수정 시 회귀 탐지 불가
- 권장: `GameState` 단위 테스트 우선 작성 (점프/충돌/점수/난이도 증가)

### [낮음] 미사용 코드/설정 흔적
- 위치: `doahGame/ContentView.swift:143`, `doahGame/ContentView.swift:541`, `doahGame/ContentView.swift:665-667`
- 내용: `GameState.earthRadius`, `Coordinator.earthRadius`, `TimeInterval.cg`가 현재 사용되지 않음
- 영향: 유지보수 시 혼동 유발
- 권장: 제거하거나 실제 사용처 연결

### [낮음] 배포 타깃이 매우 높음(26.0)
- 위치: `doahGame.xcodeproj/project.pbxproj:411`, `455`, `484`, `510`, `535`, `560`
- 내용: 전체 타깃 배포 버전이 26.0
- 영향: 지원 기기 범위가 의도치 않게 축소될 가능성
- 권장: 제품 요구사항 기준 최소 지원 버전 재설정

## 5) 아키텍처 관찰
- 장점
  - 게임 루프(타이머)와 상태 업데이트 흐름이 직관적
  - RealityKit 오브젝트 생성/업데이트 분리가 어느 정도 되어 있음(`Coordinator`)
  - 난이도 상승(속도/스폰 간격 조정) 로직이 단순하고 이해 쉬움
- 단점
  - 상태 모델과 렌더러의 책임 경계가 약함
  - 의존성 주입 없이 직접 인스턴스 생성(`GameState`)되어 테스트 어려움
  - 이벤트/상태 전이가 명시적 상태머신으로 모델링되어 있지 않음

## 6) 우선 개선 로드맵
1. 프레임 경로 `print` 제거 또는 디버그 로깅 전환
2. `dt` 상한 + 스폰 누적 잔여시간 보존 적용
3. `GameState` 분리 파일화 및 단위 테스트 5~8개 추가
4. UI 테스트에 최소 1개 실제 시나리오(시작->점프->충돌->게임오버) 추가
5. 배포 타깃/미사용 코드 정리

## 7) 실행/검증 메모
- `xcodebuild -list -project doahGame.xcodeproj` 실행 시, 현재 환경의 active developer directory가 CommandLineTools로 설정되어 있어 실패함.
- 즉, 본 보고서는 정적 분석 기반 결과이며, 빌드/런타임 검증은 Xcode 환경 전환 후 재점검 필요.

## 8) 추가 관찰
- 작업 시점에 워크트리에 사용자 변경으로 보이는 수정 사항이 이미 존재함: `doahGame/ContentView.swift` (modified)
- 본 작업에서는 해당 파일의 기존 변경 내용을 되돌리지 않았고, 신규 문서 파일만 추가함.
