//
//  ARWorldMap+Helpers.swift
//  SwiftDarts
//
//  Created by Wilson on 4/14/19.
//  Copyright © 2019 Wilson. All rights reserved.
//

import ARKit

extension ARWorldMap {
    var boardAnchor: BoardAnchor? {
        return anchors.compactMap { $0 as? BoardAnchor }.first
    }
    
    var keyPositionAnchors: [KeyPositionAnchor] {
        return anchors.compactMap { $0 as? KeyPositionAnchor }
    }
}
