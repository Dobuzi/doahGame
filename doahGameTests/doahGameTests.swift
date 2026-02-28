//
//  doahGameTests.swift
//  doahGameTests
//
//  Created by 김종원 on 10/18/25.
//

import Testing
@testable import doahGame

struct doahGameTests {

    @Test func jumpSetsPositiveVelocityFromGround() async throws {
        let state = GameState()
        state.reset()

        state.jump()

        #expect(state.velocity == state.jumpImpulse)
        #expect(state.rabbitHeight == 0)
    }

    @Test func updateClampsFallToGround() async throws {
        let state = GameState()
        state.reset()
        state.velocity = -50

        state.update(deltaTime: 1.0) { _ in }

        #expect(state.rabbitHeight == 0)
        #expect(state.velocity == 0)
    }

    @Test func collisionSetsGameOver() async throws {
        let state = GameState()
        state.reset()
        state.obstacles = [Obstacle(position: SIMD3<Float>(0, 0, 0), type: .asteroid)]
        var didCollide = false

        state.update(deltaTime: 0.0) { hit in
            didCollide = hit
        }

        #expect(didCollide == true)
        #expect(state.isGameOver == true)
    }

    @Test func spawnAccumulatorPreservesRemainderAcrossUpdates() async throws {
        let state = GameState()
        state.reset()
        state.spawnInterval = 1.0
        state.obstacles.removeAll()

        state.update(deltaTime: 1.5) { _ in }
        let afterFirst = state.obstacles.count

        state.update(deltaTime: 0.6) { _ in }
        let afterSecond = state.obstacles.count

        #expect(afterFirst == 1)
        #expect(afterSecond == 2)
    }

    @Test func contentViewCanBeInstantiated() async throws {
        let view = ContentView()
        #expect(String(describing: view).isEmpty == false)
    }

}
