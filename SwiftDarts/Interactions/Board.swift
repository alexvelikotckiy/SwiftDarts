//
//  Board.swift
//  SwiftDarts
//
//  Created by Wilson on 6/20/19.
//  Copyright © 2019 Wilson. All rights reserved.
//

import Foundation
import simd
import SceneKit

struct BoardSegmentProps {
    var segment = "segment"
    
    var inner = "inner"
    var outer = "outer"
    var ringInner = "inner_ring"
    var ringOuter = "outer_ring"
    var centerInner = "center_inner"
    var centerOuter = "center_outer"
}

class Board: GameObject {
    
    var segmentProps = BoardSegmentProps()
    
    init(_ node: SCNNode, gamedefs: [String: Any]) {
        super.init(node: node, index: nil, gamedefs: gamedefs, alive: true, server: false)
        
        let segments = node.childNodes { node, _ -> Bool in
            guard let _  = node.typeIdentifier else {
                return true
            }
            return false
        }
        
        segments.forEach { node in
            guard let physicsBody = node.physicsBody else {
                return
            }
            physicsBody.categoryBitMask = CollisionMask([.board]).rawValue
            physicsBody.contactTestBitMask = CollisionMask([.projectile]).rawValue
            physicsBody.collisionBitMask = CollisionMask([.projectile]).rawValue
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func resolveScore(segment: SCNNode) -> Int? {
        guard isSegment(segment),
            containNode(segment) else { return nil }
        
        guard let name = segment.name else { return nil }
        
        let result = Int(name.westernArabicNumeralsOnly) ?? 0
        
        switch true {
        case name.contains(segmentProps.inner):
            return result
        case name.contains(segmentProps.outer):
            return result
        case name.contains(segmentProps.ringInner):
            return result * 3
        case name.contains(segmentProps.ringOuter):
            return result * 2
        case name.contains(segmentProps.centerInner):
            return 50
        case name.contains(segmentProps.centerOuter):
            return 25
        default:
            return nil
        }
    }
    
    private func isSegment(_ node: SCNNode) -> Bool {
        guard let name = node.name, name.hasPrefix("_") else { return false }
        return name.split(separator: "_").first.map { String($0) } == segmentProps.segment
    }
    
    private func containNode(_ node: SCNNode) -> Bool {
        guard let name = node.name else { return false }
        return objectRootNode.childNode(withName: name, recursively: true) != nil
    }
}

private extension String {
    var westernArabicNumeralsOnly: String {
        let pattern = UnicodeScalar("0")..."9"
        return String(unicodeScalars
            .compactMap { pattern ~= $0 ? Character($0) : nil })
    }
}
