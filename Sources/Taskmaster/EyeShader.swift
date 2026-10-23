import CompanionCore
import SpriteKit

/// Moves the painted pupils and slides fur eyelids over each eye's landmark oval.
@MainActor
final class EyeShader {
    private let gaze = SKUniform(name: "u_gaze", vectorFloat2: .zero)
    private let blink = SKUniform(name: "u_blink", float: 0)
    private let eyeA = SKUniform(name: "u_eyeA", vectorFloat2: .zero)
    private let eyeB = SKUniform(name: "u_eyeB", vectorFloat2: .zero)
    private let sizeA = SKUniform(name: "u_sizeA", vectorFloat2: .zero)
    private let sizeB = SKUniform(name: "u_sizeB", vectorFloat2: .zero)
    private let pixels = SKUniform(name: "u_pixels", vectorFloat2: SIMD2(1, 1))
    private let lash = SKUniform(name: "u_lash", vectorFloat3: .zero)
    private(set) lazy var shader = SKShader(
        source: Self.source, uniforms: [gaze, blink, eyeA, eyeB, sizeA, sizeB, pixels, lash])

    func update(gaze: Point, blink: Double, frame: PetAtlas.Frame, avatar: AvatarKind) {
        self.gaze.vectorFloat2Value = SIMD2(Float(gaze.x), Float(gaze.y))
        self.blink.floatValue = Float(blink)
        pixels.vectorFloat2Value = SIMD2(Float(frame.width), Float(frame.height))
        let first = frame.eyes.first
        let second = frame.eyes.dropFirst().first
        eyeA.vectorFloat2Value = first?.center ?? .zero
        eyeB.vectorFloat2Value = second?.center ?? .zero
        sizeA.vectorFloat2Value = first.map { SIMD2($0.radius * $0.aspect, $0.radius) } ?? .zero
        sizeB.vectorFloat2Value = second.map { SIMD2($0.radius * $0.aspect, $0.radius) } ?? .zero
        lash.vectorFloat3Value =
            switch avatar {
            case .miso: SIMD3(0.20, 0.095, 0.055)
            case .toothless: SIMD3(0.06, 0.06, 0.07)
            }
    }

    // SpriteKit's Metal translation only exposes uniforms and u_texture inside main(),
    // so both eyes are handled in a loop there rather than in a helper function.
    private static let source = """
        void main() {
            vec2 uv = v_tex_coord;
            vec4 color = texture2D(u_texture, uv);
            vec4 result = color;
            for (int i = 0; i < 2; i++) {
                vec2 center = i == 0 ? u_eyeA : u_eyeB;
                vec2 size = i == 0 ? u_sizeA : u_sizeB;
                if (size.y < 1.0) continue;
                vec2 toUV = size / u_pixels;
                vec2 q = (uv - center) / toUV;
                float mask = 1.0 - smoothstep(0.96 + 0.08 * u_blink, 1.2 + 0.1 * u_blink, length(q));
                if (mask < 0.001) continue;
                vec4 eye = texture2D(u_texture, uv - u_gaze * toUV * vec2(0.23, 0.18) * mask);
                float close = u_blink;
                if (close > 0.001) {
                    // Lid colours are smooth blends of points in a ring just outside the eye: the upper
                    // lid uses the ring above the eye and the lower lid the ring below it, so each
                    // matches the fur it grows from (and the coat colour) without streaks.
                    vec4 above = vec4(0.0);
                    vec4 below = vec4(0.0);
                    for (int k = 0; k <= 6; k++) {
                        float angle = 0.5235988 + float(k) * 0.3490659;
                        vec2 p = vec2(cos(angle), sin(angle)) * 1.4;
                        vec2 d = q - p;
                        above += texture2D(u_texture, center + p * toUV) / (dot(d, d) + 0.05);
                        vec2 pb = vec2(p.x, -p.y);
                        vec2 db = q - pb;
                        below += texture2D(u_texture, center + pb * toUV) / (dot(db, db) + 0.05);
                    }
                    vec4 upperFur = above.a > 0.0001 ? vec4(above.rgb / above.a * color.a, color.a) : color;
                    vec4 lowerFur = below.a > 0.0001 ? vec4(below.rgb / below.a * color.a, color.a) : color;
                    float edge = 1.5 / size.y;
                    float meet = -0.22 + 0.16 * q.x * q.x;
                    float upper = mix(1.25, meet, close);
                    float lower = mix(-1.25, meet, close);
                    float shade = 1.0 - 0.22 * (1.0 - smoothstep(0.0, 0.55, q.y - upper));
                    vec4 upperLid = vec4(upperFur.rgb * shade, upperFur.a);
                    eye = mix(eye, upperLid, smoothstep(upper - edge, upper + edge, q.y));
                    eye = mix(eye, lowerFur, 1.0 - smoothstep(lower - edge, lower + edge, q.y));
                    float lashLine = (1.0 - smoothstep(edge * 0.6, edge * 1.7, abs(q.y - upper)))
                        * smoothstep(0.1, 0.5, close) * (1.0 - smoothstep(0.6, 0.9, abs(q.x)));
                    eye.rgb = mix(eye.rgb, u_lash * eye.a, lashLine * 0.75);
                }
                result = mix(result, eye, mask);
            }
            gl_FragColor = result * v_color_mix.a;
        }
        """
}
