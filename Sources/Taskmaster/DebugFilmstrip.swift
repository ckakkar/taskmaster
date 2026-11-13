#if DEBUG
    import AppKit
    import CompanionCore
    import ImageIO
    import Metal
    import SpriteKit

    /// `--debug-filmstrip <folder> [--avatar miso|toothless] [--scenario <name>] [--size 1.0] [--reduced-motion]`
    ///
    /// Renders scripted scenes off screen with a simulated clock, so every frame is reproducible and no screen
    /// recording permission is needed. Each scenario writes numbered PNG frames, a contact sheet (frames cropped
    /// around the companion with the floor aligned) and an animated GIF to `<folder>/<avatar>-<scenario>/`.
    @MainActor
    enum DebugFilmstrip {
        static var folder: URL? {
            value(after: "--debug-filmstrip").map { URL(fileURLWithPath: $0, isDirectory: true) }
        }

        private static func value(after flag: String) -> String? {
            let arguments = CommandLine.arguments
            guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
            return arguments[index + 1]
        }

        struct Scenario {
            let name: String
            /// Simulated seconds before the first captured frame.
            var warmup: Double = 0.6
            let seconds: Double
            var fps: Double = 30
            var flying = false
            let setup: (inout PetEngine) -> Void
            /// Steps run once when the simulated clock (measured from the end of the warmup) reaches them.
            var script: [(at: Double, run: (inout PetEngine) -> Void)] = []
            var cursor: ((Double) -> Point?)? = nil
        }

        static let habitat = Habitat(left: 80, right: 1_120, floor: 40, ceiling: 420)

        static var scenarios: [Scenario] {
            [
                Scenario(name: "walk", seconds: 1.2) { $0.startDebugState(.walking) },
                Scenario(
                    name: "turn", warmup: 0.8, seconds: 1.4,
                    setup: { engine in
                        engine.debugTransition(to: .sitting, at: 640)
                        engine.perform(.comeHere(300))
                    },
                    script: [(0.35, { $0.perform(.comeHere(1_000)) })]),
                Scenario(
                    name: "start-stop", warmup: 0.2, seconds: 3.2, fps: 15,
                    setup: { engine in
                        engine.debugTransition(to: .sitting, at: 500)
                    },
                    script: [(0.2, { $0.perform(.comeHere(640)) })]),
                Scenario(
                    name: "poses", warmup: 0.3, seconds: 6.4, fps: 10,
                    setup: { $0.debugTransition(to: .sitting, at: 600) },
                    script: [
                        (0.6, { $0.debugTransition(to: .idle) }), (1.4, { $0.debugTransition(to: .happy) }),
                        (2.2, { $0.debugTransition(to: .playing) }), (3.0, { $0.debugTransition(to: .scheming) }),
                        (3.8, { $0.debugTransition(to: .sitting) }), (4.6, { $0.debugTransition(to: .sleeping) }),
                        (5.6, { $0.debugTransition(to: .sitting) }),
                    ]),
                Scenario(
                    name: "carry", warmup: 0.2, seconds: 3, fps: 15,
                    setup: { engine in
                        engine.debugTransition(to: .sitting, at: 600)
                        engine.beginDrag(at: Point(x: 600, y: 100))
                    },
                    script: (0..<16).map { step in
                        let t = Double(step) * 0.06
                        return (t, { $0.drag(to: Point(x: 600 + t * 260, y: 100 + t * 230), seconds: 0.06) })
                    } + [(1.0, { $0.endDrag() })]),
                Scenario(name: "fly", seconds: 2, fps: 15, flying: true) { $0.startDebugState(.flying) },
            ]
        }

        static func run(into folder: URL) -> Int32 {
            let avatars: [AvatarKind] =
                switch value(after: "--avatar") {
                case "miso": [.miso]
                case "toothless": [.toothless]
                default: AvatarKind.available
                }
            let wanted = value(after: "--scenario")
            let size = value(after: "--size").flatMap(Double.init) ?? 1
            let reduced = CommandLine.arguments.contains("--reduced-motion")
            guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
                FileHandle.standardError.write(Data("No Metal device for the filmstrip renderer.\n".utf8))
                return 1
            }
            do {
                for avatar in avatars {
                    let atlas = try PetAtlas(avatar: avatar)
                    if CommandLine.arguments.contains("--landmarks") {
                        for pose in PetPose.allCases {
                            let frame = atlas.frame(for: pose)
                            print(
                                avatar, pose, frame.width, frame.height, "head", Int(frame.headOffset),
                                "eyes", frame.eyes.map { "(\($0.center.x), \($0.center.y))" }.joined(separator: " "))
                        }
                    }
                    for scenario in scenarios where wanted == nil || wanted == "all" || scenario.name == wanted {
                        if scenario.flying && avatar == .miso { continue }
                        let output = folder.appendingPathComponent("\(avatar.rawValue)-\(scenario.name)")
                        try record(
                            scenario, avatar: avatar, atlas: atlas, size: size, reducedMotion: reduced,
                            device: device, queue: queue, into: output)
                        print("Wrote \(output.path)")
                    }
                }
            } catch {
                FileHandle.standardError.write(Data("Filmstrip failed: \(error)\n".utf8))
                return 1
            }
            return 0
        }

        private static func record(
            _ scenario: Scenario, avatar: AvatarKind, atlas: PetAtlas, size: Double, reducedMotion: Bool,
            device: MTLDevice, queue: MTLCommandQueue, into output: URL
        ) throws {
            try? FileManager.default.removeItem(at: output)
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            var preferences = Preferences()
            preferences.avatar = avatar
            preferences.name = avatar.title
            preferences.size = size
            preferences.hasOnboarded = true
            let sceneSize = CGSize(width: 1_200, height: 520)
            let scene = PetScene(size: sceneSize, atlas: atlas)
            // `.resizeFill` collapses a scene that has no view to zero size.
            scene.scaleMode = .fill
            scene.size = sceneSize
            var clock: Double = 0
            scene.animation.clock = { clock }
            var engine = PetEngine(habitat: habitat, seed: 7)
            engine.avatar = avatar
            engine.visualScale = size
            engine.mischief = 0.25
            engine.chatter = 0
            engine.stage = 0...sceneSize.width
            scenario.setup(&engine)
            let renderer = SKRenderer(device: device)
            renderer.scene = scene
            let renderScale = 2.0
            let width = Int(sceneSize.width * renderScale)
            let height = Int(sceneSize.height * renderScale)
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
            descriptor.usage = [.renderTarget, .shaderRead]
            descriptor.storageMode = .managed
            guard let texture = device.makeTexture(descriptor: descriptor) else { throw FilmstripError.texture }

            let step = 1.0 / 60
            var pending = scenario.script.sorted { $0.at < $1.at }
            var frames: [CGImage] = []
            var nextCapture = scenario.warmup
            let total = scenario.warmup + scenario.seconds
            // Crop box (points): wide enough for the widest pose and its bob, floor near the bottom.
            let petWidth = 155 / atlas.standingHeight * size * Double(atlas.frame(for: .standing).width) * 1.25
            let box = CGSize(
                width: petWidth + 40, height: atlas.maximumFrameHeight * 155 / atlas.standingHeight * size + 50)
            while clock < total - step / 2 {
                clock += step
                let scripted = clock - scenario.warmup
                while let next = pending.first, next.at <= scripted {
                    next.run(&engine)
                    pending.removeFirst()
                }
                engine.tick(seconds: step, cursor: scenario.cursor?(scripted), userIdle: 0)
                scene.render(engine: engine, preferences: preferences, origin: .zero, reducedMotion: reducedMotion)
                scene.handle(engine.drainEvents())
                renderer.update(atTime: clock)
                guard clock + step / 2 >= nextCapture else { continue }
                nextCapture += 1 / scenario.fps
                let pass = MTLRenderPassDescriptor()
                pass.colorAttachments[0].texture = texture
                pass.colorAttachments[0].loadAction = .clear
                pass.colorAttachments[0].clearColor = MTLClearColor(red: 0.95, green: 0.93, blue: 0.89, alpha: 1)
                pass.colorAttachments[0].storeAction = .store
                guard let buffer = queue.makeCommandBuffer() else { throw FilmstripError.texture }
                renderer.render(
                    withViewport: CGRect(x: 0, y: 0, width: width, height: height), commandBuffer: buffer,
                    renderPassDescriptor: pass)
                if let blit = buffer.makeBlitCommandEncoder() {
                    blit.synchronize(resource: texture)
                    blit.endEncoding()
                }
                buffer.commit()
                buffer.waitUntilCompleted()
                guard let image = image(from: texture, width: width, height: height) else { continue }
                if frames.isEmpty, CommandLine.arguments.contains("--full-frame") {
                    try write(image, to: output.appendingPathComponent("full.png"))
                }
                // A box around the companion (the whole sky for flights), floor 30 points above its bottom edge.
                let cropHeight = scenario.flying ? sceneSize.height - 20 : box.height
                let crop = CGRect(
                    x: (scene.petLocation.x - box.width / 2) * renderScale,
                    y: (sceneSize.height - Double(habitat.floor) + 30 - cropHeight) * renderScale,
                    width: box.width * renderScale, height: cropHeight * renderScale
                ).intersection(CGRect(x: 0, y: 0, width: width, height: height))
                if let cropped = image.cropping(to: crop.integral) {
                    frames.append(cropped)
                    try write(
                        cropped, to: output.appendingPathComponent(String(format: "frame-%03d.png", frames.count)))
                }
            }
            try writeSheet(frames, to: output.appendingPathComponent("sheet.png"))
            try writeGIF(frames, delay: 1 / scenario.fps, to: output.appendingPathComponent("animation.gif"))
        }

        private static func image(from texture: MTLTexture, width: Int, height: Int) -> CGImage? {
            var bytes = [UInt8](repeating: 0, count: width * height * 4)
            texture.getBytes(
                &bytes, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
            guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
            return CGImage(
                width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(
                    rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
                provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        }

        private static func write(_ image: CGImage, to url: URL) throws {
            guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)
            else { throw FilmstripError.write(url) }
            CGImageDestinationAddImage(destination, image, nil)
            guard CGImageDestinationFinalize(destination) else { throw FilmstripError.write(url) }
        }

        private static func writeSheet(_ frames: [CGImage], to url: URL) throws {
            guard let first = frames.first else { return }
            // Half-size cells keep the sheet readable at a glance.
            let cell = CGSize(width: first.width / 2, height: first.height / 2)
            let columns = min(frames.count, max(1, Int((2_400 / cell.width).rounded(.down))))
            let rows = (frames.count + columns - 1) / columns
            guard
                let context = CGContext(
                    data: nil, width: Int(cell.width) * columns, height: Int(cell.height) * rows,
                    bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { throw FilmstripError.write(url) }
            context.setFillColor(CGColor(gray: 0.6, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: context.width, height: context.height))
            context.interpolationQuality = .high
            for (index, frame) in frames.enumerated() {
                let column = index % columns
                let row = index / columns
                let rect = CGRect(
                    x: Double(column) * cell.width, y: Double(rows - 1 - row) * cell.height,
                    width: Double(frame.width) / 2, height: Double(frame.height) / 2)
                context.draw(frame, in: rect.insetBy(dx: 0.5, dy: 0.5))
            }
            guard let sheet = context.makeImage() else { throw FilmstripError.write(url) }
            try write(sheet, to: url)
        }

        private static func writeGIF(_ frames: [CGImage], delay: Double, to url: URL) throws {
            guard
                let destination = CGImageDestinationCreateWithURL(
                    url as CFURL, "com.compuserve.gif" as CFString, frames.count, nil)
            else { throw FilmstripError.write(url) }
            CGImageDestinationSetProperties(
                destination,
                [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
            let properties =
                [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFUnclampedDelayTime: delay]] as CFDictionary
            for frame in frames { CGImageDestinationAddImage(destination, frame, properties) }
            guard CGImageDestinationFinalize(destination) else { throw FilmstripError.write(url) }
        }

        enum FilmstripError: Error {
            case texture
            case write(URL)
        }
    }
#endif
