//
//  RemoveWhenFallenComponent.swift
//  SwiftDarts
//
//  Created by Wilson on 4/20/19.
//  Copyright © 2019 Wilson. All rights reserved.
//

import GameplayKit
import os.log

class RemoveWhenFallenComponent: GKComponent {
    override func update(deltaTime seconds: TimeInterval) {
        guard GameTime.frameCount % 6 != 0 else { return }
        guard let gameObject = entity as? GameObject else { return }
        guard let physicsNode = gameObject.physicsNode else { return }
        // check past min/max bounds
        // the border was chosen experimentally to see what feels good
        
        //TODO: Resolve min/max defs for board bounces
        let minBounds = float3(-1000.0, -30.0, -1000.0) // -10.0 represents 1.0 meter high table
        let maxBounds = float3(1000.0, 1000.0, 1000.0)
        let position = physicsNode.presentation.simdWorldPosition
        
        // this is only checking position, but bounds could be offset or bigger
        let shouldRemove = min(position, minBounds) != minBounds ||
            max(position, maxBounds) != maxBounds
        if shouldRemove {
            os_log(.debug, "removing node at %s", "\(position)")
            gameObject.disable()
        }
    }
}
