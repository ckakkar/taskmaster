import Foundation

extension PetEngine {
    public mutating func holdToy(at pointer: Point) {
        guard var ball = toy else { return }
        ball.isHeld = true
        ball.position = habitat.clamped(pointer)
        ball.position.y = max(habitat.floor + 12, ball.position.y)
        ball.velocity = .zero
        ball.age = 0
        toy = ball
    }

    public mutating func releaseToy(velocity: Point) {
        guard var ball = toy else { return }
        ball.isHeld = false
        ball.velocity = Point(x: velocity.x.clamped(to: -850...850), y: velocity.y.clamped(to: -650...850))
        toy = ball
    }

    public mutating func removeToy() { toy = nil }

    mutating func updateToy(_ dt: Double) {
        guard var ball = toy else { return }
        ball.age += dt
        if ball.age > 30 {
            toy = nil
            return
        }
        if !ball.isHeld {
            ball.velocity.y -= 850 * dt
            ball.position.x += ball.velocity.x * dt
            ball.position.y += ball.velocity.y * dt
            if ball.position.y < habitat.floor + 12 {
                ball.position.y = habitat.floor + 12
                ball.velocity.y = abs(ball.velocity.y) > 24 ? abs(ball.velocity.y) * 0.66 : 0
                ball.velocity.x *= pow(0.35, dt)
            }
            if ball.position.x < habitat.left {
                ball.position.x = habitat.left
                ball.velocity.x = abs(ball.velocity.x) * 0.8
            } else if ball.position.x > habitat.right {
                ball.position.x = habitat.right
                ball.velocity.x = -abs(ball.velocity.x) * 0.8
            }
            ball.position.y = min(ball.position.y, habitat.ceiling + 100)
        }
        toy = ball
    }
}
