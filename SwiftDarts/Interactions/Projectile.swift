//
//  Projectile.swift
//  SwiftDarts
//
//  Created by Wilson on 4/11/19.
//  Copyright © 2019 Wilson. All rights reserved.
//

import Foundation
import SceneKit

enum ProjectileType: UInt32, CaseIterable {
    case none = 0
    case dart
    
    var next: ProjectileType {
        switch self {
        case .none: return .dart
        case .dart: return .dart
        }
    }
}

protocol ProjectileDelegate: class {
    var isServer: Bool { get }
    func addParticles(_ particlesNode: SCNNode, worldPosition: float3)
    func despawnProjectile(_ projectile: Projectile)
    func addNodeToLevel(node: SCNNode)
}

class Projectile: GameObject {
    var physicsBody: SCNPhysicsBody?
    
    var team: Team = .none

    weak var delegate: ProjectileDelegate?

    private var startTime: TimeInterval = 0.0
    var isLaunched = false
    var isLanded = false
    var age: TimeInterval { return isLaunched ? (GameTime.time - startTime) : 0.0 }

    // Projectile life time should be set so that projectiles will not be depleted from the pool
    private var lifeTime: TimeInterval = 0.0
    private let fadeTimeToLifeTimeRatio = 0.1
    private var fadeStartTime: TimeInterval { return lifeTime * (1.0 - fadeTimeToLifeTimeRatio) }

    init(prototypeNode: SCNNode, index: Int?, gamedefs: [String: Any]) {
        let node = prototypeNode.clone()
        // geometry and materials are reference types, so here we
        // do a deep copy. that way, each projectile gets its own color.
        node.copyGeometryAndMaterials()

        guard let physicsNode = node.findNodeWithPhysicsBody(),
            let physicsBody = physicsNode.physicsBody else {
                fatalError("Projectile node has no physics")
        }

        super.init(node: node, index: index, gamedefs: gamedefs, alive: false, server: false)
        self.physicsNode = physicsNode
        self.physicsBody = physicsBody
    }

    convenience init(prototypeNode: SCNNode) {
        self.init(prototypeNode: prototypeNode, index: nil, gamedefs: [String: Any]())
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func launch(velocity: GameVelocity, lifeTime: TimeInterval, delegate: ProjectileDelegate) {
        startTime = GameTime.time
        isLaunched = true
        self.lifeTime = lifeTime
        self.delegate = delegate

        if let physicsNode = physicsNode,
            let physicsBody = physicsBody {
            
            physicsBody.simdVelocity = velocity.vector
            physicsNode.name = "dart"
            physicsNode.simdWorldPosition = velocity.origin
            physicsBody.resetTransform()
            physicsBody.continuousCollisionDetectionThreshold = 0.001
        } else {
            fatalError("Projectile not setup")
        }
    }

    func onDidApplyConstraints(renderer: SCNSceneRenderer) {}

    func didBeginContact(contact: SCNPhysicsContact) {

    }

    func onSpawn() {

    }
    
    // TODO: Resolve if dart should disappear after a while
    override func update(deltaTime: TimeInterval) {
        super.update(deltaTime: deltaTime)
    }

    func despawn() {
        guard let delegate = delegate else { fatalError("No Delegate") }
        delegate.despawnProjectile(self)
    }

    override func generatePhysicsData() -> PhysicsNodeData? {
        guard var data = super.generatePhysicsData() else { return nil }
        data.team = team
        return data
    }
}
