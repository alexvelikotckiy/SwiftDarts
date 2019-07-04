//
//  GameManager.swift
//  SwiftDarts
//
//  Created by Wilson on 4/11/19.
//  Copyright © 2019 Wilson. All rights reserved.
//

import Foundation
import SceneKit
import GameplayKit
import simd
import AVFoundation
import os.signpost

struct GameState {
    var teamAScores = 0
    var teamBScores = 0
    
    mutating func add(_ score: Score) {
        switch score.team {
        case .none: break
        case .teamA: teamAScores += score.value
        case .teamB: teamBScores += score.value
        }
    }
}

extension GameState: BitStreamCodable {
    init(from bitStream: inout ReadableBitStream) throws {
        teamAScores = Int(try bitStream.readUInt32())
        teamBScores = Int(try bitStream.readUInt32())
    }
    
    func encode(to bitStream: inout WritableBitStream) {
        bitStream.appendUInt32(UInt32(teamAScores))
        bitStream.appendUInt32(UInt32(teamBScores))
    }
}

protocol GameManagerDelegate: class {
    func manager(_ manager: GameManager, received: BoardSetupAction, from: Player)
    func manager(_ manager: GameManager, joiningPlayer player: Player)
    func manager(_ manager: GameManager, leavingPlayer player: Player)
    func manager(_ manager: GameManager, joiningHost host: Player)
    func manager(_ manager: GameManager, leavingHost host: Player)
    func managerDidStartGame(_ manager: GameManager)
    func managerDidWinGame(_ manager: GameManager)
    func manager(_ manager: GameManager, hasNetworkDelay: Bool)
    func manager(_ manager: GameManager, updated gameState: GameState)
}

class GameManager: NSObject {
    // actions coming from the main thread/UI layer
    struct TouchEvent {
        var type: TouchType
        var camera: Ray
    }
    
    // interactions with the scene must be on the main thread
    let level: GameLevel
    private let scene: SCNScene
    private let levelNode: SCNNode
    
    // use this to access the simulation scaled camera
    private(set) var pointOfViewSimulation: SCNNode
    
    // these come from ARSCNView currentlys
    let physicsWorld: SCNPhysicsWorld
    private var pointOfView: SCNNode // can be in sim or render space
    
    private var gameBoard: GameBoard?
    private var tableBoxObject: GameObject?
    
    // should be the inverse of the level's world transform
    private var renderToSimulationTransform = float4x4.identity
    // don't execute any code from SCNView renderer until this is true
    private(set) var isInitialized = false
    
    // progress of the game
    private(set) var gameState = GameState()
    
    private var gamedefs: [String: Any]
    private var gameObjects = Set<GameObject>()      // keep track of all of our entities here
    private var gameCamera: GameCamera?
    private var gameLight: GameLight?
    
    private let session: NetworkSession?
    private let musicCoordinator: MusicCoordinator
    private let useWallClock: Bool
    
    private var gameCommands = [GameCommand]()
    private let commandsLock = NSLock()
    private var touchEvents = [TouchEvent]()
    private let touchEventsLock = NSLock()
    
    private var categories = [String: [GameObject]] ()  // this object can be used to group like items if their gamedefs include a category
    
    // Physics
    private let physicsSyncData = PhysicsSyncSceneData()
    private let gameObjectPool = GameObjectPool()
    private let interactionManager = InteractionManager()
    private let gameObjectManager = GameObjectManager()
    
    let currentPlayer = UserDefaults.standard.myself
    
    let isNetworked: Bool
    let isServer: Bool
    
    var isSolo: Bool {
        return isServer && !isNetworked
    }
    
    init(sceneView: SCNView, level: GameLevel, session: NetworkSession?,
         audioEnvironment: AVAudioEnvironmentNode?, musicCoordinator: MusicCoordinator) {
        
        // make our own scene instead of using the incoming one
        self.scene = sceneView.scene!
        self.physicsWorld = scene.physicsWorld
        physicsWorld.gravity = SCNVector3(0.0, -10, 0)
        
        // this is a node, that isn't attached to the ARSCNView
        self.pointOfView = sceneView.pointOfView!
        self.pointOfViewSimulation = pointOfView.clone()
        
        self.level = level
        
        self.session = session
        self.musicCoordinator = musicCoordinator
        self.useWallClock = UserDefaults.standard.synchronizeMusicWithWallClock
        
        // init entity system
        gamedefs = GameObject.loadGameDefs(file: "gameassets.scnassets/data/entities_def")
        
        // load the level if it wasn't already pre-loaded
        level.load()
        
        // start with a copy of the level, never change the originals, since we use original to reset
        self.levelNode = level.activeLevel!
        
        self.isNetworked = session != nil
        self.isServer = session?.isServer ?? true // Solo game act like a server
        
        super.init()
        
        self.session?.delegate = self
        physicsWorld.contactDelegate = self   // get notified of collisions
    }
    
    func unload() {
        physicsWorld.contactDelegate = nil
        levelNode.removeFromParentNode()
    }

    deinit {
        unload()
    }

    weak var delegate: GameManagerDelegate?

    func send(boardAction: BoardSetupAction) {
        session?.send(action: .boardSetup(boardAction))
    }

    func send(boardAction: BoardSetupAction, to player: Player) {
        session?.send(action: .boardSetup(boardAction), to: player)
    }

    func send(gameAction: GameAction) {
        session?.send(action: .gameAction(gameAction))
    }

    // MARK: - processing touches
    
    func handleTouch(_ type: TouchType) {
        guard !UserDefaults.standard.spectator else { return }
        touchEventsLock.lock(); defer { touchEventsLock.unlock() }
        touchEvents.append(TouchEvent(type: type, camera: lastCameraInfo.ray))
    }

    var lastCameraInfo = CameraInfo(transform: .identity)
    func updateCamera(cameraInfo: CameraInfo) {
        if gameCamera == nil {
            // need the real render camera in order to set rendering state
            let camera = pointOfView
            camera.name = "GameCamera"
            gameCamera = GameCamera(camera)
            _ = initGameObject(for: camera)

            gameCamera?.updateProps()
        }
        // transfer props to the current camera
        gameCamera?.transferProps()

        interactionManager.updateAll(cameraInfo: cameraInfo)
        lastCameraInfo = cameraInfo
    }

    // MARK: - inbound from network
    private func process(command: GameCommand) {
        os_signpost(.begin, log: .render_loop, name: .process_command, signpostID: .render_loop,
                    "Action : %s", command.action.description)
        defer { os_signpost(.end, log: .render_loop, name: .process_command, signpostID: .render_loop,
                            "Action : %s", command.action.description) }

        switch command.action {
        case .gameAction(let gameAction):
            switch gameAction {
            case .physics(let physicsData):
                physicsSyncData.receive(packet: physicsData)
            case .hitDart(let info):
                guard isServer else { return }
                gameState.add(info.score)
                
                os_log(.info, "Sending new gameState %s", "\(gameState)")
                dispatchActionToAll(gameAction: .gameState(gameState))
                
            case .gameState(let state):
                os_log(.info, "Setting new gameState %s", "\(gameState)")
                gameState = state
                delegate?.manager(self, updated: gameState)
                
            case .joinTeam:
                guard isServer else { return }
                guard let player = command.player else { return }
                
                dispatchToPlayer(gameAction: .gameState(gameState), player: player)
                fallthrough
            default:
                guard let player = command.player else { return }
                interactionManager.handle(gameAction: gameAction, from: player)
            }
        case .boardSetup(let boardAction):
            if let player = command.player {
                delegate?.manager(self, received: boardAction, from: player)
            }
        case .startGameMusic(let timeData):
            // Start music at the correct place.
            if let player = command.player {
                handleStartGameMusic(timeData, from: player)
            }
        }
    }
        
    // MARK: update
    // Called from rendering loop once per frame
    /// - Tag: GameManager-update
    func update(timeDelta: TimeInterval) {
        processCommandQueue()
        processTouches()
        syncPhysics()

        gameObjectManager.update(deltaTime: timeDelta)

        for entity in gameObjects {
            entity.update(deltaTime: timeDelta)
        }
    }

    private func processCommandQueue() {
        // retrieving the command should happen with the lock held, but executing
        // it should be outside the lock.
        // inner function lets us take advantage of the defer keyword
        // for lock management.
        func nextCommand() -> GameCommand? {
            commandsLock.lock(); defer { commandsLock.unlock() }
            if gameCommands.isEmpty {
                return nil
            } else {
                return gameCommands.removeFirst()
            }
        }

        while let command = nextCommand() {
            process(command: command)
        }
    }

    private func processTouches() {
        func nextTouch() -> TouchEvent? {
            touchEventsLock.lock(); defer { touchEventsLock.unlock() }
            if touchEvents.isEmpty {
                return nil
            } else {
                return touchEvents.removeFirst()
            }
        }

        while let touch = nextTouch() {
            process(touch)
        }
    }

    private func process(_ touch: TouchEvent) {
        interactionManager.handleTouch(touch.type, camera: touch.camera)
    }

    func queueAction(gameAction: GameAction) {
        commandsLock.lock(); defer { commandsLock.unlock() }
        gameCommands.append(GameCommand(player: currentPlayer, action: .gameAction(gameAction)))
    }

    private func syncPhysics() {
        // TODO: sync physics
        os_signpost(.begin, log: .render_loop, name: .physics_sync, signpostID: .render_loop,
                    "Physics sync started")
        defer { os_signpost(.end, log: .render_loop, name: .physics_sync, signpostID: .render_loop,
                            "Physics sync finished") }

        if isNetworked && physicsSyncData.isInitialized {
            if isServer {
                let physicsData = physicsSyncData.generateData()
                session?.send(action: .gameAction(.physics(physicsData)))
            } else {
                physicsSyncData.updateFromReceivedData()
            }
        }
    }

    // Status for SceneViewController to query and display UI interaction
    func canGrabACatapult(cameraRay: Ray) -> Bool {
        guard let throwInteraction = interactionManager.interaction(ofType: CameraThrowInteraction.self) else {
            return false
        }
        return throwInteraction.canGrabAnyThrower(cameraRay: cameraRay)
    }

    func isCurrentPlayerGrabbingADart() -> Bool {
        if let throwInteraction = interactionManager.interaction(ofType: ThrowInteraction.self),
            let thrower = throwInteraction.activeThrower,
            thrower as? CameraThrower != nil {
            return true
        }
        return false
    }

    // Configures the node from the level to be placed on the provided board.
    func addLevel(to node: SCNNode, gameBoard: GameBoard) {
        self.gameBoard = gameBoard

        level.placeLevel(on: node, gameScene: scene, boardScale: gameBoard.scale.x)

        // Initialize table box object
        createTableTopOcclusionBox(level: levelNode)

        updateRenderTransform()

        if let activeLevel = level.activeLevel {
            fixLevelsOfDetail(activeLevel)
        }
    }

    func fixLevelsOfDetail(_ node: SCNNode) {
        // set screenSpacePercent to 0 for high-poly lod always,
        // or to much greater than 1 for low-poly lod always
        let screenSpacePercent: Float = 0.15
        var screenSpaceRadius = SCNNode.computeScreenSpaceRadius(screenSpacePercent: screenSpacePercent)

        // The lod system doesn't account for camera being scaled
        // so do it ourselves.  Here we remove the scale.
        screenSpaceRadius /= level.lodScale

        let showLOD = UserDefaults.standard.showLOD
        node.fixLevelsOfDetail(screenSpaceRadius: screenSpaceRadius, showLOD: showLOD)
    }

    // call this if the level moves from AR changes or user moving/scaling it
    func updateRenderTransform() {
        guard let gameBoard = self.gameBoard else { return }

        // Scale level to normalized scale (1 unit wide) for rendering
        let levelNodeTransform = float4x4(scale: level.normalizedScale)
        renderToSimulationTransform = levelNodeTransform.inverse * gameBoard.simdWorldTransform.inverse
    }

    // Initializes all the objects and interactions for the game, and prepares
    // to process user input.
    func start() {
        // Now we initialize all the game objects and interactions for the game.

        // reset the index that we assign to GameObjects.
        // test to make sure no GameObjects are built prior
        // also be careful that the server increments the counter for new nodes
        GameObject.resetIndexCounter()
        categories = [String: [GameObject]]()

        initializeGameObjectPool()

        initializeLevel()
        initBehaviors()

        // Initialize interactions that add objects to the level
        initializeInteractions()

        physicsSyncData.delegate = self

        // Start advertising game
        if let session = session, session.isServer {
            session.startAdvertising()
        }

        delegate?.managerDidStartGame(self)

        startGameMusicEverywhere()

        isInitialized = true
    }

    func releaseLevel() {
        level.reset()
    }

    func initBehaviors() {
        // after everything is setup, add the behaviors if any
        for gameObject in gameObjects {
            for component in gameObject.components(conformingTo: PhysicsBehaviorComponent.self) {
                component.initBehavior(levelRoot: levelNode, world: physicsWorld)
            }
        }
    }

    // MARK: - Table Occlusion
    // Create an opaque object representing the table used to occlude falling objects
    private func createTableTopOcclusionBox(level: SCNNode) {
        guard let tableBoxNode = scene.rootNode.childNode(withName: "OcclusionBox", recursively: true) else {
            fatalError("Table node not found")
        }

        // make a table object so we can attach audio component to it
        tableBoxObject = initGameObject(for: tableBoxNode)
    }

    // MARK: - Initialize Game Functions

    // Walk all the nodes looking for actual objects.
    private func enumerateHierarchy(_ node: SCNNode, teamName: String? = nil) {
        // If the node has no name or a name does not contain
        // a type identifier, we look at its children.
        guard let name = node.name, let type = node.typeIdentifier else {
            for child in node.childNodes {
                enumerateHierarchy(child, teamName: teamName)
            }
            return
        }

        configure(node: node, name: name, type: type, team: teamName)
    }

    private func configure(node: SCNNode, name: String, type: String, team: String?) {
        // For nodes with types, we create at most one gameObject, configured
        // based on the node type.

        // only report team blocks
        if team != nil {
            os_log(.debug, "configuring %s on team %s", name, team!)
        }

        switch type {
        case "GameBoard":
            let gameObject = Board(node, gamedefs: [:])
            
            if gameObject.physicsNode != nil {
                physicsSyncData.addObject(gameObject)
            }
            
        case "OcclusionBox":
            // don't add a game object, but don't visit it either
            return
            
        case "ShadowLight":
            if gameLight == nil {
                node.name = "GameLight"
                let light = initGameObject(for: node)
                gameObjects.insert(light)
                gameLight = GameLight(node)
                gameLight?.updateProps()
            }
            gameLight?.transferProps()
            return
            
        default:
            // This handles all other objects
            // All special functionality is defined in entities_def.json file
            
            let gameObject = initGameObject(for: node)
            
            // add to network synchronization code
            if gameObject.physicsNode != nil {
                physicsSyncData.addObject(gameObject)

                gameObject.addComponent(RemoveWhenFallenComponent())
            }
            if gameObject.categorize {
                if categories[gameObject.category] == nil {
                    categories[gameObject.category] = [GameObject]()
                }
                categories[gameObject.category]!.append(gameObject)
            }
        }
    }

    // set the world at rest
    func restWorld() {
        for gameObject in gameObjects {
            if let physicsNode = gameObject.physicsNode,
                let physBody = physicsNode.physicsBody,
                gameObject != tableBoxObject,
                physBody.allowsResting {
                physBody.setResting(true)
            }
        }
    }

    // TODO: Invest the whole process
    private func postUpdateHierarchy(_ node: SCNNode) {
        if let nameRestore = node.value(forKey: "nameRestore") as? String {
            node.name = nameRestore
        }

        for child in node.childNodes {
            postUpdateHierarchy(child)
        }
    }

    private func initializeGameObjectPool() {
        gameObjectPool.projectileDelegate = self
        gameObjectPool.createPoolObjects(delegate: self)

        // GameObjectPool has a fixed number of items which we need to add to physicsSyncData and gameObjectManager
        for projectile in gameObjectPool.projectilePool {
            physicsSyncData.addProjectile(projectile)
            gameObjectManager.addProjectile(projectile)
            setupAudioComponent(for: projectile)
        }
        
        for cameraThrower in gameObjectPool.cameraThrowerPool {
            physicsSyncData.addCameraThrower(cameraThrower)
            setupAudioComponent(for: cameraThrower)
        }
    }

    private func setupAudioComponent(for object: GameObject) {
        // TODO
    }

    private func initializeLevel() {
        enumerateHierarchy(levelNode)

        // do post init functions here
        postUpdateHierarchy(levelNode)
    }

    private func initializeInteractions() {
        //Throw interaction
        let throwInteraction = ThrowInteraction(delegate: self)
        interactionManager.addInteraction(throwInteraction)
        
        //Camera Throw Interaction
        let cameraThrowInteraction = CameraThrowInteraction(delegate: self)
        cameraThrowInteraction.throwInteraction = throwInteraction
        interactionManager.addInteraction(cameraThrowInteraction)
    }

    // MARK: - Physics scaling
    func copySimulationCamera() {
        // copy the POV camera to minimize the need to lock, this is right after ARKit updates it in
        // the render thread, and before we scale the actual POV camera for rendering
        pointOfViewSimulation.simdWorldTransform = pointOfView.simdWorldTransform
    }

    func scaleCameraToRender() {
        pointOfView.simdWorldTransform = renderToSimulationTransform * pointOfView.simdWorldTransform
    }

    func scaleCameraToSimulation() {
        pointOfView.simdWorldTransform = pointOfViewSimulation.simdWorldTransform
    }

    func renderSpacePositionToSimulationSpace(pos: float3) -> float3 {
        return (renderToSimulationTransform * float4(pos, 1.0)).xyz
    }

    func renderSpaceTransformToSimulationSpace(transform: float4x4) -> float4x4 {
        return renderToSimulationTransform * transform
    }

    func simulationSpacePositionToRenderSpace(pos: float3) -> float3 {
        return (renderToSimulationTransform.inverse * float4(pos, 1.0)).xyz
    }

    func initGameObject(for node: SCNNode) -> GameObject {
        let gameObject = GameObject(node: node, index: nil, gamedefs: gamedefs, alive: true, server: isServer)

        gameObjects.insert(gameObject)
        setupAudioComponent(for: gameObject)
        return gameObject
    }

    // after collision we care about is detected, we check for any collision related components and process them
    func didCollision(nodeA: SCNNode, nodeB: SCNNode, pos: float3, impulse: CGFloat) {
        // let any collision handling components on nodeA respond to the collision with nodeB

        if let entity = nodeA.nearestParentGameObject() {
            for collisionHandler in entity.components(conformingTo: CollisionHandlerComponent.self) {
                collisionHandler.didCollision(manager: self, node: nodeA, otherNode: nodeB, pos: pos, impulse: impulse)
            }
        }

        // let any collision handling components in nodeB respond to the collision with nodeA
        if let entity = nodeB.nearestParentGameObject() {
            for collisionHandler in entity.components(conformingTo: CollisionHandlerComponent.self) {
                collisionHandler.didCollision(manager: self, node: nodeB, otherNode: nodeA, pos: pos, impulse: impulse)
            }
        }

        interactionManager.didCollision(nodeA: nodeA, nodeB: nodeB, pos: pos, impulse: impulse)
    }

    func didBeginContact(nodeA: SCNNode, nodeB: SCNNode, pos: float3, impulse: CGFloat) {
        interactionManager.didCollision(nodeA: nodeA, nodeB: nodeB, pos: pos, impulse: impulse)
    }

    func onDidApplyConstraints(renderer: SCNSceneRenderer) {
        gameObjectManager.onDidApplyConstraints(renderer: renderer)
    }

    /// Start the game music on the server device and all connected
    /// devices
    func startGameMusicEverywhere() {
        // TODO: Start music
    }
    
    func handleStartGameMusic(_ timeData: StartGameMusicTime, from player: Player) {
        // TODO: handleStartGameMusic
    }
}

extension GameManager: ProjectileDelegate {
    func despawnProjectile(_ projectile: Projectile) {
        gameObjectPool.despawnProjectile(projectile)
    }
    
    func addParticles(_ particlesNode: SCNNode, worldPosition: float3) {
        levelNode.addChildNode(particlesNode)
        particlesNode.simdWorldPosition = worldPosition
    }
    
    func addNodeToLevel(node: SCNNode) {
        levelNode.addChildNode(node)
    }
}

extension GameManager: PhysicsSyncSceneDataDelegate {
    func playPhysicsSound(objectIndex: Int, soundEvent: CollisionAudioSampler.CollisionEvent) {
        // TODO: Find the correct GameObject and play the collision sound
    }
    
    func hasNetworkDelayStatusChanged(hasNetworkDelay: Bool) {
        delegate?.manager(self, hasNetworkDelay: hasNetworkDelay)
    }
    
    func spawnProjectile(objectIndex: Int) -> Projectile {
        let projectile = gameObjectPool.spawnProjectile(objectIndex: objectIndex)
        projectile.delegate = self

        levelNode.addChildNode(projectile.objectRootNode)
        gameObjectManager.replaceProjectile(projectile)
        return projectile
    }
    
    func spawnCameraThrower(objectIndex: Int, team: Team, playerID: String) -> CameraThrower {
        let thrower = gameObjectPool.spawnCameraThrower(objectIndex: objectIndex)
        thrower.delegate = self
        thrower.team = team
        
        let myself = UserDefaults.standard.myself
        if playerID == myself.username {
            thrower.player = myself
        }
        
        guard let throwInteraction = interactionManager.interaction(ofType: ThrowInteraction.self) else {
            fatalError("ThrowInteraction has not been initialized")
        }
        throwInteraction.addThrower(thrower)
        
        levelNode.addChildNode(thrower.objectRootNode)
        return thrower
    }
    
    func despawnCameraThrower(_ object: CameraThrower) {
        gameObjectPool.despawnCameraThrower(object)
    }
}

extension GameManager: GameObjectPoolDelegate {
    func onSpawnedCameraThrower() {
        
    }
    
    var gamedefinitions: [String: Any] { return gamedefs }
    
    func onSpawnedProjectile() {

    }
}

extension GameManager: NetworkSessionDelegate {
    func networkSession(_ session: NetworkSession, received command: GameCommand) {
        commandsLock.lock(); defer { commandsLock.unlock() }
        // Check if the action received is used to setup the board
        // If so, process it and don't wait for the next update cycle to unqueue the event
        // The GameManager is paused at that time of joining a game
        if case Action.boardSetup(_) = command.action {
            process(command: command)
        } else {
            gameCommands.append(command)
        }
    }
    
    func networkSession(_ session: NetworkSession, joining player: Player) {
        if player == session.host {
            delegate?.manager(self, joiningHost: player)
        } else {
            delegate?.manager(self, joiningPlayer: player)
        }
    }
    
    func networkSession(_ session: NetworkSession, leaving player: Player) {
        // TODO: Think about removing throwers of a leaving player
        if player == session.host {
            delegate?.manager(self, leavingHost: player)
        } else {
            delegate?.manager(self, leavingPlayer: player)
        }
    }
}

extension GameManager: CameraThrowerDelegate {
    func cameraThrowerDidBeginGrap(_ cameraThrower: CameraThrower) {
        
    }
    
    func cameraThrowerDidMove(_ cameraThrower: CameraThrower) {
        
    }
    
    func cameraThrowerDidLaunch(_ cameraThrower: CameraThrower) {
        
    }
}

extension GameManager: InteractionDelegate {
    
    var projectileDelegate: ProjectileDelegate { return self }
    
    func playWinSound() {
        delegate?.managerDidWinGame(self)
    }

    func startGameMusic(from interaction: Interaction) {
        os_log(.debug, "time to start the game music")
        startGameMusicEverywhere()
    }

    func removeAllPhysicsBehaviors() {
        physicsWorld.removeAllBehaviors()
    }
    
    func addInteraction(_ interaction: Interaction) {
        interactionManager.addInteraction(interaction)
    }
    
    func addNodeToLevel(_ node: SCNNode) {
        levelNode.addChildNode(node)
    }
    
    func spawnProjectile() -> Projectile {
        let projectile = gameObjectPool.spawnProjectile()
        physicsSyncData.replaceProjectile(projectile)
        gameObjectManager.replaceProjectile(projectile)
        // It would be better to use a preallocated audio sampler here if
        // loading a new one takes too long. But it appears ok for now...
        setupAudioComponent(for: projectile)
        return projectile
    }
    
    func spawnCameraThrower() -> CameraThrower {
        let cameraThrower = gameObjectPool.spawnCameraThrower()
        physicsSyncData.replaceCameraThrower(cameraThrower)
        setupAudioComponent(for: cameraThrower)
        return cameraThrower
    }
    
    func gameObjectPoolCount() -> Int { return gameObjectPool.initialPoolCount }
    
    func dispatchActionToServer(gameAction: GameAction) {
        if isServer {
            queueAction(gameAction: gameAction)
        } else {
            send(gameAction: gameAction) // send to host
        }
    }
    
    func dispatchActionToAll(gameAction: GameAction) {
        queueAction(gameAction: gameAction)
        send(gameAction: gameAction)
    }
    
    func serverDispatchActionToAll(gameAction: GameAction) {
        if isServer {
            send(gameAction: gameAction)
        }
    }
    
    func dispatchToPlayer(gameAction: GameAction, player: Player) {
        if currentPlayer == player {
            queueAction(gameAction: gameAction)
        } else {
            session?.send(action: .gameAction(gameAction), to: player)
        }
    }
}

extension GameManager: SCNPhysicsContactDelegate {
    func physicsWorld(_ world: SCNPhysicsWorld, didEnd contact: SCNPhysicsContact) {
        self.didCollision(nodeA: contact.nodeA, nodeB: contact.nodeB,
                          pos: float3(contact.contactPoint), impulse: contact.collisionImpulse)
    }
    
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        self.didBeginContact(nodeA: contact.nodeA, nodeB: contact.nodeB,
                             pos: float3(contact.contactPoint), impulse: contact.collisionImpulse)
    }
}
