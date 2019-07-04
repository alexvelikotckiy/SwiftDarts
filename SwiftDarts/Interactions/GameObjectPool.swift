//
//  GameObjectPool.swift
//  SwiftDarts
//
//  Created by Wilson on 4/14/19.
//  Copyright © 2019 Wilson. All rights reserved.
//

import Foundation
import SceneKit

protocol GameObjectPoolDelegate: class {
    var gamedefinitions: [String: Any] { get }
    func onSpawnedProjectile()
    func onSpawnedCameraThrower()
}

// Pool that makes it possible for clients to join the game after a ball has been shot
// In this case, the pool helps manage fixed projectile slots used for physics sync.
// The pool do not actually reuse the object (that functionality could be added if necessary).
class GameObjectPool {
    private(set) var projectilePool = [Projectile]()
    private(set) var cameraThrowerPool = [CameraThrower]()
    
    private(set) var initialPoolCount = 0

    private let dart: SCNNode
    private let cameraThrower: SCNNode
    
    private weak var delegate: GameObjectPoolDelegate?
    weak var projectileDelegate: ProjectileDelegate?
    weak var cameraThrowerDelegate: CameraThrowerDelegate?

    init() {
        dart = SCNNode.loadSCNAsset(modelFileName: "projectile_dart")
        cameraThrower = SCNNode.loadSCNAsset(modelFileName: "CameraThrower")

        initialPoolCount = 30
    }

    func createPoolObjects(delegate: GameObjectPoolDelegate) {
        self.delegate = delegate
        for _ in 0..<initialPoolCount {
            let newProjectile = createProjectile(for: .dart, index: nil)
            projectilePool.append(newProjectile)
            
            let newCameraThrower = createCameraThrower(index: nil, team: .none, player: nil)
            cameraThrowerPool.append(newCameraThrower)
        }
    }
}

extension GameObjectPool {
    func spawnCameraThrower() -> CameraThrower {
        for cameraThrower in cameraThrowerPool where !cameraThrower.isAlive {
            return spawnCameraThrower(objectIndex: cameraThrower.index)
        }
        fatalError("No more free camera throwers in the pool")
    }
    
    func spawnCameraThrower(objectIndex: Int) -> CameraThrower {
        guard let delegate = delegate else { fatalError("No Delegate") }
        delegate.onSpawnedCameraThrower()
        
        for (poolIndex, thrower) in cameraThrowerPool.enumerated() where thrower.index == objectIndex {
            let newCameraThrower = createCameraThrower(index: thrower.index, team: thrower.team, player: thrower.player)
            newCameraThrower.isAlive = true
            cameraThrowerPool[poolIndex] = newCameraThrower
            newCameraThrower.delegate = cameraThrowerDelegate
            return newCameraThrower
        }
        fatalError("Could not find camera thrower with index: \(objectIndex)")
    }
    
    func despawnCameraThrower(_ thrower: CameraThrower) {
        thrower.disable()
    }
    
    func createCameraThrower(index: Int?, team: Team, player: Player?) -> CameraThrower {
        guard let delegate = delegate else { fatalError("No Delegate") }

        let thrower = CameraThrower(prototypeNode: cameraThrower, identifier: index,
                                    player: player, team: team, gamedefs: delegate.gamedefinitions)
        return thrower
    }
}

extension GameObjectPool {
    func spawnProjectile() -> Projectile {
        if projectilePool.first(where: { !$0.isAlive }) == nil {
            for _ in 0..<initialPoolCount {
                let newProjectile = createProjectile(for: .dart, index: nil)
                projectilePool.append(newProjectile)
            }
            initialPoolCount += initialPoolCount
        }
        
        for projectile in projectilePool where !projectile.isAlive {
            return spawnProjectile(objectIndex: projectile.index)
        }
        fatalError("No more free projectile in the pool")
    }
    
    // Spawn projectile with specific object index
    func spawnProjectile(objectIndex: Int) -> Projectile {
        guard let delegate = delegate else { fatalError("No Delegate") }
        delegate.onSpawnedProjectile()
        
        for (poolIndex, projectile) in projectilePool.enumerated() where projectile.index == objectIndex {
            let newProjectile = createProjectile(for: .dart, index: projectile.index)
            newProjectile.isAlive = true
            projectilePool[poolIndex] = newProjectile
            newProjectile.delegate = projectileDelegate
            newProjectile.onSpawn()
            return newProjectile
        }
        fatalError("Could not find projectile with index: \(objectIndex)")
    }
    
    func despawnProjectile(_ projectile: Projectile) {
        projectile.disable()
    }
    
    func createProjectile(for projectileType: ProjectileType, index: Int?) -> Projectile {
        guard let delegate = delegate else { fatalError("No Delegate") }
        
        let projectile: Projectile
        switch projectileType {
        case .dart:
            projectile = TrailDartProjectile(prototypeNode: dart, index: index, gamedefs: delegate.gamedefinitions)
        // Add other projectile types here as needed
        default:
            fatalError("Trying to get .none projectile")
        }
        projectile.addComponent(RemoveWhenFallenComponent())
        return projectile
    }
}
