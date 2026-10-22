import CompanionCore
import SpriteKit

/// A light deformation rig preserves the painted fur while moving the head, ears and tail.
@MainActor
final class PetAnimation {
    private(set) var attention = PetAttention()
    private(set) var motion = PetMotion()
    private(set) var deltaTime: Double = 1.0 / 60
    private var lastUpdate = CACurrentMediaTime()
    private let gaze = SKUniform(name: "u_gaze", vectorFloat2: .zero)
    private let blink = SKUniform(name: "u_blink", float: 0)
    private let eyeA = SKUniform(name: "u_eyeA", vectorFloat2: .zero)
    private let eyeB = SKUniform(name: "u_eyeB", vectorFloat2: .zero)
    private let radii = SKUniform(name: "u_radii", vectorFloat2: .zero)
    private let pixels = SKUniform(name: "u_pixels", vectorFloat2: SIMD2(1, 1))
    lazy var shader = SKShader(source: Self.eyeShader, uniforms: [gaze, blink, eyeA, eyeB, radii, pixels])

    func advance(target: Point?, engine: PetEngine, reducedMotion: Bool, strideLength: Double) {
        let now = CACurrentMediaTime()
        deltaTime = min(0.1, max(0, now - lastUpdate))
        attention.advance(
            seconds: deltaTime, target: target, asleep: engine.state == .sleeping, reducedMotion: reducedMotion)
        motion.advance(seconds: deltaTime, engine: engine, reducedMotion: reducedMotion, strideLength: strideLength)
        lastUpdate = now
    }

    func land(speed: Double) { motion.land(speed: speed) }

    func update(sprite: SKSpriteNode, frame: PetAtlas.Frame, engine: PetEngine, reducedMotion: Bool) {
        gaze.vectorFloat2Value = SIMD2(Float(attention.gaze.x), Float(attention.gaze.y))
        blink.floatValue = Float(attention.blink)
        pixels.vectorFloat2Value = SIMD2(Float(frame.width), Float(frame.height))
        eyeA.vectorFloat2Value = frame.eyes.first?.center ?? .zero
        eyeB.vectorFloat2Value = frame.eyes.dropFirst().first?.center ?? .zero
        radii.vectorFloat2Value = SIMD2(frame.eyes.first?.radius ?? 0, frame.eyes.dropFirst().first?.radius ?? 0)
        sprite.shader = shader
        guard !reducedMotion else {
            sprite.warpGeometry = nil
            return
        }

        let head =
            frame.eyes.isEmpty
            ? SIMD2<Float>(0.64, 0.67)
            : frame.eyes.map(\.center).reduce(.zero, +) / Float(frame.eyes.count)
        let t = attention.time
        let asleep = engine.state == .sleeping
        let happy = engine.state == .happy
        let tailWave =
            (sin(t * (happy ? 5 : 1.8)) + sin(t * 0.73) * 0.28)
            * (asleep ? 0.003 : happy ? 0.026 + engine.affection * 0.008 : 0.017)
        let walking = engine.state == .walking ? Float(motion.movement.value) : 0
        let feet = engine.avatar.footPhases.map { WalkCycle.foot(phase: motion.stride, offset: $0) }
        let stretch = engine.state == .stretching ? sin(min(1, engine.stateAge / 3.2) * .pi) : 0
        var source: [SIMD2<Float>] = []
        var destination: [SIMD2<Float>] = []
        source.reserveCapacity(325)
        destination.reserveCapacity(325)
        for row in 0...12 {
            for column in 0...24 {
                let x = Float(column) / 24
                let y = Float(row) / 12
                source.append(SIMD2(x, y))
                let headWeight = exp(-pow((x - head.x) / 0.44, 2) - pow((y - head.y) / 0.4, 2)) * min(1, y * 4)
                let tailWeight = max(0, 1 - x * 2.4) * min(1, y * 3)
                let earWeight = max(0, (y - head.y - 0.12) * 5) * headWeight
                let legBlend = min(1, max(0, (y - 0.08) / 0.35))
                let legs = 1 - legBlend * legBlend * (3 - 2 * legBlend)
                var gaitX: Float = 0
                var gaitY: Float = 0
                for index in feet.indices {
                    let distance = max(0, abs(x - Float(engine.avatar.feet[index])) - 0.045) / 0.075
                    let weight = exp(-distance * distance) * legs * walking
                    gaitX += Float(feet[index].x) * weight
                    gaitY += Float(feet[index].y - 0.012) * weight
                }
                let bodyRise = Float(sin(motion.stride * 2) * 0.004) * min(1, y * 3) * walking
                let wing =
                    engine.avatar == .toothless && engine.aerialRoute != nil
                    ? sin(t * 8) * 0.055 * Double(max(0, 1 - x * 1.7)) * Double(max(0, y - 0.2)) : 0
                let pawWeight: Float
                if engine.state == .highFive, let paw = frame.paw {
                    pawWeight = exp(-pow((x - paw.x) / 0.25, 2) - pow((y - paw.y) / 0.25, 2))
                } else {
                    pawWeight = 0
                }
                let dx =
                    Float(attention.gaze.x * 0.025) * headWeight
                    - (y - head.y) * Float(attention.headTilt) * headWeight
                    + Float(tailWave) * tailWeight
                    + Float(attention.earFlick * 0.022) * earWeight + gaitX
                    + Float(stretch * 0.025) * headWeight
                    + Float(sin(t * 4) * 0.012) * pawWeight
                let dy =
                    Float(attention.gaze.y * 0.018) * headWeight
                    + (x - head.x) * Float(attention.headTilt) * headWeight
                    + Float(tailWave * 0.6) * tailWeight
                    - Float(attention.earFlick * 0.014) * earWeight + gaitY
                    + Float(attention.engagement * 0.008) * earWeight
                    - Float(stretch * 0.025) * headWeight
                    + Float(cos(t * 4) * 0.008) * pawWeight
                    + bodyRise + Float(wing)
                destination.append(SIMD2(x + dx, y + dy))
            }
        }
        sprite.warpGeometry = SKWarpGeometryGrid(
            columns: 24, rows: 12, sourcePositions: source, destinationPositions: destination)
    }

    private static let eyeShader = """
        vec4 animateEye(vec4 color, vec2 uv, vec2 center, float radius) {
            if (radius < 1.0) return color;
            vec2 q = (uv - center) * u_pixels / radius;
            float mask = 1.0 - smoothstep(0.96, 1.2, length(q * vec2(0.88, 1.0)));
            if (mask < 0.001) return color;
            vec2 shifted = uv - u_gaze * radius * vec2(0.26, 0.18) / u_pixels * mask;
            vec4 looking = texture2D(u_texture, shifted);
            float close = u_blink;
            float opening = max(0.05, 1.0 - close);
            vec2 eyelidUV = vec2(uv.x, center.y + radius * 1.45 / u_pixels.y);
            vec4 fur = texture2D(u_texture, eyelidUV);
            float lid = smoothstep(opening - 0.10, opening + 0.10, abs(q.y));
            vec4 eye = mix(looking, fur, lid * close);
            float curve = -0.06 + q.x * q.x * 0.16;
            float line = (1.0 - smoothstep(0.04, 0.13, abs(q.y - curve)))
                * (1.0 - smoothstep(0.65, 1.0, abs(q.x))) * smoothstep(0.65, 0.97, close);
            eye.rgb = mix(eye.rgb, vec3(0.20, 0.095, 0.055) * eye.a, line);
            eye = mix(looking, eye, smoothstep(0.05, 0.7, close));
            return mix(color, eye, mask);
        }
        void main() {
            vec2 uv = v_tex_coord;
            vec4 color = texture2D(u_texture, uv);
            color = animateEye(color, uv, u_eyeA, u_radii.x);
            color = animateEye(color, uv, u_eyeB, u_radii.y);
            gl_FragColor = color * v_color_mix.a;
        }
        """
}
