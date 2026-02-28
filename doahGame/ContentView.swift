import SwiftUI
import Combine


struct ContentView: View {
    @State private var gameState = GameState()
    @State private var isRunning = false
    @State private var lastUpdate: Date = .now

    private let timer = Timer.publish(every: 1.0/60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // 3D Game View
            Game3DView(gameState: $gameState, isRunning: $isRunning)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    if !isRunning {
                        // Start game if not running
                        startGame()
                    } else {
                        // Jump when running
                        gameState.jump()
                    }
                }

            // UI overlay
            VStack {
                HStack {
                    Text("🐰 토끼 여왕: 플라워")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)
                        .padding(.horizontal)
                    Spacer()
                    Text("점수: \(gameState.score)")
                        .font(.system(size: 32, weight: .black))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)
                        .padding(.horizontal)
                }
                .padding(.top, 20)
                .allowsHitTesting(false)  // UI가 터치를 가로채지 않도록
                
                Spacer()
                
                if !isRunning {
                    VStack(spacing: 16) {
                        Text(gameState.isGameOver ? "🌍 게임 오버!" : "🌎 플레이 준비")
                            .font(.system(size: 40, weight: .black))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 3)
                        
                        if gameState.isGameOver {
                            Text("최종 점수: \(gameState.score)")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)
                        }
                        
                        Button(action: startGame) {
                            HStack(spacing: 8) {
                                Image(systemName: gameState.isGameOver ? "arrow.clockwise.circle.fill" : "play.circle.fill")
                                    .font(.title2)
                                Text(gameState.isGameOver ? "다시 시작" : "시작하기")
                                    .font(.title2.bold())
                            }
                            .padding(.horizontal, 32)
                            .padding(.vertical, 16)
                            .background(.ultraThickMaterial, in: Capsule())
                            .shadow(radius: 8)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                        
                        VStack(spacing: 8) {
                            Text("🌍 지구 주변을 달리세요!")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("화면을 탭해서 점프하세요!")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)
                        .padding(.top, 4)
                    }
                    .padding(.bottom, 80)
                }
            }
            .allowsHitTesting(!isRunning)  // 게임 중에는 UI가 터치를 받지 않음
        }
        .onReceive(timer) { now in
            guard isRunning else { lastUpdate = now; return }
            let dt = min(now.timeIntervalSince(lastUpdate), 1.0 / 15.0)
            lastUpdate = now
            gameState.update(deltaTime: dt) { didCollide in
                if didCollide {
                    stopGame()
                }
            }
        }
    }

    private func startGame() {
        gameState.reset()
        lastUpdate = .now
        isRunning = true
    }

    private func stopGame() {
        isRunning = false
    }
}


// MARK: - Preview

#Preview {
    ContentView()
}
