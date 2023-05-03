import SpriteKit
import GameKit

enum GameState {
    case ready
    case playing
    case dead
}

class GameScene: SKScene, SKPhysicsContactDelegate {
    
    var background = SKSpriteNode()
    var tutorial = SKSpriteNode()
    let cameraNode = SKCameraNode()
    var bgmPlayer = SKAudioNode()
    var water = SKSpriteNode()
    var gameState = GameState.ready {
        didSet {
            print(gameState)
        }
    }
    
    var score:Int = 0 {
        didSet {
            scoreLabel.text = "\(score)"
        }
    }
    var scoreLabel = SKLabelNode()
    
    // MARK: - Sprites Alignment
    override func didMove(to view: SKView) {
        let bgColor = SKColor(red: 81.0 / 255.0, green: 192.0 / 255.0, blue: 201.0 / 255.0, alpha: 1.0)
        self.backgroundColor = bgColor
        
        self.physicsWorld.contactDelegate = self
        self.physicsWorld.gravity = CGVector(dx: 0, dy: -9.8)
        
        createWater()
        createEnvironment()
        createScore()
        createRain()
        createTutorial()
        
        
        // BGM 모듈
        bgmPlayer = SKAudioNode(fileNamed: "bgm.mp3")
        bgmPlayer.autoplayLooped = true
        self.addChild(bgmPlayer)
        
        // 카메라 추가
        camera = cameraNode
        cameraNode.position.x = self.size.width / 2
        cameraNode.position.y = self.size.height / 2
        self.addChild(cameraNode)
    }
    
    func createScore() {
        scoreLabel = SKLabelNode(fontNamed: "neodgm")
        scoreLabel.fontSize = 24
        scoreLabel.fontColor = .white
        scoreLabel.position = CGPoint(x: self.size.width / 2,
                                      y: self.size.height - 140)
        scoreLabel.zPosition = Layer.hud
        scoreLabel.horizontalAlignmentMode = .center
        scoreLabel.text = "\(score)"
        addChild(scoreLabel)
    }
    
    func createWater() {
        water = SKSpriteNode(imageNamed: "water1")
        water.position = CGPoint(x: self.size.width / 4, y: self.size.height / 2)
        water.zPosition = Layer.water
        water.physicsBody = SKPhysicsBody(circleOfRadius: water.size.height / 2)
        water.physicsBody?.categoryBitMask = PhysicsCategory.water
        water.physicsBody?.contactTestBitMask = PhysicsCategory.land | PhysicsCategory.tree | PhysicsCategory.ceiling | PhysicsCategory.score
        water.physicsBody?.collisionBitMask = PhysicsCategory.land | PhysicsCategory.tree | PhysicsCategory.ceiling
        water.physicsBody?.affectedByGravity = true
        water.physicsBody?.isDynamic = false
        addChild(water)
        
        guard let flyingBySKS = SKAction(named: "flying") else { return }
        water.run(flyingBySKS)
        
        // thruster 효과
        guard let thruster = SKEmitterNode(fileNamed: "thruster") else { return }
        thruster.position = CGPoint.zero
        thruster.position.x -= water.size.width / 2
        thruster.zPosition = -0.1
        // Add 블렌딩 문제를 SKEffectNode로 해결
        let thrusterEffectNode = SKEffectNode()
        thrusterEffectNode.addChild(thruster)
        water.addChild(thrusterEffectNode)
    }
    
    
    func createEnvironment() {
        let envAtlas = SKTextureAtlas(named: "Environment")
        let landTexture = envAtlas.textureNamed("land")
        let landRepeatNum = Int(ceil(self.size.width / landTexture.size().width))
        guard let skyTexture = self.background.texture else { return }
        let skyRepeatNum = Int(ceil(self.size.width / skyTexture.size().width))
        let ceilTexture = envAtlas.textureNamed("ceiling")
        let ceilRepearNum = Int(ceil(self.size.width / ceilTexture.size().width))
        
        for i in 0...landRepeatNum {
            let land = SKSpriteNode(texture: landTexture)
            land.anchorPoint = CGPoint.zero
            land.position = CGPoint(x: CGFloat(i) * land.size.width, y: 0)
            land.zPosition = Layer.land
            
            land.physicsBody = SKPhysicsBody(rectangleOf: land.size,
                                             center: CGPoint(x: land.size.width / 2,
                                                             y: land.size.height / 2))
            land.physicsBody?.categoryBitMask = PhysicsCategory.land
            land.physicsBody?.affectedByGravity = false
            land.physicsBody?.isDynamic = false
            addChild(land)
            
            let moveLeft = SKAction.moveBy(x: -landTexture.size().width,
                                           y: 0, duration: 20)
            let moveReset = SKAction.moveBy(x: landTexture.size().width,
                                            y: 0, duration: 0)
            let moveSequence = SKAction.sequence([moveLeft, moveReset])
            land.run(SKAction.repeatForever(moveSequence))
        }
        
        for i in 0...skyRepeatNum {
            let sky = SKSpriteNode(texture: skyTexture)
            sky.anchorPoint = CGPoint.zero
            sky.position = CGPoint(x: CGFloat(i) * sky.size.width, y: 0)
            sky.zPosition = Layer.sky
            addChild(sky)
            
            let moveLeft = SKAction.moveBy(x: -skyTexture.size().width,
                                           y: 0, duration: 40)
            let moveReset = SKAction.moveBy(x: skyTexture.size().width,
                                            y: 0, duration: 0)
            let moveSequence = SKAction.sequence([moveLeft, moveReset])
            sky.run(SKAction.repeatForever(moveSequence))
        }
        
        for i in 0...ceilRepearNum {
            let ceiling = SKSpriteNode(texture: ceilTexture)
            ceiling.anchorPoint = CGPoint.zero
            ceiling.position = CGPoint(x: CGFloat(i) * ceiling.size.width,
                                       y: self.size.height - ceiling.size.height )
            ceiling.zPosition = Layer.ceiling
            
            ceiling.physicsBody = SKPhysicsBody(rectangleOf: ceiling.size,
                                                center: CGPoint(x: ceiling.size.width / 2,
                                                                y: ceiling.size.height ))
            ceiling.physicsBody?.categoryBitMask = PhysicsCategory.ceiling
            ceiling.physicsBody?.affectedByGravity = true
            ceiling.physicsBody?.isDynamic = false
            addChild(ceiling)
            
            let moveLeft = SKAction.moveBy(x: -ceilTexture.size().width, y: 0, duration: 3)
            let moveReset = SKAction.moveBy(x: ceilTexture.size().width, y: 0, duration: 0)
            let moveSequence = SKAction.sequence([moveLeft, moveReset])
            ceiling.run(SKAction.repeatForever(moveSequence))
        }
    }
    
    func setuptree(treeDistance:CGFloat) {
        // 스프라이트 생성
        let envAtlas = SKTextureAtlas(named: "Environment")
        let treeTexture = envAtlas.textureNamed("tree")
        
        let treeDown = SKSpriteNode(texture: treeTexture)
        treeDown.zPosition = Layer.tree
        treeDown.physicsBody = SKPhysicsBody(rectangleOf: treeTexture.size())
        treeDown.physicsBody?.categoryBitMask = PhysicsCategory.tree
        treeDown.physicsBody?.isDynamic = false
        
        let treeUp = SKSpriteNode(texture: treeTexture)
        treeUp.xScale = -1
        treeUp.zRotation = .pi
        treeUp.zPosition = Layer.tree
        treeUp.physicsBody = SKPhysicsBody(rectangleOf: treeTexture.size())
        treeUp.physicsBody?.categoryBitMask = PhysicsCategory.tree
        treeUp.physicsBody?.isDynamic = false
        
        let treeCollision = SKSpriteNode(color: UIColor.red,
                                         size: CGSize(width: 1, height: self.size.height))
        treeCollision.zPosition = Layer.tree
        treeCollision.physicsBody = SKPhysicsBody(rectangleOf: treeCollision.size)
        treeCollision.physicsBody?.categoryBitMask = PhysicsCategory.score
        treeCollision.physicsBody?.isDynamic = false
        treeCollision.name = "treeCollision"
        
        addChild(treeDown)
        addChild(treeUp)
        addChild(treeCollision)
        
        
        // 스프라이트 배치
        let max = self.size.height * 0.3
        let xPos = self.size.width + treeUp.size.width
        let yPos = CGFloat(arc4random_uniform(UInt32(max)))
            + envAtlas.textureNamed("land").size().height
        let endPos = self.size.width + (treeDown.size.width * 2)
        
        treeDown.position = CGPoint(x: xPos, y: yPos)
        treeUp.position = CGPoint(x: xPos,
                                  y: treeDown.position.y + treeDistance + treeUp.size.height)
        treeCollision.position = CGPoint(x: xPos, y: self.size.height / 2)
        
        let moveAct = SKAction.moveBy(x: -endPos, y: 0, duration: 6)
        let moveSeq = SKAction.sequence([moveAct, SKAction.removeFromParent()])
        treeDown.run(moveSeq)
        treeUp.run(moveSeq)
        treeCollision.run(moveSeq)
    }
    
    func createInfiniteTree(duration:TimeInterval) {
        let create = SKAction.run { [unowned self] in
            self.setuptree(treeDistance: 100)
        }
        
        let wait = SKAction.wait(forDuration: duration)
        let actSeq = SKAction.sequence([create, wait])
        run(SKAction.repeatForever(actSeq))
    }
    
    func createTutorial() {
        tutorial = SKSpriteNode(imageNamed: "tutorial")
        tutorial.position = CGPoint(x: self.size.width / 2, y: self.size.height / 1.5)
        tutorial.zPosition = Layer.tutorial
        addChild(tutorial)
    }
    

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        switch gameState {
        case .ready:
            gameState = .playing
            
            self.water.physicsBody?.isDynamic = true
            self.water.physicsBody?.applyImpulse(CGVector(dx: 0, dy: 10))
            self.createInfiniteTree(duration: 4)
            
            let fadeOut = SKAction.fadeOut(withDuration: 0.5)
            let wait = SKAction.wait(forDuration: 0.5)
            let remove = SKAction.removeFromParent()
            let actSequence = SKAction.sequence([fadeOut, wait, remove])
            self.tutorial.run(actSequence)
            
        case .playing:
            self.run(SoundFX.wing)
            self.water.physicsBody?.velocity = CGVector(dx: 0, dy: 0)
            self.water.physicsBody?.applyImpulse(CGVector(dx: 0, dy: 7))
        case .dead:
            let touch = touches.first
            if let location = touch?.location(in: self) {
                let nodesArray = self.nodes(at: location)
                if nodesArray.first?.name == "restartBtn" {
                    self.run(SoundFX.swooshing)
                    let scene = MenuScene(size: self.size)
                    let transition = SKTransition.doorsOpenHorizontal(withDuration: 1)
                    self.view?.presentScene(scene, transition: transition)
                } else if nodesArray.first?.name == "leaderboard" {
                    showLeaderboard()
                }
            }
        }
    }
    
    func didBegin(_ contact: SKPhysicsContact) {
        var collideBody = SKPhysicsBody()
        
        if contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask {
            collideBody = contact.bodyB
        } else {
            collideBody = contact.bodyA
        }
        
        let collideType = collideBody.categoryBitMask
        switch collideType {
        case PhysicsCategory.land:
            print("land!")
            if gameState == .playing {
                gameOver()
            }
        case PhysicsCategory.ceiling:
            print("ceiling!")
        case PhysicsCategory.tree:
            print("tree!")
            if gameState == .playing {
                gameOver()
            }
        case PhysicsCategory.score:
            score += 1
            self.run(SoundFX.point)
            print(score)
        default:
            break
        }
    }
    
    
    
    func spawnExplosion(spawnPosition: CGPoint){
           let explosion = SKSpriteNode(imageNamed: "explosion")
           explosion.position = spawnPosition
           explosion.zPosition = 4
           explosion.setScale(0)
           self.addChild(explosion)
           
           let scaleIn = SKAction.scale(to: 1, duration: 0.1)
           let fadeOut = SKAction.fadeOut(withDuration: 0.1)
           let delete = SKAction.removeFromParent()
           let explosionSequence = SKAction.sequence([scaleIn, fadeOut, delete])
           explosion.run(explosionSequence)
           
       }
    
    override func update(_ currentTime: TimeInterval) {
        let rotation = self.water.zRotation
        if rotation > 0 {
            self.water.zRotation = min(rotation, 0.7)
        } else {
            self.water.zRotation = max(rotation, -0.7)
        }
        
        if self.gameState == .dead {
            self.water.physicsBody?.velocity.dx = 0
        }
    }
    
    func gameOver() {
        damageEffect()
        cameraShake()
        
        self.water.removeAllActions()
        createGameoverBoard()
        
        self.bgmPlayer.run(SKAction.stop())
        
        self.gameState = .dead

    }
    
    func recordBestScore() {
        let userDefaults = UserDefaults.standard
        var bestScore = userDefaults.integer(forKey: "bestScore")
        
        if self.score > bestScore {
            bestScore = self.score
            userDefaults.set(bestScore, forKey: "bestScore")
        }
        userDefaults.synchronize()
    }
    
    func createGameoverBoard() {
        recordBestScore()
        updateLeaderboard()
        checkForAchievements()
        
        let gameoverBoard = SKSpriteNode(imageNamed: "gameoverBoard")
        gameoverBoard.position = CGPoint(x: self.size.width / 2,
                                         y: -gameoverBoard.size.height)
        gameoverBoard.zPosition = Layer.hud
        addChild(gameoverBoard)
        
     
        
        let scoreLabel = SKLabelNode(fontNamed: "neodgm")
        scoreLabel.fontSize = 13
        scoreLabel.fontColor = .white
        scoreLabel.text = "\(self.score)"
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.position = CGPoint(x: gameoverBoard.size.width * 0.35,
                                      y: gameoverBoard.size.height * 0.07)
        scoreLabel.zPosition = 0.1
        gameoverBoard.addChild(scoreLabel)
        
        let bestScore = UserDefaults.standard.integer(forKey: "bestScore")
        let bestScoreLabel = SKLabelNode(fontNamed: "neodgm")
        bestScoreLabel.fontSize = 13
        bestScoreLabel.fontColor = .white
        bestScoreLabel.text = "\(bestScore)"
        bestScoreLabel.horizontalAlignmentMode = .left
        bestScoreLabel.position = CGPoint(x: gameoverBoard.size.width * 0.35,
                                          y: -gameoverBoard.size.height * 0.07)
        bestScoreLabel.zPosition = 0.1
        gameoverBoard.addChild(bestScoreLabel)
        
        let restartBtn = SKSpriteNode(imageNamed: "playBtn")
        restartBtn.name = "restartBtn"
        restartBtn.position = CGPoint(x: 0, y: -gameoverBoard.size.height * 0.35)
        restartBtn.zPosition = 0.1
        gameoverBoard.addChild(restartBtn)
        
        
        
        gameoverBoard.run(SKAction.sequence([SKAction.moveTo(y: self.size.height / 2, duration: 1),
                                             SKAction.run { self.speed = 0 }]))
    }
    
    func damageEffect() {
        let flashNode = SKSpriteNode(color: UIColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 0.7),
                                     size: self.size)
        let actionSequence = SKAction.sequence([SKAction.wait(forDuration: 0.1),
                                                SKAction.removeFromParent()])
        flashNode.name = "flashNode"
        flashNode.position = CGPoint(x: self.size.width / 2, y: self.size.height / 2)
        flashNode.zPosition = Layer.hud
        addChild(flashNode)
        flashNode.run(actionSequence)
        
        let wait = SKAction.wait(forDuration: 1)
        let soundSequence = SKAction.sequence([SoundFX.hit, wait, SoundFX.die])
        run(soundSequence)
    }
    
    func cameraShake() {
        let moveLeft = SKAction.moveTo(x: self.size.width / 2 - 5, duration: 0.1)
        let moveRight = SKAction.moveTo(x: self.size.width / 2 + 5, duration: 0.1)
        let moveReset = SKAction.moveTo(x: self.size.width / 2, duration: 0.1)
        let shakeAction = SKAction.sequence([moveLeft, moveRight, moveLeft, moveRight, moveReset])
        shakeAction.timingMode = .easeInEaseOut
        self.cameraNode.run(shakeAction)
    }
    
    func createRain() {
        guard let rainField = SKEmitterNode(fileNamed: "rain") else { return }
        rainField.position = CGPoint(x: self.size.width / 2, y: self.size.height)
        rainField.zPosition = Layer.rain
        rainField.advanceSimulationTime(30)
        addChild(rainField)
    }
}

extension GameScene: GKGameCenterControllerDelegate {
    
    func showLeaderboard() {
        if GKLocalPlayer.local.isAuthenticated {
            let gameCenter = GKGameCenterViewController()
            
            gameCenter.gameCenterDelegate = self
            gameCenter.viewState = GKGameCenterViewControllerState.leaderboards
            
            if let gameViewController = self.view?.window?.rootViewController {
                gameViewController.show(gameCenter, sender: self)
                gameViewController.navigationController?.pushViewController(gameCenter, animated: true)
            }
        } else {
            print("Not logged in!")
        }
    }
    
    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true, completion: nil)
    }
    
    func updateLeaderboard() {
        if GKLocalPlayer.local.isAuthenticated {
            let leaderboardIdentifier = "net.qualitybits.FlappyBirdLikeBestScore"
            let bestScore = GKScore(leaderboardIdentifier: leaderboardIdentifier)
            let ingameBestScore = UserDefaults.standard.integer(forKey: "bestScore")
            bestScore.value = Int64(ingameBestScore)
            let scoreArray: [GKScore] = [bestScore]
            GKScore.report(scoreArray, withCompletionHandler: nil)
        }
    }
    
    func checkForAchievements() {
        if GKLocalPlayer.local.isAuthenticated {
            let ingameBestScore = UserDefaults.standard.integer(forKey: "bestScore")
            
            if ingameBestScore >= 10 {
                let identifier = "net.qualitybits.FlappyBirdLikePlatinum"
                let achieve = GKAchievement(identifier: identifier)
                achieve.showsCompletionBanner = true
                achieve.percentComplete = 100.0
                GKAchievement.report([achieve], withCompletionHandler: nil)
            } else if ingameBestScore >= 5 {
                let identifier = "net.qualitybits.FlappyBirdLikeGold"
                let achieve = GKAchievement(identifier: identifier)
                achieve.showsCompletionBanner = true
                achieve.percentComplete = 100.0
                GKAchievement.report([achieve], withCompletionHandler: nil)
            } else if ingameBestScore >= 3 {
                let identifier = "net.qualitybits.FlappyBirdLikeSilver"
                let achieve = GKAchievement(identifier: identifier)
                achieve.showsCompletionBanner = true
                achieve.percentComplete = 100.0
                GKAchievement.report([achieve], withCompletionHandler: nil)
            } else if ingameBestScore >= 1 {
                let identifier = "net.qualitybits.FlappyBirdLikeBronze"
                let achieve = GKAchievement(identifier: identifier)
                achieve.showsCompletionBanner = true
                achieve.percentComplete = 100.0
                GKAchievement.report([achieve], withCompletionHandler: nil)
            } else {
                return
            }
        }
    }
    
}
