import AppKit

@main
enum TaskmasterApplication {
    @MainActor static func main() {
        if CommandLine.arguments.contains("--self-check") {
            do {
                let atlas = try PetAtlas()
                for pose in PetPose.allCases {
                    let frame = atlas.frame(for: pose)
                    guard frame.width > 0, frame.height > 0,
                          frame.eyes.allSatisfy({ (0...1).contains($0.center.x) && (0...1).contains($0.center.y) && $0.radius > 0 }),
                          frame.paw.map({ (0...1).contains($0.x) && (0...1).contains($0.y) }) ?? true
                    else { throw PetAtlas.ArtError.invalidFrame }
                    print("\(pose): \(frame.width)×\(frame.height), \(frame.eyes.count) animated eyes")
                }
                print("Taskmaster self-check passed: all \(PetPose.allCases.count) transparent character frames loaded.")
            } catch {
                FileHandle.standardError.write(Data("Taskmaster self-check failed: \(error)\n".utf8))
                exit(1)
            }
            return
        }
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }
}
