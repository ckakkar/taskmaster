import SpriteKit
import CompanionCore

/// A light deformation rig preserves the painted fur while moving the head, ears and tail.
@MainActor
final class PetAnimation {
    private(set) var attention = PetAttention()
    private var lastUpdate = CACurrentMediaTime()
    private let gaze = SKUniform(name: "u_gaze", vectorFloat2: .zero)
    private let blink = SKUniform(name: "u_blink", float: 0)
    private let eyeA = SKUniform(name: "u_eyeA", vectorFloat2: .zero)
    private let eyeB = SKUniform(name: "u_eyeB", vectorFloat2: .zero)
    private let radii = SKUniform(name: "u_radii", vectorFloat2: .zero)
    private let pixels = SKUniform(name: "u_pixels", vectorFloat2: SIMD2(1, 1))
    lazy var shader = SKShader(source: Self.eyeShader, uniforms: [gaze, blink, eyeA, eyeB, radii, pixels])

    func update(sprite: SKSpriteNode, frame: PetAtlas.Frame, target: Point?, engine: PetEngine, reducedMotion: Bool) {
        let now = CACurrentMediaTime()
        attention.advance(seconds: now - lastUpdate, target: target, asleep: engine.state == .sleeping, reducedMotion: reducedMotion)
        lastUpdate = now
        gaze.vectorFloat2Value = SIMD2(Float(attention.gaze.x), Float(attention.gaze.y))
        blink.floatValue = Float(attention.blink)
        pixels.vectorFloat2Value = SIMD2(Float(frame.width), Float(frame.height))
        eyeA.vectorFloat2Value = frame.eyes.first?.center ?? .zero
        eyeB.vectorFloat2Value = frame.eyes.dropFirst().first?.center ?? .zero
        radii.vectorFloat2Value = SIMD2(frame.eyes.first?.radius ?? 0, frame.eyes.dropFirst().first?.radius ?? 0)
        sprite.shader = frame.eyes.isEmpty ? nil : shader
        guard !reducedMotion else { sprite.warpGeometry = nil; return }

        let head = frame.eyes.isEmpty ? SIMD2<Float>(0.64, 0.67)
            : frame.eyes.map(\.center).reduce(.zero, +) / Float(frame.eyes.count)
        let t = attention.time
        let asleep = engine.state == .sleeping
        let tailWave = sin(t * (engine.state == .happy ? 5 : 1.8)) * (asleep ? 0.003 : 0.012)
        var source: [SIMD2<Float>] = [], destination: [SIMD2<Float>] = []
        for row in 0...6 {
            for column in 0...6 {
                let x = Float(column) / 6, y = Float(row) / 6
                source.append(SIMD2(x, y))
                let headWeight = exp(-pow((x - head.x) / 0.44, 2) - pow((y - head.y) / 0.4, 2)) * min(1, y * 4)
                let tailWeight = max(0, 1 - x * 2.4) * min(1, y * 3)
                let earWeight = max(0, (y - head.y - 0.12) * 5) * headWeight
                let dx = Float(attention.gaze.x * 0.012) * headWeight
                    - (y - head.y) * Float(attention.headTilt) * headWeight
                    + Float(tailWave) * tailWeight
                    + Float(attention.earFlick * 0.015) * earWeight
                let dy = Float(attention.gaze.y * 0.009) * headWeight
                    + (x - head.x) * Float(attention.headTilt) * headWeight
                    + Float(tailWave * 0.6) * tailWeight
                    - Float(attention.earFlick * 0.009) * earWeight
                destination.append(SIMD2(x + dx, y + dy))
            }
        }
        sprite.warpGeometry = SKWarpGeometryGrid(columns: 6, rows: 6, sourcePositions: source, destinationPositions: destination)
    }

    private static let eyeShader = """
    vec4 animateEye(vec4 color, vec2 uv, vec2 center, float radius) {
        if (radius < 1.0) return color;
        vec2 q = (uv - center) * u_pixels / radius;
        float mask = 1.0 - smoothstep(0.96, 1.2, length(q * vec2(0.88, 1.0)));
        if (mask < 0.001) return color;
        vec2 shifted = uv - u_gaze * vec2(2.8, 2.0) / u_pixels * mask;
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
