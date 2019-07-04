//
//  GameObjectManager.swift
//  SwiftDarts
//
//  Created by Wilson on 4/14/19.
//  Copyright © 2019 Wilson. All rights reserved.
//

import Foundation
import SceneKit

class GameObjectManager {

    // MARK: - Projectile Management

    private var projectiles = [Projectile]()

    func addProjectile(_ projectile: Projectile) {
        projectiles.append(projectile)
    }

    func replaceProjectile(_ projectile: Projectile) {
        for (arrayIndex, oldProjectile) in projectiles.enumerated() where oldProjectile.index == projectile.index {
            projectiles[arrayIndex] = projectile
            return
        }
        fatalError("Cannot find the projectile to replace \(projectile.index)")
    }

    func didBeginContactAll(contact: SCNPhysicsContact) {
        for projectile in projectiles {
            projectile.didBeginContact(contact: contact)
        }
    }

    // MARK: - Shared Management
    func update(deltaTime: TimeInterval) {
        for projectile in projectiles {
            projectile.update(deltaTime: deltaTime)
        }
    }

    func onDidApplyConstraints(renderer: SCNSceneRenderer) {
        for projectile in projectiles {
            projectile.onDidApplyConstraints(renderer: renderer)
        }
    }
}
