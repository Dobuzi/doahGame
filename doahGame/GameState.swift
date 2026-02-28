import Foundation
import Observation
import simd

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
            spawnAccumulator -= spawnInterval
            if spawnAccumulator < 0 {
                spawnAccumulator = 0
            }
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

