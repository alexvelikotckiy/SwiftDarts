//
//  Interaction.swift
//  SwiftDarts
//
//  Created by Wilson on 4/11/19.
//  Copyright © 2019 Wilson. All rights reserved.
//

import Foundation
import SceneKit
import ARKit

enum InteractionState: Int, Codable {
    case began, update, ended
}

enum TouchType {
    case tapped
    case began
    case ended
}

protocol InteractionDelegate: class {
    var currentPlayer: Player { get }
    var physicsWorld: SCNPhysicsWorld { get }
    var projectileDelegate: ProjectileDelegate { get }
    var isServer: Bool { get }

    func addNodeToLevel(_ node: SCNNode)
    func spawnProjectile() -> Projectile
    func spawnCameraThrower() -> CameraThrower
    func gameObjectPoolCount() -> Int
    func removeAllPhysicsBehaviors()

    func addInteraction(_ interaction: Interaction)

    func dispatchActionToServer(gameAction: GameAction)
    func dispatchActionToAll(gameAction: GameAction) // including self
    func serverDispatchActionToAll(gameAction: GameAction)
    func dispatchToPlayer(gameAction: GameAction, player: Player)

    func playWinSound()
    func startGameMusic(from interaction: Interaction)
}

protocol Interaction: class {
    init(delegate: InteractionDelegate)
    
    func update(cameraInfo: CameraInfo)
    
    // MARK: - Handle Inputs
    func handleTouch(_ type: TouchType, camera: Ray)
    
    // MARK: - Handle Action
    func handle(gameAction: GameAction, player: Player)
    
    // MARK: - Handle Collision
    func didCollision(node: SCNNode, otherNode: SCNNode, pos: float3, impulse: CGFloat)
}

extension Interaction {
    
    func update(cameraInfo: CameraInfo) {
        
    }
    
    // MARK: - Handle Action
    func handle(gameAction: GameAction, player: Player) {
        
    }
    
    // MARK: - Handle Collision
    func didCollision(node: SCNNode, otherNode: SCNNode, pos: float3, impulse: CGFloat) {
        
    }
}
