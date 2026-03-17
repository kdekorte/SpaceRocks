//
//  GameScene.swift
//  SpaceRocks
//
//  Created by Kevin DeKorte on 3/17/26.
//

import SpriteKit
import GameplayKit

private struct PhysicsCategory {
    static let none: UInt32      = 0
    static let ship: UInt32      = 0x1 << 0
    static let asteroid: UInt32  = 0x1 << 1
    static let bullet: UInt32    = 0x1 << 2
}

class GameScene: SKScene, SKPhysicsContactDelegate {

    // MARK: - Game State
    private var lastUpdateTime: TimeInterval = 0
    private var ship: SKShapeNode!
    private var thrusting = false
    private var turningLeft = false
    private var turningRight = false
    private var bullets = [SKShapeNode]()
    private var asteroids = [SKShapeNode]()
    private var scoreLabel = SKLabelNode(fontNamed: "Menlo")
    private var livesLabel = SKLabelNode(fontNamed: "Menlo")
    private var titleLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private var subtitleLabel = SKLabelNode(fontNamed: "Menlo")
    private var gameOverLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private var isThrustSoundPlaying = false

    private var highScoreLabel = SKLabelNode(fontNamed: "Menlo")
    private var titleShadow = SKLabelNode(fontNamed: "Menlo-Bold")
    private var gameOverShadow = SKLabelNode(fontNamed: "Menlo-Bold")
    private var infoLabel = SKLabelNode(fontNamed: "Menlo")
    
    // Background starfield layers
    private var starfieldBack = SKNode()
    private var starfieldFront = SKNode()

    // Ship thrust emitter
    private var thrustEmitter: SKEmitterNode?
    
    // Shield
    private var shieldNode: SKShapeNode?
    private var shieldActive = false
    private var shieldPower: Int = 100 // 0..100
    private var shieldTimer: TimeInterval = 0
    private let shieldTick: TimeInterval = 0.25 // 250ms
    private let shieldMinToActivate = 10
    private var shieldCooldown: Bool = false
    private let shieldCooldownDuration: TimeInterval = 1.0
    private var shieldCooldownTimer: TimeInterval = 0

    // Shield HUD meter
    private var shieldMeterBackground = SKShapeNode()
    private var shieldMeterFill = SKShapeNode()
    private var shieldCooldownLabel = SKLabelNode(fontNamed: "Menlo")

    private enum GameState { case title, playing, gameOver }
    private var state: GameState = .title

    private var lives: Int = 3
    private var nextExtraLifeScore: Int = 10000

    private let highScoreKey = "HighScore"
    private var highScore: Int = 0 {
        didSet { highScoreLabel.text = "High: \(highScore)" }
    }

    private var score: Int = 0 {
        didSet {
            scoreLabel.text = "Score: \(score)"
            if score > highScore {
                highScore = score
                UserDefaults.standard.set(highScore, forKey: highScoreKey)
            }
            // Extra life at 10,000 increments
            if score >= nextExtraLifeScore {
                lives += 1
                updateLivesLabel()
                nextExtraLifeScore += 10000
            }
        }
    }

    // NOTE: Add fire.caf, thrust.caf, explode.caf, shield_on.caf, and shield_off.caf to your bundle for sounds. If missing, the game still runs silently.
    // Sounds (use bundled system sounds if no assets are provided)
    private let fireSound = SKAction.playSoundFileNamed("fire.caf", waitForCompletion: false)
    private let thrustSound = SKAction.playSoundFileNamed("thrust.caf", waitForCompletion: false)
    private let explodeSound = SKAction.playSoundFileNamed("explode.caf", waitForCompletion: false)
    private let shieldOnSound = SKAction.playSoundFileNamed("shield_on.caf", waitForCompletion: false)
    private let shieldOffSound = SKAction.playSoundFileNamed("shield_off.caf", waitForCompletion: false)

    // MARK: - Scene Lifecycle
    override func didMove(to view: SKView) {
        backgroundColor = .black
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        setupStarfield()

        highScore = UserDefaults.standard.integer(forKey: highScoreKey)
        createHUD()
        showTitle()
    }

    // MARK: - Setup
    private func createHUD() {
        // Score label
        scoreLabel.fontSize = 16
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.verticalAlignmentMode = .top
        scoreLabel.position = CGPoint(x: frame.minX + 20, y: frame.maxY - 20)
        addChild(scoreLabel)

        // Lives label
        livesLabel.fontSize = 16
        livesLabel.horizontalAlignmentMode = .right
        livesLabel.verticalAlignmentMode = .top
        livesLabel.position = CGPoint(x: frame.maxX - 20, y: frame.maxY - 20)
        addChild(livesLabel)
        
        // High score label (top center)
        highScoreLabel.fontSize = 16
        highScoreLabel.horizontalAlignmentMode = .center
        highScoreLabel.verticalAlignmentMode = .top
        highScoreLabel.position = CGPoint(x: frame.midX, y: frame.maxY - 20)
        addChild(highScoreLabel)
        highScoreLabel.text = "High: \(highScore)"
        
        // Shield meter near scoreboard (top center under high score)
        let meterWidth: CGFloat = 160
        let meterHeight: CGFloat = 6
        let meterOrigin = CGPoint(x: frame.midX - meterWidth/2, y: frame.maxY - 40)

        let bgPath = CGMutablePath()
        bgPath.addRoundedRect(in: CGRect(origin: meterOrigin, size: CGSize(width: meterWidth, height: meterHeight)), cornerWidth: 3, cornerHeight: 3)
        shieldMeterBackground = SKShapeNode(path: bgPath)
        shieldMeterBackground.strokeColor = .gray
        shieldMeterBackground.fillColor = SKColor.gray.withAlphaComponent(0.2)
        shieldMeterBackground.lineWidth = 1
        addChild(shieldMeterBackground)

        let fillPath = CGMutablePath()
        fillPath.addRoundedRect(in: CGRect(origin: meterOrigin, size: CGSize(width: meterWidth, height: meterHeight)), cornerWidth: 3, cornerHeight: 3)
        shieldMeterFill = SKShapeNode(path: fillPath)
        shieldMeterFill.strokeColor = .clear
        shieldMeterFill.fillColor = .yellow
        shieldMeterFill.lineWidth = 0
        addChild(shieldMeterFill)

        // Cooldown label under meter (hidden by default)
        shieldCooldownLabel.fontSize = 10
        shieldCooldownLabel.fontColor = .orange
        shieldCooldownLabel.horizontalAlignmentMode = .center
        shieldCooldownLabel.verticalAlignmentMode = .top
        shieldCooldownLabel.text = "COOLDOWN"
        shieldCooldownLabel.position = CGPoint(x: frame.midX, y: frame.maxY - 48)
        shieldCooldownLabel.alpha = 0.0
        addChild(shieldCooldownLabel)

        updateShieldMeter()

        score = 0
        lives = 3
        nextExtraLifeScore = 10000
        updateLivesLabel()
    }

    private func updateLivesLabel() {
        livesLabel.text = "Lives: \(lives)"
    }
    
    private func updateShieldMeter() {
        let meterWidth: CGFloat = 160
        let meterHeight: CGFloat = 6
        let originX = frame.midX - meterWidth/2
        let originY = frame.maxY - 40
        let currentWidth = meterWidth * CGFloat(max(0, min(100, shieldPower))) / 100.0
        let fillRect = CGRect(x: originX, y: originY, width: currentWidth, height: meterHeight)
        let path = CGMutablePath()
        path.addRoundedRect(in: fillRect, cornerWidth: 3, cornerHeight: 3)
        shieldMeterFill.path = path
        shieldMeterFill.alpha = shieldPower > 0 ? 1.0 : 0.3
    }

    private func updateShieldCooldownHUD() {
        if shieldCooldown {
            shieldMeterBackground.strokeColor = .orange
            shieldMeterBackground.fillColor = SKColor.orange.withAlphaComponent(0.2)
            shieldMeterFill.fillColor = .orange
            if shieldCooldownLabel.alpha == 0.0 {
                shieldCooldownLabel.run(.fadeIn(withDuration: 0.2))
            }
        } else {
            shieldMeterBackground.strokeColor = .gray
            shieldMeterBackground.fillColor = SKColor.gray.withAlphaComponent(0.2)
            shieldMeterFill.fillColor = .yellow
            if shieldCooldownLabel.alpha > 0.0 {
                shieldCooldownLabel.run(.fadeOut(withDuration: 0.2))
            }
        }
    }

    private func createShip() {
        // Triangle ship
        let path = CGMutablePath()
        let shipSize: CGFloat = 16
        path.move(to: CGPoint(x: shipSize, y: 0))
        path.addLine(to: CGPoint(x: -shipSize * 0.6, y: shipSize * 0.6))
        path.addLine(to: CGPoint(x: -shipSize * 0.6, y: -shipSize * 0.6))
        path.closeSubpath()

        let node = SKShapeNode(path: path)
        node.strokeColor = .white
        node.lineWidth = 2
        node.position = CGPoint(x: frame.midX, y: frame.midY)

        node.physicsBody = SKPhysicsBody(polygonFrom: path)
        node.physicsBody?.isDynamic = true
        node.physicsBody?.affectedByGravity = false
        node.physicsBody?.linearDamping = 0.0
        node.physicsBody?.angularDamping = 0.0
        node.physicsBody?.categoryBitMask = PhysicsCategory.ship
        node.physicsBody?.contactTestBitMask = PhysicsCategory.asteroid
        node.physicsBody?.collisionBitMask = PhysicsCategory.none

        addChild(node)
        ship = node
        
        thrustEmitter?.removeFromParent()
        let emitter = makeThrustEmitter()
        emitter.position = CGPoint(x: -10, y: 0)
        emitter.targetNode = self
        node.addChild(emitter)
        emitter.particleBirthRate = 0
        thrustEmitter = emitter
        
        // Shield ring (initially hidden)
        let ring = SKShapeNode(circleOfRadius: shipSize + 6)
        ring.strokeColor = .yellow
        ring.lineWidth = 2
        ring.fillColor = .clear
        ring.alpha = 0.0
        ring.glowWidth = 6
        node.addChild(ring)
        shieldNode = ring
    }

    private func spawnWave() {
        // Spawn a few large asteroids
        for _ in 0..<5 {
            spawnAsteroid(size: .large)
        }
    }

    private enum AsteroidSize { case large, medium, small }

    private func spawnAsteroid(size: AsteroidSize, position: CGPoint? = nil, velocity: CGVector? = nil) {
        let radius: CGFloat
        switch size {
        case .large: radius = 40
        case .medium: radius = 24
        case .small: radius = 14
        }

        let path = CGMutablePath()
        let sides = 10
        let jagged: CGFloat = radius * 0.3
        for i in 0..<sides {
            let angle = CGFloat(i) / CGFloat(sides) * .pi * 2
            let r = radius + CGFloat.random(in: -jagged...jagged)
            let p = CGPoint(x: cos(angle) * r, y: sin(angle) * r)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        let asteroid = SKShapeNode(path: path)
        asteroid.strokeColor = .white
        asteroid.lineWidth = 2

        let spawnPos: CGPoint
        if let position = position {
            spawnPos = position
        } else {
            // Spawn at edge away from ship
            let edges: [CGRectEdge] = [.minXEdge, .maxXEdge, .minYEdge, .maxYEdge]
            let edge = edges.randomElement()!
            switch edge {
            case .minXEdge:
                spawnPos = CGPoint(x: frame.minX + 10, y: CGFloat.random(in: frame.minY...frame.maxY))
            case .maxXEdge:
                spawnPos = CGPoint(x: frame.maxX - 10, y: CGFloat.random(in: frame.minY...frame.maxY))
            case .minYEdge:
                spawnPos = CGPoint(x: CGFloat.random(in: frame.minX...frame.maxX), y: frame.minY + 10)
            case .maxYEdge:
                spawnPos = CGPoint(x: CGFloat.random(in: frame.minX...frame.maxX), y: frame.maxY - 10)
            @unknown default:
                spawnPos = CGPoint(x: frame.midX, y: frame.midY)
            }
        }
        asteroid.position = spawnPos

        asteroid.physicsBody = SKPhysicsBody(polygonFrom: path)
        asteroid.physicsBody?.isDynamic = true
        asteroid.physicsBody?.affectedByGravity = false
        asteroid.physicsBody?.linearDamping = 0.0
        asteroid.physicsBody?.angularDamping = 0.0
        asteroid.physicsBody?.categoryBitMask = PhysicsCategory.asteroid
        asteroid.physicsBody?.contactTestBitMask = PhysicsCategory.ship | PhysicsCategory.bullet
        asteroid.physicsBody?.collisionBitMask = PhysicsCategory.none

        addChild(asteroid)
        asteroids.append(asteroid)

        // Give it some motion
        let speed: CGFloat
        switch size {
        case .large: speed = 40
        case .medium: speed = 70
        case .small: speed = 100
        }
        let vel = velocity ?? CGVector(dx: CGFloat.random(in: -1...1) * speed,
                                       dy: CGFloat.random(in: -1...1) * speed)
        asteroid.physicsBody?.velocity = vel
        asteroid.physicsBody?.angularVelocity = CGFloat.random(in: -1.5...1.5)
    }

    // MARK: - Title, GameOver, and State Management

    private func showTitle() {
        state = .title
        clearGameObjects()

        titleLabel.text = "SPACE ROCKS"
        titleLabel.fontSize = 44
        titleLabel.fontColor = .white
        titleLabel.position = CGPoint(x: frame.midX, y: frame.midY + 60)
        titleLabel.zPosition = 10
        addChild(titleLabel)

        // Drop shadow behind title
        titleShadow.removeFromParent()
        titleShadow = addDropShadow(to: titleLabel)
        addChild(titleShadow)

        subtitleLabel.text = "Press SPACE to start"
        subtitleLabel.fontSize = 20
        subtitleLabel.fontColor = .white
        subtitleLabel.position = CGPoint(x: frame.midX, y: frame.midY - 10)
        subtitleLabel.zPosition = 10
        addChild(subtitleLabel)

        // Gentle pulse animation on subtitle
        let pulse = SKAction.sequence([.fadeAlpha(to: 0.4, duration: 0.8), .fadeAlpha(to: 1.0, duration: 0.8)])
        subtitleLabel.run(.repeatForever(pulse))

        // Info label with controls
        infoLabel.removeFromParent()
        infoLabel.text = "Arrows: Rotate/Thrust   Space: Fire/Start"
        infoLabel.fontSize = 14
        infoLabel.fontColor = .lightGray
        infoLabel.position = CGPoint(x: frame.midX, y: frame.minY + 40)
        infoLabel.zPosition = 10
        addChild(infoLabel)

        // Title bounce in
        titleLabel.setScale(0.8)
        titleLabel.alpha = 0
        titleLabel.run(.group([
            .fadeIn(withDuration: 0.4),
            .sequence([.scale(to: 1.1, duration: 0.25), .scale(to: 1.0, duration: 0.15)])
        ]))
        
        highScoreLabel.text = "High: \(highScore)"
        
        shieldActive = false
        shieldNode?.alpha = 0.0
        updateShieldCooldownHUD()
    }

    private func startGame() {
        state = .playing
        titleLabel.removeFromParent()
        subtitleLabel.removeFromParent()
        gameOverLabel.removeFromParent()
        titleShadow.removeFromParent()
        gameOverShadow.removeFromParent()
        infoLabel.removeFromParent()

        score = 0
        lives = 3
        nextExtraLifeScore = 10000
        updateLivesLabel()
        highScoreLabel.text = "High: \(highScore)"
        
        shieldActive = false
        shieldPower = 100
        shieldTimer = 0
        shieldCooldown = false
        shieldCooldownTimer = 0
        updateShieldMeter()
        updateShieldCooldownHUD()

        createShip()
        spawnWave()
    }

    private func showGameOver() {
        state = .gameOver
        clearGameObjects()

        gameOverLabel.text = "GAME OVER"
        gameOverLabel.fontSize = 44
        gameOverLabel.fontColor = .white
        gameOverLabel.position = CGPoint(x: frame.midX, y: frame.midY + 40)
        gameOverLabel.zPosition = 10
        addChild(gameOverLabel)

        // Drop shadow behind game over
        gameOverShadow.removeFromParent()
        gameOverShadow = addDropShadow(to: gameOverLabel)
        addChild(gameOverShadow)

        // Show final score and high score
        subtitleLabel.text = "Score: \(score)   High: \(highScore)"
        subtitleLabel.fontSize = 18
        subtitleLabel.fontColor = .lightGray
        subtitleLabel.position = CGPoint(x: frame.midX, y: frame.midY - 10)
        subtitleLabel.zPosition = 10
        addChild(subtitleLabel)

        // Prompt to restart
        infoLabel.removeFromParent()
        infoLabel.text = "Press SPACE to restart"
        infoLabel.fontSize = 16
        infoLabel.fontColor = .white
        infoLabel.position = CGPoint(x: frame.midX, y: frame.minY + 40)
        infoLabel.zPosition = 10
        addChild(infoLabel)

        // Slight pop animation
        gameOverLabel.setScale(0.8)
        gameOverLabel.alpha = 0
        gameOverLabel.run(.group([
            .fadeIn(withDuration: 0.3),
            .sequence([.scale(to: 1.05, duration: 0.2), .scale(to: 1.0, duration: 0.1)])
        ]))
    }

    private func clearGameObjects() {
        ship?.removeFromParent()
        asteroids.forEach { $0.removeFromParent() }
        bullets.forEach { $0.removeFromParent() }
        asteroids.removeAll()
        bullets.removeAll()
    }

    // MARK: - Input
    override func keyDown(with event: NSEvent) {
        switch state {
        case .title:
            if event.keyCode == 49 { // space
                run(fireSound)
                startGame()
            }
        case .playing:
            switch event.keyCode {
            case 123: // left
                turningLeft = true
            case 124: // right
                turningRight = true
            case 126: // up
                thrusting = true
            case 49: // space -> fire
                fireBullet()
            case 1: // 'S' key -> shield on (if enough power and not cooldown)
                if !shieldActive && !shieldCooldown && shieldPower >= shieldMinToActivate {
                    shieldActive = true
                    shieldNode?.run(.group([
                        .fadeAlpha(to: 0.9, duration: 0.1),
                        .customAction(withDuration: 0.1) { node, _ in
                            (node as? SKShapeNode)?.glowWidth = 8
                        }
                    ]))
                    run(shieldOnSound)
                }
            case 56, 60: // Shift keys -> shield on (if enough power and not cooldown)
                if !shieldActive && !shieldCooldown && shieldPower >= shieldMinToActivate {
                    shieldActive = true
                    shieldNode?.run(.group([
                        .fadeAlpha(to: 0.9, duration: 0.1),
                        .customAction(withDuration: 0.1) { node, _ in
                            (node as? SKShapeNode)?.glowWidth = 8
                        }
                    ]))
                    run(shieldOnSound)
                }
            default:
                break
            }
        case .gameOver:
            if event.keyCode == 49 { // space
                run(fireSound)
                startGame()
            }
        }
    }

    override func keyUp(with event: NSEvent) {
        guard state == .playing else { return }
        switch event.keyCode {
        case 123:
            turningLeft = false
        case 124:
            turningRight = false
        case 126:
            thrusting = false
        case 1: // 'S' released
            shieldActive = false
            shieldNode?.run(.group([
                .fadeAlpha(to: 0.0, duration: 0.1),
                .customAction(withDuration: 0.1) { node, _ in
                    (node as? SKShapeNode)?.glowWidth = 6
                }
            ]))
            run(shieldOffSound)
        case 56, 60: // Shift released
            shieldActive = false
            shieldNode?.run(.group([
                .fadeAlpha(to: 0.0, duration: 0.1),
                .customAction(withDuration: 0.1) { node, _ in
                    (node as? SKShapeNode)?.glowWidth = 6
                }
            ]))
            run(shieldOffSound)
        default:
            break
        }
    }

    // MARK: - Actions
    private func fireBullet() {
        guard state == .playing else { return }
        guard ship.parent != nil else { return }
        let bullet = SKShapeNode(circleOfRadius: 2)
        bullet.fillColor = .white
        bullet.strokeColor = .white
        bullet.position = ship.position + forwardVector() * 18
        bullet.zPosition = -1

        bullet.physicsBody = SKPhysicsBody(circleOfRadius: 2)
        bullet.physicsBody?.isDynamic = true
        bullet.physicsBody?.affectedByGravity = false
        bullet.physicsBody?.linearDamping = 0
        bullet.physicsBody?.categoryBitMask = PhysicsCategory.bullet
        bullet.physicsBody?.contactTestBitMask = PhysicsCategory.asteroid
        bullet.physicsBody?.collisionBitMask = PhysicsCategory.none

        let trail = makeBulletTrail()
        trail.targetNode = self
        bullet.addChild(trail)

        run(fireSound)
        addChild(bullet)
        bullets.append(bullet)

        let speed: CGFloat = 300
        bullet.physicsBody?.velocity = forwardVector() * speed + (ship.physicsBody?.velocity ?? .zero)

        // Remove after some time
        bullet.run(.sequence([.wait(forDuration: 1.2), .removeFromParent()])) { [weak self] in
            self?.bullets.removeAll { $0 == bullet }
        }
    }

    private func forwardVector() -> CGVector {
        let angle = ship.zRotation
        return CGVector(dx: cos(angle), dy: sin(angle))
    }

    // MARK: - Update Loop
    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 { lastUpdateTime = currentTime }
        let dt = currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        guard state == .playing else { return }
        
        shieldTimer += dt
        while shieldTimer >= shieldTick {
            shieldTimer -= shieldTick
            if shieldActive {
                shieldPower = max(0, shieldPower - 10)
                if shieldPower == 0 {
                    shieldActive = false
                    shieldCooldown = true
                    shieldCooldownTimer = shieldCooldownDuration
                    updateShieldCooldownHUD()
                    let flicker = SKAction.sequence([
                        .fadeAlpha(to: 0.2, duration: 0.05),
                        .fadeAlpha(to: 0.9, duration: 0.05),
                        .fadeAlpha(to: 0.2, duration: 0.05),
                        .fadeAlpha(to: 0.0, duration: 0.1)
                    ])
                    let reduceGlow = SKAction.customAction(withDuration: 0.2) { node, _ in
                        (node as? SKShapeNode)?.glowWidth = 6
                    }
                    shieldNode?.run(.sequence([flicker, reduceGlow]))
                    run(shieldOffSound)
                }
            } else {
                shieldPower = min(100, shieldPower + 1)
            }
            updateShieldMeter()
        }
        
        if shieldCooldown {
            shieldCooldownTimer -= dt
            if shieldCooldownTimer <= 0 {
                shieldCooldown = false
                shieldCooldownTimer = 0
                updateShieldCooldownHUD()
            }
        }

        // Rotate
        let turnSpeed: CGFloat = 3.0
        if turningLeft { ship.zRotation += turnSpeed * CGFloat(dt) }
        if turningRight { ship.zRotation -= turnSpeed * CGFloat(dt) }

        // Thrust
        if thrusting {
            let thrust: CGFloat = 180
            let add = forwardVector() * (thrust * CGFloat(dt))
            if let v = ship.physicsBody?.velocity {
                ship.physicsBody!.velocity = v + add
            } else {
                ship.physicsBody!.velocity = add
            }
            if !isThrustSoundPlaying {
                isThrustSoundPlaying = true
                run(thrustSound) { [weak self] in self?.isThrustSoundPlaying = false }
            }
            thrustEmitter?.particleBirthRate = 140
        } else {
            isThrustSoundPlaying = false
            thrustEmitter?.particleBirthRate = 0
        }

        // Screen wrap for ship, asteroids, bullets
        wrapNode(ship)
        for a in asteroids { wrapNode(a) }
        for b in bullets { wrapNode(b) }

        // If no asteroids, new wave
        if asteroids.isEmpty {
            spawnWave()
        }
    }

    private func wrapNode(_ node: SKNode) {
        var p = node.position
        if p.x < frame.minX { p.x = frame.maxX }
        else if p.x > frame.maxX { p.x = frame.minX }
        if p.y < frame.minY { p.y = frame.maxY }
        else if p.y > frame.maxY { p.y = frame.minY }
        node.position = p
    }

    // MARK: - Contacts
    func didBegin(_ contact: SKPhysicsContact) {
        let a = contact.bodyA.categoryBitMask
        let b = contact.bodyB.categoryBitMask

        if (a == PhysicsCategory.bullet && b == PhysicsCategory.asteroid) ||
            (b == PhysicsCategory.bullet && a == PhysicsCategory.asteroid) {
            if let bulletNode = (contact.bodyA.categoryBitMask == PhysicsCategory.bullet ? contact.bodyA.node : contact.bodyB.node) as? SKShapeNode,
               let asteroidNode = (contact.bodyA.categoryBitMask == PhysicsCategory.asteroid ? contact.bodyA.node : contact.bodyB.node) as? SKShapeNode {
                bulletHit(bullet: bulletNode, asteroid: asteroidNode)
            }
        }

        if (a == PhysicsCategory.ship && b == PhysicsCategory.asteroid) ||
            (b == PhysicsCategory.ship && a == PhysicsCategory.asteroid) {
            if !shieldActive { shipHit() }
        }
    }

    private func bulletHit(bullet: SKShapeNode, asteroid: SKShapeNode) {
        bullet.removeFromParent()
        bullets.removeAll { $0 == bullet }

        // Determine size by approximate radius
        let approxRadius = max(asteroid.frame.width, asteroid.frame.height) * 0.5
        asteroid.removeFromParent()
        asteroids.removeAll { $0 == asteroid }

        if approxRadius > 30 { // large -> 2 medium
            for _ in 0..<2 {
                spawnAsteroid(size: .medium, position: asteroid.position, velocity: randomSplitVelocity())
            }
            score += 10
        } else if approxRadius > 18 { // medium -> 2 small
            for _ in 0..<2 {
                spawnAsteroid(size: .small, position: asteroid.position, velocity: randomSplitVelocity())
            }
            score += 25
        } else { // small destroyed
            score += 100
        }
    }

    private func randomSplitVelocity() -> CGVector {
        let speed: CGFloat = CGFloat.random(in: 60...120)
        let angle = CGFloat.random(in: 0..<(2 * .pi))
        return CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed)
    }

    private func shipHit() {
        guard state == .playing else { return }
        run(explodeSound)

        let explosion = SKEmitterNode()
        explosion.particleTexture = nil
        explosion.particleBirthRate = 0
        explosion.numParticlesToEmit = 80
        explosion.particleLifetime = 0.6
        explosion.particleLifetimeRange = 0.3
        explosion.particleSpeed = 220
        explosion.particleSpeedRange = 80
        explosion.emissionAngleRange = .pi * 2
        explosion.particleAlpha = 1.0
        explosion.particleAlphaSpeed = -1.5
        explosion.particleScale = 0.8
        explosion.particleScaleRange = 0.4
        explosion.particleColor = .white
        explosion.particleColorBlendFactor = 1.0
        explosion.position = ship.position
        addChild(explosion)
        explosion.run(.sequence([.wait(forDuration: 0.6), .removeFromParent()]))

        ship.removeFromParent()
        lives -= 1
        updateLivesLabel()

        if lives <= 0 {
            showGameOver()
            return
        }

        // Respawn after short delay
        run(.sequence([
            .wait(forDuration: 1.0),
            .run { [weak self] in self?.createShip() }
        ]))
        score = max(0, score - 200)
    }
    
    // MARK: - Label Helpers
    
    private func addDropShadow(to label: SKLabelNode, offset: CGPoint = CGPoint(x: 2, y: -2), color: SKColor = .gray) -> SKLabelNode {
        let shadow = SKLabelNode(fontNamed: label.fontName)
        shadow.text = label.text
        shadow.fontSize = label.fontSize
        shadow.fontColor = color
        shadow.position = CGPoint(x: label.position.x + offset.x, y: label.position.y + offset.y)
        shadow.zPosition = label.zPosition - 1
        shadow.alpha = 0.6
        return shadow
    }
    
    private func setupStarfield() {
        starfieldBack.removeFromParent()
        starfieldFront.removeFromParent()
        starfieldBack = SKNode()
        starfieldFront = SKNode()

        addChild(starfieldBack)
        addChild(starfieldFront)
        starfieldBack.zPosition = -100
        starfieldFront.zPosition = -90

        func makeStars(count: Int, in node: SKNode, speed: CGFloat, alpha: CGFloat) {
            for _ in 0..<count {
                let star = SKShapeNode(circleOfRadius: CGFloat.random(in: 0.5...1.4))
                star.fillColor = .white
                star.strokeColor = .clear
                star.alpha = alpha * CGFloat.random(in: 0.6...1.0)
                star.position = CGPoint(x: CGFloat.random(in: frame.minX...frame.maxX),
                                        y: CGFloat.random(in: frame.minY...frame.maxY))
                node.addChild(star)

                let dy: CGFloat = -speed
                let move = SKAction.moveBy(x: 0, y: dy, duration: 1.0)
                let loop = SKAction.repeatForever(SKAction.sequence([
                    move,
                    SKAction.run { [weak self, weak star] in
                        guard let self = self, let star = star else { return }
                        if star.position.y < self.frame.minY { star.position.y = self.frame.maxY }
                    }
                ]))
                star.run(loop)

                // Twinkle
                let twinkle = SKAction.sequence([
                    SKAction.fadeAlpha(to: star.alpha * 0.4, duration: Double.random(in: 0.6...1.2)),
                    SKAction.fadeAlpha(to: star.alpha, duration: Double.random(in: 0.6...1.2))
                ])
                star.run(SKAction.repeatForever(twinkle))
            }
        }

        makeStars(count: 80, in: starfieldBack, speed: 8, alpha: 0.6)
        makeStars(count: 40, in: starfieldFront, speed: 16, alpha: 1.0)
    }
    
    private func makeThrustEmitter() -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleTexture = nil
        emitter.particleBirthRate = 140
        emitter.particleLifetime = 0.25
        emitter.particleLifetimeRange = 0.1
        emitter.particleSpeed = 140
        emitter.particleSpeedRange = 50
        emitter.emissionAngleRange = .pi / 8
        emitter.particleAlpha = 1.0
        emitter.particleAlphaSpeed = -2.2
        emitter.particleScale = 0.9
        emitter.particleScaleRange = 0.3
        // Red/orange thrust
        emitter.particleColor = .red
        emitter.particleColorBlendFactor = 1.0
        emitter.particleColorSequence = SKKeyframeSequence(keyframeValues: [NSColor.red, NSColor.orange, NSColor.yellow], times: [0, 0.5, 1])
        emitter.zPosition = -1
        return emitter
    }
    
    private func makeBulletTrail() -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleTexture = nil
        emitter.particleBirthRate = 220
        emitter.particleLifetime = 0.28
        emitter.particleSpeed = 0
        emitter.particleAlpha = 0.95
        emitter.particleAlphaSpeed = -3.2
        emitter.particleScale = 0.7
        emitter.particleScaleRange = 0.2
        // Bright green trail
        emitter.particleColor = NSColor(calibratedRed: 0.1, green: 1.0, blue: 0.2, alpha: 1.0)
        emitter.particleColorBlendFactor = 1.0
        emitter.particleColorSequence = SKKeyframeSequence(keyframeValues: [NSColor(calibratedRed: 0.2, green: 1.0, blue: 0.3, alpha: 1.0), NSColor(calibratedRed: 0.0, green: 0.9, blue: 0.2, alpha: 1.0)], times: [0, 1])
        emitter.zPosition = -1
        return emitter
    }
}
// MARK: - Small math helpers
private extension CGPoint {
    static func + (lhs: CGPoint, rhs: CGVector) -> CGPoint { CGPoint(x: lhs.x + rhs.dx, y: lhs.y + rhs.dy) }
}
private extension CGVector {
    static func + (lhs: CGVector, rhs: CGVector) -> CGVector { CGVector(dx: lhs.dx + rhs.dx, dy: lhs.dy + rhs.dy) }
    static func * (v: CGVector, s: CGFloat) -> CGVector { CGVector(dx: v.dx * s, dy: v.dy * s) }
}

