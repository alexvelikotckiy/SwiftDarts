//
//  GameLevel.swift
//  SwiftDarts
//
//  Created by Wilson on 4/14/19.
//  Copyright © 2019 Wilson. All rights reserved.
//

import Foundation
import SceneKit

private let levelsPath = "gameassets.scnassets/levels/"
private let defaultSize = CGSize(width: 2, height: 2)
private let defaultLevelName = "default"

class GameLevel {
    
    struct Definition: Codable {
        let key: String
        let identifier: String
    }
    
    static let defaultLevel = GameLevel(definition: Definition(key: "default", identifier: "level_default"))
    
    private let definition: Definition
    var key: String { return definition.key }
    var identifier: String { return definition.identifier }
    
    // Size of the level in meters
    let targetSize: CGSize
    
    private(set) var placed = false
    
    private var scene: SCNScene?
    private var levelNodeTemplate: SCNNode?
    private var levelNodeClone: SCNNode?
    private var lock = NSLock()
    
    private(set) var lodScale: Float = 1.0
    
    var path: String { return levelsPath + identifier }
    
    func load() {
        // have to do this
        lock.lock(); defer { lock.unlock() }
        
        // only load once - can be called from preload on another thread, or regular load
        if scene != nil {
            return
        }
        
        guard let sceneUrl = Bundle.main.url(forResource: path, withExtension: "scn") else {
            fatalError("Level \(path) not found")
        }
        do {
            let scene = try SCNScene(url: sceneUrl, options: nil)
            
            // start with animations and physics paused until the board is placed
            // we don't want any animations or things falling over while ARSceneView
            // is driving SceneKit and the view.
            scene.isPaused = true
            
            // walk down the scenegraph and update the children
            scene.rootNode.fixMaterials()
            
            self.scene = scene
            
            // this may not be the root, but lookup the identifier
            // will clone the tree done from this node
            levelNodeTemplate = scene.rootNode.childNode(withName: "_" + identifier, recursively: true)
            
        } catch {
            fatalError("Could not load level \(sceneUrl): \(error.localizedDescription)")
        }
    }
    
    // an instance of the active level
    var activeLevel: SCNNode? {
        guard let levelNode = levelNodeTemplate else { return nil }
        
        if let levelNodeClone = levelNodeClone {
            return levelNodeClone
        }
        
        levelNodeClone = levelNode.clone()
        return levelNodeClone
    }
    
    // Scale factor to assign to the level to make it appear 1 unit wide.
    var normalizedScale: Float {
        guard let levelNode = levelNodeTemplate else { return 1.0 }
        let levelSize = levelNode.horizontalSize.x
        guard levelSize > 0 else {
            fatalError("Level size is 0. This might indicate something is wrong with the assets")
        }
        return 1 / levelSize
    }
    
    private init(definition: Definition) {
        self.definition = definition
        self.targetSize = defaultSize
    }
    
    func reset() {
        placed = false
        levelNodeClone = nil
    }
    
    func placeLevel(on node: SCNNode, gameScene: SCNScene, boardScale: Float) {
        guard let activeLevel = activeLevel else { return }
        guard let scene = scene else { return }
        
        // set the environment onto the SCNView
        gameScene.lightingEnvironment.contents = scene.lightingEnvironment.contents
        gameScene.lightingEnvironment.intensity = scene.lightingEnvironment.intensity
        
        // set the cloned nodes representing the active level
        node.addChildNode(activeLevel)
        
        placed = true
        
        // the lod system doesn't honor the scaled camera,
        // so have to fix this manually in fixLevelsOfDetail with inverse scale
        // applied to the screenSpaceRadius
        lodScale = normalizedScale * boardScale
    }
}
