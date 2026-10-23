import AppKit
import CompanionCore
import SpriteKit

@MainActor
final class PetScene: SKScene {
    private(set) var atlas: PetAtlas
    weak var library: MemeLibrary?
    // Internal node storage is shared by the scene's rendering/effects feature extensions.
    let pet = SKSpriteNode()
    let shadow = SKShapeNode(ellipseOf: CGSize(width: 110, height: 15))
    let ball = SKShapeNode(circleOfRadius: 12)
    let ballStripe = SKShapeNode(circleOfRadius: 8)
    let nameLabel = SKLabelNode()
    let sleepLabel = SKLabelNode()
    let snack = SKShapeNode(circleOfRadius: 8)
    let pawRing = SKShapeNode(circleOfRadius: 19)
    var contactShadows: [SKShapeNode] = []
    var pose: PetPose = .sitting
    var coat: CoatStyle = .cinnamon
    var facingRight = true
    var origin = CGPoint.zero
    var isPreview = false
    var petLocation = CGPoint.zero
    var reducedMotion = false
    let animation = PetAnimation()
    var memeCard: MemeCardNode?
    let ribbon = SKShapeNode()
    let focusLabel = SKLabelNode()
    let focusTrack = SKShapeNode(rectOf: CGSize(width: 58, height: 3), cornerRadius: 1.5)
    let focusFill = SKShapeNode(rectOf: CGSize(width: 58, height: 3), cornerRadius: 1.5)
    var speechSeconds: Double = 4
    var bubbleStyle: BubbleStyle = .cream
    let wardrobe = PetWardrobe()
    var pawprintSeconds: Double = 35
    var printScale: Double = 1
    var flightSparkAt: Double = 0
    // Transient nodes touched every frame are referenced directly: SpriteKit's
    // childNode(withName:) parses a search pattern on every call.
    weak var poseTransition: SKNode?
    weak var speechBubble: SKNode?
    weak var note: SKNode?

    init(size: CGSize, atlas: PetAtlas, preview: Bool = false) {
        self.atlas = atlas
        isPreview = preview
        super.init(size: size)
        backgroundColor = .clear
        scaleMode = .resizeFill
        ribbon.strokeColor = NSColor(calibratedRed: 0.67, green: 0.48, blue: 0.32, alpha: 0.65)
        ribbon.lineWidth = 1.5
        ribbon.zPosition = 2.5
        ribbon.isHidden = true
        addChild(ribbon)
        focusLabel.fontName = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium).fontName
        focusLabel.fontSize = 11
        focusLabel.fontColor = NSColor(calibratedRed: 0.30, green: 0.46, blue: 0.36, alpha: 1)
        focusLabel.zPosition = 6
        focusLabel.isHidden = true
        addChild(focusLabel)
        focusTrack.fillColor = .black.withAlphaComponent(0.08)
        focusTrack.strokeColor = .clear
        focusTrack.isHidden = true
        focusTrack.zPosition = 6
        addChild(focusTrack)
        focusFill.fillColor = NSColor(calibratedRed: 0.47, green: 0.62, blue: 0.44, alpha: 1)
        focusFill.strokeColor = .clear
        focusTrack.addChild(focusFill)
        shadow.fillColor = NSColor(calibratedRed: 0.23, green: 0.13, blue: 0.08, alpha: 0.13)
        shadow.strokeColor = .clear
        shadow.zPosition = 0
        addChild(shadow)
        for _ in 0..<4 {
            let contact = SKShapeNode(ellipseOf: CGSize(width: 17, height: 4))
            contact.fillColor = NSColor(calibratedRed: 0.28, green: 0.18, blue: 0.11, alpha: 0.18)
            contact.strokeColor = .clear
            contact.zPosition = 0.1
            addChild(contact)
            contactShadows.append(contact)
        }
        pet.anchorPoint = CGPoint(x: 0.5, y: 0)
        pet.name = "character"
        pet.zPosition = 3
        addChild(pet)
        wardrobe.zPosition = 0.5
        pet.addChild(wardrobe)

        ball.fillColor = NSColor(calibratedRed: 0.31, green: 0.59, blue: 0.52, alpha: 1)
        ball.strokeColor = NSColor(calibratedRed: 0.20, green: 0.43, blue: 0.38, alpha: 1)
        ball.lineWidth = 1.5
        ball.zPosition = 4
        ball.name = "ball"
        ballStripe.strokeColor = NSColor(calibratedRed: 0.90, green: 0.91, blue: 0.71, alpha: 0.9)
        ballStripe.lineWidth = 2
        ballStripe.fillColor = .clear
        ball.addChild(ballStripe)
        let glint = SKShapeNode(ellipseOf: CGSize(width: 5, height: 3))
        glint.fillColor = .white.withAlphaComponent(0.65)
        glint.strokeColor = .clear
        glint.position = CGPoint(x: -4, y: 5)
        ball.addChild(glint)
        ball.isHidden = true
        addChild(ball)

        snack.fillColor = NSColor(calibratedRed: 0.83, green: 0.57, blue: 0.29, alpha: 1)
        snack.strokeColor = NSColor(calibratedRed: 0.57, green: 0.34, blue: 0.17, alpha: 1)
        snack.lineWidth = 1.5
        snack.zPosition = 4
        snack.isHidden = true
        for point in [CGPoint(x: -3, y: 2), CGPoint(x: 3, y: 3), CGPoint(x: 0, y: -3)] {
            let crumb = SKShapeNode(circleOfRadius: 1.4)
            crumb.fillColor = snack.strokeColor
            crumb.strokeColor = .clear
            crumb.position = point
            snack.addChild(crumb)
        }
        addChild(snack)
        pawRing.strokeColor = NSColor(calibratedRed: 0.79, green: 0.47, blue: 0.29, alpha: 0.7)
        pawRing.fillColor = .clear
        pawRing.lineWidth = 1.5
        pawRing.zPosition = 5
        pawRing.isHidden = true
        addChild(pawRing)

        for label in [nameLabel, sleepLabel] {
            label.fontName = NSFont.systemFont(ofSize: 11, weight: .semibold).fontName
            label.fontSize = 11
            label.fontColor = NSColor(calibratedRed: 0.42, green: 0.32, blue: 0.27, alpha: 1)
            label.zPosition = 6
            addChild(label)
        }
        sleepLabel.text = "z  z  z"
        sleepLabel.fontColor = NSColor(calibratedRed: 0.49, green: 0.57, blue: 0.56, alpha: 0.8)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func changeAtlas(_ atlas: PetAtlas) {
        guard self.atlas !== atlas else { return }
        self.atlas = atlas
        pet.texture = nil
        dismissNote()
        clearFootprints()
    }

    func setFocus(text: String?, progress: Double) {
        focusLabel.text = text
        focusLabel.isHidden = text == nil
        focusTrack.isHidden = text == nil
        let width = progress.clamped(to: 0...1)
        focusFill.xScale = width
        focusFill.position.x = -29 * (1 - width)
    }

    func local(_ point: Point) -> CGPoint { CGPoint(x: point.x - origin.x, y: point.y - origin.y) }
}
