import SwiftUI
import RealityKit
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
                        print("탭! 높이: \(gameState.rabbitHeight), 속도: \(gameState.velocity)")
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
            let dt = now.timeIntervalSince(lastUpdate)
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

// MARK: - Game State

struct Obstacle: Identifiable {
    let id = UUID()
    var position: SIMD3<Float>  // 3D position
    var type: ObstacleType
    
    enum ObstacleType {
        case asteroid
        case satellite
        case meteor
    }
}

@Observable
class GameState {
    // Player (3D)
    var rabbitHeight: Float = 0.0  // Height above ground (0 = on ground)
    var velocity: Float = 0
    let gravity: Float = 8.0  // Stronger gravity for faster fall
    let jumpImpulse: Float = 3.5  // Higher jump
    let maxFallSpeed: Float = 10.0  // Positive value, how fast it can fall
    let maxJumpSpeed: Float = 5.0   // Positive value, how fast it can rise
    
    // World rotation (rabbit runs around the earth)
    var worldRotation: Float = 0  // Angle in radians
    let earthRadius: Float = 5.0
    let rotationSpeed: Float = 1.5  // Faster rotation
    
    // Obstacles
    var obstacles: [Obstacle] = []
    var obstacleSpeed: Float = 1.5
    var spawnInterval: TimeInterval = 2.0
    private var spawnAccumulator: TimeInterval = 0
    
    // Scoring
    var score: Int = 0
    private var passedObstacleIDs: Set<UUID> = []
    
    // State
    var isGameOver: Bool = false
    
    func reset() {
        rabbitHeight = 0
        velocity = 0
        worldRotation = 0
        obstacles.removeAll()
        score = 0
        passedObstacleIDs.removeAll()
        isGameOver = false
        spawnAccumulator = 0
        obstacleSpeed = 1.5
    }
    
    func jump() {
        // Allow jump if on ground or still rising
        if rabbitHeight <= 0.1 {
            velocity = jumpImpulse
            print("🐰 점프 시작! velocity: \(velocity)")
        }
    }
    
    func update(deltaTime dt: TimeInterval, collision: (Bool) -> Void) {
        guard !isGameOver else { return }
        
        let dtf = Float(dt)
        
        // Physics - vertical movement
        velocity -= gravity * dtf  // Gravity pulls down (reduces velocity)
        
        // Clamp vertical velocity (positive = up, negative = down)
        if velocity > maxJumpSpeed {
            velocity = maxJumpSpeed
        }
        if velocity < -maxFallSpeed {
            velocity = -maxFallSpeed
        }
        
        rabbitHeight += velocity * dtf
        
        if velocity != 0 {
            print("⚡️ Update - 높이: \(rabbitHeight), 속도: \(velocity), dt: \(dtf)")
        }
        
        // Ground collision
        if rabbitHeight <= 0 {
            rabbitHeight = 0
            velocity = 0
        }
        
        // World rotation - rabbit moves forward
        worldRotation += rotationSpeed * dtf
        if worldRotation > Float.pi * 2 {
            worldRotation -= Float.pi * 2
        }
        
        // Move obstacles toward the rabbit
        for i in obstacles.indices {
            obstacles[i].position.z += obstacleSpeed * dtf
        }
        
        // Spawn obstacles
        spawnAccumulator += dt
        if spawnAccumulator >= spawnInterval {
            spawnAccumulator = 0
            spawnObstacle()
        }
        
        // Remove obstacles that are behind the rabbit
        obstacles.removeAll { $0.position.z > 3.0 }
        
        // Check for passed obstacles (scoring)
        for obstacle in obstacles {
            if obstacle.position.z > 0.5 && !passedObstacleIDs.contains(obstacle.id) {
                passedObstacleIDs.insert(obstacle.id)
                score += 1
                
                // Increase difficulty
                obstacleSpeed += 0.05
                if spawnInterval > 1.2 {
                    spawnInterval -= 0.02
                }
            }
        }
        
        // Collision detection
        let rabbitPosition = SIMD3<Float>(0, rabbitHeight, 0)
        for obstacle in obstacles {
            let distance = simd_distance(rabbitPosition, obstacle.position)
            if distance < 0.6 {  // Collision radius
                isGameOver = true
                collision(true)
                return
            }
        }
        
        collision(false)
    }
    
    private func spawnObstacle() {
        let types: [Obstacle.ObstacleType] = [.asteroid, .satellite, .meteor]
        let type = types.randomElement()!
        
        // Random lane: left, center, or right
        let lanes: [Float] = [-1.2, 0, 1.2]
        let x = lanes.randomElement()!
        
        // Random height
        let y: Float
        switch type {
        case .asteroid:
            y = Float.random(in: 0.3...1.5)
        case .satellite:
            y = Float.random(in: 1.0...2.0)
        case .meteor:
            y = Float.random(in: 0.5...1.8)
        }
        
        let position = SIMD3<Float>(x, y, -8.0)  // Spawn far ahead
        obstacles.append(Obstacle(position: position, type: type))
    }
}

// MARK: - 3D View

struct Game3DView: UIViewRepresentable {
    @Binding var gameState: GameState
    @Binding var isRunning: Bool
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.environment.background = .color(.black)
        
        // Create anchor at world origin
        let anchor = AnchorEntity(world: .zero)
        arView.scene.addAnchor(anchor)
        
        // Create Earth - much smaller, positioned lower
        let earthRadius: Float = 0.8
        let earthMesh = MeshResource.generateSphere(radius: earthRadius)
        var earthMaterial = SimpleMaterial()
        earthMaterial.color = .init(tint: .init(red: 0.2, green: 0.6, blue: 0.9, alpha: 1.0))
        earthMaterial.metallic = .init(floatLiteral: 0.4)
        earthMaterial.roughness = .init(floatLiteral: 0.6)
        let earth = ModelEntity(mesh: earthMesh, materials: [earthMaterial])
        earth.position = [0, -2.5, -4]  // Lower position, closer to camera
        anchor.addChild(earth)
        
        // Add atmosphere glow
        let atmosphereMesh = MeshResource.generateSphere(radius: earthRadius + 0.1)
        var atmosphereMaterial = SimpleMaterial()
        atmosphereMaterial.color = .init(tint: .init(red: 0.5, green: 0.8, blue: 1.0, alpha: 0.3))
        let atmosphere = ModelEntity(mesh: atmosphereMesh, materials: [atmosphereMaterial])
        earth.addChild(atmosphere)
        
        // Add stars background
        for _ in 0..<100 {
            let starMesh = MeshResource.generateSphere(radius: 0.015)
            var starMaterial = SimpleMaterial()
            starMaterial.color = .init(tint: .white)
            let star = ModelEntity(mesh: starMesh, materials: [starMaterial])
            
            let distance: Float = Float.random(in: 8...15)
            let theta = Float.random(in: 0...(2 * .pi))
            let phi = Float.random(in: 0...(.pi))
            
            star.position = SIMD3<Float>(
                distance * sin(phi) * cos(theta),
                distance * sin(phi) * sin(theta) - 2,
                -distance * cos(phi) - 4
            )
            anchor.addChild(star)
        }
        
        // Create ground line (invisible reference)
        let groundY: Float = -1.5
        
        // Create rabbit - cute 3D model with body parts
        let rabbit = ModelEntity()
        rabbit.name = "rabbit"
        
        // Main body (white sphere)
        let bodyMesh = MeshResource.generateSphere(radius: 0.28)
        var bodyMaterial = SimpleMaterial()
        bodyMaterial.color = .init(tint: .white)
        bodyMaterial.roughness = .init(floatLiteral: 0.4)
        let body = ModelEntity(mesh: bodyMesh, materials: [bodyMaterial])
        rabbit.addChild(body)
        
        // ✨ 반짝이 노랑 드레스! ✨
        let dressMesh = MeshResource.generateBox(size: [0.5, 0.4, 0.4], cornerRadius: 0.1)
        var dressMaterial = SimpleMaterial()
        dressMaterial.color = .init(tint: .init(red: 1.0, green: 0.95, blue: 0.0, alpha: 1.0))
        dressMaterial.metallic = .init(floatLiteral: 0.7)  // Shiny!
        dressMaterial.roughness = .init(floatLiteral: 0.2)  // Very smooth for sparkle
        let dress = ModelEntity(mesh: dressMesh, materials: [dressMaterial])
        dress.position = [0, -0.1, 0]
        rabbit.addChild(dress)
        
        // Dress frills (bottom ruffle)
        let frillMesh = MeshResource.generateBox(size: [0.6, 0.08, 0.5], cornerRadius: 0.04)
        var frillMaterial = SimpleMaterial()
        frillMaterial.color = .init(tint: .init(red: 1.0, green: 0.9, blue: 0.0, alpha: 1.0))
        frillMaterial.metallic = .init(floatLiteral: 0.8)
        let frill = ModelEntity(mesh: frillMesh, materials: [frillMaterial])
        frill.position = [0, -0.25, 0]
        rabbit.addChild(frill)
        
        // Sparkle accents (small golden spheres)
        let sparkleMesh = MeshResource.generateSphere(radius: 0.04)
        var sparkleMaterial = SimpleMaterial()
        sparkleMaterial.color = .init(tint: .init(red: 1.0, green: 0.85, blue: 0.0, alpha: 1.0))
        sparkleMaterial.metallic = .init(floatLiteral: 1.0)
        
        // Add sparkles around dress
        for angle in stride(from: 0.0, to: 2 * Float.pi, by: Float.pi / 3) {
            let sparkle = ModelEntity(mesh: sparkleMesh, materials: [sparkleMaterial])
            sparkle.position = [0.28 * cos(angle), -0.1, 0.28 * sin(angle)]
            rabbit.addChild(sparkle)
        }
        
        // Head (smaller white sphere, positioned higher)
        let headMesh = MeshResource.generateSphere(radius: 0.22)
        var headMaterial = SimpleMaterial()
        headMaterial.color = .init(tint: .white)
        headMaterial.roughness = .init(floatLiteral: 0.3)
        let head = ModelEntity(mesh: headMesh, materials: [headMaterial])
        head.position = [0, 0.35, 0.05]
        rabbit.addChild(head)
        
        // 👑 Golden crown/tiara
        let crownMesh = MeshResource.generateBox(size: [0.3, 0.08, 0.08], cornerRadius: 0.02)
        var crownMaterial = SimpleMaterial()
        crownMaterial.color = .init(tint: .init(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0))
        crownMaterial.metallic = .init(floatLiteral: 1.0)
        crownMaterial.roughness = .init(floatLiteral: 0.1)
        let crown = ModelEntity(mesh: crownMesh, materials: [crownMaterial])
        crown.position = [0, 0.55, 0]
        rabbit.addChild(crown)
        
        // Crown jewel (pink gem)
        let jewelMesh = MeshResource.generateSphere(radius: 0.05)
        var jewelMaterial = SimpleMaterial()
        jewelMaterial.color = .init(tint: .init(red: 1.0, green: 0.4, blue: 0.7, alpha: 1.0))
        jewelMaterial.metallic = .init(floatLiteral: 0.9)
        let jewel = ModelEntity(mesh: jewelMesh, materials: [jewelMaterial])
        jewel.position = [0, 0, 0.05]
        crown.addChild(jewel)
        
        // Cute long ears (elongated boxes)
        let earMesh = MeshResource.generateBox(size: [0.08, 0.4, 0.06], cornerRadius: 0.03)
        var earMaterial = SimpleMaterial()
        earMaterial.color = .init(tint: .init(red: 1.0, green: 0.96, blue: 0.96, alpha: 1.0))
        earMaterial.roughness = .init(floatLiteral: 0.3)
        
        // Inner ear (pink)
        let innerEarMesh = MeshResource.generateBox(size: [0.04, 0.25, 0.02])
        var innerEarMaterial = SimpleMaterial()
        innerEarMaterial.color = .init(tint: .init(red: 1.0, green: 0.75, blue: 0.8, alpha: 1.0))
        
        let leftEar = ModelEntity(mesh: earMesh, materials: [earMaterial])
        leftEar.position = [-0.13, 0.6, 0.02]
        leftEar.orientation = simd_quatf(angle: -0.25, axis: [0, 0, 1])
        rabbit.addChild(leftEar)
        
        let leftInnerEar = ModelEntity(mesh: innerEarMesh, materials: [innerEarMaterial])
        leftInnerEar.position = [0, 0, 0.03]
        leftEar.addChild(leftInnerEar)
        
        let rightEar = ModelEntity(mesh: earMesh, materials: [earMaterial])
        rightEar.position = [0.13, 0.6, 0.02]
        rightEar.orientation = simd_quatf(angle: 0.25, axis: [0, 0, 1])
        rabbit.addChild(rightEar)
        
        let rightInnerEar = ModelEntity(mesh: innerEarMesh, materials: [innerEarMaterial])
        rightInnerEar.position = [0, 0, 0.03]
        rightEar.addChild(rightInnerEar)
        
        // Big cute eyes
        let eyeMesh = MeshResource.generateSphere(radius: 0.055)
        var eyeMaterial = SimpleMaterial()
        eyeMaterial.color = .init(tint: .black)
        
        let leftEye = ModelEntity(mesh: eyeMesh, materials: [eyeMaterial])
        leftEye.position = [-0.09, 0.42, 0.18]
        rabbit.addChild(leftEye)
        
        let rightEye = ModelEntity(mesh: eyeMesh, materials: [eyeMaterial])
        rightEye.position = [0.09, 0.42, 0.18]
        rabbit.addChild(rightEye)
        
        // Eye shine (white dots)
        let shineMesh = MeshResource.generateSphere(radius: 0.02)
        var shineMaterial = SimpleMaterial()
        shineMaterial.color = .init(tint: .white)
        
        let leftShine = ModelEntity(mesh: shineMesh, materials: [shineMaterial])
        leftShine.position = [-0.02, 0.02, 0.04]
        leftEye.addChild(leftShine)
        
        let rightShine = ModelEntity(mesh: shineMesh, materials: [shineMaterial])
        rightShine.position = [-0.02, 0.02, 0.04]
        rightEye.addChild(rightShine)
        
        // Cute pink nose
        let noseMesh = MeshResource.generateSphere(radius: 0.035)
        var noseMaterial = SimpleMaterial()
        noseMaterial.color = .init(tint: .init(red: 1.0, green: 0.6, blue: 0.7, alpha: 1.0))
        let nose = ModelEntity(mesh: noseMesh, materials: [noseMaterial])
        nose.position = [0, 0.33, 0.22]
        rabbit.addChild(nose)
        
        // Fluffy tail (small sphere at back) - golden touch
        let tailMesh = MeshResource.generateSphere(radius: 0.12)
        var tailMaterial = SimpleMaterial()
        tailMaterial.color = .init(tint: .init(red: 1.0, green: 0.98, blue: 0.85, alpha: 1.0))
        tailMaterial.roughness = .init(floatLiteral: 0.5)
        let tail = ModelEntity(mesh: tailMesh, materials: [tailMaterial])
        tail.position = [0, 0.05, -0.25]
        rabbit.addChild(tail)
        
        // Little feet (golden shoes!)
        let footMesh = MeshResource.generateBox(size: [0.12, 0.08, 0.15], cornerRadius: 0.04)
        var footMaterial = SimpleMaterial()
        footMaterial.color = .init(tint: .init(red: 1.0, green: 0.9, blue: 0.3, alpha: 1.0))
        footMaterial.metallic = .init(floatLiteral: 0.6)
        
        let leftFoot = ModelEntity(mesh: footMesh, materials: [footMaterial])
        leftFoot.position = [-0.12, -0.25, 0.08]
        rabbit.addChild(leftFoot)
        
        let rightFoot = ModelEntity(mesh: footMesh, materials: [footMaterial])
        rightFoot.position = [0.12, -0.25, 0.08]
        rabbit.addChild(rightFoot)
        
        // Position rabbit on ground
        rabbit.position = [0, groundY, -4]
        anchor.addChild(rabbit)
        
        // Add lighting - very bright for visibility
        let directionalLight = DirectionalLight()
        directionalLight.light.intensity = 8000
        directionalLight.light.color = .white
        directionalLight.position = [2, 3, -2]
        directionalLight.look(at: [0, groundY, -4], from: directionalLight.position, relativeTo: nil)
        anchor.addChild(directionalLight)
        
        let ambientLight = DirectionalLight()
        ambientLight.light.intensity = 3000
        ambientLight.light.color = .init(red: 0.9, green: 0.9, blue: 1.0, alpha: 1.0)
        ambientLight.position = [-2, 2, -2]
        anchor.addChild(ambientLight)
        
        // Additional fill light from front
        let fillLight = DirectionalLight()
        fillLight.light.intensity = 2500
        fillLight.light.color = .init(red: 1.0, green: 1.0, blue: 0.95, alpha: 1.0)
        fillLight.position = [0, 0, -1]
        fillLight.look(at: [0, groundY, -4], from: fillLight.position, relativeTo: nil)
        anchor.addChild(fillLight)
        
        context.coordinator.arView = arView
        context.coordinator.anchor = anchor
        context.coordinator.rabbit = rabbit
        context.coordinator.earth = earth
        context.coordinator.earthRadius = earthRadius
        context.coordinator.groundY = groundY
        
        return arView
    }
    
    func updateUIView(_ arView: ARView, context: Context) {
        context.coordinator.update(with: gameState, isRunning: isRunning)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        weak var arView: ARView?
        weak var anchor: AnchorEntity?
        weak var rabbit: ModelEntity?
        weak var earth: ModelEntity?
        var earthRadius: Float = 0.8
        var groundY: Float = -1.5
        var obstacleEntities: [UUID: ModelEntity] = [:]
        
        func update(with gameState: GameState, isRunning: Bool) {
            guard let anchor = anchor,
                  let rabbit = rabbit,
                  let earth = earth else { return }
            
            // Update rabbit position with jump height
            let rabbitY = groundY + gameState.rabbitHeight
            rabbit.position = [0, rabbitY, -4]
            
            // Animate rabbit based on state
            let tiltAngle: Float
            let earAngle: Float
            
            if gameState.velocity > 0.5 {
                // Jumping up - lean back slightly, ears back
                tiltAngle = -gameState.velocity * 0.03
                earAngle = -0.3
            } else if gameState.velocity < -0.5 {
                // Falling down - lean forward, ears forward
                tiltAngle = -gameState.velocity * 0.02
                earAngle = 0.2
            } else {
                // On ground - neutral
                tiltAngle = 0
                earAngle = 0
            }
            
            rabbit.orientation = simd_quatf(angle: tiltAngle, axis: [1, 0, 0])
            
            // Animate ears (find ear entities)
            for child in rabbit.children {
                if let earEntity = child as? ModelEntity {
                    // Check if it's an ear by position
                    if earEntity.position.y > 0.5 {
                        if earEntity.position.x < 0 {
                            // Left ear
                            earEntity.orientation = simd_quatf(angle: -0.25 + earAngle, axis: [0, 0, 1])
                        } else if earEntity.position.x > 0 {
                            // Right ear
                            earEntity.orientation = simd_quatf(angle: 0.25 - earAngle, axis: [0, 0, 1])
                        }
                    }
                }
            }
            
            // Slight bounce animation when on ground and running
            if isRunning && gameState.rabbitHeight <= 0.05 {
                let bounceTime = Float(Date().timeIntervalSince1970)
                let bounce = sin(bounceTime * 15) * 0.03
                rabbit.position.y += bounce
            }
            
            // Rotate earth to simulate running
            if isRunning {
                earth.orientation = simd_quatf(angle: gameState.worldRotation, axis: [0, 0, 1])
            }
            
            // Update obstacles
            let currentIDs = Set(gameState.obstacles.map { $0.id })
            
            // Remove obstacles that no longer exist
            for (id, entity) in obstacleEntities {
                if !currentIDs.contains(id) {
                    entity.removeFromParent()
                    obstacleEntities.removeValue(forKey: id)
                }
            }
            
            // Add or update obstacles
            for obstacle in gameState.obstacles {
                if let entity = obstacleEntities[obstacle.id] {
                    // Update position
                    var adjustedPosition = obstacle.position
                    adjustedPosition.z += -4  // Match rabbit Z position
                    adjustedPosition.y += groundY
                    entity.position = adjustedPosition
                    
                    // Rotate obstacles for visual interest
                    let rotationSpeed: Float = 2.0
                    let rotation = Float(Date().timeIntervalSince1970) * rotationSpeed
                    entity.orientation = simd_quatf(angle: rotation, axis: [0, 1, 0])
                } else {
                    // Create new obstacle
                    let entity = createObstacle(type: obstacle.type)
                    var adjustedPosition = obstacle.position
                    adjustedPosition.z += -4
                    adjustedPosition.y += groundY
                    entity.position = adjustedPosition
                    anchor.addChild(entity)
                    obstacleEntities[obstacle.id] = entity
                }
            }
        }
        
        func createObstacle(type: Obstacle.ObstacleType) -> ModelEntity {
            let mesh: MeshResource
            var material = SimpleMaterial()
            
            switch type {
            case .asteroid:
                mesh = MeshResource.generateBox(size: [0.4, 0.4, 0.4])
                material.color = .init(tint: .init(red: 0.8, green: 0.6, blue: 0.4, alpha: 1.0))
                material.roughness = .init(floatLiteral: 0.8)
            case .satellite:
                mesh = MeshResource.generateBox(size: [0.4, 0.3, 0.5])
                material.color = .init(tint: .init(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0))
                material.metallic = .init(floatLiteral: 0.9)
                material.roughness = .init(floatLiteral: 0.2)
            case .meteor:
                mesh = MeshResource.generateSphere(radius: 0.25)
                material.color = .init(tint: .init(red: 1.0, green: 0.5, blue: 0.2, alpha: 1.0))
                material.roughness = .init(floatLiteral: 0.7)
            }
            
            let entity = ModelEntity(mesh: mesh, materials: [material])
            return entity
        }
    }
}

private extension TimeInterval {
    var cg: CGFloat { CGFloat(self) }
}

// MARK: - Preview

#Preview {
    ContentView()
}
