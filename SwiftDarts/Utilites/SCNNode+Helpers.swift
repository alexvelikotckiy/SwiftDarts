//
//  SCNNode+Helpers.swift
//  SwiftDarts
//
//  Created by Wilson on 4/12/19.
//  Copyright © 2019 Wilson. All rights reserved.
//

import Foundation
import SceneKit
import os.log

extension SCNTransaction {
    static func animate(duration: TimeInterval,
                        animations: (() -> Void)) {
        animate(duration: duration, animations: animations, completion: nil)
    }
    static func animate(duration: TimeInterval,
                        animations: (() -> Void),
                        completion: (() -> Void)? = nil) {
        lock(); defer { unlock() }
        begin(); defer { commit() }
        
        animationDuration = duration
        completionBlock = completion
        animations()
    }
}

extension SCNNode {
    
    var gameObject: GameObject? {
        get { return entity as? GameObject }
        set { entity = newValue }
    }
    
    func nearestParentGameObject() -> GameObject? {
        if let result = gameObject { return result }
        if let parent = parent { return parent.nearestParentGameObject() }
        return nil
    }
    
    var team: Team {
        var parent = self.parent
        while let current = parent {
            if current.name == "_teamA" {
                return .teamA
            } else if current.name == "_teamB" {
                return .teamB
            }
            parent = current.parent
        }
        return .none
    }
    
    var typeIdentifier: String? {
        if let name = name, !name.hasPrefix("_") {
            return name.split(separator: "_").first.map { String($0) }
        } else {
            return nil
        }
    }
    
    // Returns the size of the horizontal parts of the node's bounding box.
    // x is the width, y is the depth.
    var horizontalSize: float2 {
        let (minBox, maxBox) = simdBoundingBox
        
        // Scene is y-up, horizontal extent is calculated on x and z
        let sceneWidth = abs(maxBox.x - minBox.x)
        let sceneLength = abs(maxBox.z - minBox.z)
        return float2(sceneWidth, sceneLength)
    }
    
    var simdBoundingBox: (min: float3, max: float3) {
        get { return (float3(boundingBox.min), float3(boundingBox.max)) }
        set { boundingBox = (min: SCNVector3(newValue.min), max: SCNVector3(newValue.max)) }
    }

    static func loadSCNAsset(modelFileName: String) -> SCNNode {
        let assetPaths = [
            "gameassets.scnassets/models/",
            "gameassets.scnassets/entities/",
            "gameassets.scnassets/blocks/",
            "gameassets.scnassets/projectiles/",
            "gameassets.scnassets/catapults/",
            "gameassets.scnassets/levels/",
            "gameassets.scnassets/effects/"
        ]
        
        let assetExtensions = [
            "scn",
            "scnp"
        ]
        
        var nodeRefSearch: SCNReferenceNode?
        for path in assetPaths {
            for ext in assetExtensions {
                if let url = Bundle.main.url(forResource: path + modelFileName, withExtension: ext) {
                    nodeRefSearch = SCNReferenceNode(url: url)
                    if nodeRefSearch != nil { break }
                }
            }
            if nodeRefSearch != nil { break }
        }
        
        guard let nodeRef = nodeRefSearch else {
            fatalError("couldn't load \(modelFileName)")
        }
        
        // this does the load, default policy is load immediate
        nodeRef.load()
        
        // log an error if geo not nested under a physics shape
        guard let node = nodeRef.childNodes.first else {
            fatalError("model \(modelFileName) has no child nodes")
        }
        if nodeRef.childNodes.count > 1 {
            os_log(.error, "model %s should have a single root node", modelFileName)
        }
        
        // walk down the scenegraph and update all children
        node.fixMaterials()
        
        return node
    }
    
    func findNodeWithPhysicsBody() -> SCNNode? {
        return findNodeWithPhysicsBodyHelper(node: self)
    }
    
    func findNodeWithGeometry() -> SCNNode? {
        return findNodeWithGeometryHelper(node: self)
    }
    
    private func findNodeWithPhysicsBodyHelper(node: SCNNode) -> SCNNode? {
        if node.physicsBody != nil {
            return node
        }
        for child in node.childNodes {
            if shouldContinueSpecialNodeSearch(node: child) {
                if let childWithPhysicsBody = findNodeWithPhysicsBodyHelper(node: child) {
                    return childWithPhysicsBody
                }
            }
        }
        return nil
    }
    
    private func findNodeWithGeometryHelper(node: SCNNode) -> SCNNode? {
        if node.geometry != nil {
            return node
        }
        for child in node.childNodes {
            if shouldContinueSpecialNodeSearch(node: child) {
                if let childWithGeosBody = findNodeWithGeometryHelper(node: child) {
                    return childWithGeosBody
                }
            }
            
        }
        return nil
    }
    
    private func shouldContinueSpecialNodeSearch(node: SCNNode) -> Bool {
        // end geo + physics search when a system collection is found
        if let isEndpoint = node.value(forKey: "isEndpoint") as? Bool, isEndpoint {
            return false
        }
        
        return true
    }
}
