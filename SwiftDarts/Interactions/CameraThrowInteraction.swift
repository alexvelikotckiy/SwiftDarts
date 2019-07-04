//
//  DartInteraction.swift
//  SwiftDarts
//
//  Created by Wilson on 4/21/19.
//  Copyright © 2019 Wilson. All rights reserved.
//

import Foundation
import SceneKit

class CameraThrowInteraction: Interaction, ThrowInteractionDelegate {
    weak var delegate: InteractionDelegate?
    
    // this is a dart that doesn't have physics
    private var dummyDart: SCNNode!
    
    var thrower: CameraThrower?
    
    var throwInteraction: ThrowInteraction? {
        didSet {
            // Add hook up to throwInteraction delegate automatically
            if let throwInteraction = throwInteraction {
                throwInteraction.throwDelegate = self
            }
        }
    }
    
    required init(delegate: InteractionDelegate) {
        self.delegate = delegate
        
        dummyDart = SCNNode.loadSCNAsset(modelFileName: "projectile_dart")
    }
    
    private func setProjectileOnThrower(_ thrower: Thrower, projectileType: ProjectileType) {
        guard let delegate = delegate else { fatalError("No delegate") }

        let projectile = TrailDartProjectile(prototypeNode: dummyDart.clone())
        projectile.isAlive = true
        projectile.team = thrower.team

        guard let physicsNode = projectile.physicsNode else { fatalError("Projectile has no physicsNode") }
        physicsNode.physicsBody = nil
        delegate.addNodeToLevel(physicsNode)

        guard let cameraThrower = thrower as? CameraThrower else { return }
        cameraThrower.setProjectileType(projectileType: projectileType, projectile: projectile.objectRootNode)
    }
    
    func didUpdateThrowers(throwers: [Int : Thrower]) {
        let myself = UserDefaults.standard.myself
        guard let cameraThrower = throwers.values.first(where: { $0.player == myself }) as? CameraThrower else { return }
        
        thrower = cameraThrower
        setProjectileOnThrower(cameraThrower, projectileType: .dart)
    }
    
    func canGrabAnyThrower(cameraRay: Ray) -> Bool {
        return thrower?.canThrow(cameraRay: cameraRay) ?? false
    }
    
    // MARK: - Interactions

    func update(cameraInfo: CameraInfo) {
        thrower?.update(cameraInfo: cameraInfo)
    }
    
    // MARK: - Game Action Handling
    
    func handle(gameAction: GameAction, player: Player) {
        switch gameAction {
        case .joinTeam(let team):
            handleJoinTeam(team: team, player: player)
        case .cameraThrowerRelease(let data):
            guard let delegate = delegate else { fatalError("No Delegate") }
            handleThrowRelease(data: data, player: player, delegate: delegate)
        default:
            return
        }
    }
    
    private func handleJoinTeam(team: Team, player: Player) {
        guard let delegate = delegate else { fatalError("No Delegate") }
        guard delegate.isServer else { return }
        
        let thrower = delegate.spawnCameraThrower()
        thrower.team = team
        thrower.player = player

        delegate.addNodeToLevel(thrower.objectRootNode)
        
        guard let interaction = throwInteraction else { fatalError("No interaction set") }

        setProjectileOnThrower(thrower, projectileType: .dart)
        interaction.addThrower(thrower)
        
        if player == delegate.currentPlayer {
            self.thrower = thrower
        }
    }
    
    private func handleThrowRelease(data: ThrowData, player: Player, delegate: InteractionDelegate) {
        guard let activeThrower = thrower,
            data.throwerID == activeThrower.index else { return }
        activeThrower.onLaunch(velocity: GameVelocity.zero)
        releaseThrower(thrower: activeThrower)
    }
    
    private func releaseThrower(thrower: CameraThrower) {
        guard let throwInteraction = throwInteraction else { fatalError("GrabInteraction not set") }
        thrower.isGrabbed = false
        throwInteraction.activeThrower = nil
    }

    // MARK: - Throw Interaction Delegate
    
    func shouldForceRelease(thrower: Thrower) -> Bool {
        return false
    }
    
    func onServerTryStartThrow(thrower: Thrower, cameraInfo: CameraInfo, player: Player) {
        guard let cameraThrower = thrower as? CameraThrower else { return }
        
        cameraThrower.onServerStartTryThrow() 
    }
    
    func onTrowStart(thrower: Thrower, cameraInfo: CameraInfo, player: Player) {
        guard let cameraThrower = thrower as? CameraThrower else { return }
        
        cameraThrower.onStartThrow()
    }
    
    func onServerRelease(thrower: Thrower, cameraInfo: CameraInfo, player: Player) {
        guard let delegate = delegate else { fatalError("No Delegate") }
        guard let cameraThrower = thrower as? CameraThrower else { return }
        
        // Launch
        guard let velocity = cameraThrower.tryGetLaunchVelocity(cameraInfo: cameraInfo) else { return }
        
        cameraThrower.onLaunch(velocity: velocity)
        throwDart(thrower: cameraThrower, velocity: velocity)
        cameraThrower.releaseGrab()
        
        releaseThrower(thrower: cameraThrower)
        
        let throwData = ThrowData(throwerID: cameraThrower.index, projectileType: cameraThrower.projectileType, velocity: velocity)
        
        // succeed in launching, notify all clients of the update
        delegate.serverDispatchActionToAll(gameAction: .cameraThrowerRelease(throwData))
    }
    
    func onUpdateThrowStatus(thrower: Thrower, cameraInfo: CameraInfo) {
        guard let cameraThrower = thrower as? CameraThrower else { return }
        cameraThrower.dartVisible = .visible
        cameraThrower.onGrab(cameraInfo)
    }
    
    // MARK: - Collision
    func didCollision(node: SCNNode, otherNode: SCNNode, pos: float3, impulse: CGFloat) {
        guard let delegate = delegate else { fatalError("No Delegate") }
        
        guard let gameObject = node.nearestParentGameObject(),
            let otherGameObject = otherNode.nearestParentGameObject(),
            let dart = gameObject as? TrailDartProjectile,
            let board = otherGameObject as? Board else { return }
        
        guard let physicsBody = dart.physicsBody else { fatalError("Dart has no physicsBody") }
        physicsBody.type = .static
        
        guard delegate.isServer else { return }
        
        guard let scoreValue = board.resolveScore(segment: otherNode) else { return }
        
        guard dart.isLanded == false else { return }
        dart.isLanded = true
        
        let score = Score(team: dart.team, value: scoreValue)
        let hitInfo = HitDart(dartID: dart.index, score: score)
        
        delegate.dispatchActionToServer(gameAction: .hitDart(hitInfo))
    }
    
    func throwDart(thrower: CameraThrower, velocity: GameVelocity) {
        guard let delegate = delegate else { fatalError("No delegate") }
        let newProjectile = delegate.spawnProjectile()
        newProjectile.team = thrower.team
        thrower.alignProjectile(newProjectile.objectRootNode)
        
        delegate.addNodeToLevel(newProjectile.objectRootNode)
        
        let poolCount = delegate.gameObjectPoolCount()
        let lifeTime = Double(poolCount) * thrower.coolDownTime

        newProjectile.launch(velocity: velocity, lifeTime: lifeTime, delegate: delegate.projectileDelegate)
    }
    
    func handleTouch(_ type: TouchType, camera: Ray) {
        
    }
}
